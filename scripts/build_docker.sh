#!/bin/bash

# Docker 构建和推送脚本
# 用于构建所有 baidaohui 微服务的 Docker 镜像

set -e

# 加载通用函数库
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "$SCRIPT_DIR/common_functions.sh"

# 构建配置
VERSION=${1:-latest}
export IMAGE_TAG=$VERSION

# 选择构建范围
SELECTED_SERVICES=""
BUILD_MODE=""

# 显示帮助信息
show_help() {
    echo "用法: $0 [VERSION] [OPTIONS]"
    echo ""
    echo "参数:"
    echo "  VERSION          镜像版本标签 (默认: latest)"
    echo ""
    echo "环境变量:"
    echo "  CLEANUP_ALL      设置为 'true' 清理所有未使用镜像"
    echo "  SKIP_CLEANUP     设置为 'true' 跳过镜像清理"
    echo "  SKIP_PUSH        设置为 'true' 跳过镜像推送"
    echo ""
    echo "示例:"
    echo "  $0                    # 交互式选择构建范围"
    echo "  $0 v1.0.0            # 构建指定版本"
    echo "  CLEANUP_ALL=true $0  # 构建并清理所有未使用镜像"
    echo ""
}

# 显示构建选择菜单
show_build_selection() {
    echo -e "${BLUE}请选择构建范围:${NC}"
    echo ""
    echo -e "${CYAN}1. 圣何塞 VPS 服务 (8个高性能服务)${NC}"
    echo "   • $(get_san_jose_services | tr ' ' '\n' | wc -l)个服务: $(get_san_jose_services)"
    echo ""
    echo -e "${CYAN}2. 水牛城 VPS 服务 (5个后台服务)${NC}"
    echo "   • $(get_buffalo_services | tr ' ' '\n' | wc -l)个服务: $(get_buffalo_services)"
    echo ""
    echo -e "${CYAN}3. 所有服务 (13个微服务)${NC}"
    echo "   • 包含所有前端和后台服务"
    echo ""
    echo -e "${YELLOW}4. 自定义选择服务${NC}"
    echo ""
}

# 获取构建选择
get_build_selection() {
    while true; do
        show_build_selection
        read -p "请输入选项 (1/2/3/4): " choice
        
        case $choice in
            1)
                SELECTED_SERVICES=$(get_san_jose_services)
                BUILD_MODE="san-jose"
                break
                ;;
            2)
                SELECTED_SERVICES=$(get_buffalo_services)
                BUILD_MODE="buffalo"
                break
                ;;
            3)
                SELECTED_SERVICES=$(get_all_services)
                BUILD_MODE="all"
                break
                ;;
            4)
                custom_service_selection
                BUILD_MODE="custom"
                break
                ;;
            *)
                log_error "无效选项，请重新选择"
                echo ""
                ;;
        esac
    done
}

# 自定义服务选择
custom_service_selection() {
    local all_services=($(get_all_services))
    local selected=()
    
    echo ""
    log_info "自定义服务选择 (输入服务编号，用空格分隔):"
    echo ""
    
    for i in "${!all_services[@]}"; do
        local service="${all_services[$i]}"
        local desc=$(get_service_description "$service")
        echo "  $((i+1)). $service ($desc)"
    done
    
    echo ""
    read -p "请输入要构建的服务编号 (例如: 1 3 5): " service_numbers
    
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
    
    SELECTED_SERVICES="${selected[*]}"
    log_info "已选择 ${#selected[@]} 个服务: ${SELECTED_SERVICES}"
}

# 批量构建服务
batch_build_services() {
    local services=($SELECTED_SERVICES)
    local total_services=${#services[@]}
    local success_count=0
    local failed_services=()
    
    log_step "开始构建 $total_services 个服务"
    log_info "版本: $VERSION"
    log_info "仓库: $DOCKER_REGISTRY"
    echo ""
    
    # 构建所有服务
    for service in "${services[@]}"; do
        if build_service_image "$service"; then
            ((success_count++))
        else
            failed_services+=("$service")
        fi
        echo "----------------------------------------"
    done
    
    # 推送镜像（如果没有跳过）
    if [ "$SKIP_PUSH" != "true" ]; then
        log_step "推送镜像到仓库..."
        local push_success_count=0
        local push_failed_services=()
        
        for service in "${services[@]}"; do
            # 只推送构建成功的服务
            if [[ ! " ${failed_services[@]} " =~ " ${service} " ]]; then
                if push_service_image "$service"; then
                    ((push_success_count++))
                    
                    # 标记为 latest（如果版本不是 latest）
                    if [ "$VERSION" != "latest" ]; then
                        local latest_image="$DOCKER_REGISTRY/$PROJECT-$service:latest"
                        local versioned_image="$DOCKER_REGISTRY/$PROJECT-$service:$VERSION"
                        docker tag "$versioned_image" "$latest_image"
                        docker push "$latest_image" > /dev/null 2>&1
                        log_info "✅ 已标记并推送 latest 标签: $service"
                    fi
                else
                    push_failed_services+=("$service")
                fi
            fi
        done
        
        log_info "推送完成: $push_success_count/${#services[@]}"
        if [ ${#push_failed_services[@]} -gt 0 ]; then
            log_warning "推送失败的服务: ${push_failed_services[*]}"
        fi
    else
        log_info "跳过镜像推送 (SKIP_PUSH=true)"
    fi
    
    return $success_count
}

# 构建后验证
post_build_verification() {
    log_step "验证构建的镜像..."
    
    local services=($SELECTED_SERVICES)
    local verification_failed=()
    
    for service in "${services[@]}"; do
        local image_name="$DOCKER_REGISTRY/$PROJECT-$service:$VERSION"
        if docker image inspect "$image_name" > /dev/null 2>&1; then
            local image_size=$(docker image inspect "$image_name" --format='{{.Size}}' | numfmt --to=iec)
            log_success "✅ $service 镜像验证通过 (大小: $image_size)"
        else
            log_error "❌ $service 镜像验证失败"
            verification_failed+=("$service")
        fi
    done
    
    if [ ${#verification_failed[@]} -gt 0 ]; then
        log_error "镜像验证失败的服务: ${verification_failed[*]}"
        return 1
    fi
    
    return 0
}

# 主函数
main() {
    show_banner
    
    log_info "Docker 镜像构建和推送工具"
    log_info "目标版本: $VERSION"
    
    # 检查 Docker 环境
    check_docker
    
    # 获取构建选择
    get_build_selection
    
    echo ""
    log_info "构建配置："
    log_info "• 构建模式: $BUILD_MODE"
    log_info "• 服务数量: $(echo $SELECTED_SERVICES | wc -w)"
    log_info "• 目标版本: $VERSION"
    log_info "• Docker仓库: $DOCKER_REGISTRY"
    echo ""
    
    # 确认构建
    read -p "确认开始构建? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_info "构建已取消"
        exit 0
    fi
    
    # 执行构建
    success_count=$(batch_build_services)
    total_services=$(echo $SELECTED_SERVICES | wc -w)
    failed_count=$((total_services - success_count))
    
    # 验证镜像
    if [ $success_count -gt 0 ]; then
        post_build_verification
    fi
    
    # 清理镜像
    if [ "$SKIP_CLEANUP" != "true" ]; then
        cleanup_docker_images "$CLEANUP_ALL"
    fi
    
    # 显示构建总结
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}    构建完成总结${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    echo -e "${BLUE}构建模式:${NC} $BUILD_MODE"
    echo -e "${BLUE}目标版本:${NC} $VERSION"
    echo -e "${BLUE}总服务数:${NC} $total_services"
    echo -e "${GREEN}成功:${NC} $success_count"
    echo -e "${RED}失败:${NC} $failed_count"
    echo -e "${BLUE}构建时间:${NC} $(date)"
    
    if [ $failed_count -eq 0 ]; then
        echo ""
        log_success "🎉 所有服务构建成功！"
        
        # 显示下一步建议
        echo ""
        log_info "下一步操作建议："
        if [ "$BUILD_MODE" = "san-jose" ]; then
            echo "  ./scripts/deploy_vps.sh  # 部署到圣何塞VPS"
        elif [ "$BUILD_MODE" = "buffalo" ]; then
            echo "  ./scripts/deploy_vps.sh  # 部署到水牛城VPS"
        else
            echo "  ./scripts/deploy_vps.sh  # 部署到VPS"
        fi
        
        exit 0
    else
        echo ""
        log_error "部分服务构建失败，请检查错误信息"
        exit 1
    fi
}

# 检查参数
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_help
    exit 0
fi

# 执行主函数
main "$@" 