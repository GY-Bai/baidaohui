#!/bin/bash

# Baidaohui VPS 部署脚本
# 支持两台VPS的服务分布部署

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# VPS配置
SAN_JOSE_IP="107.172.87.113"
BUFFALO_IP="216.144.233.104"
SAN_JOSE_MEMORY="2.4G"
BUFFALO_MEMORY="0.6G"

# Docker Registry
DOCKER_REGISTRY="yourregistry"
IMAGE_TAG="latest"

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

# 显示横幅
show_banner() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}    Baidaohui VPS 部署脚本${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    echo -e "${BLUE}VPS 配置信息:${NC}"
    echo -e "  1. 圣何塞 VPS: ${SAN_JOSE_IP} (${SAN_JOSE_MEMORY}, 2C)"
    echo -e "     服务: 认证、SSO、聊天、电商API、支付、邀请、密钥、Redis"
    echo ""
    echo -e "  2. 水牛城 VPS: ${BUFFALO_IP} (${BUFFALO_MEMORY}, 1C)"
    echo -e "     服务: 算命、邮件、电商轮询、汇率更新"
    echo ""
    echo -e "${BLUE}MongoDB: Azure 加州（美东）${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
}

# 检查环境
check_environment() {
    log_info "检查部署环境..."
    
    # 检查Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker 未安装，请先安装 Docker"
        exit 1
    fi
    
    # 检查Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose 未安装，请先安装 Docker Compose"
        exit 1
    fi
    
    # 检查环境变量文件
    if [ ! -f "infra/.env" ]; then
        log_error "环境变量文件 infra/.env 不存在"
        log_info "请复制 infra/.env.example 并配置相应的环境变量"
        exit 1
    fi
    
    log_success "环境检查通过"
}

# 构建Docker镜像
build_images() {
    log_info "构建 Docker 镜像..."
    
    # 服务列表
    services=(
        "auth-service"
        "sso-service" 
        "chat-service"
        "fortune-service"
        "ecommerce-poller"
        "ecommerce-api-service"
        "payment-service"
        "invite-service"
        "key-service"
        "email-service"
        "static-api-service"
        "r2-sync-service"
    )
    
    for service in "${services[@]}"; do
        log_info "构建 $service 镜像..."
        
        if [ -d "services/$service" ]; then
            cd "services/$service"
            
            if docker build -t "$DOCKER_REGISTRY/baidaohui-$service:$IMAGE_TAG" .; then
                log_success "$service 镜像构建成功"
            else
                log_error "$service 镜像构建失败"
                exit 1
            fi
            
            cd - > /dev/null
        else
            log_warning "服务目录 services/$service 不存在，跳过"
        fi
    done
    
    log_success "所有镜像构建完成"
}

# 推送镜像到仓库
push_images() {
    log_info "推送镜像到 Docker Registry..."
    
    services=(
        "auth-service"
        "sso-service"
        "chat-service" 
        "fortune-service"
        "ecommerce-poller"
        "ecommerce-api-service"
        "payment-service"
        "invite-service"
        "key-service"
        "email-service"
        "static-api-service"
        "r2-sync-service"
    )
    
    for service in "${services[@]}"; do
        log_info "推送 $service 镜像..."
        
        if docker push "$DOCKER_REGISTRY/baidaohui-$service:$IMAGE_TAG"; then
            log_success "$service 镜像推送成功"
        else
            log_error "$service 镜像推送失败"
            exit 1
        fi
    done
    
    log_success "所有镜像推送完成"
}

# 部署圣何塞VPS服务
deploy_san_jose() {
    log_info "部署圣何塞 VPS 服务..."
    
    # 检查内存使用规划
    log_info "内存使用规划 (总计: 2.4G):"
    echo "  - API Gateway:        128M"
    echo "  - Auth Service:       256M"
    echo "  - SSO Service:        256M"
    echo "  - Chat Service:       512M"
    echo "  - Ecommerce API:      384M"
    echo "  - Payment Service:    256M"
    echo "  - Invite Service:     192M"
    echo "  - Key Service:        192M"
    echo "  - Static API Service: 128M (缓存优化)"
    echo "  - Redis:              256M"
    echo "  - 系统预留:           ~372M"
    echo ""
    
    # 停止现有服务
    log_info "停止现有服务..."
    docker-compose -f infra/docker-compose.san-jose.yml down 2>/dev/null || true
    
    # 启动服务
    log_info "启动圣何塞 VPS 服务..."
    cd infra
    
    if docker-compose -f docker-compose.san-jose.yml up -d; then
        log_success "圣何塞 VPS 服务启动成功"
    else
        log_error "圣何塞 VPS 服务启动失败"
        exit 1
    fi
    
    cd - > /dev/null
    
    # 等待服务启动
    log_info "等待服务启动..."
    sleep 30
    
    # 健康检查
    check_san_jose_health
}

# 部署水牛城VPS服务
deploy_buffalo() {
    log_info "部署水牛城 VPS 服务..."
    
    # 检查内存使用规划
    log_info "内存使用规划 (总计: 0.6G):"
    echo "  - Fortune Service:    384M"
    echo "  - Email Service:      192M"
    echo "  - Ecommerce Poller:   128M"
    echo "  - Exchange Updater:   64M"
    echo "  - R2 Sync Service:    96M (数据同步)"
    echo "  - 系统预留:           ~4M"
    echo ""
    
    # 停止现有服务
    log_info "停止现有服务..."
    docker-compose -f infra/docker-compose.buffalo.yml down 2>/dev/null || true
    
    # 启动服务
    log_info "启动水牛城 VPS 服务..."
    cd infra
    
    if docker-compose -f docker-compose.buffalo.yml up -d; then
        log_success "水牛城 VPS 服务启动成功"
    else
        log_error "水牛城 VPS 服务启动失败"
        exit 1
    fi
    
    cd - > /dev/null
    
    # 等待服务启动
    log_info "等待服务启动..."
    sleep 30
    
    # 健康检查
    check_buffalo_health
}

# 圣何塞健康检查
check_san_jose_health() {
    log_info "执行圣何塞 VPS 健康检查..."
    
    health_urls=(
        "http://localhost:5001/health"  # auth-service
        "http://localhost:5002/health"  # sso-service
        "http://localhost:5004/health"  # chat-service
        "http://localhost:5005/health"  # ecommerce-api-service
        "http://localhost:5006/health"  # payment-service
        "http://localhost:5008/health"  # invite-service
        "http://localhost:5009/health"  # key-service
        "http://localhost:5010/health"  # static-api-service
    )
    
    for url in "${health_urls[@]}"; do
        service_name=$(echo $url | cut -d':' -f3 | cut -d'/' -f1)
        log_info "检查服务 $service_name..."
        
        for i in {1..5}; do
            if curl -f -s "$url" > /dev/null 2>&1; then
                log_success "✅ $service_name 健康检查通过"
                break
            else
                if [ $i -eq 5 ]; then
                    log_error "❌ $service_name 健康检查失败"
                else
                    log_warning "⏳ $service_name 健康检查失败，重试中... ($i/5)"
                    sleep 10
                fi
            fi
        done
    done
    
    # 检查Redis
    if docker exec redis redis-cli ping > /dev/null 2>&1; then
        log_success "✅ Redis 连接正常"
    else
        log_error "❌ Redis 连接失败"
    fi
}

# 水牛城健康检查
check_buffalo_health() {
    log_info "执行水牛城 VPS 健康检查..."
    
    health_urls=(
        "http://localhost:5003/health"  # fortune-service
        "http://localhost:5007/health"  # email-service
        "http://localhost:5011/health"  # r2-sync-service
    )
    
    for url in "${health_urls[@]}"; do
        service_name=$(echo $url | cut -d':' -f3 | cut -d'/' -f1)
        log_info "检查服务 $service_name..."
        
        for i in {1..5}; do
            if curl -f -s "$url" > /dev/null 2>&1; then
                log_success "✅ $service_name 健康检查通过"
                break
            else
                if [ $i -eq 5 ]; then
                    log_error "❌ $service_name 健康检查失败"
                else
                    log_warning "⏳ $service_name 健康检查失败，重试中... ($i/5)"
                    sleep 10
                fi
            fi
        done
    done
    
    # 检查容器状态
    log_info "检查容器状态..."
    docker-compose -f infra/docker-compose.buffalo.yml ps
}

# 显示服务状态
show_service_status() {
    echo ""
    log_info "服务访问信息:"
    echo ""
    echo -e "${CYAN}圣何塞 VPS (${SAN_JOSE_IP}):${NC}"
    echo "  • 认证服务:     http://${SAN_JOSE_IP}:5001"
    echo "  • SSO服务:      http://${SAN_JOSE_IP}:5002"
    echo "  • 聊天服务:     http://${SAN_JOSE_IP}:5004"
    echo "  • 电商API:      http://${SAN_JOSE_IP}:5005"
    echo "  • 支付服务:     http://${SAN_JOSE_IP}:5006"
    echo "  • 邀请服务:     http://${SAN_JOSE_IP}:5008"
    echo "  • 密钥服务:     http://${SAN_JOSE_IP}:5009"
    echo "  • 静态API:      http://${SAN_JOSE_IP}:5010 (缓存优化)"
    echo ""
    echo -e "${CYAN}水牛城 VPS (${BUFFALO_IP}):${NC}"
    echo "  • 算命服务:     http://${BUFFALO_IP}:5003"
    echo "  • 邮件服务:     http://${BUFFALO_IP}:5007"
    echo "  • R2同步服务:   http://${BUFFALO_IP}:5011 (数据同步)"
    echo ""
    echo -e "${YELLOW}注意: 请确保防火墙已开放相应端口${NC}"
}

# 主函数
main() {
    show_banner
    
    # 选择操作
    echo -e "${BLUE}请选择部署选项:${NC}"
    echo "1. 部署圣何塞 VPS (聊天、电商、认证等主要服务)"
    echo "2. 部署水牛城 VPS (算命、邮件等后台服务)"
    echo "3. 构建并推送所有镜像"
    echo "4. 部署所有VPS (先构建镜像)"
    echo "5. 查看服务状态"
    echo "6. 停止所有服务"
    echo ""
    
    read -p "请输入选项 (1-6): " choice
    
    case $choice in
        1)
            check_environment
            log_info "开始部署圣何塞 VPS..."
            deploy_san_jose
            show_service_status
            ;;
        2)
            check_environment
            log_info "开始部署水牛城 VPS..."
            deploy_buffalo
            show_service_status
            ;;
        3)
            check_environment
            build_images
            push_images
            log_success "镜像构建和推送完成"
            ;;
        4)
            check_environment
            build_images
            push_images
            log_info "开始部署所有 VPS..."
            deploy_san_jose
            deploy_buffalo
            show_service_status
            ;;
        5)
            log_info "圣何塞 VPS 服务状态:"
            docker-compose -f infra/docker-compose.san-jose.yml ps 2>/dev/null || echo "服务未运行"
            echo ""
            log_info "水牛城 VPS 服务状态:"
            docker-compose -f infra/docker-compose.buffalo.yml ps 2>/dev/null || echo "服务未运行"
            ;;
        6)
            log_info "停止所有服务..."
            docker-compose -f infra/docker-compose.san-jose.yml down 2>/dev/null || true
            docker-compose -f infra/docker-compose.buffalo.yml down 2>/dev/null || true
            log_success "所有服务已停止"
            ;;
        *)
            log_error "无效选项"
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@" 