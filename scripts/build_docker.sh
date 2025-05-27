#!/bin/bash

# Docker 构建和推送脚本
# 用于构建所有 baidaohui 微服务的 Docker 镜像

set -e

# 配置
REGISTRY="yourregistry"
PROJECT="baidaohui"
VERSION=${1:-latest}

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查 Docker 是否运行
check_docker() {
    if ! docker info > /dev/null 2>&1; then
        log_error "Docker 未运行或无法访问"
        exit 1
    fi
    log_info "Docker 检查通过"
}

# 构建单个服务
build_service() {
    local service=$1
    local service_dir="services/$service"
    local image_name="$REGISTRY/$PROJECT-$service:$VERSION"
    
    log_info "开始构建服务: $service"
    
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
        log_info "✅ 构建成功: $service"
    else
        log_error "❌ 构建失败: $service"
        return 1
    fi
    
    # 推送镜像
    log_info "推送镜像: $image_name"
    if docker push "$image_name"; then
        log_info "✅ 推送成功: $service"
    else
        log_error "❌ 推送失败: $service"
        return 1
    fi
    
    # 标记为 latest（如果版本不是 latest）
    if [ "$VERSION" != "latest" ]; then
        local latest_image="$REGISTRY/$PROJECT-$service:latest"
        docker tag "$image_name" "$latest_image"
        docker push "$latest_image"
        log_info "✅ 已标记并推送 latest 标签: $service"
    fi
}

# 清理本地镜像
cleanup_images() {
    log_info "清理本地镜像..."
    
    # 清理悬空镜像
    docker image prune -f
    
    # 可选：清理所有未使用的镜像
    if [ "$CLEANUP_ALL" = "true" ]; then
        docker image prune -a -f
    fi
    
    log_info "✅ 镜像清理完成"
}

# 主函数
main() {
    log_info "开始构建 baidaohui 项目 Docker 镜像"
    log_info "版本: $VERSION"
    log_info "仓库: $REGISTRY"
    
    # 检查 Docker
    check_docker
    
    # 定义所有服务
    services=(
        "auth-service"
        "chat-service" 
        "fortune-service"
        "ecommerce-poller"
        "ecommerce-api-service"
        "payment-service"
        "invite-service"
        "key-service"
    )
    
    # 统计
    total_services=${#services[@]}
    success_count=0
    failed_services=()
    
    log_info "准备构建 $total_services 个服务"
    
    # 构建所有服务
    for service in "${services[@]}"; do
        if build_service "$service"; then
            ((success_count++))
        else
            failed_services+=("$service")
        fi
        echo "----------------------------------------"
    done
    
    # 清理镜像
    if [ "$SKIP_CLEANUP" != "true" ]; then
        cleanup_images
    fi
    
    # 输出结果
    echo ""
    log_info "构建完成!"
    log_info "成功: $success_count/$total_services"
    
    if [ ${#failed_services[@]} -gt 0 ]; then
        log_error "失败的服务:"
        for service in "${failed_services[@]}"; do
            log_error "  - $service"
        done
        exit 1
    else
        log_info "🎉 所有服务构建成功!"
    fi
}

# 帮助信息
show_help() {
    echo "用法: $0 [VERSION] [OPTIONS]"
    echo ""
    echo "参数:"
    echo "  VERSION          镜像版本标签 (默认: latest)"
    echo ""
    echo "环境变量:"
    echo "  CLEANUP_ALL      设置为 'true' 清理所有未使用镜像"
    echo "  SKIP_CLEANUP     设置为 'true' 跳过镜像清理"
    echo ""
    echo "示例:"
    echo "  $0                    # 构建 latest 版本"
    echo "  $0 v1.0.0            # 构建 v1.0.0 版本"
    echo "  CLEANUP_ALL=true $0  # 构建并清理所有未使用镜像"
    echo ""
}

# 检查参数
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_help
    exit 0
fi

# 执行主函数
main "$@" 