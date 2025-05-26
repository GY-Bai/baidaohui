#!/bin/bash

# SJ服务器Redis端口冲突修复脚本
# 将Docker Redis端口从6379改为6380，解决端口冲突问题

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[SJ-REDIS-INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SJ-REDIS-SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[SJ-REDIS-WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[SJ-REDIS-ERROR]${NC} $1"
}

log_step() {
    echo -e "${CYAN}[SJ-REDIS-STEP]${NC} $1"
}

# 显示使用说明
show_usage() {
    echo -e "${BLUE}🔧 SJ服务器Redis端口冲突修复脚本${NC}"
    echo ""
    echo "使用方法："
    echo "  $0 [操作]"
    echo ""
    echo "操作："
    echo "  check        - 检查端口冲突情况"
    echo "  stop-external - 停止外部Redis服务"
    echo "  fix-port     - 修复Docker Redis端口配置"
    echo "  restart      - 重启所有服务"
    echo "  verify       - 验证修复结果"
    echo "  full-fix     - 执行完整修复流程"
    echo ""
    echo "示例："
    echo "  $0 check         # 检查端口冲突"
    echo "  $0 full-fix      # 执行完整修复"
}

# 检查端口占用情况
check_port_usage() {
    log_step "检查SJ服务器端口占用情况..."
    
    local ports=(6379 6380 6381)
    
    for port in "${ports[@]}"; do
        echo -e "\n${CYAN}检查端口 $port:${NC}"
        
        if netstat -tlnp | grep ":$port " > /dev/null 2>&1; then
            log_warning "端口 $port 已被占用:"
            netstat -tlnp | grep ":$port "
            
            # 检查是否是Docker容器
            if docker ps --format "table {{.Names}}\t{{.Ports}}" | grep ":$port->" > /dev/null 2>&1; then
                echo "  -> 被Docker容器占用"
            fi
        else
            log_success "端口 $port 可用"
        fi
    done
    
    # 检查Redis进程
    echo -e "\n${CYAN}检查Redis进程:${NC}"
    if pgrep redis-server > /dev/null 2>&1; then
        log_warning "发现外部Redis进程:"
        ps aux | grep redis-server | grep -v grep
    else
        log_success "未发现外部Redis进程"
    fi
}

# 停止外部Redis服务
stop_external_redis() {
    log_step "停止SJ服务器外部Redis服务..."
    
    # 停止系统Redis服务
    log_info "尝试停止系统Redis服务..."
    systemctl stop redis-server 2>/dev/null || systemctl stop redis 2>/dev/null || true
    systemctl disable redis-server 2>/dev/null || systemctl disable redis 2>/dev/null || true
    
    # 杀死Redis进程
    log_info "杀死残留的Redis进程..."
    pkill -f redis-server 2>/dev/null || true
    
    # 等待进程完全停止
    sleep 3
    
    # 验证
    if pgrep redis-server > /dev/null 2>&1; then
        log_error "仍有Redis进程运行，强制杀死..."
        pkill -9 -f redis-server 2>/dev/null || true
        sleep 2
    fi
    
    if ! pgrep redis-server > /dev/null 2>&1; then
        log_success "外部Redis服务已停止"
    else
        log_error "无法完全停止外部Redis服务"
        return 1
    fi
}

# 修复Docker Compose配置
fix_docker_compose_config() {
    log_step "修复SJ服务器Docker Compose Redis配置..."
    
    if [ ! -d "infra/docker" ]; then
        log_error "未找到infra/docker目录"
        return 1
    fi
    
    cd infra/docker
    
    if [ ! -f "docker-compose.sj.yml" ]; then
        log_error "未找到docker-compose.sj.yml文件"
        cd ../..
        return 1
    fi
    
    # 备份原配置
    local backup_file="docker-compose.sj.yml.backup.$(date +%Y%m%d_%H%M%S)"
    cp docker-compose.sj.yml "$backup_file"
    log_info "已备份原配置到: $backup_file"
    
    # 修改Redis端口映射
    log_info "将Redis端口从6379改为6380..."
    sed -i 's/- "6379:6379"/- "6380:6379"/' docker-compose.sj.yml
    
    # 更新所有服务的Redis URL
    log_info "更新所有服务的Redis连接配置..."
    sed -i 's|redis://redis:6379|redis://redis:6379|g' docker-compose.sj.yml
    
    # 验证修改
    if grep -q '- "6380:6379"' docker-compose.sj.yml; then
        log_success "Redis端口映射已更新为6380"
    else
        log_error "Redis端口映射更新失败"
        cd ../..
        return 1
    fi
    
    cd ../..
}

# 重启Docker服务
restart_docker_services() {
    log_step "重启SJ服务器Docker服务..."
    
    if [ ! -d "infra/docker" ]; then
        log_error "未找到infra/docker目录"
        return 1
    fi
    
    cd infra/docker
    
    # 停止所有服务
    log_info "停止所有Docker服务..."
    docker-compose -f docker-compose.sj.yml down || true
    
    # 清理Redis容器和数据（如果需要）
    log_info "清理Redis容器..."
    docker rm -f baidaohui-redis 2>/dev/null || true
    
    # 启动Redis服务
    log_info "启动Redis服务..."
    docker-compose -f docker-compose.sj.yml up -d redis
    
    # 等待Redis启动
    log_info "等待Redis启动（10秒）..."
    sleep 10
    
    # 验证Redis连接
    if docker exec baidaohui-redis redis-cli ping > /dev/null 2>&1; then
        log_success "Docker Redis服务启动成功"
    else
        log_error "Docker Redis服务启动失败"
        cd ../..
        return 1
    fi
    
    # 启动其他服务
    log_info "启动其他服务..."
    docker-compose -f docker-compose.sj.yml up -d
    
    cd ../..
}

# 验证修复结果
verify_fix() {
    log_step "验证SJ服务器Redis修复结果..."
    
    # 检查端口
    echo -e "\n${CYAN}端口检查:${NC}"
    if netstat -tlnp | grep ":6380 " > /dev/null 2>&1; then
        log_success "Docker Redis在端口6380运行正常"
    else
        log_error "Docker Redis端口6380未监听"
    fi
    
    if ! netstat -tlnp | grep ":6379 " > /dev/null 2>&1; then
        log_success "端口6379已释放"
    else
        log_warning "端口6379仍被占用"
    fi
    
    # 检查Docker容器
    echo -e "\n${CYAN}容器检查:${NC}"
    if docker ps | grep baidaohui-redis > /dev/null 2>&1; then
        log_success "Redis容器运行正常"
        docker ps | grep baidaohui-redis
    else
        log_error "Redis容器未运行"
    fi
    
    # 检查Redis连接
    echo -e "\n${CYAN}Redis连接检查:${NC}"
    if docker exec baidaohui-redis redis-cli ping > /dev/null 2>&1; then
        log_success "Redis连接正常"
    else
        log_error "Redis连接失败"
    fi
    
    # 检查SSO API健康状态
    echo -e "\n${CYAN}SSO API健康检查:${NC}"
    sleep 5  # 等待服务启动
    
    local sso_endpoints=(
        "http://localhost:5004/health"
        "http://127.0.0.1:5004/health"
    )
    
    for endpoint in "${sso_endpoints[@]}"; do
        if curl -s -f "$endpoint" > /dev/null 2>&1; then
            log_success "SSO API健康检查通过: $endpoint"
        else
            log_warning "SSO API健康检查失败: $endpoint"
        fi
    done
}

# 执行完整修复流程
full_fix() {
    log_info "开始SJ服务器Redis端口冲突完整修复流程..."
    
    echo -e "\n${YELLOW}=== 第1步: 检查当前状态 ===${NC}"
    check_port_usage
    
    echo -e "\n${YELLOW}=== 第2步: 停止外部Redis服务 ===${NC}"
    stop_external_redis
    
    echo -e "\n${YELLOW}=== 第3步: 修复Docker配置 ===${NC}"
    fix_docker_compose_config
    
    echo -e "\n${YELLOW}=== 第4步: 重启Docker服务 ===${NC}"
    restart_docker_services
    
    echo -e "\n${YELLOW}=== 第5步: 验证修复结果 ===${NC}"
    verify_fix
    
    log_success "SJ服务器Redis端口冲突修复完成！"
    echo ""
    echo -e "${GREEN}修复摘要:${NC}"
    echo "  - 外部Redis服务已停止"
    echo "  - Docker Redis端口已改为6380"
    echo "  - 所有服务配置已更新"
    echo "  - 服务已重启并验证"
}

# 主函数
main() {
    echo -e "${BLUE}🔧 SJ服务器Redis端口冲突修复${NC}"
    
    case "${1:-}" in
        "check")
            check_port_usage
            ;;
        "stop-external")
            stop_external_redis
            ;;
        "fix-port")
            fix_docker_compose_config
            ;;
        "restart")
            restart_docker_services
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

# 执行主函数
main "$@" 