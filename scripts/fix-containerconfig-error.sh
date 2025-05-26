#!/bin/bash

# 专门修复 ContainerConfig 错误的脚本
# 这个错误通常由 Docker 镜像损坏或缓存问题导致

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
    echo -e "${BLUE}🔧 ContainerConfig 错误修复脚本${NC}"
    echo ""
    echo "此脚本专门用于修复 Docker Compose 中的 ContainerConfig 错误："
    echo "  KeyError: 'ContainerConfig'"
    echo ""
    echo "使用方法："
    echo "  $0 [VPS选择]"
    echo ""
    echo "VPS选择："
    echo "  1    - SJ 服务器 (Profile, Auth, Chat, SSO API)"
    echo "  2    - Buffalo 服务器 (Fortune API)"
    echo ""
    echo "示例："
    echo "  $0 1    # 修复 SJ 服务器的 ContainerConfig 错误"
    echo "  $0 2    # 修复 Buffalo 服务器的 ContainerConfig 错误"
}

# 选择 VPS
select_vps() {
    if [ -z "$1" ]; then
        echo -e "${YELLOW}请选择要修复的 VPS：${NC}"
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
}

# 检查 Docker 是否运行
check_docker() {
    if ! docker info > /dev/null 2>&1; then
        log_error "Docker 未运行，请启动 Docker 后重试"
        exit 1
    fi
    log_success "Docker 运行正常"
}

# 完全停止和清理
complete_cleanup() {
    log_warning "开始完全清理，这将删除所有相关的容器、镜像和卷..."
    
    cd infra/docker
    
    # 1. 停止所有服务
    log_info "停止所有 Docker Compose 服务..."
    docker-compose -f "$DOCKER_COMPOSE_FILE" down --remove-orphans --volumes 2>/dev/null || true
    
    # 2. 强制删除相关容器
    log_info "强制删除相关容器..."
    if [ "$VPS_CHOICE" = "1" ]; then
        containers="baidaohui-profile-api baidaohui-auth-api baidaohui-chat-api baidaohui-sso-api"
    else
        containers="buffalo-fortune-api"
    fi
    
    for container in $containers; do
        docker stop "$container" 2>/dev/null || true
        docker rm -f "$container" 2>/dev/null || true
    done
    
    # 3. 删除所有相关镜像（包括中间镜像）
    log_info "删除所有相关镜像..."
    if [ "$VPS_CHOICE" = "1" ]; then
        # SJ 服务器镜像
        docker rmi $(docker images | grep -E "(profile|auth|chat|sso)" | awk '{print $3}') 2>/dev/null || true
        docker rmi infra-docker-profile-api infra-docker-auth-api infra-docker-chat-api infra-docker-sso-api 2>/dev/null || true
        docker rmi infra_docker_profile-api infra_docker_auth-api infra_docker_chat-api infra_docker_sso-api 2>/dev/null || true
        docker rmi docker-profile-api docker-auth-api docker-chat-api docker-sso-api 2>/dev/null || true
    else
        # Buffalo 服务器镜像
        docker rmi $(docker images | grep -E "fortune" | awk '{print $3}') 2>/dev/null || true
        docker rmi infra-docker-fortune-api infra_docker_fortune-api docker-fortune-api 2>/dev/null || true
    fi
    
    # 4. 删除悬空镜像
    log_info "删除悬空镜像..."
    docker rmi $(docker images -f "dangling=true" -q) 2>/dev/null || true
    
    # 5. 清理 Docker 系统
    log_info "清理 Docker 系统..."
    docker system prune -a -f --volumes
    
    # 6. 清理 Docker 构建缓存
    log_info "清理 Docker 构建缓存..."
    docker builder prune -a -f
    
    cd ../..
    log_success "完全清理完成"
}

# 重新拉取基础镜像
pull_base_images() {
    log_info "重新拉取基础镜像..."
    
    # 拉取 Python 基础镜像
    docker pull python:3.11-slim
    docker pull python:3.11
    
    # 拉取其他可能用到的基础镜像
    docker pull alpine:latest
    docker pull ubuntu:22.04
    
    log_success "基础镜像拉取完成"
}

# 重新构建服务
rebuild_services() {
    log_info "重新构建 $SERVER_NAME 服务..."
    
    cd infra/docker
    
    # 逐个构建服务，避免并发问题
    for service in $SERVICES; do
        log_info "构建 $service..."
        
        # 使用最严格的构建参数
        docker-compose -f "$DOCKER_COMPOSE_FILE" build \
            --no-cache \
            --pull \
            --force-rm \
            --parallel \
            "$service"
        
        # 验证镜像是否构建成功
        if docker images | grep -q "$service"; then
            log_success "$service 构建成功"
        else
            log_error "$service 构建失败"
            exit 1
        fi
    done
    
    cd ../..
    log_success "所有服务重新构建完成"
}

# 验证镜像完整性
verify_images() {
    log_info "验证镜像完整性..."
    
    cd infra/docker
    
    for service in $SERVICES; do
        log_info "验证 $service 镜像..."
        
        # 检查镜像是否存在
        image_id=$(docker-compose -f "$DOCKER_COMPOSE_FILE" images -q "$service" 2>/dev/null || true)
        if [ -z "$image_id" ]; then
            log_error "$service 镜像不存在"
            exit 1
        fi
        
        # 检查镜像是否损坏
        if docker inspect "$image_id" > /dev/null 2>&1; then
            log_success "$service 镜像完整"
        else
            log_error "$service 镜像损坏"
            exit 1
        fi
    done
    
    cd ../..
    log_success "所有镜像验证通过"
}

# 启动服务
start_services() {
    log_info "启动 $SERVER_NAME 服务..."
    
    cd infra/docker
    
    # 逐个启动服务，避免并发问题
    for service in $SERVICES; do
        log_info "启动 $service..."
        
        # 单独启动每个服务
        docker-compose -f "$DOCKER_COMPOSE_FILE" up -d "$service"
        
        # 等待服务启动
        sleep 5
        
        # 检查服务是否启动成功
        if docker-compose -f "$DOCKER_COMPOSE_FILE" ps "$service" | grep -q "Up"; then
            log_success "$service 启动成功"
        else
            log_error "$service 启动失败"
            docker-compose -f "$DOCKER_COMPOSE_FILE" logs "$service"
            exit 1
        fi
    done
    
    cd ../..
    log_success "所有服务启动完成"
}

# 检查服务状态
check_services() {
    log_info "检查服务状态..."
    
    cd infra/docker
    
    echo -e "\n${BLUE}=== 服务状态 ===${NC}"
    docker-compose -f "$DOCKER_COMPOSE_FILE" ps $SERVICES
    
    echo -e "\n${BLUE}=== 最近日志 ===${NC}"
    for service in $SERVICES; do
        echo -e "\n${BLUE}--- $service 日志 ---${NC}"
        docker-compose -f "$DOCKER_COMPOSE_FILE" logs --tail=10 "$service"
    done
    
    cd ../..
}

# 主函数
main() {
    echo -e "${BLUE}🔧 开始修复 ContainerConfig 错误...${NC}"
    log_warning "这个过程将完全清理和重建所有相关的 Docker 资源"
    
    read -p "确定要继续吗？(y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log_info "操作已取消"
        exit 0
    fi
    
    check_docker
    complete_cleanup
    pull_base_images
    rebuild_services
    verify_images
    start_services
    check_services
    
    log_success "ContainerConfig 错误修复完成！"
    log_info "如果问题仍然存在，可能需要："
    log_info "1. 重启 Docker 服务"
    log_info "2. 检查磁盘空间"
    log_info "3. 更新 Docker 版本"
}

# 处理命令行参数
if [ $# -eq 0 ]; then
    show_usage
    exit 0
fi

# 选择 VPS 并运行修复
select_vps "$1"
main 