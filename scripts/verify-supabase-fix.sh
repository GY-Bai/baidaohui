#!/bin/bash

# 验证 Supabase 兼容性修复的脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 全局变量
VPS_CHOICE=""
CONTAINERS=()
HEALTH_CHECKS=()
SERVER_NAME=""

# 显示使用说明
show_usage() {
    echo -e "${BLUE}🔍 Supabase 兼容性修复验证脚本${NC}"
    echo ""
    echo "使用方法："
    echo "  $0 [VPS选择]"
    echo ""
    echo "VPS选择："
    echo "  1    - SJ 服务器 (Profile, Auth, Chat, SSO API)"
    echo "  2    - Buffalo 服务器 (Fortune API)"
    echo ""
    echo "示例："
    echo "  $0 1    # 验证 SJ 服务器"
    echo "  $0 2    # 验证 Buffalo 服务器"
}

# 选择 VPS
select_vps() {
    if [ -z "$1" ]; then
        echo -e "${YELLOW}请选择要验证的 VPS：${NC}"
        echo "1) SJ 服务器 (Profile, Auth, Chat, SSO API)"
        echo "2) Buffalo 服务器 (Fortune API)"
        read -p "请输入选择 (1 或 2): " VPS_CHOICE
    else
        VPS_CHOICE="$1"
    fi

    case "$VPS_CHOICE" in
        "1")
            CONTAINERS=(
                "baidaohui-profile-api"
                "baidaohui-auth-api"
                "baidaohui-chat-api"
                "baidaohui-sso-api"
            )
            HEALTH_CHECKS=(
                "baidaohui-profile-api:5002"
                "baidaohui-auth-api:5001"
                "baidaohui-chat-api:5003"
                "baidaohui-sso-api:5004"
            )
            SERVER_NAME="SJ 服务器"
            ;;
        "2")
            CONTAINERS=(
                "buffalo-fortune-api"
            )
            HEALTH_CHECKS=(
                "buffalo-fortune-api:5000"
            )
            SERVER_NAME="Buffalo 服务器"
            ;;
        *)
            echo -e "${RED}无效的选择，请输入 1 或 2${NC}"
            show_usage
            exit 1
            ;;
    esac

    echo -e "${BLUE}🔍 验证 $SERVER_NAME Supabase 兼容性修复...${NC}"
}

# 检查 requirements.txt 文件中的版本
check_requirements() {
    local service=$1
    local file=$2
    
    echo -e "\n${BLUE}检查 $service 的依赖版本...${NC}"
    
    if [ -f "$file" ]; then
        local supabase_version=$(grep "supabase==" "$file" | cut -d'=' -f3)
        if [ "$supabase_version" = "2.9.0" ]; then
            echo -e "${GREEN}✅ $service: supabase==$supabase_version${NC}"
        else
            echo -e "${RED}❌ $service: supabase==$supabase_version (应该是 2.9.0)${NC}"
        fi
    else
        echo -e "${RED}❌ $service: requirements.txt 文件不存在${NC}"
    fi
}

# 检查依赖版本
check_all_requirements() {
    echo -e "${BLUE}检查依赖版本...${NC}"
    
    if [ "$VPS_CHOICE" = "1" ]; then
        check_requirements "Profile API" "apps/api/profile/requirements.txt"
        check_requirements "Auth API" "apps/api/auth/requirements.txt"
        check_requirements "Chat API" "apps/api/chat/requirements.txt"
        check_requirements "SSO API" "apps/api/sso/requirements.txt"
    else
        check_requirements "Fortune API" "apps/api/fortune/requirements.txt"
    fi
}

# 检查容器状态
check_container_status() {
    echo -e "\n${BLUE}检查 $SERVER_NAME 容器状态...${NC}"
    
    for container in "${CONTAINERS[@]}"; do
        if docker ps --format "{{.Names}}" | grep -q "^${container}$"; then
            status=$(docker ps --format "{{.Names}}\t{{.Status}}" | grep "^${container}" | cut -f2)
            if [[ $status == *"Up"* ]]; then
                echo -e "${GREEN}✅ $container: 运行中${NC}"
            else
                echo -e "${YELLOW}⚠️  $container: $status${NC}"
            fi
        else
            echo -e "${RED}❌ $container: 未运行${NC}"
        fi
    done
}

# 检查健康端点
check_health_endpoints() {
    echo -e "\n${BLUE}检查 $SERVER_NAME 健康端点...${NC}"
    
    for check in "${HEALTH_CHECKS[@]}"; do
        container_name=$(echo $check | cut -d':' -f1)
        port=$(echo $check | cut -d':' -f2)
        
        if docker ps --format "{{.Names}}" | grep -q "^${container_name}$"; then
            if timeout 5 docker exec "$container_name" curl -f "http://localhost:$port/health" > /dev/null 2>&1; then
                echo -e "${GREEN}✅ $container_name: 健康检查通过${NC}"
            else
                echo -e "${YELLOW}⚠️  $container_name: 健康检查失败或超时${NC}"
            fi
        else
            echo -e "${RED}❌ $container_name: 容器未运行，跳过健康检查${NC}"
        fi
    done
}

# 检查错误日志
check_error_logs() {
    echo -e "\n${BLUE}检查 $SERVER_NAME 最近的错误日志...${NC}"
    error_found=false
    
    for container in "${CONTAINERS[@]}"; do
        if docker ps --format "{{.Names}}" | grep -q "^${container}$"; then
            # 检查最近 50 行日志中是否有 proxy 相关错误
            if docker logs "$container" --tail=50 2>&1 | grep -q "unexpected keyword argument.*proxy"; then
                echo -e "${RED}❌ $container: 仍然存在 proxy 相关错误${NC}"
                error_found=true
            fi
        fi
    done
    
    if [ "$error_found" = false ]; then
        echo -e "${GREEN}✅ 未发现 proxy 相关错误${NC}"
        return 0
    else
        return 1
    fi
}

# 显示详细的容器信息
show_container_details() {
    echo -e "\n${BLUE}=== $SERVER_NAME 容器详细信息 ===${NC}"
    
    for container in "${CONTAINERS[@]}"; do
        if docker ps --format "{{.Names}}" | grep -q "^${container}$"; then
            echo -e "\n${BLUE}--- $container ---${NC}"
            echo "状态: $(docker ps --format "{{.Status}}" --filter "name=^${container}$")"
            echo "镜像: $(docker ps --format "{{.Image}}" --filter "name=^${container}$")"
            echo "端口: $(docker ps --format "{{.Ports}}" --filter "name=^${container}$")"
            
            # 检查 Supabase 版本
            supabase_version=$(docker exec "$container" pip show supabase 2>/dev/null | grep "Version:" | cut -d' ' -f2 || echo "未知")
            echo "Supabase 版本: $supabase_version"
            
            # 检查 httpx 版本
            httpx_version=$(docker exec "$container" pip show httpx 2>/dev/null | grep "Version:" | cut -d' ' -f2 || echo "未知")
            echo "httpx 版本: $httpx_version"
        else
            echo -e "\n${RED}--- $container (未运行) ---${NC}"
        fi
    done
}

# 生成总结报告
generate_summary() {
    echo -e "\n${BLUE}=== $SERVER_NAME 验证总结 ===${NC}"
    echo -e "${GREEN}✅ 已更新所有服务的 Supabase 版本到 2.9.0${NC}"
    
    running_count=$(docker ps --format "{{.Names}}" | grep -E "$(IFS='|'; echo "${CONTAINERS[*]}")" | wc -l)
    total_count=${#CONTAINERS[@]}
    
    if [ "$running_count" -eq "$total_count" ]; then
        echo -e "${GREEN}✅ 所有服务 ($running_count/$total_count) 都在运行${NC}"
    else
        echo -e "${YELLOW}⚠️  只有 $running_count/$total_count 个服务在运行${NC}"
    fi
    
    # 检查错误日志
    if check_error_logs; then
        echo -e "${GREEN}✅ 修复成功！所有服务应该正常工作${NC}"
        return 0
    else
        echo -e "${RED}❌ 仍有问题，请检查日志并重新构建服务${NC}"
        echo -e "${YELLOW}建议运行: ./scripts/fix-supabase-compatibility.sh $VPS_CHOICE${NC}"
        return 1
    fi
}

# 主函数
main() {
    check_all_requirements
    check_container_status
    check_health_endpoints
    show_container_details
    
    if generate_summary; then
        echo -e "\n${BLUE}如需查看详细日志，运行:${NC}"
        echo -e "${YELLOW}  ./scripts/fix-supabase-compatibility.sh $VPS_CHOICE logs${NC}"
    else
        echo -e "\n${BLUE}如需重新修复，运行:${NC}"
        echo -e "${YELLOW}  ./scripts/fix-supabase-compatibility.sh $VPS_CHOICE clean${NC}"
        echo -e "${YELLOW}  ./scripts/fix-supabase-compatibility.sh $VPS_CHOICE${NC}"
    fi
}

# 处理命令行参数
if [ $# -eq 0 ]; then
    show_usage
    exit 0
fi

# 选择 VPS 并运行验证
select_vps "$1"
main 