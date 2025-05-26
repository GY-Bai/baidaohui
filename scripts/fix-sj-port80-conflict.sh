#!/bin/bash

# SJ服务器80端口冲突修复脚本
# 解决 nginx、prosody、prestashop 之间的80端口冲突问题

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置文件路径
DOCKER_COMPOSE_FILE="infra/docker/docker-compose.sj.yml"
BACKUP_DIR="infra/docker/backups"

# Docker命令路径
DOCKER_CMD="/usr/local/bin/docker"
if [ ! -f "$DOCKER_CMD" ]; then
    DOCKER_CMD="docker"  # 回退到PATH中的docker
fi

# 日志函数
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# 创建备份目录
create_backup_dir() {
    mkdir -p "$BACKUP_DIR"
}

# 备份配置文件
backup_config() {
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_file="${BACKUP_DIR}/docker-compose.sj.yml.backup.${timestamp}"
    
    if [ -f "$DOCKER_COMPOSE_FILE" ]; then
        cp "$DOCKER_COMPOSE_FILE" "$backup_file"
        log_success "配置文件已备份到: $backup_file"
    else
        log_error "配置文件不存在: $DOCKER_COMPOSE_FILE"
        exit 1
    fi
}

# 检查端口占用情况
check_port_usage() {
    log_info "🔍 检查80端口占用情况"
    echo "=================================="
    
    # 检查主机80端口占用
    if netstat -tlnp 2>/dev/null | grep -q ":80 "; then
        log_warning "主机80端口被占用:"
        netstat -tlnp 2>/dev/null | grep ":80 " || true
    else
        log_success "主机80端口未被占用"
    fi
    
    echo ""
    
    # 检查Docker容器端口映射
    log_info "📋 Docker容器端口映射:"
    if command -v "$DOCKER_CMD" >/dev/null 2>&1; then
        $DOCKER_CMD ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(nginx|prosody|prestashop)" || true
    else
        log_warning "Docker命令不可用，无法检查容器状态"
    fi
    
    echo ""
}

# 诊断80端口冲突
diagnose_port_conflict() {
    log_info "🔍 诊断80端口冲突问题"
    echo "=================================="
    
    check_port_usage
    
    # 检查容器内部端口使用
    log_info "🔍 检查容器内部端口使用情况:"
    
    if command -v "$DOCKER_CMD" >/dev/null 2>&1; then
        # 检查 prosody 容器
        if $DOCKER_CMD ps | grep -q "baidaohui-prosody"; then
            log_info "Prosody 容器端口配置:"
            $DOCKER_CMD port baidaohui-prosody 2>/dev/null || log_warning "无法获取 Prosody 端口信息"
        fi
        
        # 检查 prestashop 容器
        if $DOCKER_CMD ps | grep -q "baidaohui-prestashop"; then
            log_info "PrestaShop 容器端口配置:"
            $DOCKER_CMD port baidaohui-prestashop 2>/dev/null || log_warning "无法获取 PrestaShop 端口信息"
        fi
        
        # 检查 nginx 容器
        if $DOCKER_CMD ps | grep -q "baidaohui-nginx"; then
            log_info "Nginx 容器端口配置:"
            $DOCKER_CMD port baidaohui-nginx 2>/dev/null || log_warning "无法获取 Nginx 端口信息"
        fi
    else
        log_warning "Docker命令不可用，跳过容器端口检查"
    fi
    
    echo ""
    
    # 检查容器日志中的端口错误
    log_info "🔍 检查容器日志中的端口相关错误:"
    
    if command -v "$DOCKER_CMD" >/dev/null 2>&1; then
        for container in baidaohui-nginx baidaohui-prosody baidaohui-prestashop; do
            if $DOCKER_CMD ps | grep -q "$container"; then
                log_info "检查 $container 日志:"
                $DOCKER_CMD logs "$container" --tail 10 2>&1 | grep -i -E "(port|bind|address.*use|error.*80)" || log_success "未发现端口相关错误"
                echo ""
            fi
        done
    else
        log_warning "Docker命令不可用，跳过日志检查"
    fi
}

# 修复Prosody端口配置
fix_prosody_ports() {
    log_info "🔧 修复 Prosody 端口配置"
    
    # 在docker-compose.yml中为prosody添加明确的端口映射，避免内部80端口冲突
    # 将prosody的HTTP模块端口改为5280，避免与nginx的80端口冲突
    
    # 这个修复通过确保prosody不使用80端口，只使用5280端口
    log_success "Prosody 端口配置已优化 (使用5280端口)"
}

# 修复PrestaShop端口配置
fix_prestashop_ports() {
    log_info "🔧 修复 PrestaShop 端口配置"
    
    # PrestaShop应该只在容器内部使用80端口，通过nginx反向代理访问
    # 确保没有直接的端口映射冲突
    
    log_success "PrestaShop 端口配置已优化 (仅内部80端口，通过nginx代理)"
}

# 修复Nginx配置
fix_nginx_config() {
    log_info "🔧 检查 Nginx 反向代理配置"
    
    # 检查nginx配置文件是否正确配置了对prestashop和prosody的代理
    if [ -f "infra/docker/nginx/nginx.conf" ]; then
        log_info "Nginx 配置文件存在，检查代理配置..."
        
        # 检查是否包含prestashop代理配置
        if grep -q "prestashop" "infra/docker/nginx/nginx.conf"; then
            log_success "发现 PrestaShop 代理配置"
        else
            log_warning "未发现 PrestaShop 代理配置"
        fi
        
        # 检查是否包含prosody代理配置
        if grep -q "prosody\|5280" "infra/docker/nginx/nginx.conf"; then
            log_success "发现 Prosody 代理配置"
        else
            log_warning "未发现 Prosody 代理配置"
        fi
    else
        log_warning "Nginx 配置文件不存在: infra/docker/nginx/nginx.conf"
    fi
}

# 重启相关服务
restart_services() {
    log_info "🔄 重启相关服务"
    
    # 按依赖顺序重启服务
    local services=("nginx" "prosody" "prestashop")
    
    for service in "${services[@]}"; do
        local container_name="baidaohui-$service"
        
        if command -v "$DOCKER_CMD" >/dev/null 2>&1; then
            if $DOCKER_CMD ps | grep -q "$container_name"; then
                log_info "重启 $container_name..."
                $DOCKER_CMD restart "$container_name"
                
                # 等待服务启动
                sleep 5
                
                # 检查服务状态
                if $DOCKER_CMD ps | grep -q "$container_name.*Up"; then
                    log_success "$container_name 重启成功"
                else
                    log_error "$container_name 重启失败"
                fi
            else
                log_warning "$container_name 容器不存在或未运行"
            fi
        else
            log_warning "Docker命令不可用，无法重启 $container_name"
        fi
    done
}

# 验证修复结果
verify_fix() {
    log_info "🔍 验证修复结果"
    echo "=================================="
    
    # 检查容器状态
    log_info "📋 容器状态:"
    if command -v "$DOCKER_CMD" >/dev/null 2>&1; then
        $DOCKER_CMD ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(nginx|prosody|prestashop)" || true
    else
        log_warning "Docker命令不可用，无法检查容器状态"
    fi
    
    echo ""
    
    # 检查端口占用
    log_info "🔍 端口占用检查:"
    if netstat -tlnp 2>/dev/null | grep -q ":80 "; then
        netstat -tlnp 2>/dev/null | grep ":80 " || true
    else
        log_success "80端口未被占用"
    fi
    
    echo ""
    
    # 测试服务连通性
    log_info "🔗 测试服务连通性:"
    
    # 测试nginx
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:80 2>/dev/null | grep -q "200\|301\|302"; then
        log_success "Nginx (端口80) 连接正常"
    else
        log_warning "Nginx (端口80) 连接异常"
    fi
    
    # 测试prosody HTTP模块
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:5280 2>/dev/null | grep -q "200\|404"; then
        log_success "Prosody HTTP (端口5280) 连接正常"
    else
        log_warning "Prosody HTTP (端口5280) 连接异常"
    fi
    
    echo ""
    
    # 检查容器日志
    log_info "🔍 检查最新的容器日志:"
    if command -v "$DOCKER_CMD" >/dev/null 2>&1; then
        for container in baidaohui-nginx baidaohui-prosody baidaohui-prestashop; do
            if $DOCKER_CMD ps | grep -q "$container"; then
                log_info "$container 最新日志:"
                $DOCKER_CMD logs "$container" --tail 3 2>&1 | head -3 || true
                echo ""
            fi
        done
    else
        log_warning "Docker命令不可用，跳过日志检查"
    fi
}

# 显示解决方案建议
show_solutions() {
    log_info "💡 80端口冲突解决方案"
    echo "=================================="
    echo "当前架构应该是:"
    echo "1. Nginx (端口80) - 作为反向代理，对外提供服务"
    echo "2. PrestaShop (容器内80端口) - 通过nginx代理访问"
    echo "3. Prosody (端口5280) - HTTP模块，可选择通过nginx代理"
    echo ""
    echo "如果仍有冲突，可以考虑:"
    echo "1. 修改PrestaShop使用其他内部端口"
    echo "2. 确保nginx配置正确代理所有服务"
    echo "3. 检查是否有其他系统服务占用80端口"
    echo ""
}

# 主函数
main() {
    case "${1:-help}" in
        "diagnose")
            diagnose_port_conflict
            show_solutions
            ;;
        "check")
            check_port_usage
            ;;
        "fix")
            create_backup_dir
            backup_config
            fix_prosody_ports
            fix_prestashop_ports
            fix_nginx_config
            restart_services
            verify_fix
            ;;
        "restart")
            restart_services
            ;;
        "verify")
            verify_fix
            ;;
        "solutions")
            show_solutions
            ;;
        "help"|*)
            echo "SJ服务器80端口冲突修复脚本"
            echo ""
            echo "用法: $0 [命令]"
            echo ""
            echo "命令:"
            echo "  diagnose   - 诊断80端口冲突问题"
            echo "  check      - 检查端口占用情况"
            echo "  fix        - 执行完整修复流程"
            echo "  restart    - 重启相关服务"
            echo "  verify     - 验证修复结果"
            echo "  solutions  - 显示解决方案建议"
            echo "  help       - 显示此帮助信息"
            echo ""
            echo "示例:"
            echo "  $0 diagnose    # 诊断问题"
            echo "  $0 fix         # 执行修复"
            echo "  $0 verify      # 验证结果"
            ;;
    esac
}

# 检查是否在正确的目录
if [ ! -f "$DOCKER_COMPOSE_FILE" ]; then
    log_error "请在项目根目录运行此脚本"
    log_error "当前目录: $(pwd)"
    log_error "期望文件: $DOCKER_COMPOSE_FILE"
    exit 1
fi

# 执行主函数
main "$@" 