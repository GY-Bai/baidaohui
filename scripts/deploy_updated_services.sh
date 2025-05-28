#!/bin/bash

# 快速服务更新部署脚本
# 用于快速更新和部署特定的服务，无需重新部署整个系统

set -e

# 加载通用函数库
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "$SCRIPT_DIR/common_functions.sh"

# 更新配置
UPDATE_SERVICES=""
UPDATE_MODE=""
RESTART_ONLY=${RESTART_ONLY:-false}

# 显示更新选择菜单
show_update_menu() {
    echo -e "${BLUE}请选择更新方式:${NC}"
    echo ""
    echo -e "${CYAN}1. 快速重启特定服务 (不重新构建)${NC}"
    echo "   • 适用于配置文件更改或临时故障"
    echo ""
    echo -e "${CYAN}2. 更新算命相关服务${NC}"
    echo "   • fortune-service, exchange-rate-updater"
    echo ""
    echo -e "${CYAN}3. 更新支付相关服务${NC}"
    echo "   • payment-service, ecommerce-api-service"
    echo ""
    echo -e "${CYAN}4. 更新认证相关服务${NC}"
    echo "   • auth-service, sso-service"
    echo ""
    echo -e "${CYAN}5. 更新电商相关服务${NC}"
    echo "   • ecommerce-api-service, ecommerce-poller, r2-sync-service"
    echo ""
    echo -e "${CYAN}6. 自定义选择服务${NC}"
    echo "   • 手动选择要更新的服务"
    echo ""
    echo -e "${YELLOW}7. 滚动更新所有服务${NC}"
    echo "   • 逐个更新所有13个服务"
    echo ""
}

# 获取更新选择
get_update_selection() {
    while true; do
        show_update_menu
        read -p "请输入选项 (1-7): " choice
        
        case $choice in
            1)
                custom_restart_selection
                UPDATE_MODE="restart"
                RESTART_ONLY=true
                break
                ;;
            2)
                UPDATE_SERVICES="fortune-service exchange-rate-updater"
                UPDATE_MODE="fortune"
                break
                ;;
            3)
                UPDATE_SERVICES="payment-service ecommerce-api-service"
                UPDATE_MODE="payment"
                break
                ;;
            4)
                UPDATE_SERVICES="auth-service sso-service"
                UPDATE_MODE="auth"
                break
                ;;
            5)
                UPDATE_SERVICES="ecommerce-api-service ecommerce-poller r2-sync-service"
                UPDATE_MODE="ecommerce"
                break
                ;;
            6)
                custom_update_selection
                UPDATE_MODE="custom"
                break
                ;;
            7)
                UPDATE_SERVICES=$(get_all_services)
                UPDATE_MODE="rolling"
                break
                ;;
            *)
                log_error "无效选项，请重新选择"
                echo ""
                ;;
        esac
    done
}

# 自定义重启选择
custom_restart_selection() {
    local all_services=($(get_all_services))
    local selected=()
    
    echo ""
    log_info "选择要重启的服务 (输入服务编号，用空格分隔):"
    echo ""
    
    for i in "${!all_services[@]}"; do
        local service="${all_services[$i]}"
        local desc=$(get_service_description "$service")
        local port=$(get_service_port "$service")
        if [ -n "$port" ]; then
            echo "  $((i+1)). $service ($desc) - 端口:$port"
        else
            echo "  $((i+1)). $service ($desc) - 内部服务"
        fi
    done
    
    echo ""
    read -p "请输入要重启的服务编号 (例如: 1 3 5): " service_numbers
    
    for num in $service_numbers; do
        if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le "${#all_services[@]}" ]; then
            selected+=("${all_services[$((num-1))]}")
        else
            log_warning "无效的服务编号: $num"
        fi
    done
    
    if [ ${#selected[@]} -eq 0 ]; then
        log_error "没有选择任何服务"
        exit 1
    fi
    
    UPDATE_SERVICES="${selected[*]}"
    log_info "已选择重启 ${#selected[@]} 个服务: ${UPDATE_SERVICES}"
}

# 自定义更新选择
custom_update_selection() {
    local all_services=($(get_all_services))
    local selected=()
    
    echo ""
    log_info "选择要更新的服务 (将重新构建镜像):"
    echo ""
    
    for i in "${!all_services[@]}"; do
        local service="${all_services[$i]}"
        local desc=$(get_service_description "$service")
        echo "  $((i+1)). $service ($desc)"
    done
    
    echo ""
    read -p "请输入要更新的服务编号 (例如: 1 3 5): " service_numbers
    
    for num in $service_numbers; do
        if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le "${#all_services[@]}" ]; then
            selected+=("${all_services[$((num-1))]}")
        else
            log_warning "无效的服务编号: $num"
        fi
    done
    
    if [ ${#selected[@]} -eq 0 ]; then
        log_error "没有选择任何服务"
        exit 1
    fi
    
    UPDATE_SERVICES="${selected[*]}"
    log_info "已选择更新 ${#selected[@]} 个服务: ${UPDATE_SERVICES}"
}

# 确定服务所在的VPS
get_service_vps() {
    local service="$1"
    local san_jose_services=$(get_san_jose_services)
    local buffalo_services=$(get_buffalo_services)
    
    if [[ " $san_jose_services " =~ " $service " ]]; then
        echo "san-jose"
    elif [[ " $buffalo_services " =~ " $service " ]]; then
        echo "buffalo"
    else
        echo "unknown"
    fi
}

# 重启单个服务
restart_single_service() {
    local service="$1"
    local vps=$(get_service_vps "$service")
    
    log_step "重启服务: $service ($(get_service_description $service))"
    
    if [ "$vps" = "unknown" ]; then
        log_error "未知服务: $service"
        return 1
    fi
    
    local compose_file=""
    if [ "$vps" = "san-jose" ]; then
        compose_file="infra/docker-compose.san-jose.yml"
    else
        compose_file="infra/docker-compose.buffalo.yml"
    fi
    
    # 重启服务
    if docker-compose -f "$compose_file" restart "$service" > /dev/null 2>&1; then
        log_success "✅ $service 重启成功"
        
        # 等待服务启动
        sleep 5
        
        # 健康检查
        if check_service_health "$service" "localhost" 3 5; then
            log_success "✅ $service 健康检查通过"
            return 0
        else
            log_warning "⚠️  $service 重启成功，但健康检查失败"
            return 1
        fi
    else
        log_error "❌ $service 重启失败"
        return 1
    fi
}

# 更新单个服务
update_single_service() {
    local service="$1"
    local vps=$(get_service_vps "$service")
    
    log_step "更新服务: $service ($(get_service_description $service))"
    
    if [ "$vps" = "unknown" ]; then
        log_error "未知服务: $service"
        return 1
    fi
    
    # 构建新镜像
    if ! build_service_image "$service"; then
        log_error "❌ $service 镜像构建失败"
        return 1
    fi
    
    # 推送镜像
    if ! push_service_image "$service"; then
        log_error "❌ $service 镜像推送失败"
        return 1
    fi
    
    # 停止旧容器并启动新容器
    local compose_file=""
    if [ "$vps" = "san-jose" ]; then
        compose_file="infra/docker-compose.san-jose.yml"
    else
        compose_file="infra/docker-compose.buffalo.yml"
    fi
    
    log_info "重新部署 $service..."
    if docker-compose -f "$compose_file" up -d "$service" > /dev/null 2>&1; then
        log_success "✅ $service 部署成功"
        
        # 等待服务启动
        sleep 10
        
        # 健康检查
        if check_service_health "$service" "localhost" 5 8; then
            log_success "✅ $service 更新完成"
            return 0
        else
            log_warning "⚠️  $service 部署成功，但健康检查失败"
            return 1
        fi
    else
        log_error "❌ $service 部署失败"
        return 1
    fi
}

# 批量处理服务
batch_process_services() {
    local services=($UPDATE_SERVICES)
    local total_services=${#services[@]}
    local success_count=0
    local failed_services=()
    
    if [ "$RESTART_ONLY" = "true" ]; then
        log_step "批量重启 $total_services 个服务..."
    else
        log_step "批量更新 $total_services 个服务..."
    fi
    
    for service in "${services[@]}"; do
        if [ "$RESTART_ONLY" = "true" ]; then
            if restart_single_service "$service"; then
                ((success_count++))
            else
                failed_services+=("$service")
            fi
        else
            if update_single_service "$service"; then
                ((success_count++))
            else
                failed_services+=("$service")
            fi
        fi
        echo "----------------------------------------"
    done
    
    # 显示结果
    echo ""
    if [ "$RESTART_ONLY" = "true" ]; then
        log_info "重启完成: $success_count/$total_services"
    else
        log_info "更新完成: $success_count/$total_services"
    fi
    
    if [ ${#failed_services[@]} -gt 0 ]; then
        log_error "处理失败的服务: ${failed_services[*]}"
    fi
    
    return $success_count
}

# 滚动更新所有服务
rolling_update_all_services() {
    local all_services=($(get_all_services))
    local total_services=${#all_services[@]}
    local success_count=0
    local failed_services=()
    
    log_step "开始滚动更新所有 $total_services 个服务..."
    log_warning "这将需要较长时间，请确保有足够的时间"
    
    echo ""
    read -p "确认开始滚动更新? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_info "滚动更新已取消"
        exit 0
    fi
    
    # 分组更新：先更新不影响用户的后台服务
    local backend_services="ecommerce-poller r2-sync-service exchange-rate-updater email-service"
    local frontend_services="auth-service sso-service payment-service ecommerce-api-service invite-service key-service static-api-service fortune-service chat-service"
    
    echo ""
    log_info "第一阶段：更新后台服务..."
    for service in $backend_services; do
        if update_single_service "$service"; then
            ((success_count++))
        else
            failed_services+=("$service")
        fi
        sleep 5  # 给系统一些时间稳定
    done
    
    echo ""
    log_info "第二阶段：更新前台服务..."
    for service in $frontend_services; do
        if update_single_service "$service"; then
            ((success_count++))
        else
            failed_services+=("$service")
        fi
        sleep 10  # 前台服务更新后给更多时间稳定
    done
    
    echo ""
    log_info "滚动更新完成: $success_count/$total_services"
    
    if [ ${#failed_services[@]} -gt 0 ]; then
        log_error "更新失败的服务: ${failed_services[*]}"
    fi
    
    return $success_count
}

# 显示更新后状态
show_update_summary() {
    local operation="$1"
    local success_count="$2"
    local total_count="$3"
    local failed_count=$((total_count - success_count))
    
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}    $operation 完成总结${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    echo -e "${BLUE}操作模式:${NC} $UPDATE_MODE"
    echo -e "${BLUE}总服务数:${NC} $total_count"
    echo -e "${GREEN}成功:${NC} $success_count"
    echo -e "${RED}失败:${NC} $failed_count"
    echo -e "${BLUE}操作时间:${NC} $(date)"
    echo ""
    
    if [ $failed_count -eq 0 ]; then
        log_success "🎉 所有服务$operation成功！"
    else
        log_warning "⚠️  部分服务$operation失败，请检查日志"
    fi
}

# 主函数
main() {
    show_banner
    
    log_info "快速服务更新工具"
    log_info "用于快速更新或重启特定服务"
    echo ""
    
    # 检查环境
    check_docker
    check_env_file
    
    # 获取更新选择
    get_update_selection
    
    # 显示操作配置
    echo ""
    log_info "操作配置："
    log_info "• 操作模式: $UPDATE_MODE"
    log_info "• 目标服务: $(echo $UPDATE_SERVICES | wc -w)个"
    if [ "$RESTART_ONLY" = "true" ]; then
        log_info "• 操作类型: 重启服务 (不重新构建)"
    else
        log_info "• 操作类型: 更新服务 (重新构建镜像)"
    fi
    echo ""
    
    # 显示影响的服务列表
    log_info "将要处理的服务："
    for service in $UPDATE_SERVICES; do
        local desc=$(get_service_description "$service")
        local vps=$(get_service_vps "$service")
        echo "  • $service ($desc) - $vps VPS"
    done
    echo ""
    
    # 确认操作
    if [ "$RESTART_ONLY" = "true" ]; then
        read -p "确认重启这些服务? (y/N): " confirm
    else
        read -p "确认更新这些服务? (y/N): " confirm
    fi
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_info "操作已取消"
        exit 0
    fi
    
    # 执行操作
    if [ "$UPDATE_MODE" = "rolling" ]; then
        success_count=$(rolling_update_all_services)
        total_count=$(get_all_services | wc -w)
    else
        success_count=$(batch_process_services)
        total_count=$(echo $UPDATE_SERVICES | wc -w)
    fi
    
    # 最终健康检查
    if [ $success_count -gt 0 ]; then
        echo ""
        log_step "执行最终健康检查..."
        batch_health_check "$UPDATE_SERVICES" "localhost"
    fi
    
    # 显示总结
    if [ "$RESTART_ONLY" = "true" ]; then
        show_update_summary "重启" "$success_count" "$total_count"
    else
        show_update_summary "更新" "$success_count" "$total_count"
    fi
    
    # 清理镜像
    if [ "$RESTART_ONLY" != "true" ] && [ "$SKIP_CLEANUP" != "true" ]; then
        cleanup_docker_images false
    fi
}

# 执行主函数
main "$@" 