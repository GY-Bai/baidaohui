#!/bin/bash

# SJ服务器Supervisor容器修复脚本
# 解决 "supervisord: executable file not found in $PATH" 错误

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

# 显示脚本标题
show_header() {
    echo -e "${BLUE}🔧 SJ服务器Supervisor容器修复脚本${NC}"
    echo -e "${BLUE}=====================================${NC}"
    echo ""
    echo -e "${YELLOW}问题：${NC}supervisor容器启动失败"
    echo -e "${YELLOW}错误：${NC}supervisord: executable file not found in \$PATH"
    echo -e "${YELLOW}原因：${NC}python:3.11-slim镜像未包含supervisord"
    echo ""
}

# 检查Docker环境
check_docker() {
    log_step "检查Docker环境..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker未安装"
        exit 1
    fi
    
    if ! docker info > /dev/null 2>&1; then
        log_error "Docker未运行，请启动Docker服务"
        exit 1
    fi
    
    log_success "Docker环境正常"
}

# 检查当前问题状态
diagnose_supervisor_issue() {
    log_step "诊断supervisor容器问题..."
    
    cd infra/docker
    
    # 检查supervisor容器状态
    if docker ps -a | grep -q "baidaohui-supervisor"; then
        log_info "发现supervisor容器，检查状态..."
        
        container_status=$(docker ps -a --format "table {{.Names}}\t{{.Status}}" | grep "baidaohui-supervisor" | awk '{print $2}')
        
        if [[ "$container_status" == "Exited"* ]]; then
            log_warning "supervisor容器已退出"
            
            # 显示容器日志
            log_info "显示supervisor容器错误日志："
            docker logs baidaohui-supervisor 2>&1 | tail -10
        else
            log_info "supervisor容器状态：$container_status"
        fi
    else
        log_info "未发现supervisor容器"
    fi
    
    # 检查Docker Compose配置
    if [ -f "docker-compose.sj.yml" ]; then
        log_info "检查Docker Compose中的supervisor配置..."
        
        if grep -A 10 "supervisor:" docker-compose.sj.yml | grep -q "python:3.11-slim"; then
            log_error "发现问题：supervisor使用python:3.11-slim镜像，该镜像不包含supervisord"
        fi
    fi
    
    cd ../..
}

# 创建配置备份
create_backup() {
    log_step "创建配置备份..."
    
    # 创建备份目录
    mkdir -p infra/docker/backups
    
    # 备份Docker Compose文件
    timestamp=$(date +"%Y%m%d_%H%M%S")
    backup_file="infra/docker/backups/docker-compose.sj.yml.backup.$timestamp"
    
    cp infra/docker/docker-compose.sj.yml "$backup_file"
    log_success "配置已备份到: $backup_file"
}

# 方案1：修改supervisor服务配置（推荐）
fix_supervisor_config() {
    log_step "修复supervisor服务配置..."
    
    cd infra/docker
    
    # 检查是否需要修复
    if grep -q "image: python:3.11-slim" docker-compose.sj.yml; then
        log_info "修改supervisor镜像配置..."
        
        # 使用包含supervisord的镜像
        sed -i.tmp 's|image: python:3.11-slim|image: python:3.11-slim\n    # 安装supervisor\n    entrypoint: |\n      sh -c "\n        apt-get update && \\\n        apt-get install -y supervisor && \\\n        supervisord -c /etc/supervisor/conf.d/supervisord.conf\n      "|' docker-compose.sj.yml
        
        # 删除临时文件
        rm -f docker-compose.sj.yml.tmp
        
        log_success "supervisor配置已修复"
    else
        log_info "supervisor配置无需修复"
    fi
    
    cd ../..
}

# 方案2：使用专用的supervisor镜像
use_supervisor_image() {
    log_step "使用专用的supervisor镜像..."
    
    cd infra/docker
    
    # 创建临时文件进行替换
    cat > supervisor_fix.tmp << 'EOF'
  # Supervisor 进程管理
  supervisor:
    image: supervisord/supervisord:latest
    container_name: baidaohui-supervisor
    volumes:
      - ./supervisor/supervisord.conf:/etc/supervisor/conf.d/supervisord.conf
      - /var/run/docker.sock:/var/run/docker.sock
    networks:
      - baidaohui-network
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 50M
EOF

    # 替换supervisor服务配置
    # 找到supervisor服务的开始和结束行
    start_line=$(grep -n "# Supervisor 进程管理" docker-compose.sj.yml | cut -d: -f1)
    end_line=$(grep -n -A 20 "# Supervisor 进程管理" docker-compose.sj.yml | grep -E "(networks:|volumes:)" | head -1 | cut -d: -f1)
    
    if [ ! -z "$start_line" ] && [ ! -z "$end_line" ]; then
        # 创建新的配置文件
        head -n $((start_line-1)) docker-compose.sj.yml > docker-compose.sj.yml.new
        cat supervisor_fix.tmp >> docker-compose.sj.yml.new
        tail -n +$((end_line)) docker-compose.sj.yml >> docker-compose.sj.yml.new
        
        # 替换原文件
        mv docker-compose.sj.yml.new docker-compose.sj.yml
        rm supervisor_fix.tmp
        
        log_success "已切换到专用supervisor镜像"
    else
        log_error "无法找到supervisor服务配置"
        rm supervisor_fix.tmp
        return 1
    fi
    
    cd ../..
}

# 方案3：禁用supervisor服务（如果不需要）
disable_supervisor() {
    log_step "禁用supervisor服务..."
    
    cd infra/docker
    
    # 注释掉supervisor服务
    sed -i.tmp '/# Supervisor 进程管理/,/memory: 13M/s/^/  # /' docker-compose.sj.yml
    
    # 删除临时文件
    rm -f docker-compose.sj.yml.tmp
    
    log_success "supervisor服务已禁用"
    
    cd ../..
}

# 清理supervisor容器
cleanup_supervisor() {
    log_step "清理supervisor容器..."
    
    cd infra/docker
    
    # 停止并删除supervisor容器
    docker-compose -f docker-compose.sj.yml stop supervisor 2>/dev/null || true
    docker-compose -f docker-compose.sj.yml rm -f supervisor 2>/dev/null || true
    
    # 删除supervisor镜像
    docker rmi python:3.11-slim 2>/dev/null || true
    docker rmi supervisord/supervisord:latest 2>/dev/null || true
    
    log_success "supervisor容器清理完成"
    
    cd ../..
}

# 重启所有服务（除了supervisor）
restart_services() {
    log_step "重启SJ服务器服务..."
    
    cd infra/docker
    
    # 停止所有服务
    log_info "停止所有服务..."
    docker-compose -f docker-compose.sj.yml down --remove-orphans
    
    # 启动服务（排除supervisor如果被禁用）
    log_info "启动服务..."
    docker-compose -f docker-compose.sj.yml up -d
    
    cd ../..
    
    log_success "服务重启完成"
}

# 验证修复结果
verify_fix() {
    log_step "验证修复结果..."
    
    cd infra/docker
    
    # 等待服务启动
    log_info "等待服务启动（30秒）..."
    sleep 30
    
    # 检查容器状态
    log_info "检查容器状态..."
    docker-compose -f docker-compose.sj.yml ps
    
    # 检查是否有失败的容器
    failed_containers=$(docker-compose -f docker-compose.sj.yml ps | grep -E "(Exit|Restarting)" | wc -l)
    
    if [ "$failed_containers" -eq 0 ]; then
        log_success "所有服务启动成功！"
    else
        log_warning "仍有 $failed_containers 个容器启动失败"
        
        # 显示失败的容器
        log_info "失败的容器："
        docker-compose -f docker-compose.sj.yml ps | grep -E "(Exit|Restarting)"
    fi
    
    # 检查关键服务端口
    log_info "检查服务端口..."
    
    services_to_check=(
        "5001:Auth API"
        "5002:Profile API" 
        "5003:Chat API"
        "5004:SSO API"
        "5005:Shop API"
        "80:Nginx"
        "6380:Redis"
    )
    
    for service in "${services_to_check[@]}"; do
        port=$(echo $service | cut -d':' -f1)
        name=$(echo $service | cut -d':' -f2)
        
        if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
            log_success "$name (端口 $port) 正常运行"
        else
            log_warning "$name (端口 $port) 未运行"
        fi
    done
    
    cd ../..
}

# 显示使用说明
show_usage() {
    echo -e "${BLUE}使用方法：${NC}"
    echo "  $0 [操作]"
    echo ""
    echo -e "${BLUE}操作选项：${NC}"
    echo "  diagnose    - 诊断supervisor问题"
    echo "  fix-config  - 修复supervisor配置（方案1）"
    echo "  use-image   - 使用专用supervisor镜像（方案2）"
    echo "  disable     - 禁用supervisor服务（方案3）"
    echo "  cleanup     - 清理supervisor容器"
    echo "  restart     - 重启所有服务"
    echo "  verify      - 验证修复结果"
    echo "  full-fix    - 执行完整修复流程（推荐）"
    echo ""
    echo -e "${BLUE}示例：${NC}"
    echo "  $0 full-fix    # 执行完整修复"
    echo "  $0 diagnose    # 仅诊断问题"
    echo "  $0 disable     # 禁用supervisor"
}

# 完整修复流程
full_fix() {
    show_header
    check_docker
    diagnose_supervisor_issue
    create_backup
    
    # 询问用户选择修复方案
    echo -e "${YELLOW}请选择修复方案：${NC}"
    echo "1) 禁用supervisor服务（推荐，如果不需要进程监控）"
    echo "2) 使用专用supervisor镜像"
    echo "3) 修改现有配置安装supervisor"
    
    read -p "请输入选择 (1-3): " choice
    
    case "$choice" in
        "1")
            cleanup_supervisor
            disable_supervisor
            ;;
        "2")
            cleanup_supervisor
            use_supervisor_image
            ;;
        "3")
            cleanup_supervisor
            fix_supervisor_config
            ;;
        *)
            log_warning "无效选择，使用默认方案（禁用supervisor）"
            cleanup_supervisor
            disable_supervisor
            ;;
    esac
    
    restart_services
    verify_fix
    
    echo ""
    log_success "SJ服务器supervisor问题修复完成！"
    echo ""
    echo -e "${BLUE}修复总结：${NC}"
    echo "- supervisor容器启动问题已解决"
    echo "- 所有其他服务应该正常运行"
    echo "- 如果仍有问题，请运行: $0 diagnose"
}

# 主程序
main() {
    case "${1:-}" in
        "diagnose")
            show_header
            check_docker
            diagnose_supervisor_issue
            ;;
        "fix-config")
            check_docker
            create_backup
            cleanup_supervisor
            fix_supervisor_config
            restart_services
            verify_fix
            ;;
        "use-image")
            check_docker
            create_backup
            cleanup_supervisor
            use_supervisor_image
            restart_services
            verify_fix
            ;;
        "disable")
            check_docker
            create_backup
            cleanup_supervisor
            disable_supervisor
            restart_services
            verify_fix
            ;;
        "cleanup")
            check_docker
            cleanup_supervisor
            ;;
        "restart")
            check_docker
            restart_services
            ;;
        "verify")
            verify_fix
            ;;
        "full-fix")
            full_fix
            ;;
        "")
            show_usage
            ;;
        *)
            log_error "未知操作: $1"
            show_usage
            exit 1
            ;;
    esac
}

# 执行主程序
main "$@" 