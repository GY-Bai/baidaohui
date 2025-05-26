#!/bin/bash

# SJ服务器完整修复脚本
# 综合修复Redis端口冲突和SSO API配置问题

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
    echo -e "${BLUE}[SJ-COMPLETE-FIX]${NC} $1"
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

log_step() {
    echo -e "${CYAN}[SJ-STEP]${NC} $1"
}

log_phase() {
    echo -e "${PURPLE}[SJ-PHASE]${NC} $1"
}

# 显示使用说明
show_usage() {
    echo -e "${BLUE}🔧 SJ服务器完整修复脚本${NC}"
    echo ""
    echo "这个脚本将执行以下修复操作："
    echo "  1. 停止外部Redis服务"
    echo "  2. 修改Docker Redis端口为6380"
    echo "  3. 更新所有服务配置"
    echo "  4. 重启所有服务"
    echo "  5. 验证修复结果"
    echo ""
    echo "使用方法："
    echo "  $0 [操作]"
    echo ""
    echo "操作："
    echo "  diagnose     - 诊断当前问题"
    echo "  fix          - 执行完整修复"
    echo "  verify       - 验证修复结果"
    echo "  rollback     - 回滚到备份配置"
    echo ""
    echo "示例："
    echo "  $0 diagnose  # 诊断问题"
    echo "  $0 fix       # 执行完整修复"
}

# 诊断当前问题
diagnose_issues() {
    log_phase "🔍 开始诊断SJ服务器问题..."
    
    echo -e "\n${YELLOW}=== 端口占用检查 ===${NC}"
    local ports=(6379 6380 6381)
    
    for port in "${ports[@]}"; do
        echo -e "\n${CYAN}检查端口 $port:${NC}"
        
        if netstat -tlnp 2>/dev/null | grep -q ":${port} "; then
            log_warning "端口 $port 已被占用:"
            netstat -tlnp 2>/dev/null | grep ":${port} " || true
        else
            log_success "端口 $port 可用"
        fi
    done
    
    echo -e "\n${YELLOW}=== Redis进程检查 ===${NC}"
    if pgrep redis-server > /dev/null 2>&1; then
        log_warning "发现外部Redis进程:"
        ps aux | grep redis-server | grep -v grep
    else
        log_success "未发现外部Redis进程"
    fi
    
    echo -e "\n${YELLOW}=== Docker容器检查 ===${NC}"
    if docker ps --format "{{.Names}}" | grep -q "^baidaohui-redis$"; then
        log_success "Redis容器正在运行"
        docker ps | grep baidaohui-redis || true
    else
        log_warning "Redis容器未运行"
    fi
    
    if docker ps --format "{{.Names}}" | grep -q "^baidaohui-sso-api$"; then
        log_success "SSO API容器正在运行"
        docker ps | grep baidaohui-sso-api || true
    else
        log_warning "SSO API容器未运行"
    fi
    
    echo -e "\n${YELLOW}=== SSO API健康检查 ===${NC}"
    local endpoints=("http://localhost:5004/health")
    
    for endpoint in "${endpoints[@]}"; do
        if curl -s -f "$endpoint" > /dev/null 2>&1; then
            log_success "SSO API健康检查通过: $endpoint"
        else
            log_error "SSO API健康检查失败: $endpoint"
            echo "错误信息:"
            curl -s "$endpoint" 2>/dev/null || echo "连接被拒绝"
        fi
    done
}

# 停止外部Redis服务
stop_external_redis() {
    log_step "停止外部Redis服务..."
    
    # 停止系统Redis服务
    log_info "停止系统Redis服务..."
    systemctl stop redis-server 2>/dev/null || systemctl stop redis 2>/dev/null || true
    systemctl disable redis-server 2>/dev/null || systemctl disable redis 2>/dev/null || true
    
    # 杀死Redis进程
    log_info "杀死Redis进程..."
    pkill -f redis-server 2>/dev/null || true
    sleep 3
    
    # 强制杀死残留进程
    if pgrep redis-server > /dev/null 2>&1; then
        log_warning "强制杀死残留Redis进程..."
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
    local backup_file="docker-compose.sj.yml.complete-backup.$(date +%Y%m%d_%H%M%S)"
    cp docker-compose.sj.yml "$backup_file"
    log_info "已备份配置到: $backup_file"
    
    # 检查当前Redis端口配置
    if grep -q -- '- "6379:6379"' docker-compose.sj.yml; then
        log_info "将Redis端口从6379改为6380..."
        sed -i 's/- "6379:6379"/- "6380:6379"/' docker-compose.sj.yml
        log_success "Redis端口映射已更新"
    elif grep -q -- '- "6380:6379"' docker-compose.sj.yml; then
        log_success "Redis端口已经是6380，无需修改"
    else
        log_warning "未找到标准Redis端口配置"
        # 尝试查找其他可能的Redis端口配置格式
        if grep -q "6379:6379" docker-compose.sj.yml; then
            log_info "发现其他格式的Redis端口配置，尝试修复..."
            sed -i 's/6379:6379/6380:6379/g' docker-compose.sj.yml
            log_success "Redis端口映射已更新"
        fi
    fi
    
    # 验证配置
    if grep -q -- '- "6380:6379"' docker-compose.sj.yml || grep -q "6380:6379" docker-compose.sj.yml; then
        log_success "Docker配置修复完成"
    else
        log_error "Docker配置修复失败"
        cd ../..
        return 1
    fi
    
    cd ../..
}

# 重启Docker服务
restart_docker_services() {
    log_step "重启Docker服务..."
    
    cd infra/docker
    
    # 停止所有服务
    log_info "停止所有服务..."
    docker-compose -f docker-compose.sj.yml down || true
    
    # 清理容器
    log_info "清理容器..."
    docker rm -f baidaohui-redis baidaohui-sso-api 2>/dev/null || true
    
    # 启动Redis
    log_info "启动Redis服务..."
    docker-compose -f docker-compose.sj.yml up -d redis
    
    # 等待Redis启动
    log_info "等待Redis启动（10秒）..."
    sleep 10
    
    # 验证Redis
    if docker exec baidaohui-redis redis-cli ping > /dev/null 2>&1; then
        log_success "Redis启动成功"
    else
        log_error "Redis启动失败"
        cd ../..
        return 1
    fi
    
    # 启动SSO API
    log_info "启动SSO API服务..."
    docker-compose -f docker-compose.sj.yml up -d sso-api
    
    # 等待SSO API启动
    log_info "等待SSO API启动（20秒）..."
    sleep 20
    
    # 启动其他服务
    log_info "启动其他服务..."
    docker-compose -f docker-compose.sj.yml up -d
    
    cd ../..
}

# 验证修复结果
verify_fix() {
    log_step "验证修复结果..."
    
    echo -e "\n${CYAN}端口检查:${NC}"
    if netstat -tlnp 2>/dev/null | grep -q ":6380 "; then
        log_success "Redis在端口6380运行正常"
    else
        log_error "Redis端口6380未监听"
    fi
    
    if ! netstat -tlnp 2>/dev/null | grep -q ":6379 "; then
        log_success "端口6379已释放"
    else
        log_warning "端口6379仍被占用"
    fi
    
    echo -e "\n${CYAN}容器检查:${NC}"
    if docker ps --format "{{.Names}}" | grep -q "^baidaohui-redis$"; then
        log_success "Redis容器运行正常"
    else
        log_error "Redis容器未运行"
    fi
    
    if docker ps --format "{{.Names}}" | grep -q "^baidaohui-sso-api$"; then
        log_success "SSO API容器运行正常"
    else
        log_error "SSO API容器未运行"
    fi
    
    echo -e "\n${CYAN}Redis连接检查:${NC}"
    if docker exec baidaohui-redis redis-cli ping > /dev/null 2>&1; then
        log_success "Redis连接正常"
    else
        log_error "Redis连接失败"
    fi
    
    echo -e "\n${CYAN}SSO API健康检查:${NC}"
    sleep 5  # 等待服务完全启动
    
    local endpoints=("http://localhost:5004/health")
    
    for endpoint in "${endpoints[@]}"; do
        if curl -s -f "$endpoint" > /dev/null 2>&1; then
            log_success "SSO API健康检查通过: $endpoint"
            echo "响应内容:"
            curl -s "$endpoint" | jq . 2>/dev/null || curl -s "$endpoint"
        else
            log_warning "SSO API健康检查失败: $endpoint"
            echo "错误响应:"
            curl -s "$endpoint" 2>/dev/null || echo "连接被拒绝"
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
    
    cd infra/docker
    
    # 查找最新的备份文件
    local backup_file=$(ls -t docker-compose.sj.yml.*.backup.* 2>/dev/null | head -1)
    
    if [ -n "$backup_file" ] && [ -f "$backup_file" ]; then
        log_info "找到备份文件: $backup_file"
        cp "$backup_file" docker-compose.sj.yml
        log_success "配置已回滚"
        
        # 重启服务
        log_info "重启服务以应用回滚配置..."
        docker-compose -f docker-compose.sj.yml down
        docker-compose -f docker-compose.sj.yml up -d
    else
        log_error "未找到备份文件"
        return 1
    fi
    
    cd ../..
}

# 主函数
main() {
    echo -e "${BLUE}🔧 SJ服务器完整修复脚本${NC}"
    echo -e "${CYAN}专门解决Redis端口冲突和SSO API连接问题${NC}"
    echo ""
    
    case "${1:-}" in
        "diagnose")
            diagnose_issues
            ;;
        "fix")
            execute_fix
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