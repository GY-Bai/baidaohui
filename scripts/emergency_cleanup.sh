#!/bin/bash

# 紧急容器清理脚本
# 用于VPS上手动清理所有Docker容器

echo "=========================================="
echo "    紧急Docker容器清理脚本"
echo "=========================================="
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# 显示当前容器状态
echo "当前Docker容器状态:"
docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "无法获取容器信息"
echo ""

# 确认清理
read -p "是否要强制清理所有Docker容器? (y/N): " confirm
if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "操作已取消"
    exit 0
fi

echo ""
log_info "开始强制清理所有Docker容器..."

# 第一步：停止所有compose服务
log_info "停止Docker Compose服务..."
if [ -f "docker-compose.san-jose.yml" ]; then
    docker-compose -f docker-compose.san-jose.yml down --remove-orphans --volumes --timeout 10 2>/dev/null || true
fi
if [ -f "docker-compose.buffalo.yml" ]; then
    docker-compose -f docker-compose.buffalo.yml down --remove-orphans --volumes --timeout 10 2>/dev/null || true
fi
if [ -f "docker-compose.yml" ]; then
    docker-compose down --remove-orphans --volumes --timeout 10 2>/dev/null || true
fi

# 第二步：停止所有运行容器
log_info "停止所有运行容器..."
RUNNING_CONTAINERS=$(docker ps -q)
if [ -n "$RUNNING_CONTAINERS" ]; then
    docker stop $RUNNING_CONTAINERS 2>/dev/null || true
    log_success "已停止 $(echo $RUNNING_CONTAINERS | wc -w) 个运行容器"
else
    log_info "没有运行中的容器"
fi

# 第三步：删除所有容器
log_info "删除所有容器..."
ALL_CONTAINERS=$(docker ps -aq)
if [ -n "$ALL_CONTAINERS" ]; then
    docker rm -f $ALL_CONTAINERS 2>/dev/null || true
    log_success "已删除 $(echo $ALL_CONTAINERS | wc -w) 个容器"
else
    log_info "没有容器需要删除"
fi

# 第四步：按名称删除特定服务容器
SERVICE_NAMES="auth-service sso-service chat-service ecommerce-service payment-service invite-service key-service static-api-service fortune-service email-service ecommerce-poller r2-sync-service exchange-rate-updater baidaohui-redis baidaohui-nginx redis nginx"

log_info "清理特定服务容器..."
for service in $SERVICE_NAMES; do
    docker stop "$service" 2>/dev/null || true
    docker rm -f "$service" 2>/dev/null || true
    docker stop "/$service" 2>/dev/null || true
    docker rm -f "/$service" 2>/dev/null || true
done

# 第五步：清理网络
log_info "清理Docker网络..."
docker network prune -f 2>/dev/null || true

# 第六步：清理卷
log_info "清理未使用的卷..."
docker volume prune -f 2>/dev/null || true

# 第七步：清理镜像（可选）
read -p "是否同时清理未使用的镜像? (y/N): " cleanup_images
if [ "$cleanup_images" = "y" ] || [ "$cleanup_images" = "Y" ]; then
    log_info "清理未使用的镜像..."
    docker image prune -f 2>/dev/null || true
fi

echo ""
log_success "✅ 清理完成！"

# 显示清理后状态
echo ""
echo "清理后Docker状态:"
echo "容器: $(docker ps -a --format "{{.Names}}" 2>/dev/null | wc -l) 个"
echo "镜像: $(docker images --format "{{.Repository}}" 2>/dev/null | wc -l) 个"
echo "网络: $(docker network ls --format "{{.Name}}" 2>/dev/null | grep -v "bridge\|host\|none" | wc -l) 个"
echo "卷: $(docker volume ls --format "{{.Name}}" 2>/dev/null | wc -l) 个"

if [ $(docker ps -aq | wc -l) -eq 0 ]; then
    log_success "🎉 所有容器已清理完毕！"
else
    log_warning "⚠️  仍有 $(docker ps -aq | wc -l) 个容器残留"
    echo "剩余容器:"
    docker ps -a --format "table {{.Names}}\t{{.Status}}"
fi 