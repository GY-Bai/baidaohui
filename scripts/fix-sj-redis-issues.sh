#!/bin/bash

# SJ服务器Redis问题诊断和修复脚本
# 专门解决SJ服务器上Redis服务启动失败但连接正常的问题

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

# 显示使用说明
show_usage() {
    echo -e "${BLUE}🔧 SJ服务器Redis问题诊断和修复脚本${NC}"
    echo ""
    echo "使用方法："
    echo "  $0 [操作]"
    echo ""
    echo "操作："
    echo "  diagnose     - 全面诊断Redis问题"
    echo "  fix-systemd  - 修复systemd Redis服务"
    echo "  fix-docker   - 修复Docker Redis服务"
    echo "  restart-sso  - 重启SSO API服务"
    echo "  check-ports  - 检查端口占用情况"
    echo "  logs         - 查看相关日志"
    echo "  status       - 检查服务状态"
    echo "  cleanup      - 清理冲突的Redis实例"
    echo ""
    echo "示例："
    echo "  $0 diagnose      # 全面诊断"
    echo "  $0 fix-systemd   # 修复系统Redis服务"
    echo "  $0 restart-sso   # 重启SSO API"
}

# 检查Redis进程
check_redis_processes() {
    log_step "检查Redis进程..."
    
    echo -e "${CYAN}系统Redis进程:${NC}"
    ps aux | grep redis | grep -v grep || echo "  无系统Redis进程"
    
    echo -e "\n${CYAN}Docker Redis容器:${NC}"
    docker ps | grep redis || echo "  无Docker Redis容器"
    
    echo -e "\n${CYAN}所有Redis相关进程:${NC}"
    pgrep -fl redis || echo "  无Redis进程"
}

# 检查端口占用
check_port_usage() {
    log_step "检查Redis端口占用情况..."
    
    local ports=(6379 6380 6381)
    
    for port in "${ports[@]}"; do
        echo -e "\n${CYAN}端口 $port:${NC}"
        if netstat -tlnp 2>/dev/null | grep ":$port " || ss -tlnp 2>/dev/null | grep ":$port "; then
            echo "  端口 $port 被占用"
        else
            echo "  端口 $port 空闲"
        fi
    done
}

# 检查Redis配置文件
check_redis_config() {
    log_step "检查Redis配置文件..."
    
    local config_paths=(
        "/etc/redis/redis.conf"
        "/etc/redis.conf"
        "/usr/local/etc/redis.conf"
        "/opt/redis/redis.conf"
    )
    
    for config in "${config_paths[@]}"; do
        if [ -f "$config" ]; then
            log_success "找到配置文件: $config"
            echo "  文件大小: $(ls -lh "$config" | awk '{print $5}')"
            echo "  修改时间: $(ls -l "$config" | awk '{print $6, $7, $8}')"
        else
            log_debug "配置文件不存在: $config"
        fi
    done
}

# 检查systemd服务状态
check_systemd_status() {
    log_step "检查systemd Redis服务状态..."
    
    local services=("redis" "redis-server" "redis.service" "redis-server.service")
    
    for service in "${services[@]}"; do
        echo -e "\n${CYAN}服务 $service:${NC}"
        if systemctl list-unit-files | grep -q "$service"; then
            systemctl status "$service" --no-pager -l || true
        else
            echo "  服务 $service 不存在"
        fi
    done
}

# 检查Redis连接
test_redis_connection() {
    log_step "测试Redis连接..."
    
    local hosts=("localhost" "127.0.0.1" "redis")
    local ports=(6379 6380 6381)
    
    for host in "${hosts[@]}"; do
        for port in "${ports[@]}"; do
            echo -e "\n${CYAN}测试 $host:$port${NC}"
            if timeout 5 redis-cli -h "$host" -p "$port" ping 2>/dev/null; then
                log_success "Redis连接成功: $host:$port"
                redis-cli -h "$host" -p "$port" info server | head -5
            else
                log_debug "Redis连接失败: $host:$port"
            fi
        done
    done
}

# 检查Docker Compose服务
check_docker_compose() {
    log_step "检查Docker Compose Redis服务..."
    
    if [ -d "infra/docker" ]; then
        cd infra/docker
        
        local compose_files=("docker-compose.sj.yml" "docker-compose.yml")
        
        for file in "${compose_files[@]}"; do
            if [ -f "$file" ]; then
                echo -e "\n${CYAN}检查 $file:${NC}"
                if grep -q "redis" "$file"; then
                    log_success "在 $file 中找到Redis配置"
                    grep -A 10 -B 2 "redis" "$file" || true
                else
                    log_debug "在 $file 中未找到Redis配置"
                fi
            fi
        done
        
        cd ../..
    else
        log_warning "infra/docker 目录不存在"
    fi
}

# 全面诊断
full_diagnosis() {
    log_info "开始SJ服务器Redis全面诊断..."
    
    check_redis_processes
    check_port_usage
    check_redis_config
    check_systemd_status
    test_redis_connection
    check_docker_compose
    
    log_info "诊断完成"
}

# 修复systemd Redis服务
fix_systemd_redis() {
    log_step "修复systemd Redis服务..."
    
    # 停止可能冲突的Redis服务
    log_info "停止现有Redis服务..."
    systemctl stop redis-server 2>/dev/null || true
    systemctl stop redis 2>/dev/null || true
    
    # 检查是否有Redis配置文件
    if [ ! -f "/etc/redis/redis.conf" ] && [ ! -f "/etc/redis.conf" ]; then
        log_warning "Redis配置文件不存在，创建基本配置..."
        
        sudo mkdir -p /etc/redis
        sudo tee /etc/redis/redis.conf > /dev/null << 'EOF'
# SJ服务器Redis配置
bind 127.0.0.1
port 6379
timeout 0
tcp-keepalive 300
daemonize yes
supervised systemd
pidfile /var/run/redis/redis-server.pid
loglevel notice
logfile /var/log/redis/redis-server.log
databases 16
save 900 1
save 300 10
save 60 10000
stop-writes-on-bgsave-error yes
rdbcompression yes
rdbchecksum yes
dbfilename dump.rdb
dir /var/lib/redis
maxmemory-policy allkeys-lru
EOF
        log_success "Redis配置文件已创建"
    fi
    
    # 创建必要的目录
    sudo mkdir -p /var/lib/redis /var/log/redis /var/run/redis
    sudo chown redis:redis /var/lib/redis /var/log/redis /var/run/redis 2>/dev/null || true
    
    # 重新启动Redis服务
    log_info "启动Redis服务..."
    if systemctl start redis-server; then
        log_success "Redis服务启动成功"
        systemctl enable redis-server
    else
        log_error "Redis服务启动失败"
        journalctl -xeu redis-server.service --no-pager -l | tail -20
    fi
}

# 修复Docker Redis服务
fix_docker_redis() {
    log_step "修复Docker Redis服务..."
    
    if [ -d "infra/docker" ]; then
        cd infra/docker
        
        # 检查是否有Redis容器配置
        if [ -f "docker-compose.sj.yml" ]; then
            log_info "检查SJ Docker Compose配置..."
            
            if ! grep -q "redis" docker-compose.sj.yml; then
                log_warning "在docker-compose.sj.yml中未找到Redis配置，添加Redis服务..."
                
                # 备份原文件
                cp docker-compose.sj.yml docker-compose.sj.yml.backup
                
                # 添加Redis服务配置
                cat >> docker-compose.sj.yml << 'EOF'

  redis-sj:
    image: redis:7.4-alpine
    container_name: sj-redis
    restart: unless-stopped
    ports:
      - "6379:6379"
    volumes:
      - redis_data_sj:/data
    command: redis-server --appendonly yes
    networks:
      - sj-network

volumes:
  redis_data_sj:

networks:
  sj-network:
    driver: bridge
EOF
                log_success "Redis配置已添加到docker-compose.sj.yml"
            fi
            
            # 启动Redis容器
            log_info "启动Redis容器..."
            docker-compose -f docker-compose.sj.yml up -d redis-sj || true
            
        fi
        
        cd ../..
    fi
}

# 重启SSO API服务
restart_sso_api() {
    log_step "重启SJ服务器SSO API服务..."
    
    if [ -d "infra/docker" ]; then
        cd infra/docker
        
        if [ -f "docker-compose.sj.yml" ]; then
            log_info "重启SSO API容器..."
            docker-compose -f docker-compose.sj.yml restart sso-api || true
            
            # 等待服务启动
            log_info "等待SSO API启动（15秒）..."
            sleep 15
            
            # 检查健康状态
            log_info "检查SSO API健康状态..."
            if curl -f http://localhost:5004/health 2>/dev/null; then
                log_success "SSO API健康检查通过"
            else
                log_warning "SSO API健康检查失败"
                docker-compose -f docker-compose.sj.yml logs --tail=20 sso-api
            fi
        fi
        
        cd ../..
    fi
}

# 清理冲突的Redis实例
cleanup_redis_conflicts() {
    log_step "清理冲突的Redis实例..."
    
    # 停止所有Redis进程
    log_info "停止所有Redis进程..."
    sudo pkill -f redis-server 2>/dev/null || true
    
    # 停止systemd服务
    systemctl stop redis-server 2>/dev/null || true
    systemctl stop redis 2>/dev/null || true
    
    # 停止Docker Redis容器
    docker stop sj-redis 2>/dev/null || true
    docker rm sj-redis 2>/dev/null || true
    
    # 清理PID文件
    sudo rm -f /var/run/redis/*.pid 2>/dev/null || true
    
    log_success "Redis实例清理完成"
}

# 查看相关日志
show_logs() {
    log_step "查看SJ服务器相关日志..."
    
    echo -e "\n${CYAN}=== systemd Redis日志 ===${NC}"
    journalctl -xeu redis-server.service --no-pager -l | tail -30 || true
    
    echo -e "\n${CYAN}=== Redis日志文件 ===${NC}"
    if [ -f "/var/log/redis/redis-server.log" ]; then
        tail -30 /var/log/redis/redis-server.log
    else
        echo "Redis日志文件不存在"
    fi
    
    echo -e "\n${CYAN}=== Docker Redis日志 ===${NC}"
    if docker ps | grep -q sj-redis; then
        docker logs --tail=30 sj-redis
    else
        echo "Docker Redis容器未运行"
    fi
    
    echo -e "\n${CYAN}=== SSO API日志 ===${NC}"
    if [ -d "infra/docker" ]; then
        cd infra/docker
        if [ -f "docker-compose.sj.yml" ]; then
            docker-compose -f docker-compose.sj.yml logs --tail=30 sso-api || true
        fi
        cd ../..
    fi
}

# 检查服务状态
check_status() {
    log_step "检查SJ服务器服务状态..."
    
    echo -e "\n${CYAN}=== Redis进程状态 ===${NC}"
    check_redis_processes
    
    echo -e "\n${CYAN}=== 端口占用状态 ===${NC}"
    check_port_usage
    
    echo -e "\n${CYAN}=== Redis连接测试 ===${NC}"
    test_redis_connection
    
    echo -e "\n${CYAN}=== SSO API状态 ===${NC}"
    if curl -f http://localhost:5004/health 2>/dev/null; then
        log_success "SSO API运行正常"
    else
        log_error "SSO API无法访问"
    fi
}

# 主函数
main() {
    echo -e "${BLUE}🔧 SJ服务器Redis问题诊断和修复${NC}"
    
    case "${1:-}" in
        "diagnose")
            full_diagnosis
            ;;
        "fix-systemd")
            fix_systemd_redis
            ;;
        "fix-docker")
            fix_docker_redis
            ;;
        "restart-sso")
            restart_sso_api
            ;;
        "check-ports")
            check_port_usage
            ;;
        "logs")
            show_logs
            ;;
        "status")
            check_status
            ;;
        "cleanup")
            cleanup_redis_conflicts
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