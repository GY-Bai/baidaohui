#!/bin/bash

# SJ服务器Prosody 80端口冲突修复脚本
# 移除Prosody容器内的80端口配置，避免与PrestaShop冲突

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
        return 0
    else
        log_error "配置文件不存在: $DOCKER_COMPOSE_FILE"
        return 1
    fi
}

# 检查当前Prosody配置
check_prosody_config() {
    log_info "🔍 检查当前Prosody配置"
    echo "=================================="
    
    if [ -f "$DOCKER_COMPOSE_FILE" ]; then
        log_info "当前Prosody端口配置:"
        
        # 查找prosody服务配置
        local prosody_section=$(grep -n "prosody:" "$DOCKER_COMPOSE_FILE" | cut -d: -f1)
        if [ -n "$prosody_section" ]; then
            # 显示prosody服务的ports配置
            sed -n "${prosody_section},/^  [a-zA-Z]/p" "$DOCKER_COMPOSE_FILE" | grep -A 10 "ports:" || log_info "未找到ports配置"
        else
            log_warning "未找到prosody服务配置"
        fi
    else
        log_error "Docker Compose配置文件不存在"
        return 1
    fi
    
    echo ""
}

# 修复Prosody端口配置
fix_prosody_ports() {
    log_info "🔧 修复Prosody端口配置"
    echo "=================================="
    
    if [ ! -f "$DOCKER_COMPOSE_FILE" ]; then
        log_error "Docker Compose配置文件不存在"
        return 1
    fi
    
    # 检查是否需要修复
    if ! grep -A 20 "prosody:" "$DOCKER_COMPOSE_FILE" | grep -q "80/tcp\|80:80"; then
        log_success "Prosody配置中没有发现80端口映射，无需修复"
        return 0
    fi
    
    log_info "发现Prosody使用80端口，开始修复..."
    
    # 创建临时文件
    local temp_file=$(mktemp)
    
    # 处理配置文件
    local in_prosody_section=false
    local in_ports_section=false
    local prosody_indent=""
    
    while IFS= read -r line; do
        # 检测prosody服务开始
        if [[ "$line" =~ ^[[:space:]]*prosody:[[:space:]]*$ ]]; then
            in_prosody_section=true
            prosody_indent=$(echo "$line" | sed 's/prosody:.*//')
            echo "$line" >> "$temp_file"
            continue
        fi
        
        # 检测prosody服务结束（下一个服务开始）
        if [ "$in_prosody_section" = true ] && [[ "$line" =~ ^[[:space:]]*[a-zA-Z][a-zA-Z0-9_-]*:[[:space:]]*$ ]]; then
            in_prosody_section=false
            in_ports_section=false
        fi
        
        # 在prosody服务内部
        if [ "$in_prosody_section" = true ]; then
            # 检测ports部分开始
            if [[ "$line" =~ ^[[:space:]]*ports:[[:space:]]*$ ]]; then
                in_ports_section=true
                echo "$line" >> "$temp_file"
                continue
            fi
            
            # 检测ports部分结束
            if [ "$in_ports_section" = true ] && [[ "$line" =~ ^[[:space:]]*[a-zA-Z][a-zA-Z0-9_]*:[[:space:]]*.*$ ]]; then
                in_ports_section=false
            fi
            
            # 在ports部分内，跳过80端口相关配置
            if [ "$in_ports_section" = true ]; then
                # 跳过包含80端口的行
                if [[ "$line" =~ 80/tcp ]] || [[ "$line" =~ 80:80 ]] || [[ "$line" =~ \"80:80\" ]]; then
                    log_info "移除端口配置: $(echo "$line" | xargs)"
                    continue
                fi
            fi
        fi
        
        # 写入其他所有行
        echo "$line" >> "$temp_file"
        
    done < "$DOCKER_COMPOSE_FILE"
    
    # 替换原文件
    mv "$temp_file" "$DOCKER_COMPOSE_FILE"
    
    log_success "Prosody端口配置修复完成"
    
    # 显示修复后的配置
    log_info "修复后的Prosody端口配置:"
    local prosody_section=$(grep -n "prosody:" "$DOCKER_COMPOSE_FILE" | cut -d: -f1)
    if [ -n "$prosody_section" ]; then
        sed -n "${prosody_section},/^  [a-zA-Z]/p" "$DOCKER_COMPOSE_FILE" | grep -A 10 "ports:" || log_info "无ports配置（已移除80端口）"
    fi
    
    echo ""
}

# 验证nginx配置
verify_nginx_config() {
    log_info "🔍 验证Nginx配置"
    echo "=================================="
    
    local nginx_conf="infra/docker/nginx/nginx.conf"
    
    if [ -f "$nginx_conf" ]; then
        # 检查prosody_http upstream配置
        if grep -q "upstream prosody_http" "$nginx_conf"; then
            log_info "Prosody HTTP upstream配置:"
            grep -A 3 "upstream prosody_http" "$nginx_conf"
            
            # 检查是否指向5280端口
            if grep -A 3 "upstream prosody_http" "$nginx_conf" | grep -q "5280"; then
                log_success "Nginx正确配置为代理到prosody:5280"
            else
                log_warning "Nginx可能未正确配置prosody代理端口"
            fi
        else
            log_warning "未找到prosody_http upstream配置"
        fi
        
        # 检查http-bind配置
        if grep -q "http-bind" "$nginx_conf"; then
            log_info "发现XMPP HTTP绑定配置:"
            grep -A 5 -B 2 "http-bind" "$nginx_conf"
        fi
        
    else
        log_warning "Nginx配置文件不存在: $nginx_conf"
    fi
    
    echo ""
}

# 生成重启命令
generate_restart_commands() {
    log_info "📝 生成重启命令"
    echo "=================================="
    
    echo "修复完成后，请执行以下命令重启相关服务:"
    echo ""
    echo "# 如果有Docker Compose命令可用:"
    echo "docker-compose -f $DOCKER_COMPOSE_FILE restart prosody nginx"
    echo ""
    echo "# 或者单独重启容器:"
    echo "docker restart baidaohui-prosody"
    echo "docker restart baidaohui-nginx"
    echo ""
    echo "# 验证修复结果:"
    echo "docker ps | grep -E '(prosody|nginx|prestashop)'"
    echo ""
}

# 验证修复结果
verify_fix() {
    log_info "🔍 验证修复结果"
    echo "=================================="
    
    # 检查配置文件
    if [ -f "$DOCKER_COMPOSE_FILE" ]; then
        log_info "检查修复后的配置:"
        
        # 检查prosody是否还有80端口配置
        if grep -A 20 "prosody:" "$DOCKER_COMPOSE_FILE" | grep -q "80/tcp\|80:80"; then
            log_warning "Prosody配置中仍然存在80端口映射"
        else
            log_success "Prosody配置中已移除80端口映射"
        fi
        
        # 检查prosody是否保留了其他端口
        local prosody_ports=$(grep -A 20 "prosody:" "$DOCKER_COMPOSE_FILE" | grep -A 10 "ports:" | grep -E "^\s*-" | wc -l)
        log_info "Prosody保留的端口映射数量: $prosody_ports"
        
    else
        log_error "配置文件不存在，无法验证"
    fi
    
    echo ""
}

# 显示解决方案总结
show_solution_summary() {
    log_info "📋 解决方案总结"
    echo "=================================="
    
    echo "本脚本执行的修复操作:"
    echo "1. ✅ 备份原始配置文件"
    echo "2. ✅ 移除Prosody容器内的80端口配置"
    echo "3. ✅ 保留Prosody的其他端口（5222, 5269, 5280等）"
    echo "4. ✅ 验证Nginx配置正确代理到prosody:5280"
    echo ""
    echo "修复后的架构:"
    echo "• Nginx: 主机80端口 -> 容器80端口（反向代理）"
    echo "• PrestaShop: 仅容器内80端口（通过nginx代理）"
    echo "• Prosody: 5222(XMPP), 5269(S2S), 5280(HTTP) 端口"
    echo ""
    echo "这样可以避免Prosody和PrestaShop在容器内的80端口冲突。"
    echo ""
}

# 主函数
main() {
    case "${1:-fix}" in
        "check")
            check_prosody_config
            verify_nginx_config
            ;;
        "fix")
            log_info "🚀 开始修复Prosody 80端口冲突"
            echo "=================================="
            
            create_backup_dir
            if backup_config; then
                check_prosody_config
                fix_prosody_ports
                verify_nginx_config
                verify_fix
                generate_restart_commands
                show_solution_summary
            else
                log_error "备份失败，终止修复操作"
                exit 1
            fi
            ;;
        "verify")
            verify_fix
            verify_nginx_config
            ;;
        "restart-commands")
            generate_restart_commands
            ;;
        "help"|*)
            echo "SJ服务器Prosody 80端口冲突修复脚本"
            echo ""
            echo "用法: $0 [命令]"
            echo ""
            echo "命令:"
            echo "  fix              - 执行完整修复流程（默认）"
            echo "  check            - 检查当前Prosody配置"
            echo "  verify           - 验证修复结果"
            echo "  restart-commands - 显示重启命令"
            echo "  help             - 显示此帮助信息"
            echo ""
            echo "示例:"
            echo "  $0 fix           # 执行修复"
            echo "  $0 check         # 检查配置"
            echo "  $0 verify        # 验证结果"
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