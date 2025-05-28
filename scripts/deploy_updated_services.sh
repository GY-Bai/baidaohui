#!/bin/bash

# 部署更新的后端服务
# 包含payment-service、fortune-service、auth-service、ecommerce-poller和汇率更新服务

set -e

echo "开始部署更新的后端服务（支付架构调整版本）..."

# 颜色定义
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

# 检查Docker是否运行
if ! docker info > /dev/null 2>&1; then
    log_error "Docker未运行，请启动Docker后重试"
    exit 1
fi

# 设置环境变量
export DOCKER_REGISTRY=${DOCKER_REGISTRY:-"your-registry.com"}
export IMAGE_TAG=${IMAGE_TAG:-"v2.0"}

# 需要更新的服务列表
SERVICES=(
    "payment-service"
    "fortune-service" 
    "auth-service"
    "ecommerce-poller"
    "ecommerce-api-service"
)

log_info "支付架构调整说明："
echo "  - 算命服务：使用动态Checkout Session（单一Stripe账号）"
echo "  - 电商服务：使用静态Payment Link（多Stripe账号）"
echo "  - Payment Service：移除静态Payment Link管理功能"
echo "  - Ecommerce Poller：新增Payment Link同步功能"

# 构建和推送服务镜像
for service in "${SERVICES[@]}"; do
    log_info "构建 $service 镜像..."
    
    cd "services/$service"
    
    # 构建镜像
    docker build -t "$DOCKER_REGISTRY/baidaohui-$service:$IMAGE_TAG" .
    
    if [ $? -eq 0 ]; then
        log_info "$service 镜像构建成功"
        
        # 推送镜像
        log_info "推送 $service 镜像到仓库..."
        docker push "$DOCKER_REGISTRY/baidaohui-$service:$IMAGE_TAG"
        
        if [ $? -eq 0 ]; then
            log_info "$service 镜像推送成功"
        else
            log_error "$service 镜像推送失败"
            exit 1
        fi
    else
        log_error "$service 镜像构建失败"
        exit 1
    fi
    
    cd - > /dev/null
done

# 构建汇率更新服务
log_info "构建汇率更新服务镜像..."
cd "services/fortune-service"

docker build -f Dockerfile.exchange-updater -t "$DOCKER_REGISTRY/baidaohui-exchange-updater:$IMAGE_TAG" .

if [ $? -eq 0 ]; then
    log_info "汇率更新服务镜像构建成功"
    
    # 推送镜像
    log_info "推送汇率更新服务镜像到仓库..."
    docker push "$DOCKER_REGISTRY/baidaohui-exchange-updater:$IMAGE_TAG"
    
    if [ $? -eq 0 ]; then
        log_info "汇率更新服务镜像推送成功"
    else
        log_error "汇率更新服务镜像推送失败"
        exit 1
    fi
else
    log_error "汇率更新服务镜像构建失败"
    exit 1
fi

cd - > /dev/null

# 更新Docker Compose配置
log_info "更新Docker Compose配置..."

# 创建更新的docker-compose.yml
cat > infra/docker-compose.updated-v2.yml << EOF
version: '3.8'

services:
  # 更新的支付服务（仅处理算命动态支付）
  payment-service:
    image: $DOCKER_REGISTRY/baidaohui-payment-service:$IMAGE_TAG
    container_name: payment-service
    restart: unless-stopped
    environment:
      - MONGODB_URI=\${MONGODB_URI}
      - JWT_SECRET=\${JWT_SECRET}
      - STRIPE_SECRET_KEY=\${STRIPE_SECRET_KEY}
      - STRIPE_WEBHOOK_SECRET=\${STRIPE_WEBHOOK_SECRET}
      - FRONTEND_URL=\${FRONTEND_URL}
      - FORTUNE_SERVICE_URL=\${FORTUNE_SERVICE_URL}
      - INTERNAL_API_KEY=\${INTERNAL_API_KEY}
    ports:
      - "5006:5006"
    networks:
      - baidaohui-network
    depends_on:
      - mongodb
    deploy:
      placement:
        constraints:
          - node.labels.location == san-jose

  # 更新的算命服务
  fortune-service:
    image: $DOCKER_REGISTRY/baidaohui-fortune-service:$IMAGE_TAG
    container_name: fortune-service
    restart: unless-stopped
    environment:
      - MONGODB_URI=\${MONGODB_URI}
      - REDIS_URL=\${REDIS_URL}
      - JWT_SECRET=\${JWT_SECRET}
      - SUPABASE_JWT_SECRET=\${SUPABASE_JWT_SECRET}
      - R2_ENDPOINT=\${R2_ENDPOINT}
      - R2_ACCESS_KEY=\${R2_ACCESS_KEY}
      - R2_SECRET_KEY=\${R2_SECRET_KEY}
      - R2_BUCKET=\${R2_BUCKET}
      - EXCHANGE_API_KEY=\${EXCHANGE_API_KEY}
      - INTERNAL_API_KEY=\${INTERNAL_API_KEY}
    ports:
      - "5003:5003"
    networks:
      - baidaohui-network
    depends_on:
      - mongodb
      - redis
    deploy:
      placement:
        constraints:
          - node.labels.location == buffalo

  # 更新的认证服务
  auth-service:
    image: $DOCKER_REGISTRY/baidaohui-auth-service:$IMAGE_TAG
    container_name: auth-service
    restart: unless-stopped
    environment:
      - SUPABASE_URL=\${SUPABASE_URL}
      - SUPABASE_SERVICE_KEY=\${SUPABASE_SERVICE_KEY}
      - SUPABASE_JWT_SECRET=\${SUPABASE_JWT_SECRET}
      - JWT_SECRET=\${JWT_SECRET}
      - FRONTEND_URL=\${FRONTEND_URL}
      - DOMAIN=\${DOMAIN}
    ports:
      - "5001:5001"
    networks:
      - baidaohui-network
    deploy:
      placement:
        constraints:
          - node.labels.location == san-jose

  # 更新的电商轮询服务（新增Payment Link同步）
  ecommerce-poller:
    image: $DOCKER_REGISTRY/baidaohui-ecommerce-poller:$IMAGE_TAG
    container_name: ecommerce-poller
    restart: unless-stopped
    environment:
      - MONGODB_URI=\${MONGODB_URI}
      - R2_ENDPOINT=\${R2_ENDPOINT}
      - R2_ACCESS_KEY=\${R2_ACCESS_KEY}
      - R2_SECRET_KEY=\${R2_SECRET_KEY}
      - R2_BUCKET=\${R2_BUCKET}
      - STRIPE_ACCOUNTS=\${STRIPE_ACCOUNTS}
    networks:
      - baidaohui-network
    depends_on:
      - mongodb
    deploy:
      placement:
        constraints:
          - node.labels.location == buffalo

  # 更新的电商API服务
  ecommerce-api-service:
    image: $DOCKER_REGISTRY/baidaohui-ecommerce-api-service:$IMAGE_TAG
    container_name: ecommerce-api-service
    restart: unless-stopped
    environment:
      - MONGODB_URI=\${MONGODB_URI}
      - R2_ENDPOINT=\${R2_ENDPOINT}
      - R2_BUCKET=\${R2_BUCKET}
      - JWT_SECRET=\${JWT_SECRET}
    ports:
      - "5004:5004"
    networks:
      - baidaohui-network
    depends_on:
      - mongodb
    deploy:
      placement:
        constraints:
          - node.labels.location == buffalo

  # 汇率更新服务
  exchange-rate-updater:
    image: $DOCKER_REGISTRY/baidaohui-exchange-updater:$IMAGE_TAG
    container_name: exchange-rate-updater
    restart: unless-stopped
    environment:
      - REDIS_URL=\${REDIS_URL}
      - EXCHANGE_API_KEY=\${EXCHANGE_API_KEY}
      - FORTUNE_SERVICE_URL=\${FORTUNE_SERVICE_URL}
      - INTERNAL_API_KEY=\${INTERNAL_API_KEY}
    volumes:
      - ./logs:/var/log
    networks:
      - baidaohui-network
    depends_on:
      - redis
    deploy:
      placement:
        constraints:
          - node.labels.location == buffalo
      resources:
        limits:
          memory: 128M
        reservations:
          memory: 64M

networks:
  baidaohui-network:
    external: true

volumes:
  mongodb_data:
  redis_data:
EOF

# 部署服务
log_info "部署更新的服务..."

# 停止旧服务
log_info "停止旧服务..."
docker-compose -f infra/docker-compose.yml down payment-service fortune-service auth-service ecommerce-poller ecommerce-api-service

# 启动新服务
log_info "启动更新的服务..."
docker-compose -f infra/docker-compose.updated-v2.yml up -d

# 等待服务启动
log_info "等待服务启动..."
sleep 30

# 健康检查
log_info "执行健康检查..."

HEALTH_CHECK_URLS=(
    "http://localhost:5001/health"
    "http://localhost:5003/health"
    "http://localhost:5004/health"
    "http://localhost:5006/health"
)

for url in "${HEALTH_CHECK_URLS[@]}"; do
    log_info "检查 $url ..."
    
    for i in {1..5}; do
        if curl -f -s "$url" > /dev/null; then
            log_info "$url 健康检查通过"
            break
        else
            if [ $i -eq 5 ]; then
                log_error "$url 健康检查失败"
                exit 1
            fi
            log_warn "$url 健康检查失败，重试中... ($i/5)"
            sleep 10
        fi
    done
done

# 验证支付架构
log_info "验证支付架构配置..."

# 检查算命服务支付接口
if curl -f -s "http://localhost:5006/health" > /dev/null; then
    log_info "✅ Payment Service (算命动态支付) 运行正常"
else
    log_error "❌ Payment Service 健康检查失败"
fi

# 检查电商API服务
if curl -f -s "http://localhost:5004/health" > /dev/null; then
    log_info "✅ Ecommerce API Service (静态Payment Link) 运行正常"
else
    log_error "❌ Ecommerce API Service 健康检查失败"
fi

# 清理旧镜像
log_info "清理旧镜像..."
docker image prune -f

log_info "所有服务部署完成！"

# 显示服务状态
log_info "当前服务状态："
docker-compose -f infra/docker-compose.updated-v2.yml ps

log_info "支付架构调整完成！新架构特点："
echo "✅ 算命服务：动态Checkout Session（单一Stripe账号）"
echo "✅ 电商服务：静态Payment Link（多Stripe账号）"
echo "✅ Payment Service：专注算命支付处理"
echo "✅ Ecommerce Poller：自动同步Payment Link"
echo "✅ Auth Service：跨子域SSO认证"
echo "✅ Exchange Rate Updater：自动汇率更新服务"

log_info "部署版本：$IMAGE_TAG"
log_info "部署时间：$(date)" 