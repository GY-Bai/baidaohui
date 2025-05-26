#!/bin/bash

# SJ服务器80端口冲突分析脚本
# 基于已知的容器状态信息分析80端口冲突问题

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# 分析容器端口配置
analyze_container_ports() {
    log_info "🔍 分析容器端口配置"
    echo "=================================="
    
    log_info "根据您提供的容器状态信息:"
    echo "NAMES                     STATUS          PORTS"
    echo "baidaohui-sso-api         Up 7 minutes    0.0.0.0:5004->5004/tcp"
    echo "baidaohui-nginx           Up 15 minutes   0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp"
    echo "baidaohui-auth-api        Up 15 minutes   0.0.0.0:5001->5001/tcp"
    echo "baidaohui-profile-api     Up 15 minutes   0.0.0.0:5002->5002/tcp"
    echo "baidaohui-celery-beat     Up 15 minutes   "
    echo "baidaohui-shop-api        Up 15 minutes   5005/tcp"
    echo "baidaohui-chat-api        Up 15 minutes   0.0.0.0:5003->5003/tcp"
    echo "baidaohui-celery-worker   Up 15 minutes   "
    echo "baidaohui-prosody         Up 15 minutes   80/tcp, 0.0.0.0:5222->5222/tcp, 0.0.0.0:5269->5269/tcp, 443/tcp, 5281/tcp, 5347/tcp, 0.0.0.0:5280->5280/tcp"
    echo "baidaohui-prestashop      Up 8 seconds    80/tcp"
    echo "baidaohui-prestashop-db   Up 18 minutes   3306/tcp, 33060/tcp"
    echo "baidaohui-redis           Up 18 minutes   0.0.0.0:6380->6379/tcp"
    
    echo ""
}

# 分析80端口冲突
analyze_port80_conflict() {
    log_info "🔍 80端口冲突分析"
    echo "=================================="
    
    log_info "端口80使用情况:"
    echo "1. baidaohui-nginx: 0.0.0.0:80->80/tcp (映射到主机80端口) ✅"
    echo "2. baidaohui-prosody: 80/tcp (仅容器内部使用) ⚠️"
    echo "3. baidaohui-prestashop: 80/tcp (仅容器内部使用) ⚠️"
    
    echo ""
    
    log_warning "潜在冲突分析:"
    echo "• Nginx 正确映射到主机80端口，作为反向代理"
    echo "• Prosody 在容器内部使用80端口，可能与其他服务冲突"
    echo "• PrestaShop 在容器内部使用80端口，可能与其他服务冲突"
    echo "• 虽然没有主机端口冲突，但容器内部可能存在端口竞争"
    
    echo ""
}

# 检查Docker Compose配置
check_docker_compose_config() {
    log_info "🔍 检查Docker Compose配置"
    echo "=================================="
    
    local compose_file="infra/docker/docker-compose.sj.yml"
    
    if [ -f "$compose_file" ]; then
        log_success "Docker Compose配置文件存在"
        
        # 检查nginx端口配置
        log_info "Nginx端口配置:"
        grep -A 3 -B 1 "ports:" "$compose_file" | grep -A 3 -B 1 "nginx" -A 5 || true
        
        echo ""
        
        # 检查prosody端口配置
        log_info "Prosody端口配置:"
        grep -A 10 "prosody:" "$compose_file" | grep -A 5 "ports:" || true
        
        echo ""
        
        # 检查prestashop端口配置
        log_info "PrestaShop端口配置:"
        grep -A 10 "prestashop:" "$compose_file" | grep -A 5 "ports:" || log_info "PrestaShop没有显式端口映射配置"
        
    else
        log_error "Docker Compose配置文件不存在: $compose_file"
    fi
    
    echo ""
}

# 检查Nginx配置
check_nginx_config() {
    log_info "🔍 检查Nginx反向代理配置"
    echo "=================================="
    
    local nginx_conf="infra/docker/nginx/nginx.conf"
    
    if [ -f "$nginx_conf" ]; then
        log_success "Nginx配置文件存在"
        
        # 检查upstream配置
        log_info "Upstream服务配置:"
        grep -A 1 "upstream" "$nginx_conf" || true
        
        echo ""
        
        # 检查server配置
        log_info "Server配置数量:"
        grep -c "server {" "$nginx_conf" && echo "个server块" || true
        
        echo ""
        
        # 检查PrestaShop代理配置
        if grep -q "prestashop" "$nginx_conf"; then
            log_success "发现PrestaShop代理配置"
            grep -A 5 -B 2 "prestashop" "$nginx_conf" | head -10
        else
            log_warning "未发现PrestaShop代理配置"
        fi
        
        echo ""
        
        # 检查Prosody代理配置
        if grep -q "prosody\|5280" "$nginx_conf"; then
            log_success "发现Prosody代理配置"
            grep -A 5 -B 2 "prosody\|5280" "$nginx_conf" | head -10
        else
            log_warning "未发现Prosody代理配置"
        fi
        
    else
        log_error "Nginx配置文件不存在: $nginx_conf"
    fi
    
    echo ""
}

# 提供解决方案
provide_solutions() {
    log_info "💡 80端口冲突解决方案"
    echo "=================================="
    
    echo "根据分析，当前架构存在以下问题:"
    echo ""
    
    log_warning "问题1: 容器内部端口冲突"
    echo "• Prosody和PrestaShop都在容器内使用80端口"
    echo "• 这可能导致Docker网络内部的端口冲突"
    echo ""
    
    log_info "解决方案1: 修改Prosody端口配置"
    echo "• 将Prosody的HTTP模块端口从80改为其他端口（如8080）"
    echo "• 更新nginx配置中的upstream prosody_http"
    echo "• 这样只有PrestaShop使用容器内80端口"
    echo ""
    
    log_info "解决方案2: 修改PrestaShop端口配置"
    echo "• 将PrestaShop的端口从80改为其他端口（如8080）"
    echo "• 更新nginx配置中的upstream prestashop"
    echo "• 这样只有Prosody使用容器内80端口"
    echo ""
    
    log_info "解决方案3: 使用不同的Docker网络"
    echo "• 将Prosody和PrestaShop放在不同的Docker网络中"
    echo "• 通过nginx进行路由和代理"
    echo ""
    
    log_success "推荐方案: 修改Prosody配置"
    echo "因为Prosody已经有5280端口用于HTTP模块，建议:"
    echo "1. 移除Prosody的80端口配置"
    echo "2. 确保nginx正确代理到prosody:5280"
    echo "3. 让PrestaShop独占容器内80端口"
    echo ""
}

# 生成修复脚本
generate_fix_script() {
    log_info "📝 生成修复脚本建议"
    echo "=================================="
    
    echo "建议的修复步骤:"
    echo ""
    echo "1. 备份当前配置:"
    echo "   cp infra/docker/docker-compose.sj.yml infra/docker/docker-compose.sj.yml.backup"
    echo ""
    echo "2. 修改Prosody配置，移除80端口:"
    echo "   编辑 docker-compose.sj.yml 中的 prosody 服务"
    echo "   移除 ports 中的 80/tcp 配置"
    echo ""
    echo "3. 验证nginx配置:"
    echo "   确保 nginx.conf 中 prosody_http upstream 指向 prosody:5280"
    echo ""
    echo "4. 重启服务:"
    echo "   docker-compose -f infra/docker/docker-compose.sj.yml restart prosody nginx"
    echo ""
    echo "5. 验证结果:"
    echo "   检查容器状态和端口映射"
    echo ""
}

# 主函数
main() {
    case "${1:-analyze}" in
        "analyze")
            analyze_container_ports
            analyze_port80_conflict
            check_docker_compose_config
            check_nginx_config
            provide_solutions
            ;;
        "solutions")
            provide_solutions
            generate_fix_script
            ;;
        "config")
            check_docker_compose_config
            check_nginx_config
            ;;
        "help"|*)
            echo "SJ服务器80端口冲突分析脚本"
            echo ""
            echo "用法: $0 [命令]"
            echo ""
            echo "命令:"
            echo "  analyze    - 完整分析80端口冲突问题（默认）"
            echo "  solutions  - 显示解决方案和修复建议"
            echo "  config     - 检查配置文件"
            echo "  help       - 显示此帮助信息"
            echo ""
            echo "示例:"
            echo "  $0 analyze     # 完整分析"
            echo "  $0 solutions   # 查看解决方案"
            echo "  $0 config      # 检查配置"
            ;;
    esac
}

# 执行主函数
main "$@" 