#!/bin/bash

# 通用函数库 - 供所有部署脚本使用
# 避免代码重复，提供统一的功能接口

# 颜色定义
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export CYAN='\033[0;36m'
export NC='\033[0m' # No Color

# VPS配置
export SAN_JOSE_IP="107.172.87.113"
export BUFFALO_IP="216.144.233.104"
export SAN_JOSE_MEMORY="2.4G"
export BUFFALO_MEMORY="0.6G"

# Docker配置
export DOCKER_REGISTRY=${DOCKER_REGISTRY:-"yourregistry"}
export IMAGE_TAG=${IMAGE_TAG:-"latest"}
export PROJECT="baidaohui"

# 内部API密钥
export INTERNAL_API_KEY=${INTERNAL_API_KEY:-"auto-generated-internal-key"}

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${CYAN}[STEP]${NC} $1"
}

# 显示横幅
show_banner() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}    Baidaohui 部署管理系统${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
}

# 检查Docker环境
check_docker() {
    log_info "检查Docker环境..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker 未安装，请先安装 Docker"
        exit 1
    fi
    
    if ! docker info > /dev/null 2>&1; then
        log_error "Docker 未运行或无法访问"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose 未安装，请先安装 Docker Compose"
        exit 1
    fi
    
    log_success "Docker 环境检查通过"
}

# 检查环境变量文件
check_env_file() {
    if [ ! -f "infra/.env" ]; then
        log_error "环境变量文件 infra/.env 不存在"
        log_info "请复制 infra/.env.example 并配置相应的环境变量"
        exit 1
    fi
    log_success "环境变量文件检查通过"
}

# 获取所有服务列表
get_all_services() {
    echo "$(get_san_jose_services) $(get_buffalo_services)"
}

# 获取圣何塞VPS服务列表
get_san_jose_services() {
    echo "auth-service sso-service chat-service ecommerce-api-service invite-service payment-service key-service static-api-service ai-proxy-service"
}

# 获取水牛城VPS服务列表
get_buffalo_services() {
    echo "fortune-service email-service r2-sync-service"
}

# 获取服务端口映射
get_service_port() {
    local service=$1
    case $service in
        "auth-service") echo "5001" ;;
        "sso-service") echo "5002" ;;
        "chat-service") echo "5003" ;;
        "fortune-service") echo "5007" ;;
        "ecommerce-api-service") echo "5004" ;;
        "payment-service") echo "5008" ;;
        "invite-service") echo "5006" ;;
        "key-service") echo "5009" ;;
        "email-service") echo "5008" ;;
        "static-api-service") echo "5010" ;;
        "r2-sync-service") echo "5011" ;;
        "ai-proxy-service") echo "5012" ;;
        "ecommerce-poller") echo "" ;; # 内部服务，无端口映射
        "exchange-rate-updater") echo "" ;; # 内部服务，无端口映射
        *) echo "" ;;
    esac
}

# 获取服务描述
get_service_description() {
    local service=$1
    case $service in
        "auth-service") echo "用户认证服务" ;;
        "sso-service") echo "单点登录服务" ;;
        "chat-service") echo "聊天功能服务" ;;
        "fortune-service") echo "算命业务服务" ;;
        "ecommerce-api-service") echo "电商API服务" ;;
        "payment-service") echo "支付处理服务" ;;
        "invite-service") echo "邀请管理服务" ;;
        "key-service") echo "密钥管理服务" ;;
        "email-service") echo "邮件发送服务" ;;
        "static-api-service") echo "静态API服务" ;;
        "r2-sync-service") echo "R2数据同步服务" ;;
        "ai-proxy-service") echo "AI代理服务" ;;
        "ecommerce-poller") echo "电商数据轮询服务" ;;
        "exchange-rate-updater") echo "汇率更新服务" ;;
        *) echo "未知服务" ;;
    esac
}

# 构建单个服务镜像（本地部署版本）
build_service_image() {
    local service=$1
    local service_dir="services/$service"
    local image_name="baidaohui-$service:latest"
    
    log_step "构建服务: $service ($(get_service_description $service))"
    
    if [ ! -d "$service_dir" ]; then
        log_error "服务目录不存在: $service_dir"
        return 1
    fi
    
    if [ ! -f "$service_dir/Dockerfile" ]; then
        log_error "Dockerfile 不存在: $service_dir/Dockerfile"
        return 1
    fi
    
    # 构建镜像
    log_info "构建镜像: $image_name"
    if docker build -t "$image_name" "$service_dir"; then
        log_success "✅ 构建成功: $service"
    else
        log_error "❌ 构建失败: $service"
        return 1
    fi
    
    return 0
}

# 单个服务健康检查
check_service_health() {
    local service=$1
    local host=${2:-"localhost"}
    local port=$(get_service_port $service)
    local max_retries=${3:-5}
    local wait_time=${4:-10}
    
    if [ -z "$port" ]; then
        # 内部服务，检查容器状态
        if docker ps --filter "name=$service" --filter "status=running" | grep -q "$service"; then
            log_success "✅ $service 容器运行正常"
            return 0
        else
            log_error "❌ $service 容器未运行"
            return 1
        fi
    else
        # 有端口映射的服务，检查HTTP健康端点
        local health_url="http://$host:$port/health"
        log_info "检查服务健康状态: $service ($health_url)"
        
        for i in $(seq 1 $max_retries); do
            if curl -f -s --connect-timeout 5 --max-time 10 "$health_url" > /dev/null 2>&1; then
                log_success "✅ $service 健康检查通过"
                return 0
            else
                if [ $i -eq $max_retries ]; then
                    log_error "❌ $service 健康检查失败"
                    return 1
                else
                    log_warning "⏳ $service 健康检查失败，重试中... ($i/$max_retries)"
                    sleep $wait_time
                fi
            fi
        done
    fi
    
    return 1
}

# 批量健康检查
batch_health_check() {
    local services_list="$1"
    local host=${2:-"localhost"}
    local failed_services=()
    
    log_step "执行批量健康检查..."
    
    for service in $services_list; do
        if ! check_service_health "$service" "$host" 3 5; then
            failed_services+=("$service")
        fi
    done
    
    echo ""
    if [ ${#failed_services[@]} -eq 0 ]; then
        log_success "🎉 所有服务健康检查通过！"
        return 0
    else
        log_error "以下服务健康检查失败:"
        for service in "${failed_services[@]}"; do
            log_error "  - $service ($(get_service_description $service))"
        done
        return 1
    fi
}

# 显示VPS选择菜单
show_vps_selection() {
    echo -e "${BLUE}请选择部署目标VPS:${NC}"
    echo ""
    echo -e "${CYAN}1. 圣何塞 VPS (${SAN_JOSE_IP})${NC}"
    echo "   • 内存: ${SAN_JOSE_MEMORY}, CPU: 2核"
    echo "   • 服务: $(get_san_jose_services | wc -w)个高性能服务"
    echo "   • 功能: 认证、SSO、聊天、电商API、支付、邀请、密钥、静态API、AI代理服务"
    echo ""
    echo -e "${CYAN}2. 水牛城 VPS (${BUFFALO_IP})${NC}"
    echo "   • 内存: ${BUFFALO_MEMORY}, CPU: 1核"
    echo "   • 服务: $(get_buffalo_services | wc -w)个后台服务"
    echo "   • 功能: 算命、邮件、电商轮询、R2同步、汇率更新"
    echo ""
    echo -e "${YELLOW}3. 两个VPS都部署${NC}"
    echo ""
}

# 获取用户VPS选择
get_vps_selection() {
    while true; do
        show_vps_selection
        read -p "请输入选项 (1/2/3): " choice
        
        case $choice in
            1)
                echo "san-jose"
                return 0
                ;;
            2)
                echo "buffalo"
                return 0
                ;;
            3)
                echo "both"
                return 0
                ;;
            *)
                log_error "无效选项，请重新选择"
                echo ""
                ;;
        esac
    done
}

# 显示服务状态
show_service_status() {
    local target_vps="$1"
    
    echo ""
    log_info "服务访问信息:"
    echo ""
    
    if [ "$target_vps" = "san-jose" ] || [ "$target_vps" = "both" ]; then
        echo -e "${CYAN}圣何塞 VPS (${SAN_JOSE_IP}):${NC}"
        for service in $(get_san_jose_services); do
            local port=$(get_service_port $service)
            local desc=$(get_service_description $service)
            if [ -n "$port" ]; then
                echo "  • $desc: http://${SAN_JOSE_IP}:$port"
            else
                echo "  • $desc: 内部服务"
            fi
        done
        echo ""
    fi
    
    if [ "$target_vps" = "buffalo" ] || [ "$target_vps" = "both" ]; then
        echo -e "${CYAN}水牛城 VPS (${BUFFALO_IP}):${NC}"
        for service in $(get_buffalo_services); do
            local port=$(get_service_port $service)
            local desc=$(get_service_description $service)
            if [ -n "$port" ]; then
                echo "  • $desc: http://${BUFFALO_IP}:$port"
            else
                echo "  • $desc: 内部服务"
            fi
        done
        echo ""
    fi
    
    echo -e "${YELLOW}注意: 请确保防火墙已开放相应端口${NC}"
}

# 清理Docker镜像
cleanup_docker_images() {
    local cleanup_all=${1:-false}
    
    log_info "清理Docker镜像..."
    
    # 清理悬空镜像
    docker image prune -f > /dev/null 2>&1
    
    # 可选：清理所有未使用的镜像
    if [ "$cleanup_all" = "true" ]; then
        docker image prune -a -f > /dev/null 2>&1
    fi
    
    log_success "✅ 镜像清理完成"
}

# 显示内存使用规划
show_memory_planning() {
    local target_vps="$1"
    
    if [ "$target_vps" = "san-jose" ] || [ "$target_vps" = "both" ]; then
        echo ""
        log_info "圣何塞 VPS 内存使用规划 (总计: 2.4G):"
        echo "  - Auth Service:       256M"
        echo "  - SSO Service:        256M"
        echo "  - Chat Service:       512M"
        echo "  - Ecommerce API:      384M"
        echo "  - Payment Service:    256M"
        echo "  - Invite Service:     192M"
        echo "  - Key Service:        192M"
        echo "  - Static API Service: 128M"
        echo "  - Redis:              256M"
        echo "  - AI Proxy Service:   256M"
        echo "  - 系统预留:           ~116M"
    fi
    
    if [ "$target_vps" = "buffalo" ] || [ "$target_vps" = "both" ]; then
        echo ""
        log_info "水牛城 VPS 内存使用规划 (总计: 0.6G):"
        echo "  - Fortune Service:    384M"
        echo "  - Email Service:      192M"
        echo "  - Ecommerce Poller:   128M"
        echo "  - Exchange Updater:   64M"
        echo "  - R2 Sync Service:    96M"
        echo "  - 系统预留:           ~4M"
    fi
    echo ""
}

# 停止VPS服务 - 核弹级清理
stop_vps_services() {
    local target_vps="$1"
    
    log_info "执行强制容器清理..."
    
    # 第一步：停止所有compose服务
    if [ "$target_vps" = "san-jose" ] || [ "$target_vps" = "both" ]; then
        log_info "停止圣何塞VPS compose服务..."
        cd infra 2>/dev/null || true
        docker-compose -f docker-compose.san-jose.yml down --remove-orphans --volumes --timeout 10 2>/dev/null || true
        cd - > /dev/null 2>&1 || true
    fi
    
    if [ "$target_vps" = "buffalo" ] || [ "$target_vps" = "both" ]; then
        log_info "停止水牛城VPS compose服务..."
        cd infra 2>/dev/null || true
        docker-compose -f docker-compose.buffalo.yml down --remove-orphans --volumes --timeout 10 2>/dev/null || true
        cd - > /dev/null 2>&1 || true
    fi
    
    # 第二步：核弹级清理 - 停止所有运行的容器
    log_info "强制停止所有运行容器..."
    docker stop $(docker ps -q) 2>/dev/null || true
    
    # 第三步：删除所有已停止的容器
    log_info "删除所有容器..."
    docker rm -f $(docker ps -aq) 2>/dev/null || true
    
    # 第四步：按名称强制删除可能残留的容器
    local all_service_names="auth-service sso-service chat-service ecommerce-service payment-service invite-service key-service static-api-service fortune-service email-service ecommerce-poller r2-sync-service exchange-rate-updater baidaohui-redis baidaohui-nginx redis nginx ai-proxy-service"
    
    log_info "清理特定服务容器..."
    for container_name in $all_service_names; do
        # 尝试多种方式删除
        docker stop "$container_name" 2>/dev/null || true
        docker rm -f "$container_name" 2>/dev/null || true
        docker stop "/${container_name}" 2>/dev/null || true  
        docker rm -f "/${container_name}" 2>/dev/null || true
        
        # 通过容器ID查找并删除
        local container_ids=$(docker ps -aq --filter "name=${container_name}" 2>/dev/null || true)
        if [ -n "$container_ids" ]; then
            echo "$container_ids" | xargs -r docker stop 2>/dev/null || true
            echo "$container_ids" | xargs -r docker rm -f 2>/dev/null || true
        fi
    done
    
    # 第五步：清理网络
    log_info "清理Docker网络..."
    docker network prune -f 2>/dev/null || true
    
    # 第六步：清理卷
    log_info "清理未使用的卷..."
    docker volume prune -f 2>/dev/null || true
    
    # 最后：等待确保清理完成
    sleep 3
    
    log_success "✅ 容器强制清理完成"
    
    # 显示清理后状态
    local remaining_containers=$(docker ps -a --format "table {{.Names}}\t{{.Status}}" 2>/dev/null | tail -n +2 | wc -l)
    log_info "剩余容器数量: $remaining_containers"
}

# 启动VPS服务
start_vps_services() {
    local target_vps="$1"
    
    log_info "启动服务..."
    
    # 确保在正确的目录中
    if [ ! -d "infra" ]; then
        log_error "错误：未找到 infra 目录，请确保在项目根目录中运行脚本"
        return 1
    fi
    
    cd infra || {
        log_error "无法进入 infra 目录"
        return 1
    }
    
    if [ "$target_vps" = "san-jose" ] || [ "$target_vps" = "both" ]; then
        log_info "启动圣何塞 VPS 服务..."
        if [ ! -f "docker-compose.san-jose.yml" ]; then
            log_error "未找到 docker-compose.san-jose.yml 文件"
            cd - > /dev/null
            return 1
        fi
        
        if docker-compose -f docker-compose.san-jose.yml up -d; then
            log_success "✅ 圣何塞 VPS 服务启动成功"
        else
            log_error "❌ 圣何塞 VPS 服务启动失败"
            cd - > /dev/null
            return 1
        fi
    fi
    
    if [ "$target_vps" = "buffalo" ] || [ "$target_vps" = "both" ]; then
        log_info "启动水牛城 VPS 服务..."
        if [ ! -f "docker-compose.buffalo.yml" ]; then
            log_error "未找到 docker-compose.buffalo.yml 文件"
            cd - > /dev/null
            return 1
        fi
        
        if docker-compose -f docker-compose.buffalo.yml up -d; then
            log_success "✅ 水牛城 VPS 服务启动成功"
        else
            log_error "❌ 水牛城 VPS 服务启动失败"
            cd - > /dev/null
            return 1
        fi
    fi
    
    cd - > /dev/null
    
    # 等待服务启动
    log_info "等待服务启动完成..."
    sleep 30
    
    return 0
}

# 检查Redis连接
check_redis_connection() {
    if docker exec redis redis-cli ping > /dev/null 2>&1; then
        log_success "✅ Redis 连接正常"
        return 0
    else
        log_error "❌ Redis 连接失败"
        return 1
    fi
}

# 显示部署总结
show_deployment_summary() {
    local target_vps="$1"
    local total_services=0
    local success_count="$2"
    local failed_count="$3"
    
    if [ "$target_vps" = "san-jose" ]; then
        total_services=$(get_san_jose_services | wc -w)
    elif [ "$target_vps" = "buffalo" ]; then
        total_services=$(get_buffalo_services | wc -w)
    else
        total_services=$(get_all_services | wc -w)
    fi
    
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}    部署完成总结${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    echo -e "${BLUE}目标VPS:${NC} $target_vps"
    echo -e "${BLUE}总服务数:${NC} $total_services"
    echo -e "${GREEN}成功:${NC} ${success_count:-0}"
    echo -e "${RED}失败:${NC} ${failed_count:-0}"
    echo -e "${BLUE}部署时间:${NC} $(date)"
    echo ""
} 