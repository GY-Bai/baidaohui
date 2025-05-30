#!/bin/bash

# Baidaohui VPS 部署脚本
# 支持两台VPS的服务分布部署，完整的健康监测

set -e

# 加载通用函数库
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "$SCRIPT_DIR/common_functions.sh"

# 部署配置
DEPLOYMENT_MODE=""
BUILD_FIRST=${BUILD_FIRST:-false}

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
    echo -e "  🖥️  圣何塞 VPS: ${SAN_JOSE_IP} (${SAN_JOSE_MEMORY}, 2C)"
    echo -e "     📦 服务: $(get_san_jose_services | wc -w)个高性能服务 (包括AI代理)"
    echo ""
    echo -e "  🖥️  水牛城 VPS: ${BUFFALO_IP} (${BUFFALO_MEMORY}, 1C)"
    echo -e "     📦 服务: $(get_buffalo_services | wc -w)个后台服务"
    echo ""
    echo -e "  🗄️  MongoDB: Azure 加州（美东）"
    echo -e "${CYAN}========================================${NC}"
    echo ""
}

# 显示操作菜单
show_operation_menu() {
    echo -e "${BLUE}请选择部署操作:${NC}"
    echo ""
    echo -e "${CYAN}1. 构建并部署到圣何塞 VPS${NC}"
    echo "   • 构建镜像 → 推送仓库 → 部署高性能服务(含AI代理)"
    echo ""
    echo -e "${CYAN}2. 构建并部署到水牛城 VPS${NC}"
    echo "   • 构建镜像 → 推送仓库 → 部署后台服务"
    echo ""
    echo -e "${CYAN}3. 构建并部署到所有VPS${NC}"
    echo "   • 构建所有镜像 → 推送仓库 → 分布式部署"
    echo ""
    echo -e "${YELLOW}4. 仅部署到圣何塞 VPS (使用现有镜像)${NC}"
    echo ""
    echo -e "${YELLOW}5. 仅部署到水牛城 VPS (使用现有镜像)${NC}"
    echo ""
    echo -e "${YELLOW}6. 仅部署到所有VPS (使用现有镜像)${NC}"
    echo ""
    echo -e "${GREEN}7. 查看所有服务状态${NC}"
    echo ""
    echo -e "${GREEN}8. 执行完整健康检查${NC}"
    echo ""
    echo -e "${RED}9. 停止所有服务${NC}"
    echo ""
    echo -e "${BLUE}10. 修复nginx和AI代理服务${NC}"
    echo ""
}

# 获取操作选择
get_operation_selection() {
    while true; do
        show_operation_menu
        read -p "请输入选项 (1-10): " choice
        
        case $choice in
            1)
                DEPLOYMENT_MODE="san-jose"
                BUILD_FIRST=true
                break
                ;;
            2)
                DEPLOYMENT_MODE="buffalo"
                BUILD_FIRST=true
                break
                ;;
            3)
                DEPLOYMENT_MODE="both"
                BUILD_FIRST=true
                break
                ;;
            4)
                DEPLOYMENT_MODE="san-jose"
                BUILD_FIRST=false
                break
                ;;
            5)
                DEPLOYMENT_MODE="buffalo"
                BUILD_FIRST=false
                break
                ;;
            6)
                DEPLOYMENT_MODE="both"
                BUILD_FIRST=false
                break
                ;;
            7)
                show_all_service_status
                exit 0
                ;;
            8)
                execute_full_health_check
                exit 0
                ;;
            9)
                stop_all_services
                exit 0
                ;;
            10)
                fix_nginx_and_ai_proxy
                exit 0
                ;;
            *)
                log_error "无效选项，请重新选择"
                echo ""
                ;;
        esac
    done
}

# 检查环境变量文件
check_env_file() {
    log_info "检查环境变量配置..."
    
    # 检查多个可能的位置
    local env_files=(".env" "infra/.env" "./.env")
    local env_file=""
    
    for file in "${env_files[@]}"; do
        if [ -f "$file" ]; then
            env_file="$file"
            break
        fi
    done
    
    if [ -z "$env_file" ]; then
        log_error "环境变量文件不存在，请创建 .env 文件"
        log_info "可以复制 infra/env.example 作为模板"
        exit 1
    fi
    
    log_success "找到环境变量文件: $env_file"
    
    # 检查关键环境变量
    source "$env_file"
    
    if [ -z "$OPENROUTER_API_KEY" ]; then
        log_warning "⚠️  OPENROUTER_API_KEY 未设置，AI代理服务可能无法正常工作"
    else
        log_success "✅ OPENROUTER_API_KEY 已设置"
    fi
    
    if [ -z "$MONGODB_URI" ]; then
        log_warning "⚠️  MONGODB_URI 未设置"
    else
        log_success "✅ MONGODB_URI 已设置"
    fi
    
    echo ""
}

# 构建镜像（本地部署版本）
build_images() {
    local target_vps="$1"
    
    log_step "构建镜像..."
    
    # 选择要构建的服务
    local services_to_build=""
    if [ "$target_vps" = "san-jose" ]; then
        services_to_build=$(get_san_jose_services)
    elif [ "$target_vps" = "buffalo" ]; then
        services_to_build=$(get_buffalo_services)
    else
        services_to_build=$(get_all_services)
    fi
    
    local success_count=0
    local failed_services=()
    
    # 先构建nginx镜像（如果是圣何塞VPS）
    if [ "$target_vps" = "san-jose" ] || [ "$target_vps" = "both" ]; then
        log_info "构建 Nginx API 代理镜像..."
        if docker build -t baidaohui-nginx:latest infra/nginx/; then
            log_success "Nginx 镜像构建成功"
            ((success_count++))
        else
            log_error "Nginx 镜像构建失败"
            failed_services+=("nginx")
        fi
        
        # 构建AI代理服务镜像
        log_info "构建 AI代理服务镜像..."
        if [ -d "services/ai-proxy-service" ]; then
            cd services/ai-proxy-service
            if docker build -t baidaohui/ai-proxy-service:latest .; then
                log_success "AI代理服务镜像构建成功"
                ((success_count++))
            else
                log_error "AI代理服务镜像构建失败"
                failed_services+=("ai-proxy-service")
            fi
            cd ../../
        else
            log_warning "AI代理服务目录不存在，跳过构建"
        fi
    fi
    
    # 构建其他服务镜像
    for service in $services_to_build; do
        # 跳过ai-proxy-service，已经单独处理过
        if [ "$service" = "ai-proxy-service" ]; then
            continue
        fi
        
        if build_service_image "$service"; then
            ((success_count++))
        else
            failed_services+=("$service")
        fi
    done
    
    local total_services=$(echo $services_to_build | wc -w)
    # 如果包含nginx和ai-proxy，总数加2
    if [ "$target_vps" = "san-jose" ] || [ "$target_vps" = "both" ]; then
        ((total_services++)) # nginx
        if [ -d "services/ai-proxy-service" ]; then
            ((total_services++)) # ai-proxy
        fi
    fi
    
    log_info "镜像构建完成: $success_count/$total_services"
    
    if [ ${#failed_services[@]} -gt 0 ]; then
        log_error "构建失败的服务: ${failed_services[*]}"
        log_error "镜像构建失败，部署终止"
        return 1
    fi
    
    log_success "所有镜像构建成功，开始部署..."
    return 0
}

# 部署VPS服务
deploy_to_vps() {
    local target_vps="$1"
    
    log_step "部署到 $target_vps VPS..."
    
    # 显示内存规划
    show_memory_planning "$target_vps"
    
    # 停止现有服务
    stop_vps_services "$target_vps"
    
    # 启动新服务
    if start_vps_services "$target_vps"; then
        log_success "VPS 服务启动成功"
    else
        log_error "VPS 服务启动失败"
        return 1
    fi
    
    return 0
}

# 执行部署后健康检查
post_deployment_health_check() {
    local target_vps="$1"
    
    log_step "执行部署后健康检查..."
    
    local services_to_check=""
    local check_host="localhost"
    
    if [ "$target_vps" = "san-jose" ]; then
        services_to_check=$(get_san_jose_services)
        
        # 等待服务启动
        log_info "等待服务启动完成..."
        sleep 30
        
        # 特别检查AI代理服务
        log_info "检查AI代理服务..."
        local ai_attempts=10
        for i in $(seq 1 $ai_attempts); do
            if curl -s -f http://localhost:5012/health >/dev/null 2>&1; then
                log_success "✅ AI代理服务健康检查通过"
                break
            else
                if [ $i -eq $ai_attempts ]; then
                    log_error "❌ AI代理服务健康检查失败"
                    docker logs ai-proxy-service --tail 10
                else
                    log_info "⏳ AI代理服务启动中... ($i/$ai_attempts)"
                    sleep 5
                fi
            fi
        done
        
        # 检查nginx状态
        log_info "检查nginx状态..."
        if docker ps | grep -q "baidaohui-nginx"; then
            log_success "✅ Nginx容器运行正常"
        else
            log_error "❌ Nginx容器未运行"
            docker logs baidaohui-nginx --tail 10 2>/dev/null || true
        fi
        
    elif [ "$target_vps" = "buffalo" ]; then
        services_to_check=$(get_buffalo_services)
    else
        # 检查两个VPS的服务
        log_info "检查圣何塞 VPS 服务..."
        if batch_health_check "$(get_san_jose_services)" "localhost"; then
            log_success "圣何塞 VPS 健康检查通过"
        else
            log_error "圣何塞 VPS 健康检查失败"
        fi
        
        echo ""
        log_info "检查水牛城 VPS 服务..."
        if batch_health_check "$(get_buffalo_services)" "localhost"; then
            log_success "水牛城 VPS 健康检查通过"
        else
            log_error "水牛城 VPS 健康检查失败"
        fi
        
        # 检查Redis连接
        check_redis_connection
        return 0
    fi
    
    # 单个VPS检查
    if batch_health_check "$services_to_check" "$check_host"; then
        log_success "$target_vps VPS 健康检查通过"
    else
        log_error "$target_vps VPS 健康检查失败"
        return 1
    fi
    
    # 检查Redis连接（如果是圣何塞VPS）
    if [ "$target_vps" = "san-jose" ]; then
        check_redis_connection
    fi
    
    return 0
}

# 修复nginx和AI代理服务
fix_nginx_and_ai_proxy() {
    log_step "修复nginx和AI代理服务..."
    
    # 检查环境变量
    check_env_file
    
    # 强制重建关键服务
    log_info "重建nginx镜像..."
    docker build -t baidaohui-nginx:latest infra/nginx/ || {
        log_error "nginx镜像构建失败"
        exit 1
    }
    
    log_info "重建AI代理服务镜像..."
    if [ -d "services/ai-proxy-service" ]; then
        cd services/ai-proxy-service
        docker build -t baidaohui/ai-proxy-service:latest . || {
            log_error "AI代理服务镜像构建失败"
            exit 1
        }
        cd ../../
    fi
    
    # 停止所有服务
    stop_vps_services "san-jose"
    
    # 重新启动圣何塞VPS服务
    log_info "启动圣何塞VPS服务..."
    docker-compose -f infra/docker-compose.san-jose.yml up -d
    
    # 等待并检查服务
    log_info "等待服务启动..."
    sleep 45
    
    # 详细检查
    log_info "检查容器状态..."
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    
    echo ""
    log_info "检查AI代理服务..."
    if curl -s -f http://localhost:5012/health; then
        log_success "✅ AI代理服务运行正常"
    else
        log_error "❌ AI代理服务异常"
        docker logs ai-proxy-service --tail 20
    fi
    
    echo ""
    log_info "检查nginx代理状态..."
    if docker exec baidaohui-nginx nginx -t 2>/dev/null; then
        log_success "✅ Nginx配置正确"
    else
        log_error "❌ Nginx配置有误"
        docker logs baidaohui-nginx --tail 20
    fi
    
    echo ""
    log_success "修复完成！请访问健康检查页面验证结果"
}

# 显示所有服务状态
show_all_service_status() {
    log_step "查看所有服务状态..."
    
    echo ""
    log_info "Docker Compose 服务状态:"
    echo ""
    
    echo -e "${CYAN}圣何塞 VPS 服务:${NC}"
    if docker-compose -f infra/docker-compose.san-jose.yml ps 2>/dev/null; then
        echo ""
    else
        echo "  未运行或配置文件不存在"
        echo ""
    fi
    
    echo -e "${CYAN}水牛城 VPS 服务:${NC}"
    if docker-compose -f infra/docker-compose.buffalo.yml ps 2>/dev/null; then
        echo ""
    else
        echo "  未运行或配置文件不存在"
        echo ""
    fi
    
    # 显示端口访问信息
    show_service_status "both"
    
    # 特别显示AI代理服务状态
    echo ""
    log_info "AI代理服务详细状态:"
    if docker ps | grep -q "ai-proxy-service"; then
        echo "  容器状态: 运行中"
        if curl -s -f http://localhost:5012/health >/dev/null 2>&1; then
            echo -e "  健康检查: ${GREEN}✅ 正常${NC}"
        else
            echo -e "  健康检查: ${RED}❌ 异常${NC}"
        fi
        
        if curl -s -f -H "Authorization: Bearer wzj5788@gmail.com" http://localhost:5012/v1/models >/dev/null 2>&1; then
            echo -e "  API认证: ${GREEN}✅ 正常${NC}"
        else
            echo -e "  API认证: ${RED}❌ 异常${NC}"
        fi
    else
        echo -e "  容器状态: ${RED}未运行${NC}"
    fi
}

# 执行完整健康检查
execute_full_health_check() {
    log_step "执行完整的服务健康检查..."
    
    echo ""
    log_info "=== 微服务健康检查 ==="
    echo ""
    
    # 检查所有服务
    local all_services=$(get_all_services)
    local healthy_count=0
    local unhealthy_services=()
    
    for service in $all_services; do
        echo -n "检查 $service ($(get_service_description $service))... "
        
        if check_service_health "$service" "localhost" 2 3; then
            ((healthy_count++))
        else
            unhealthy_services+=("$service")
        fi
    done
    
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}    健康检查总结${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    echo -e "${BLUE}总服务数:${NC} $(echo $all_services | wc -w)"
    echo -e "${GREEN}健康服务:${NC} $healthy_count"
    echo -e "${RED}异常服务:${NC} ${#unhealthy_services[@]}"
    
    if [ ${#unhealthy_services[@]} -gt 0 ]; then
        echo ""
        log_error "异常服务列表:"
        for service in "${unhealthy_services[@]}"; do
            log_error "  - $service ($(get_service_description $service))"
        done
        echo ""
        log_info "建议操作:"
        echo "  1. 检查服务日志: docker logs <service-name>"
        echo "  2. 重启异常服务: docker-compose restart <service-name>"
        echo "  3. 检查环境变量配置"
        echo "  4. 运行修复脚本: 选择选项10"
    else
        echo ""
        log_success "🎉 所有服务运行正常！"
    fi
    
    # 额外检查
    echo ""
    log_info "额外组件检查:"
    check_redis_connection
    
    # 检查磁盘空间
    echo ""
    log_info "系统资源检查:"
    local disk_usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$disk_usage" -gt 85 ]; then
        log_warning "⚠️  磁盘使用率: ${disk_usage}% (建议清理)"
    else
        log_success "✅ 磁盘使用率: ${disk_usage}%"
    fi
    
    # 检查内存使用
    local memory_usage=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')
    if [ "$memory_usage" -gt 90 ]; then
        log_warning "⚠️  内存使用率: ${memory_usage}%"
    else
        log_success "✅ 内存使用率: ${memory_usage}%"
    fi
}

# 停止所有服务
stop_all_services() {
    log_step "停止所有VPS服务..."
    
    echo ""
    read -p "确认停止所有服务? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_info "操作已取消"
        exit 0
    fi
    
    stop_vps_services "both"
    
    log_success "所有服务已停止"
}

# 主函数
main() {
    show_banner
    
    log_info "VPS 分布式部署管理系统"
    echo ""
    echo -e "${BLUE}VPS 配置信息:${NC}"
    echo -e "  🖥️  圣何塞 VPS: ${SAN_JOSE_IP} (${SAN_JOSE_MEMORY}, 2C)"
    echo -e "     📦 服务: $(get_san_jose_services | wc -w)个高性能服务 (含AI代理)"
    echo ""
    echo -e "  🖥️  水牛城 VPS: ${BUFFALO_IP} (${BUFFALO_MEMORY}, 1C)"
    echo -e "     📦 服务: $(get_buffalo_services | wc -w)个后台服务"
    echo ""
    echo -e "  🗄️  MongoDB: Azure 加州（美东）"
    echo ""
    
    # 检查环境
    check_docker
    check_env_file
    
    # 获取操作选择
    get_operation_selection
    
    # 执行部署操作
    if [ "$DEPLOYMENT_MODE" != "" ]; then
        echo ""
        log_info "部署配置："
        log_info "• 目标VPS: $DEPLOYMENT_MODE"
        log_info "• 构建镜像: $([ "$BUILD_FIRST" = "true" ] && echo "是" || echo "否")"
        echo ""
        
        # 确认部署
        read -p "确认开始部署? (y/N): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            log_info "部署已取消"
            exit 0
        fi
        
        # 构建镜像（如果需要）
        if [ "$BUILD_FIRST" = "true" ]; then
            if ! build_images "$DEPLOYMENT_MODE"; then
                log_error "镜像构建失败，部署终止"
                exit 1
            fi
        fi
        
        # 部署服务
        if deploy_to_vps "$DEPLOYMENT_MODE"; then
            # 健康检查
            if post_deployment_health_check "$DEPLOYMENT_MODE"; then
                # 显示服务状态
                show_service_status "$DEPLOYMENT_MODE"
                
                # 显示部署总结
                show_deployment_summary "$DEPLOYMENT_MODE" "成功" "0"
                
                log_success "🎉 部署完成！所有服务运行正常"
                
                # 特别提示AI代理服务
                if [ "$DEPLOYMENT_MODE" = "san-jose" ] || [ "$DEPLOYMENT_MODE" = "both" ]; then
                    echo ""
                    log_info "🤖 AI代理服务信息:"
                    echo "  • API Key: wzj5788@gmail.com"
                    echo "  • 本地端点: http://localhost:5012"
                    echo "  • 网关端点: https://api.baidaohui.com/v1/"
                    echo "  • 测试命令: ./scripts/test-ai-proxy.sh"
                fi
            else
                log_warning "⚠️  部署完成，但部分服务健康检查失败"
                log_info "💡 可以运行选项10进行修复"
            fi
        else
            log_error "❌ 部署失败"
            exit 1
        fi
    fi
}

# 执行主函数
main "$@" 