#!/bin/bash

# SJ服务器SSO API问题修复脚本
# 专门解决SJ服务器上SSO API Redis连接问题

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
    echo -e "${BLUE}[SJ-SSO-INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SJ-SSO-SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[SJ-SSO-WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[SJ-SSO-ERROR]${NC} $1"
}

log_debug() {
    echo -e "${PURPLE}[SJ-SSO-DEBUG]${NC} $1"
}

log_step() {
    echo -e "${CYAN}[SJ-SSO-STEP]${NC} $1"
}

# 显示使用说明
show_usage() {
    echo -e "${BLUE}🔧 SJ服务器SSO API问题修复脚本${NC}"
    echo ""
    echo "使用方法："
    echo "  $0 [操作]"
    echo ""
    echo "操作："
    echo "  diagnose     - 诊断SSO API问题"
    echo "  fix-redis    - 修复Redis连接问题"
    echo "  fix-config   - 修复SSO API配置"
    echo "  restart      - 重启SSO API服务"
    echo "  rebuild      - 重新构建SSO API"
    echo "  logs         - 查看SSO API日志"
    echo "  health       - 检查健康状态"
    echo "  env-check    - 检查环境变量"
    echo ""
    echo "示例："
    echo "  $0 diagnose      # 诊断问题"
    echo "  $0 fix-redis     # 修复Redis连接"
    echo "  $0 restart       # 重启服务"
}

# 检查SSO API健康状态
check_sso_health() {
    log_step "检查SJ服务器SSO API健康状态..."
    
    local endpoints=(
        "http://localhost:5004/health"
        "http://127.0.0.1:5004/health"
    )
    
    for endpoint in "${endpoints[@]}"; do
        echo -e "\n${CYAN}测试端点: $endpoint${NC}"
        
        if curl -s -f "$endpoint" 2>/dev/null; then
            log_success "SSO API健康检查通过: $endpoint"
            echo "响应内容:"
            curl -s "$endpoint" | jq . 2>/dev/null || curl -s "$endpoint"
        else
            log_error "SSO API健康检查失败: $endpoint"
            echo "错误响应:"
            curl -s "$endpoint" 2>/dev/null || echo "无法连接"
        fi
    done
}

# 检查SSO API容器状态
check_container_status() {
    log_step "检查SSO API容器状态..."
    
    local container_names=("baidaohui-sso-api" "sj-sso-api" "sso-api")
    
    for container in "${container_names[@]}"; do
        echo -e "\n${CYAN}检查容器: $container${NC}"
        
        if docker ps | grep -q "$container"; then
            log_success "容器 $container 正在运行"
            docker ps | grep "$container"
            
            # 检查容器日志
            echo -e "\n${CYAN}最近日志:${NC}"
            docker logs --tail=10 "$container" 2>/dev/null || true
        else
            log_warning "容器 $container 未运行"
            
            # 检查是否存在但已停止
            if docker ps -a | grep -q "$container"; then
                echo "容器存在但已停止:"
                docker ps -a | grep "$container"
            else
                echo "容器不存在"
            fi
        fi
    done
}

# 检查Redis连接配置
check_redis_config() {
    log_step "检查SSO API Redis连接配置..."
    
    # 检查环境变量
    echo -e "\n${CYAN}环境变量检查:${NC}"
    local redis_vars=("REDIS_HOST" "REDIS_PORT" "REDIS_URL" "REDIS_PASSWORD")
    
    for var in "${redis_vars[@]}"; do
        if [ ! -z "${!var}" ]; then
            log_success "$var = ${!var}"
        else
            log_debug "$var 未设置"
        fi
    done
    
    # 检查Docker Compose配置
    if [ -d "infra/docker" ]; then
        cd infra/docker
        
        if [ -f "docker-compose.sj.yml" ]; then
            echo -e "\n${CYAN}Docker Compose Redis配置:${NC}"
            grep -A 5 -B 5 -i "redis" docker-compose.sj.yml || log_warning "未找到Redis配置"
            
            echo -e "\n${CYAN}SSO API环境变量:${NC}"
            grep -A 10 -B 2 "sso-api" docker-compose.sj.yml | grep -E "(REDIS|environment)" || log_warning "未找到SSO API Redis环境变量"
        fi
        
        cd ../..
    fi
}

# 诊断SSO API问题
diagnose_sso_issues() {
    log_info "开始诊断SJ服务器SSO API问题..."
    
    check_container_status
    check_redis_config
    check_sso_health
    
    # 检查网络连接
    log_step "检查网络连接..."
    
    local redis_hosts=("localhost" "127.0.0.1" "redis" "sj-redis")
    local redis_ports=(6379 6380 6381)
    
    for host in "${redis_hosts[@]}"; do
        for port in "${redis_ports[@]}"; do
            if timeout 3 nc -z "$host" "$port" 2>/dev/null; then
                log_success "网络连接正常: $host:$port"
            else
                log_debug "网络连接失败: $host:$port"
            fi
        done
    done
    
    log_info "诊断完成"
}

# 修复Redis连接问题
fix_redis_connection() {
    log_step "修复SJ服务器SSO API Redis连接问题..."
    
    # 确保Redis服务运行
    log_info "检查Redis服务状态..."
    
    # 尝试启动Docker Redis
    if [ -d "infra/docker" ]; then
        cd infra/docker
        
        if [ -f "docker-compose.sj.yml" ]; then
            # 检查是否有Redis服务配置
            if grep -q "redis" docker-compose.sj.yml; then
                log_info "启动Docker Redis服务..."
                docker-compose -f docker-compose.sj.yml up -d redis-sj 2>/dev/null || \
                docker-compose -f docker-compose.sj.yml up -d redis 2>/dev/null || true
            else
                log_warning "Docker Compose中未找到Redis配置"
            fi
        fi
        
        cd ../..
    fi
    
    # 尝试启动系统Redis
    log_info "尝试启动系统Redis服务..."
    systemctl start redis-server 2>/dev/null || systemctl start redis 2>/dev/null || true
    
    # 等待Redis启动
    log_info "等待Redis启动（10秒）..."
    sleep 10
    
    # 验证Redis连接
    if redis-cli ping > /dev/null 2>&1; then
        log_success "Redis连接正常"
    else
        log_error "Redis连接仍然失败"
        return 1
    fi
}

# 修复SSO API配置
fix_sso_config() {
    log_step "修复SJ服务器SSO API配置..."
    
    if [ -d "infra/docker" ]; then
        cd infra/docker
        
        if [ -f "docker-compose.sj.yml" ]; then
            # 备份原配置
            cp docker-compose.sj.yml docker-compose.sj.yml.backup.$(date +%Y%m%d_%H%M%S)
            
            # 检查SSO API配置
            log_info "检查SSO API配置..."
            
            # 确保SSO API有正确的Redis环境变量
            if ! grep -A 20 "sso-api:" docker-compose.sj.yml | grep -q "REDIS_HOST"; then
                log_warning "SSO API缺少Redis环境变量，需要手动添加"
                
                # 显示建议的配置
                echo -e "\n${YELLOW}建议在docker-compose.sj.yml的sso-api服务中添加以下环境变量:${NC}"
                cat << 'EOF'
    environment:
      - REDIS_HOST=localhost
      - REDIS_PORT=6379
      - REDIS_URL=redis://localhost:6379/0
EOF
            fi
        fi
        
        cd ../..
    fi
}

# 重启SSO API服务
restart_sso_service() {
    log_step "重启SJ服务器SSO API服务..."
    
    if [ -d "infra/docker" ]; then
        cd infra/docker
        
        if [ -f "docker-compose.sj.yml" ]; then
            # 停止SSO API
            log_info "停止SSO API服务..."
            docker-compose -f docker-compose.sj.yml stop sso-api || true
            
            # 删除容器
            log_info "删除SSO API容器..."
            docker-compose -f docker-compose.sj.yml rm -f sso-api || true
            
            # 重新启动
            log_info "重新启动SSO API服务..."
            docker-compose -f docker-compose.sj.yml up -d sso-api
            
            # 等待启动
            log_info "等待SSO API启动（20秒）..."
            sleep 20
            
            # 检查状态
            check_sso_health
        fi
        
        cd ../..
    fi
}

# 重新构建SSO API
rebuild_sso_service() {
    log_step "重新构建SJ服务器SSO API服务..."
    
    if [ -d "infra/docker" ]; then
        cd infra/docker
        
        if [ -f "docker-compose.sj.yml" ]; then
            # 停止并删除服务
            log_info "停止并删除SSO API服务..."
            docker-compose -f docker-compose.sj.yml down sso-api || true
            
            # 删除镜像
            log_info "删除SSO API镜像..."
            docker rmi $(docker images | grep sso | awk '{print $3}') 2>/dev/null || true
            
            # 重新构建
            log_info "重新构建SSO API服务..."
            docker-compose -f docker-compose.sj.yml build --no-cache sso-api
            
            # 启动服务
            log_info "启动SSO API服务..."
            docker-compose -f docker-compose.sj.yml up -d sso-api
            
            # 等待启动
            log_info "等待SSO API启动（30秒）..."
            sleep 30
            
            # 检查状态
            check_sso_health
        fi
        
        cd ../..
    fi
}

# 查看SSO API日志
show_sso_logs() {
    log_step "查看SJ服务器SSO API日志..."
    
    # Docker Compose日志
    if [ -d "infra/docker" ]; then
        cd infra/docker
        
        if [ -f "docker-compose.sj.yml" ]; then
            echo -e "\n${CYAN}=== Docker Compose SSO API日志 ===${NC}"
            docker-compose -f docker-compose.sj.yml logs --tail=50 sso-api || true
        fi
        
        cd ../..
    fi
    
    # 容器日志
    echo -e "\n${CYAN}=== 容器日志 ===${NC}"
    local containers=("baidaohui-sso-api" "sj-sso-api" "sso-api")
    
    for container in "${containers[@]}"; do
        if docker ps | grep -q "$container"; then
            echo -e "\n${CYAN}--- $container 日志 ---${NC}"
            docker logs --tail=30 "$container" 2>/dev/null || true
        fi
    done
}

# 检查环境变量
check_environment() {
    log_step "检查SJ服务器SSO API环境变量..."
    
    # 系统环境变量
    echo -e "\n${CYAN}系统环境变量:${NC}"
    env | grep -i redis || echo "无Redis相关环境变量"
    
    # Docker容器环境变量
    echo -e "\n${CYAN}容器环境变量:${NC}"
    local containers=("baidaohui-sso-api" "sj-sso-api" "sso-api")
    
    for container in "${containers[@]}"; do
        if docker ps | grep -q "$container"; then
            echo -e "\n${CYAN}--- $container 环境变量 ---${NC}"
            docker exec "$container" env | grep -i redis 2>/dev/null || echo "无Redis相关环境变量"
        fi
    done
}

# 主函数
main() {
    echo -e "${BLUE}🔧 SJ服务器SSO API问题修复${NC}"
    
    case "${1:-}" in
        "diagnose")
            diagnose_sso_issues
            ;;
        "fix-redis")
            fix_redis_connection
            ;;
        "fix-config")
            fix_sso_config
            ;;
        "restart")
            restart_sso_service
            ;;
        "rebuild")
            rebuild_sso_service
            ;;
        "logs")
            show_sso_logs
            ;;
        "health")
            check_sso_health
            ;;
        "env-check")
            check_environment
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