#!/bin/bash

# SJ服务器综合问题修复脚本
# 整合Redis和SSO API的修复功能，一键解决SJ服务器问题

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# 全局变量
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/tmp/sj-server-fix-$(date +%Y%m%d_%H%M%S).log"

# 日志函数
log_info() {
    echo -e "${BLUE}[SJ-COMPLETE-INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SJ-COMPLETE-SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[SJ-COMPLETE-WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[SJ-COMPLETE-ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

log_debug() {
    echo -e "${PURPLE}[SJ-COMPLETE-DEBUG]${NC} $1" | tee -a "$LOG_FILE"
}

log_step() {
    echo -e "${CYAN}[SJ-COMPLETE-STEP]${NC} $1" | tee -a "$LOG_FILE"
}

log_header() {
    echo -e "\n${BOLD}${BLUE}================================${NC}" | tee -a "$LOG_FILE"
    echo -e "${BOLD}${BLUE} $1${NC}" | tee -a "$LOG_FILE"
    echo -e "${BOLD}${BLUE}================================${NC}\n" | tee -a "$LOG_FILE"
}

# 显示使用说明
show_usage() {
    echo -e "${BLUE}🔧 SJ服务器综合问题修复脚本${NC}"
    echo ""
    echo "使用方法："
    echo "  $0 [操作]"
    echo ""
    echo "操作："
    echo "  auto         - 自动修复所有问题（推荐）"
    echo "  diagnose     - 全面诊断所有问题"
    echo "  fix-redis    - 修复Redis相关问题"
    echo "  fix-sso      - 修复SSO API问题"
    echo "  fix-docker   - 修复Docker相关问题"
    echo "  restart-all  - 重启所有服务"
    echo "  status       - 检查所有服务状态"
    echo "  logs         - 查看所有相关日志"
    echo "  cleanup      - 清理所有冲突"
    echo ""
    echo "示例："
    echo "  $0 auto          # 自动修复所有问题"
    echo "  $0 diagnose      # 全面诊断"
    echo "  $0 status        # 检查状态"
}

# 检查依赖工具
check_dependencies() {
    log_step "检查依赖工具..."
    
    local tools=("docker" "docker-compose" "redis-cli" "curl" "jq" "nc")
    local missing_tools=()
    
    for tool in "${tools[@]}"; do
        if command -v "$tool" > /dev/null 2>&1; then
            log_debug "$tool 已安装"
        else
            missing_tools+=("$tool")
            log_warning "$tool 未安装"
        fi
    done
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        log_warning "缺少以下工具: ${missing_tools[*]}"
        log_info "尝试安装缺少的工具..."
        
        # 尝试安装缺少的工具
        for tool in "${missing_tools[@]}"; do
            case "$tool" in
                "jq")
                    sudo apt-get update && sudo apt-get install -y jq 2>/dev/null || \
                    yum install -y jq 2>/dev/null || \
                    log_warning "无法自动安装 $tool"
                    ;;
                "nc")
                    sudo apt-get update && sudo apt-get install -y netcat 2>/dev/null || \
                    yum install -y nc 2>/dev/null || \
                    log_warning "无法自动安装 $tool"
                    ;;
            esac
        done
    else
        log_success "所有依赖工具已安装"
    fi
}

# 全面诊断
comprehensive_diagnosis() {
    log_header "开始SJ服务器全面诊断"
    
    # 1. 系统信息
    log_step "收集系统信息..."
    echo "系统信息:" >> "$LOG_FILE"
    uname -a >> "$LOG_FILE" 2>&1
    echo "内存使用:" >> "$LOG_FILE"
    free -h >> "$LOG_FILE" 2>&1
    echo "磁盘使用:" >> "$LOG_FILE"
    df -h >> "$LOG_FILE" 2>&1
    
    # 2. Docker状态
    log_step "检查Docker状态..."
    if docker info > /dev/null 2>&1; then
        log_success "Docker运行正常"
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | tee -a "$LOG_FILE"
    else
        log_error "Docker未运行或有问题"
        return 1
    fi
    
    # 3. Redis诊断
    log_step "诊断Redis问题..."
    if [ -f "$SCRIPT_DIR/fix-sj-redis-issues.sh" ]; then
        bash "$SCRIPT_DIR/fix-sj-redis-issues.sh" diagnose | tee -a "$LOG_FILE"
    else
        log_warning "Redis诊断脚本不存在"
        # 内置Redis检查
        check_redis_inline
    fi
    
    # 4. SSO API诊断
    log_step "诊断SSO API问题..."
    if [ -f "$SCRIPT_DIR/fix-sj-sso-api.sh" ]; then
        bash "$SCRIPT_DIR/fix-sj-sso-api.sh" diagnose | tee -a "$LOG_FILE"
    else
        log_warning "SSO API诊断脚本不存在"
        # 内置SSO检查
        check_sso_inline
    fi
    
    # 5. 网络检查
    log_step "检查网络连接..."
    check_network_connectivity
    
    # 6. 端口检查
    log_step "检查端口占用..."
    check_port_status
    
    log_success "诊断完成，详细日志保存在: $LOG_FILE"
}

# 内置Redis检查
check_redis_inline() {
    log_step "内置Redis检查..."
    
    # 检查Redis进程
    echo "Redis进程:" | tee -a "$LOG_FILE"
    ps aux | grep redis | grep -v grep | tee -a "$LOG_FILE" || echo "无Redis进程" | tee -a "$LOG_FILE"
    
    # 检查Redis连接
    if redis-cli ping > /dev/null 2>&1; then
        log_success "Redis连接正常"
        redis-cli info server | head -5 | tee -a "$LOG_FILE"
    else
        log_error "Redis连接失败"
    fi
    
    # 检查systemd服务
    echo "Redis systemd状态:" | tee -a "$LOG_FILE"
    systemctl status redis-server --no-pager -l | tee -a "$LOG_FILE" 2>&1 || true
}

# 内置SSO检查
check_sso_inline() {
    log_step "内置SSO API检查..."
    
    # 检查SSO容器
    echo "SSO API容器:" | tee -a "$LOG_FILE"
    docker ps | grep sso | tee -a "$LOG_FILE" || echo "无SSO容器运行" | tee -a "$LOG_FILE"
    
    # 检查SSO健康状态
    if curl -s -f http://localhost:5004/health > /dev/null 2>&1; then
        log_success "SSO API健康检查通过"
        curl -s http://localhost:5004/health | tee -a "$LOG_FILE"
    else
        log_error "SSO API健康检查失败"
        curl -s http://localhost:5004/health | tee -a "$LOG_FILE" 2>&1 || echo "无法连接SSO API" | tee -a "$LOG_FILE"
    fi
}

# 检查网络连接
check_network_connectivity() {
    local hosts=("localhost" "127.0.0.1")
    local ports=(5001 5002 5003 5004 6379)
    
    echo "网络连接检查:" | tee -a "$LOG_FILE"
    for host in "${hosts[@]}"; do
        for port in "${ports[@]}"; do
            if timeout 3 nc -z "$host" "$port" 2>/dev/null; then
                echo "✅ $host:$port 可达" | tee -a "$LOG_FILE"
            else
                echo "❌ $host:$port 不可达" | tee -a "$LOG_FILE"
            fi
        done
    done
}

# 检查端口状态
check_port_status() {
    echo "端口占用状态:" | tee -a "$LOG_FILE"
    netstat -tlnp 2>/dev/null | grep -E ":(5001|5002|5003|5004|6379) " | tee -a "$LOG_FILE" || \
    ss -tlnp 2>/dev/null | grep -E ":(5001|5002|5003|5004|6379) " | tee -a "$LOG_FILE" || \
    echo "无法获取端口信息" | tee -a "$LOG_FILE"
}

# 修复Redis问题
fix_redis_issues() {
    log_header "修复Redis问题"
    
    if [ -f "$SCRIPT_DIR/fix-sj-redis-issues.sh" ]; then
        log_info "使用专用Redis修复脚本..."
        bash "$SCRIPT_DIR/fix-sj-redis-issues.sh" cleanup
        bash "$SCRIPT_DIR/fix-sj-redis-issues.sh" fix-systemd
        bash "$SCRIPT_DIR/fix-sj-redis-issues.sh" fix-docker
    else
        log_info "使用内置Redis修复..."
        fix_redis_inline
    fi
}

# 内置Redis修复
fix_redis_inline() {
    log_step "内置Redis修复..."
    
    # 停止冲突的Redis服务
    log_info "停止冲突的Redis服务..."
    sudo pkill -f redis-server 2>/dev/null || true
    systemctl stop redis-server 2>/dev/null || true
    systemctl stop redis 2>/dev/null || true
    
    # 清理PID文件
    sudo rm -f /var/run/redis/*.pid 2>/dev/null || true
    
    # 尝试启动系统Redis
    log_info "启动系统Redis服务..."
    if systemctl start redis-server 2>/dev/null; then
        log_success "系统Redis启动成功"
        systemctl enable redis-server
    else
        log_warning "系统Redis启动失败，尝试Docker Redis..."
        
        # 启动Docker Redis
        if [ -d "infra/docker" ]; then
            cd infra/docker
            if [ -f "docker-compose.sj.yml" ]; then
                docker-compose -f docker-compose.sj.yml up -d redis 2>/dev/null || \
                docker run -d --name sj-redis -p 6379:6379 redis:7.4-alpine || true
            fi
            cd ../..
        fi
    fi
    
    # 验证Redis
    sleep 5
    if redis-cli ping > /dev/null 2>&1; then
        log_success "Redis修复成功"
    else
        log_error "Redis修复失败"
    fi
}

# 修复SSO API问题
fix_sso_issues() {
    log_header "修复SSO API问题"
    
    if [ -f "$SCRIPT_DIR/fix-sj-sso-api.sh" ]; then
        log_info "使用专用SSO API修复脚本..."
        bash "$SCRIPT_DIR/fix-sj-sso-api.sh" fix-redis
        bash "$SCRIPT_DIR/fix-sj-sso-api.sh" restart
    else
        log_info "使用内置SSO API修复..."
        fix_sso_inline
    fi
}

# 内置SSO API修复
fix_sso_inline() {
    log_step "内置SSO API修复..."
    
    if [ -d "infra/docker" ]; then
        cd infra/docker
        
        if [ -f "docker-compose.sj.yml" ]; then
            # 重启SSO API
            log_info "重启SSO API服务..."
            docker-compose -f docker-compose.sj.yml restart sso-api || true
            
            # 等待启动
            log_info "等待SSO API启动（20秒）..."
            sleep 20
            
            # 检查健康状态
            if curl -s -f http://localhost:5004/health > /dev/null 2>&1; then
                log_success "SSO API修复成功"
            else
                log_warning "SSO API仍有问题，尝试重新构建..."
                docker-compose -f docker-compose.sj.yml down sso-api
                docker-compose -f docker-compose.sj.yml build --no-cache sso-api
                docker-compose -f docker-compose.sj.yml up -d sso-api
                sleep 30
            fi
        fi
        
        cd ../..
    fi
}

# 修复Docker问题
fix_docker_issues() {
    log_header "修复Docker问题"
    
    # 清理Docker系统
    log_info "清理Docker系统..."
    docker system prune -f
    
    # 重启Docker服务
    if [ -d "infra/docker" ]; then
        cd infra/docker
        
        if [ -f "docker-compose.sj.yml" ]; then
            log_info "重启SJ服务器所有服务..."
            docker-compose -f docker-compose.sj.yml down
            docker-compose -f docker-compose.sj.yml up -d
            
            # 等待服务启动
            log_info "等待服务启动（60秒）..."
            sleep 60
        fi
        
        cd ../..
    fi
}

# 重启所有服务
restart_all_services() {
    log_header "重启所有SJ服务器服务"
    
    # 重启Redis
    log_info "重启Redis服务..."
    systemctl restart redis-server 2>/dev/null || systemctl restart redis 2>/dev/null || true
    
    # 重启Docker服务
    if [ -d "infra/docker" ]; then
        cd infra/docker
        
        if [ -f "docker-compose.sj.yml" ]; then
            log_info "重启Docker服务..."
            docker-compose -f docker-compose.sj.yml restart
            
            # 等待服务启动
            log_info "等待服务启动（30秒）..."
            sleep 30
        fi
        
        cd ../..
    fi
    
    log_success "所有服务重启完成"
}

# 检查所有服务状态
check_all_status() {
    log_header "检查所有SJ服务器服务状态"
    
    # Redis状态
    log_step "Redis状态:"
    if redis-cli ping > /dev/null 2>&1; then
        log_success "Redis: 运行正常"
        redis-cli info server | grep redis_version
    else
        log_error "Redis: 连接失败"
    fi
    
    # Docker容器状态
    log_step "Docker容器状态:"
    if [ -d "infra/docker" ]; then
        cd infra/docker
        if [ -f "docker-compose.sj.yml" ]; then
            docker-compose -f docker-compose.sj.yml ps
        fi
        cd ../..
    fi
    
    # API健康检查
    log_step "API健康检查:"
    local apis=(
        "Profile API:http://localhost:5002/health"
        "Auth API:http://localhost:5001/health"
        "Chat API:http://localhost:5003/health"
        "SSO API:http://localhost:5004/health"
    )
    
    for api in "${apis[@]}"; do
        local name=$(echo "$api" | cut -d':' -f1)
        local url=$(echo "$api" | cut -d':' -f2-)
        
        if curl -s -f "$url" > /dev/null 2>&1; then
            log_success "$name: 健康"
        else
            log_error "$name: 不健康"
        fi
    done
}

# 查看所有日志
show_all_logs() {
    log_header "查看所有SJ服务器日志"
    
    # systemd日志
    echo -e "\n${CYAN}=== Redis systemd日志 ===${NC}"
    journalctl -xeu redis-server.service --no-pager -l | tail -20 || true
    
    # Docker日志
    if [ -d "infra/docker" ]; then
        cd infra/docker
        
        if [ -f "docker-compose.sj.yml" ]; then
            echo -e "\n${CYAN}=== Docker Compose日志 ===${NC}"
            docker-compose -f docker-compose.sj.yml logs --tail=20
        fi
        
        cd ../..
    fi
}

# 清理所有冲突
cleanup_all_conflicts() {
    log_header "清理所有SJ服务器冲突"
    
    # 停止所有服务
    log_info "停止所有服务..."
    
    # 停止Docker服务
    if [ -d "infra/docker" ]; then
        cd infra/docker
        if [ -f "docker-compose.sj.yml" ]; then
            docker-compose -f docker-compose.sj.yml down --remove-orphans
        fi
        cd ../..
    fi
    
    # 停止Redis
    sudo pkill -f redis-server 2>/dev/null || true
    systemctl stop redis-server 2>/dev/null || true
    
    # 清理Docker
    log_info "清理Docker资源..."
    docker system prune -f
    docker volume prune -f
    
    # 清理PID文件
    sudo rm -f /var/run/redis/*.pid 2>/dev/null || true
    
    log_success "清理完成"
}

# 自动修复所有问题
auto_fix_all() {
    log_header "自动修复SJ服务器所有问题"
    
    log_info "开始自动修复流程..."
    
    # 1. 检查依赖
    check_dependencies
    
    # 2. 诊断问题
    log_step "步骤 1/6: 诊断问题..."
    comprehensive_diagnosis
    
    # 3. 清理冲突
    log_step "步骤 2/6: 清理冲突..."
    cleanup_all_conflicts
    
    # 4. 修复Redis
    log_step "步骤 3/6: 修复Redis..."
    fix_redis_issues
    
    # 5. 修复SSO API
    log_step "步骤 4/6: 修复SSO API..."
    fix_sso_issues
    
    # 6. 重启所有服务
    log_step "步骤 5/6: 重启所有服务..."
    restart_all_services
    
    # 7. 最终验证
    log_step "步骤 6/6: 最终验证..."
    check_all_status
    
    log_success "自动修复完成！"
    log_info "详细日志保存在: $LOG_FILE"
}

# 主函数
main() {
    echo -e "${BOLD}${BLUE}🔧 SJ服务器综合问题修复脚本${NC}"
    echo -e "${BLUE}日志文件: $LOG_FILE${NC}\n"
    
    case "${1:-}" in
        "auto")
            auto_fix_all
            ;;
        "diagnose")
            check_dependencies
            comprehensive_diagnosis
            ;;
        "fix-redis")
            fix_redis_issues
            ;;
        "fix-sso")
            fix_sso_issues
            ;;
        "fix-docker")
            fix_docker_issues
            ;;
        "restart-all")
            restart_all_services
            ;;
        "status")
            check_all_status
            ;;
        "logs")
            show_all_logs
            ;;
        "cleanup")
            cleanup_all_conflicts
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