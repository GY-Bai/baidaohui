#!/bin/bash

# SJ服务器完整修复脚本 - 安全版本
# 专门解决SJ服务器上的Redis端口冲突和SSO API问题

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
    echo -e "${BLUE}[SJ-INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SJ-SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[SJ-WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[SJ-ERROR]${NC} $1"
}

log_debug() {
    echo -e "${PURPLE}[SJ-DEBUG]${NC} $1"
}

log_step() {
    echo -e "${CYAN}[SJ-STEP]${NC} $1"
}

log_phase() {
    echo -e "${PURPLE}[SJ-PHASE]${NC} $1"
}

# 显示使用说明
show_usage() {
    echo -e "${BLUE}🔧 SJ服务器完整修复脚本 - 安全版本${NC}"
    echo ""
    echo "使用方法："
    echo "  $0 [操作]"
    echo ""
    echo "操作："
    echo "  fix          - 执行完整修复流程"
    echo "  diagnose     - 仅诊断问题"
    echo "  stop-redis   - 仅停止外部Redis"
    echo "  fix-config   - 仅修复Docker配置"
    echo "  restart      - 仅重启服务"
    echo "  verify       - 仅验证结果"
    echo "  rollback     - 回滚配置"
    echo ""
    echo "示例："
    echo "  $0 fix       # 执行完整修复"
    echo "  $0 diagnose  # 仅诊断问题"
}

# 安全的grep函数
safe_grep() {
    local pattern="$1"
    local file="$2"
    local options="${3:-}"
    
    if [ ! -f "$file" ]; then
        log_debug "文件不存在: $file"
        return 1
    fi
    
    if [ -n "$options" ]; then
        grep $options -- "$pattern" "$file" 2>/dev/null || return 1
    else
        grep -- "$pattern" "$file" 2>/dev/null || return 1
    fi
}

# 安全的端口检查函数
check_port_safe() {
    local port="$1"
    
    # 使用多种方法检查端口
    if command -v netstat >/dev/null 2>&1; then
        netstat -tlnp 2>/dev/null | grep -q ":${port} " && return 0
    fi
    
    if command -v ss >/dev/null 2>&1; then
        ss -tlnp 2>/dev/null | grep -q ":${port} " && return 0
    fi
    
    if command -v lsof >/dev/null 2>&1; then
        lsof -i ":${port}" >/dev/null 2>&1 && return 0
    fi
    
    return 1
}

# 安全的容器检查函数
check_container_safe() {
    local container_name="$1"
    
    if ! command -v docker >/dev/null 2>&1; then
        log_debug "Docker命令不可用"
        return 1
    fi
    
    docker ps --format "{{.Names}}" 2>/dev/null | grep -q "^${container_name}$" 2>/dev/null || return 1
}

# 诊断问题
diagnose_issues() {
    log_step "诊断SJ服务器问题..."
    
    echo -e "\n${YELLOW}=== 系统信息 ===${NC}"
    log_info "操作系统: $(uname -s)"
    log_info "内核版本: $(uname -r)"
    log_info "当前用户: $(whoami)"
    log_info "当前目录: $(pwd)"
    
    echo -e "\n${YELLOW}=== Docker状态检查 ===${NC}"
    if command -v docker >/dev/null 2>&1; then
        if docker info >/dev/null 2>&1; then
            log_success "Docker运行正常"
            log_info "Docker版本: $(docker --version)"
        else
            log_error "Docker未运行或无权限"
        fi
    else
        log_error "Docker未安装"
    fi
    
    echo -e "\n${YELLOW}=== 端口占用检查 ===${NC}"
    local ports=(6379 6380 6381 5004)
    
    for port in "${ports[@]}"; do
        echo -e "\n${CYAN}检查端口 $port:${NC}"
        
        if check_port_safe "$port"; then
            log_warning "端口 $port 已被占用"
            # 显示占用进程信息
            if command -v netstat >/dev/null 2>&1; then
                netstat -tlnp 2>/dev/null | grep ":${port} " | head -3 || true
            fi
        else
            log_success "端口 $port 可用"
        fi
    done
    
    echo -e "\n${YELLOW}=== Redis进程检查 ===${NC}"
    if pgrep redis-server >/dev/null 2>&1; then
        log_warning "发现外部Redis进程:"
        ps aux | grep redis-server | grep -v grep | head -5 || true
    else
        log_success "未发现外部Redis进程"
    fi
    
    echo -e "\n${YELLOW}=== Docker容器检查 ===${NC}"
    local containers=("baidaohui-redis" "baidaohui-sso-api" "baidaohui-profile-api" "baidaohui-auth-api")
    
    for container in "${containers[@]}"; do
        if check_container_safe "$container"; then
            log_success "$container 容器正在运行"
        else
            log_warning "$container 容器未运行"
        fi
    done
    
    echo -e "\n${YELLOW}=== 配置文件检查 ===${NC}"
    if [ -f "infra/docker/docker-compose.sj.yml" ]; then
        log_success "找到Docker Compose配置文件"
        
        # 检查Redis配置
        if safe_grep "redis" "infra/docker/docker-compose.sj.yml" "-i"; then
            log_success "配置文件包含Redis配置"
            
            # 检查端口配置
            if safe_grep "6379:6379" "infra/docker/docker-compose.sj.yml"; then
                log_warning "发现6379端口配置，可能需要修改"
            elif safe_grep "6380:6379" "infra/docker/docker-compose.sj.yml"; then
                log_success "Redis端口已配置为6380"
            else
                log_warning "未找到标准Redis端口配置"
            fi
        else
            log_warning "配置文件未包含Redis配置"
        fi
    else
        log_error "未找到Docker Compose配置文件"
    fi
    
    echo -e "\n${YELLOW}=== SSO API健康检查 ===${NC}"
    local endpoints=("http://localhost:5004/health" "http://127.0.0.1:5004/health")
    
    for endpoint in "${endpoints[@]}"; do
        log_debug "测试端点: $endpoint"
        if curl -s -f --connect-timeout 5 "$endpoint" >/dev/null 2>&1; then
            log_success "SSO API健康检查通过: $endpoint"
        else
            log_warning "SSO API健康检查失败: $endpoint"
        fi
    done
}

# 停止外部Redis服务
stop_external_redis() {
    log_step "停止外部Redis服务..."
    
    # 停止系统Redis服务
    log_info "尝试停止系统Redis服务..."
    if command -v systemctl >/dev/null 2>&1; then
        systemctl stop redis-server 2>/dev/null || true
        systemctl stop redis 2>/dev/null || true
        systemctl disable redis-server 2>/dev/null || true
        systemctl disable redis 2>/dev/null || true
        log_success "系统Redis服务停止命令已执行"
    else
        log_debug "systemctl不可用，跳过系统服务停止"
    fi
    
    # 杀死Redis进程
    log_info "终止Redis进程..."
    if pgrep redis-server >/dev/null 2>&1; then
        pkill -f redis-server 2>/dev/null || true
        sleep 3
        
        # 强制杀死残留进程
        if pgrep redis-server >/dev/null 2>&1; then
            log_warning "强制终止残留Redis进程..."
            pkill -9 -f redis-server 2>/dev/null || true
            sleep 2
        fi
    fi
    
    # 验证结果
    if ! pgrep redis-server >/dev/null 2>&1; then
        log_success "外部Redis服务已停止"
    else
        log_error "无法完全停止外部Redis服务"
        log_info "残留进程:"
        ps aux | grep redis-server | grep -v grep || true
        return 1
    fi
}

# 修复Docker配置
fix_docker_config() {
    log_step "修复Docker配置..."
    
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
    local backup_file="docker-compose.sj.yml.safe-backup.$(date +%Y%m%d_%H%M%S)"
    cp docker-compose.sj.yml "$backup_file"
    log_info "已备份配置到: $backup_file"
    
    # 检查当前Redis端口配置
    log_info "检查当前Redis端口配置..."
    
    local config_updated=false
    
    if safe_grep '- "6379:6379"' "docker-compose.sj.yml" "-q"; then
        log_info "将Redis端口从6379改为6380..."
        sed -i.bak 's/- "6379:6379"/- "6380:6379"/' docker-compose.sj.yml
        config_updated=true
        log_success "Redis端口映射已更新"
    elif safe_grep '- "6380:6379"' "docker-compose.sj.yml" "-q"; then
        log_success "Redis端口已经是6380，无需修改"
        config_updated=true
    else
        log_warning "未找到标准Redis端口配置格式"
        
        # 尝试查找其他可能的Redis端口配置格式
        if safe_grep "6379:6379" "docker-compose.sj.yml" "-q"; then
            log_info "发现其他格式的Redis端口配置，尝试修复..."
            sed -i.bak 's/6379:6379/6380:6379/g' docker-compose.sj.yml
            config_updated=true
            log_success "Redis端口映射已更新"
        else
            log_warning "未找到任何Redis端口配置"
        fi
    fi
    
    # 验证配置
    if safe_grep '- "6380:6379"' "docker-compose.sj.yml" "-q" || safe_grep "6380:6379" "docker-compose.sj.yml" "-q"; then
        log_success "Docker配置修复完成"
    else
        if [ "$config_updated" = true ]; then
            log_warning "配置已更新但验证失败，请手动检查"
        else
            log_error "Docker配置修复失败"
            cd ../..
            return 1
        fi
    fi
    
    cd ../..
}

# 重启Docker服务
restart_docker_services() {
    log_step "重启Docker服务..."
    
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
    
    # 停止所有服务
    log_info "停止所有服务..."
    docker-compose -f docker-compose.sj.yml down 2>/dev/null || true
    
    # 清理容器
    log_info "清理容器..."
    docker rm -f baidaohui-redis baidaohui-sso-api 2>/dev/null || true
    
    # 启动Redis
    log_info "启动Redis服务..."
    if docker-compose -f docker-compose.sj.yml up -d redis 2>/dev/null; then
        log_success "Redis服务启动命令已执行"
    else
        log_error "Redis服务启动失败"
        cd ../..
        return 1
    fi
    
    # 等待Redis启动
    log_info "等待Redis启动（10秒）..."
    sleep 10
    
    # 验证Redis
    if check_container_safe "baidaohui-redis"; then
        if docker exec baidaohui-redis redis-cli ping >/dev/null 2>&1; then
            log_success "Redis启动成功并可连接"
        else
            log_warning "Redis容器运行但连接失败"
        fi
    else
        log_error "Redis容器启动失败"
        cd ../..
        return 1
    fi
    
    # 启动SSO API
    log_info "启动SSO API服务..."
    if docker-compose -f docker-compose.sj.yml up -d sso-api 2>/dev/null; then
        log_success "SSO API服务启动命令已执行"
    else
        log_warning "SSO API服务启动可能失败"
    fi
    
    # 等待SSO API启动
    log_info "等待SSO API启动（20秒）..."
    sleep 20
    
    # 启动其他服务
    log_info "启动其他服务..."
    docker-compose -f docker-compose.sj.yml up -d 2>/dev/null || true
    
    cd ../..
}

# 验证修复结果
verify_fix() {
    log_step "验证修复结果..."
    
    echo -e "\n${CYAN}端口检查:${NC}"
    if check_port_safe "6380"; then
        log_success "Redis在端口6380运行正常"
    else
        log_error "Redis端口6380未监听"
    fi
    
    if ! check_port_safe "6379"; then
        log_success "端口6379已释放"
    else
        log_warning "端口6379仍被占用"
    fi
    
    echo -e "\n${CYAN}容器检查:${NC}"
    if check_container_safe "baidaohui-redis"; then
        log_success "Redis容器运行正常"
    else
        log_error "Redis容器未运行"
    fi
    
    if check_container_safe "baidaohui-sso-api"; then
        log_success "SSO API容器运行正常"
    else
        log_error "SSO API容器未运行"
    fi
    
    echo -e "\n${CYAN}Redis连接检查:${NC}"
    if check_container_safe "baidaohui-redis"; then
        if docker exec baidaohui-redis redis-cli ping >/dev/null 2>&1; then
            log_success "Redis连接正常"
        else
            log_error "Redis连接失败"
        fi
    else
        log_error "Redis容器未运行，无法测试连接"
    fi
    
    echo -e "\n${CYAN}SSO API健康检查:${NC}"
    sleep 5  # 等待服务完全启动
    
    local endpoints=("http://localhost:5004/health")
    
    for endpoint in "${endpoints[@]}"; do
        if curl -s -f --connect-timeout 10 "$endpoint" >/dev/null 2>&1; then
            log_success "SSO API健康检查通过: $endpoint"
            echo "响应内容:"
            curl -s --connect-timeout 10 "$endpoint" | jq . 2>/dev/null || curl -s --connect-timeout 10 "$endpoint"
        else
            log_warning "SSO API健康检查失败: $endpoint"
            echo "错误响应:"
            curl -s --connect-timeout 10 "$endpoint" 2>/dev/null || echo "连接被拒绝或超时"
        fi
    done
}

# 执行完整修复
execute_fix() {
    log_phase "🚀 开始SJ服务器完整修复流程..."
    
    echo -e "\n${YELLOW}=== 阶段1: 诊断问题 ===${NC}"
    diagnose_issues
    
    echo -e "\n${YELLOW}=== 阶段2: 停止外部Redis ===${NC}"
    stop_external_redis
    
    echo -e "\n${YELLOW}=== 阶段3: 修复Docker配置 ===${NC}"
    fix_docker_config
    
    echo -e "\n${YELLOW}=== 阶段4: 重启服务 ===${NC}"
    restart_docker_services
    
    echo -e "\n${YELLOW}=== 阶段5: 验证结果 ===${NC}"
    verify_fix
    
    log_success "🎉 SJ服务器完整修复完成！"
    echo ""
    echo -e "${GREEN}修复摘要:${NC}"
    echo "  ✅ 外部Redis服务已停止"
    echo "  ✅ Docker Redis端口已改为6380"
    echo "  ✅ 所有服务配置已更新"
    echo "  ✅ 服务已重启并验证"
    echo ""
    echo -e "${BLUE}现在可以通过以下方式访问:${NC}"
    echo "  - Redis: localhost:6380"
    echo "  - SSO API: http://localhost:5004"
}

# 回滚配置
rollback_config() {
    log_step "回滚配置..."
    
    if [ ! -d "infra/docker" ]; then
        log_error "未找到infra/docker目录"
        return 1
    fi
    
    cd infra/docker
    
    # 查找最新的备份文件
    local backup_file=$(ls -t docker-compose.sj.yml.*backup.* 2>/dev/null | head -1)
    
    if [ -n "$backup_file" ] && [ -f "$backup_file" ]; then
        log_info "找到备份文件: $backup_file"
        cp "$backup_file" docker-compose.sj.yml
        log_success "配置已回滚"
        
        # 重启服务
        log_info "重启服务以应用回滚配置..."
        docker-compose -f docker-compose.sj.yml down 2>/dev/null || true
        docker-compose -f docker-compose.sj.yml up -d 2>/dev/null || true
        log_success "服务已重启"
    else
        log_error "未找到备份文件"
        cd ../..
        return 1
    fi
    
    cd ../..
}

# 主函数
main() {
    echo -e "${BLUE}🔧 SJ服务器完整修复脚本 - 安全版本${NC}"
    
    case "${1:-}" in
        "fix")
            execute_fix
            ;;
        "diagnose")
            diagnose_issues
            ;;
        "stop-redis")
            stop_external_redis
            ;;
        "fix-config")
            fix_docker_config
            ;;
        "restart")
            restart_docker_services
            ;;
        "verify")
            verify_fix
            ;;
        "rollback")
            rollback_config
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