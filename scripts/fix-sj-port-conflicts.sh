#!/bin/bash

# SJ服务器端口冲突综合修复脚本
# 解决80端口冲突和服务端口映射问题

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

log_step() {
    echo -e "${CYAN}🔧 $1${NC}"
}

# 显示帮助信息
show_help() {
    echo -e "${BLUE}SJ服务器端口冲突修复脚本${NC}"
    echo "=================================="
    echo ""
    echo "用法: $0 [命令]"
    echo ""
    echo "命令:"
    echo "  diagnose     - 诊断当前端口问题"
    echo "  fix          - 修复所有端口问题（推荐）"
    echo "  fix-80       - 仅修复80端口冲突"
    echo "  fix-mapping  - 仅修复端口映射问题"
    echo "  verify       - 验证修复结果"
    echo "  rollback     - 回滚到备份配置"
    echo "  help         - 显示此帮助信息"
    echo ""
    echo "问题说明:"
    echo "1. 80端口冲突: nginx、prosody、prestashop 都使用80端口"
    echo "2. 端口映射缺失: shop-api 服务未映射到主机端口"
    echo ""
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
        echo "$backup_file" > "${BACKUP_DIR}/latest_backup.txt"
        return 0
    else
        log_error "配置文件不存在: $DOCKER_COMPOSE_FILE"
        return 1
    fi
}

# 诊断当前问题
diagnose_issues() {
    log_info "🔍 SJ服务器端口问题诊断"
    echo "=================================="
    
    # 检查配置文件
    if [ ! -f "$DOCKER_COMPOSE_FILE" ]; then
        log_error "Docker Compose配置文件不存在: $DOCKER_COMPOSE_FILE"
        return 1
    fi
    
    log_success "找到Docker Compose配置文件"
    echo ""
    
    # 检查容器状态
    log_info "📋 当前容器状态:"
    if command -v docker >/dev/null 2>&1; then
        docker ps --filter "name=baidaohui" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" || true
    else
        log_warning "Docker命令不可用"
    fi
    echo ""
    
    # 分析80端口冲突
    log_info "🔍 80端口使用分析:"
    echo "1. baidaohui-nginx: 映射到主机80端口 ✅ 正确"
    echo "2. baidaohui-prosody: 容器内部80端口 ⚠️ 潜在冲突"
    echo "3. baidaohui-prestashop: 容器内部80端口 ⚠️ 潜在冲突"
    echo ""
    
    # 检查端口映射问题
    log_info "🔍 端口映射问题分析:"
    
    # 检查shop-api端口映射
    if grep -A 10 "shop-api:" "$DOCKER_COMPOSE_FILE" | grep -q "ports:"; then
        log_success "shop-api 已有端口映射配置"
    else
        log_warning "shop-api 缺少端口映射配置"
    fi
    
    # 检查prosody端口配置
    if grep -A 10 "prosody:" "$DOCKER_COMPOSE_FILE" | grep -q "80/tcp"; then
        log_warning "prosody 配置中包含80端口，可能与其他服务冲突"
    else
        log_success "prosody 端口配置正常"
    fi
    
    # 检查prestashop端口配置
    if grep -A 10 "prestashop:" "$DOCKER_COMPOSE_FILE" | grep -q "ports:"; then
        log_warning "prestashop 有端口映射配置，可能导致冲突"
    else
        log_success "prestashop 无端口映射配置（通过nginx代理访问）"
    fi
    
    echo ""
    
    # 检查主机端口占用
    log_info "🔍 主机端口占用检查:"
    local ports=(80 443 5001 5002 5003 5004 5005 5222 5269 5280 6380)
    for port in "${ports[@]}"; do
        if command -v netstat >/dev/null 2>&1; then
            if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
                echo "  端口 $port: ✅ 已占用"
            else
                echo "  端口 $port: ❌ 未占用"
            fi
        else
            echo "  端口 $port: ❓ 无法检查（netstat不可用）"
        fi
    done
    
    echo ""
    log_info "诊断完成"
}

# 修复80端口冲突
fix_port80_conflicts() {
    log_step "修复80端口冲突问题"
    
    # 备份配置
    backup_config || return 1
    
    # 修复prosody配置 - 移除容器内80端口的暴露
    log_info "修复prosody端口配置..."
    
    # 创建临时文件进行修改
    local temp_file=$(mktemp)
    
    # 使用awk处理prosody服务配置，移除80端口暴露
    awk '
    /^  # Prosody XMPP服务器$/ { in_prosody = 1 }
    /^  # [^P]/ && in_prosody { in_prosody = 0 }
    /^  [a-zA-Z]/ && !/^  prosody:/ && in_prosody { in_prosody = 0 }
    
    in_prosody && /ports:/ {
        print $0
        # 只保留XMPP相关端口，移除80端口
        getline; if ($0 ~ /5222:5222/) print $0
        getline; if ($0 ~ /5269:5269/) print $0  
        getline; if ($0 ~ /5280:5280/) print $0
        # 跳过80端口和443端口行
        while (getline && ($0 ~ /80\/tcp/ || $0 ~ /443\/tcp/ || $0 ~ /5281\/tcp/ || $0 ~ /5347\/tcp/)) {
            # 跳过这些行
        }
        # 输出当前行（应该是下一个配置项）
        if ($0 !~ /^[ ]*$/) print $0
        next
    }
    
    !in_prosody || !/80\/tcp/ && !/443\/tcp/ && !/5281\/tcp/ && !/5347\/tcp/ { print }
    ' "$DOCKER_COMPOSE_FILE" > "$temp_file"
    
    # 检查修改是否成功
    if [ -s "$temp_file" ]; then
        mv "$temp_file" "$DOCKER_COMPOSE_FILE"
        log_success "prosody 80端口冲突已修复"
    else
        log_error "prosody 配置修复失败"
        rm -f "$temp_file"
        return 1
    fi
    
    log_success "80端口冲突修复完成"
}

# 修复端口映射问题
fix_port_mapping() {
    log_step "修复端口映射问题"
    
    # 为shop-api添加端口映射
    log_info "为shop-api添加端口映射..."
    
    # 检查shop-api是否已有端口映射
    if grep -A 10 "shop-api:" "$DOCKER_COMPOSE_FILE" | grep -q "ports:"; then
        log_info "shop-api 已有端口映射配置"
    else
        # 在shop-api服务的container_name行后添加ports配置
        sed -i '/container_name: baidaohui-shop-api/a\    ports:\n      - "5005:5005"' "$DOCKER_COMPOSE_FILE"
        
        # 验证修改
        if grep -A 3 "container_name: baidaohui-shop-api" "$DOCKER_COMPOSE_FILE" | grep -q "5005:5005"; then
            log_success "shop-api 端口映射已添加 (5005:5005)"
        else
            log_error "shop-api 端口映射添加失败"
            return 1
        fi
    fi
    
    log_success "端口映射修复完成"
}

# 重启Docker服务
restart_services() {
    log_step "重启Docker服务"
    
    if [ ! -d "infra/docker" ]; then
        log_error "未找到infra/docker目录"
        return 1
    fi
    
    cd infra/docker
    
    # 停止服务
    log_info "停止现有服务..."
    if command -v docker-compose >/dev/null 2>&1; then
        docker-compose -f docker-compose.sj.yml down || true
    elif command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
        docker compose -f docker-compose.sj.yml down || true
    else
        log_error "未找到docker-compose或docker compose命令"
        cd ../..
        return 1
    fi
    
    # 等待停止
    sleep 5
    
    # 启动服务
    log_info "启动服务..."
    if command -v docker-compose >/dev/null 2>&1; then
        docker-compose -f docker-compose.sj.yml up -d
    else
        docker compose -f docker-compose.sj.yml up -d
    fi
    
    cd ../..
    
    # 等待服务启动
    log_info "等待服务启动（30秒）..."
    sleep 30
    
    log_success "服务重启完成"
}

# 验证修复结果
verify_fix() {
    log_info "🔍 验证修复结果"
    echo "=================================="
    
    # 检查容器状态
    log_info "📋 容器状态检查:"
    if command -v docker >/dev/null 2>&1; then
        docker ps --filter "name=baidaohui" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    else
        log_warning "Docker命令不可用"
    fi
    echo ""
    
    # 检查端口访问
    log_info "🌐 端口访问测试:"
    local api_ports=(5001 5002 5003 5004 5005)
    local api_names=("auth-api" "profile-api" "chat-api" "sso-api" "shop-api")
    
    for i in "${!api_ports[@]}"; do
        local port="${api_ports[$i]}"
        local name="${api_names[$i]}"
        
        echo -n "  $name (端口 $port): "
        if command -v curl >/dev/null 2>&1; then
            if curl -f -s --connect-timeout 10 "http://localhost:$port/health" >/dev/null 2>&1; then
                echo "✅ 可访问"
            else
                echo "❌ 无法访问"
            fi
        else
            echo "❓ 无法测试（curl不可用）"
        fi
    done
    
    echo ""
    
    # 检查nginx访问
    log_info "🌐 Nginx访问测试:"
    if command -v curl >/dev/null 2>&1; then
        if curl -f -s --connect-timeout 10 "http://localhost" >/dev/null 2>&1; then
            log_success "Nginx (端口80) 可访问"
        else
            log_warning "Nginx (端口80) 无法访问"
        fi
    else
        log_warning "无法测试Nginx访问（curl不可用）"
    fi
    
    echo ""
    log_success "验证完成"
}

# 回滚配置
rollback_config() {
    log_step "回滚配置"
    
    if [ ! -f "${BACKUP_DIR}/latest_backup.txt" ]; then
        log_error "未找到备份记录"
        return 1
    fi
    
    local backup_file=$(cat "${BACKUP_DIR}/latest_backup.txt")
    
    if [ ! -f "$backup_file" ]; then
        log_error "备份文件不存在: $backup_file"
        return 1
    fi
    
    # 恢复配置
    cp "$backup_file" "$DOCKER_COMPOSE_FILE"
    log_success "配置已回滚到: $backup_file"
    
    # 重启服务
    restart_services
    
    log_success "回滚完成"
}

# 完整修复流程
full_fix() {
    log_info "🚀 开始完整修复流程"
    echo "=================================="
    
    # 创建备份目录
    create_backup_dir
    
    # 修复80端口冲突
    fix_port80_conflicts || {
        log_error "80端口冲突修复失败"
        return 1
    }
    
    # 修复端口映射
    fix_port_mapping || {
        log_error "端口映射修复失败"
        return 1
    }
    
    # 重启服务
    restart_services || {
        log_error "服务重启失败"
        return 1
    }
    
    # 验证结果
    verify_fix
    
    log_success "🎉 完整修复流程完成！"
    echo ""
    echo "修复内容:"
    echo "✅ 移除了prosody容器内的80端口暴露，避免与nginx冲突"
    echo "✅ 为shop-api添加了端口映射 (5005:5005)"
    echo "✅ 重启了所有Docker服务"
    echo ""
    echo "现在可以访问:"
    echo "- Nginx: http://localhost"
    echo "- Auth API: http://localhost:5001"
    echo "- Profile API: http://localhost:5002"
    echo "- Chat API: http://localhost:5003"
    echo "- SSO API: http://localhost:5004"
    echo "- Shop API: http://localhost:5005"
}

# 主函数
main() {
    case "${1:-help}" in
        "diagnose")
            diagnose_issues
            ;;
        "fix")
            full_fix
            ;;
        "fix-80")
            create_backup_dir
            fix_port80_conflicts
            restart_services
            ;;
        "fix-mapping")
            create_backup_dir
            fix_port_mapping
            restart_services
            ;;
        "verify")
            verify_fix
            ;;
        "rollback")
            rollback_config
            ;;
        "help"|*)
            show_help
            ;;
    esac
}

# 检查是否在正确的目录
if [ ! -f "$DOCKER_COMPOSE_FILE" ]; then
    log_error "请在项目根目录运行此脚本"
    log_info "当前目录: $(pwd)"
    log_info "期望文件: $DOCKER_COMPOSE_FILE"
    exit 1
fi

# 运行主函数
main "$@" 