#!/bin/bash

# 修复 Supabase 兼容性问题的部署脚本
# 解决 TypeError: Client.__init__() got an unexpected keyword argument 'proxy' 错误

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 全局变量
VPS_CHOICE=""
DOCKER_COMPOSE_FILE=""
SERVICES=""
SERVER_NAME=""

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

# 显示使用说明
show_usage() {
    echo -e "${BLUE}🔧 Supabase 兼容性问题修复脚本${NC}"
    echo ""
    echo "使用方法："
    echo "  $0 [VPS选择] [操作]"
    echo ""
    echo "VPS选择："
    echo "  1    - SJ 服务器 (Profile, Auth, Chat, SSO API)"
    echo "  2    - Buffalo 服务器 (Fortune API)"
    echo ""
    echo "操作："
    echo "  (无)     - 执行完整修复流程"
    echo "  stop     - 停止服务"
    echo "  clean    - 强力清理（解决 ContainerConfig 错误）"
    echo "  rebuild  - 重新构建服务"
    echo "  start    - 启动服务"
    echo "  health   - 检查健康状态"
    echo "  logs     - 查看日志"
    echo ""
    echo "示例："
    echo "  $0 1         # 修复 SJ 服务器"
    echo "  $0 2         # 修复 Buffalo 服务器"
    echo "  $0 1 clean   # 强力清理 SJ 服务器"
    echo "  $0 2 logs    # 查看 Buffalo 服务器日志"
}

# 选择 VPS
select_vps() {
    if [ -z "$1" ]; then
        echo -e "${YELLOW}请选择要操作的 VPS：${NC}"
        echo "1) SJ 服务器 (Profile, Auth, Chat, SSO API)"
        echo "2) Buffalo 服务器 (Fortune API)"
        read -p "请输入选择 (1 或 2): " VPS_CHOICE
    else
        VPS_CHOICE="$1"
    fi

    case "$VPS_CHOICE" in
        "1")
            DOCKER_COMPOSE_FILE="docker-compose.sj.yml"
            SERVICES="profile-api auth-api chat-api sso-api"
            SERVER_NAME="SJ 服务器"
            ;;
        "2")
            DOCKER_COMPOSE_FILE="docker-compose.buffalo.yml"
            SERVICES="fortune-api"
            SERVER_NAME="Buffalo 服务器"
            ;;
        *)
            log_error "无效的选择，请输入 1 或 2"
            show_usage
            exit 1
            ;;
    esac

    log_info "已选择：$SERVER_NAME"
    log_info "Docker Compose 文件：$DOCKER_COMPOSE_FILE"
    log_info "服务：$SERVICES"
}

# 检查 Docker 是否运行
check_docker() {
    if ! docker info > /dev/null 2>&1; then
        log_error "Docker 未运行，请启动 Docker 后重试"
        exit 1
    fi
    log_success "Docker 运行正常"
}

# 停止相关服务
stop_services() {
    log_info "停止 $SERVER_NAME 服务..."
    
    cd infra/docker
    
    # 停止服务
    docker-compose -f "$DOCKER_COMPOSE_FILE" stop $SERVICES || true
    
    # 强制删除容器
    log_info "强制删除相关容器..."
    for service in $SERVICES; do
        container_name=$(docker-compose -f "$DOCKER_COMPOSE_FILE" ps -q "$service" 2>/dev/null || true)
        if [ ! -z "$container_name" ]; then
            docker rm -f "$container_name" 2>/dev/null || true
        fi
    done
    
    cd ../..
    log_success "服务停止完成"
}

# 强力清理（解决 ContainerConfig 错误）
force_cleanup() {
    log_warning "执行强力清理，这将删除所有相关的镜像和容器..."
    
    # 停止所有相关容器
    log_info "停止所有相关容器..."
    if [ "$VPS_CHOICE" = "1" ]; then
        docker stop baidaohui-profile-api baidaohui-auth-api baidaohui-chat-api baidaohui-sso-api 2>/dev/null || true
        docker rm -f baidaohui-profile-api baidaohui-auth-api baidaohui-chat-api baidaohui-sso-api 2>/dev/null || true
    else
        docker stop buffalo-fortune-api 2>/dev/null || true
        docker rm -f buffalo-fortune-api 2>/dev/null || true
    fi
    
    # 删除相关镜像
    log_info "删除相关镜像..."
    if [ "$VPS_CHOICE" = "1" ]; then
        docker rmi $(docker images | grep -E "(profile|auth|chat|sso)" | awk '{print $3}') 2>/dev/null || true
        docker rmi infra-docker-profile-api infra-docker-auth-api infra-docker-chat-api infra-docker-sso-api 2>/dev/null || true
        docker rmi infra_docker_profile-api infra_docker_auth-api infra_docker_chat-api infra_docker_sso-api 2>/dev/null || true
    else
        docker rmi $(docker images | grep -E "fortune" | awk '{print $3}') 2>/dev/null || true
        docker rmi infra-docker-fortune-api infra_docker_fortune-api 2>/dev/null || true
    fi
    
    # 清理 Docker 系统
    log_info "清理 Docker 系统..."
    docker system prune -f
    docker image prune -a -f
    docker volume prune -f
    
    # 清理 Docker Compose 缓存
    log_info "清理 Docker Compose 缓存..."
    cd infra/docker
    docker-compose -f "$DOCKER_COMPOSE_FILE" down --remove-orphans 2>/dev/null || true
    cd ../..
    
    log_success "强力清理完成"
}

# 清理旧镜像（温和版本）
cleanup_images() {
    log_info "清理旧的 Docker 镜像..."
    
    # 删除相关的镜像
    if [ "$VPS_CHOICE" = "1" ]; then
        docker rmi $(docker images | grep -E "(profile|auth|chat|sso)" | awk '{print $3}') 2>/dev/null || true
    else
        docker rmi $(docker images | grep -E "fortune" | awk '{print $3}') 2>/dev/null || true
    fi
    
    # 清理未使用的镜像
    docker image prune -f
    
    log_success "镜像清理完成"
}

# 重新构建服务
rebuild_services() {
    log_info "重新构建 $SERVER_NAME 服务..."
    
    cd infra/docker
    
    # 拉取最新的基础镜像
    log_info "拉取最新的基础镜像..."
    docker pull python:3.11-slim || true
    
    # 重新构建服务
    for service in $SERVICES; do
        log_info "重新构建 $service..."
        docker-compose -f "$DOCKER_COMPOSE_FILE" build --no-cache --pull "$service"
    done
    
    cd ../..
    log_success "服务重新构建完成"
}

# 启动服务
start_services() {
    log_info "启动 $SERVER_NAME 服务..."
    
    cd infra/docker
    
    # 启动服务
    log_info "启动服务：$SERVICES"
    docker-compose -f "$DOCKER_COMPOSE_FILE" up -d $SERVICES
    
    cd ../..
    log_success "服务启动完成"
}

# 检查服务健康状态
check_health() {
    log_info "检查 $SERVER_NAME 服务健康状态..."
    
    # 等待服务启动
    log_info "等待服务启动（30秒）..."
    sleep 30
    
    # 根据 VPS 选择检查不同的服务
    if [ "$VPS_CHOICE" = "1" ]; then
        services_to_check=(
            "baidaohui-profile-api:5002"
            "baidaohui-auth-api:5001"
            "baidaohui-chat-api:5003"
            "baidaohui-sso-api:5004"
        )
    else
        services_to_check=(
            "buffalo-fortune-api:5000"
        )
    fi
    
    for service in "${services_to_check[@]}"; do
        container_name=$(echo $service | cut -d':' -f1)
        port=$(echo $service | cut -d':' -f2)
        
        if docker ps | grep -q $container_name; then
            log_success "$container_name 容器运行正常"
            
            # 尝试访问健康检查端点
            if docker exec $container_name curl -f http://localhost:$port/health > /dev/null 2>&1; then
                log_success "$container_name 健康检查通过"
            else
                log_warning "$container_name 健康检查失败，请检查日志"
            fi
        else
            log_error "$container_name 容器未运行"
        fi
    done
}

# 显示服务日志
show_logs() {
    log_info "显示 $SERVER_NAME 服务日志（最近 50 行）..."
    
    cd infra/docker
    
    for service in $SERVICES; do
        echo -e "\n${BLUE}=== $service 日志 ===${NC}"
        docker-compose -f "$DOCKER_COMPOSE_FILE" logs --tail=50 "$service"
    done
    
    cd ../..
}

# 主函数
main() {
    echo -e "${BLUE}🔧 开始修复 Supabase 兼容性问题...${NC}"
    log_info "问题：TypeError: Client.__init__() got an unexpected keyword argument 'proxy'"
    log_info "解决方案：升级 Supabase 客户端从 2.3.0 到 2.9.0"
    
    check_docker
    stop_services
    force_cleanup  # 使用强力清理来解决 ContainerConfig 错误
    rebuild_services
    start_services
    check_health
    
    log_success "修复完成！"
    log_info "如果仍有问题，请运行以下命令查看详细日志："
    log_info "  $0 $VPS_CHOICE logs"
}

# 处理命令行参数
if [ $# -eq 0 ]; then
    show_usage
    exit 0
fi

# 选择 VPS
select_vps "$1"

# 处理操作
case "${2:-}" in
    "stop")
        check_docker
        stop_services
        ;;
    "clean")
        check_docker
        stop_services
        force_cleanup
        ;;
    "rebuild")
        check_docker
        rebuild_services
        ;;
    "start")
        check_docker
        start_services
        ;;
    "health")
        check_health
        ;;
    "logs")
        show_logs
        ;;
    "")
        main
        ;;
    *)
        log_error "未知操作: $2"
        show_usage
        exit 1
        ;;
esac 