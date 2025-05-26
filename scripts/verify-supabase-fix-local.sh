#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 显示使用说明
show_usage() {
    echo "用法: $0 [1|2]"
    echo "  1 - 验证 SJ 服务器 (profile, auth, chat, sso APIs)"
    echo "  2 - 验证 Buffalo 服务器 (fortune API)"
}

# 选择 VPS
select_vps() {
    VPS_CHOICE=$1
    
    case $VPS_CHOICE in
        "1")
            SERVICES=(
                "Profile API:apps/api/profile/requirements.txt"
                "Auth API:apps/api/auth/requirements.txt"
                "Chat API:apps/api/chat/requirements.txt"
                "SSO API:apps/api/sso/requirements.txt"
            )
            SERVER_NAME="SJ 服务器"
            ;;
        "2")
            SERVICES=(
                "Fortune API:apps/api/fortune/requirements.txt"
            )
            SERVER_NAME="Buffalo 服务器"
            ;;
        *)
            echo -e "${RED}无效的选择，请输入 1 或 2${NC}"
            show_usage
            exit 1
            ;;
    esac

    echo -e "${BLUE}🔍 验证 $SERVER_NAME Supabase 兼容性修复（本地检查）...${NC}"
}

# 检查 requirements.txt 文件中的版本
check_requirements() {
    local service_name=$1
    local file_path=$2
    
    echo -e "\n${BLUE}检查 $service_name 的依赖版本...${NC}"
    
    if [ -f "$file_path" ]; then
        echo "文件路径: $file_path"
        
        # 检查 supabase 版本
        local supabase_line=$(grep "supabase==" "$file_path")
        if [ -n "$supabase_line" ]; then
            local supabase_version=$(echo "$supabase_line" | cut -d'=' -f3)
            if [ "$supabase_version" = "2.9.0" ]; then
                echo -e "${GREEN}✅ $service_name: supabase==$supabase_version${NC}"
            else
                echo -e "${RED}❌ $service_name: supabase==$supabase_version (应该是 2.9.0)${NC}"
            fi
        else
            echo -e "${RED}❌ $service_name: 未找到 supabase 依赖${NC}"
        fi
        
        # 检查 httpx 版本
        local httpx_line=$(grep "httpx==" "$file_path")
        if [ -n "$httpx_line" ]; then
            local httpx_version=$(echo "$httpx_line" | cut -d'=' -f3)
            echo -e "${GREEN}✅ $service_name: httpx==$httpx_version${NC}"
        else
            echo -e "${YELLOW}⚠️  $service_name: 未找到 httpx 依赖${NC}"
        fi
        
        # 显示文件内容
        echo -e "${BLUE}文件内容:${NC}"
        cat "$file_path" | sed 's/^/  /'
        
    else
        echo -e "${RED}❌ $service_name: requirements.txt 文件不存在 ($file_path)${NC}"
    fi
}

# 检查 Dockerfile 是否存在
check_dockerfile() {
    local service_name=$1
    local dockerfile_path=$2
    
    if [ -f "$dockerfile_path" ]; then
        echo -e "${GREEN}✅ $service_name: Dockerfile 存在${NC}"
    else
        echo -e "${RED}❌ $service_name: Dockerfile 不存在 ($dockerfile_path)${NC}"
    fi
}

# 检查应用文件是否存在
check_app_file() {
    local service_name=$1
    local app_path=$2
    
    if [ -f "$app_path" ]; then
        echo -e "${GREEN}✅ $service_name: app.py 存在${NC}"
        
        # 检查是否有健康检查端点
        if grep -q "/health" "$app_path"; then
            echo -e "${GREEN}✅ $service_name: 包含健康检查端点${NC}"
        else
            # 对于 SSO API，检查 supabase_presta.py 文件
            if [ "$service_name" = "SSO API" ]; then
                sso_presta_path="$service_dir/supabase_presta.py"
                if [ -f "$sso_presta_path" ] && grep -q "/health" "$sso_presta_path"; then
                    echo -e "${GREEN}✅ $service_name: 包含健康检查端点 (在 supabase_presta.py 中)${NC}"
                else
                    echo -e "${YELLOW}⚠️  $service_name: 未找到健康检查端点${NC}"
                fi
            else
                echo -e "${YELLOW}⚠️  $service_name: 未找到健康检查端点${NC}"
            fi
        fi
    else
        echo -e "${RED}❌ $service_name: app.py 不存在 ($app_path)${NC}"
    fi
}

# 检查所有服务
check_all_services() {
    echo -e "${BLUE}检查 $SERVER_NAME 服务文件...${NC}"
    
    for service_info in "${SERVICES[@]}"; do
        service_name=$(echo "$service_info" | cut -d':' -f1)
        requirements_path=$(echo "$service_info" | cut -d':' -f2)
        
        # 获取服务目录
        service_dir=$(dirname "$requirements_path")
        dockerfile_path="$service_dir/Dockerfile"
        app_path="$service_dir/app.py"
        
        echo -e "\n${BLUE}=== $service_name ===${NC}"
        check_requirements "$service_name" "$requirements_path"
        check_dockerfile "$service_name" "$dockerfile_path"
        check_app_file "$service_name" "$app_path"
    done
}

# 检查 Docker Compose 文件
check_docker_compose() {
    echo -e "\n${BLUE}检查 Docker Compose 配置...${NC}"
    
    if [ "$VPS_CHOICE" = "1" ]; then
        compose_file="infra/docker/docker-compose.sj.yml"
    else
        compose_file="infra/docker/docker-compose.buffalo.yml"
    fi
    
    if [ -f "$compose_file" ]; then
        echo -e "${GREEN}✅ Docker Compose 文件存在: $compose_file${NC}"
        
        # 检查端口配置
        echo -e "${BLUE}端口配置:${NC}"
        grep -E "ports:|[0-9]+:[0-9]+" "$compose_file" | sed 's/^/  /'
    else
        echo -e "${RED}❌ Docker Compose 文件不存在: $compose_file${NC}"
    fi
}

# 生成总结报告
generate_summary() {
    echo -e "\n${BLUE}=== $SERVER_NAME 本地验证总结 ===${NC}"
    
    # 统计检查结果
    total_services=${#SERVICES[@]}
    echo -e "${GREEN}✅ 检查了 $total_services 个服务的配置文件${NC}"
    
    # 检查是否所有 requirements.txt 都有正确的 supabase 版本
    all_correct=true
    for service_info in "${SERVICES[@]}"; do
        requirements_path=$(echo "$service_info" | cut -d':' -f2)
        if [ -f "$requirements_path" ]; then
            if ! grep -q "supabase==2.9.0" "$requirements_path"; then
                all_correct=false
                break
            fi
        else
            all_correct=false
            break
        fi
    done
    
    if [ "$all_correct" = true ]; then
        echo -e "${GREEN}✅ 所有服务的 Supabase 版本都已更新到 2.9.0${NC}"
        echo -e "${GREEN}✅ 本地文件检查通过！${NC}"
        echo -e "\n${BLUE}下一步：在服务器上重新构建和部署服务${NC}"
        echo -e "${YELLOW}在服务器上运行:${NC}"
        echo -e "${YELLOW}  ./scripts/fix-supabase-compatibility.sh $VPS_CHOICE clean${NC}"
        echo -e "${YELLOW}  ./scripts/fix-supabase-compatibility.sh $VPS_CHOICE${NC}"
        echo -e "${YELLOW}  ./scripts/verify-supabase-fix.sh $VPS_CHOICE${NC}"
    else
        echo -e "${RED}❌ 发现配置问题，请检查上述错误信息${NC}"
        echo -e "${YELLOW}建议重新运行修复脚本:${NC}"
        echo -e "${YELLOW}  ./scripts/fix-supabase-compatibility.sh $VPS_CHOICE${NC}"
    fi
}

# 主函数
main() {
    check_all_services
    check_docker_compose
    generate_summary
}

# 处理命令行参数
if [ $# -eq 0 ]; then
    show_usage
    exit 0
fi

# 选择 VPS 并运行验证
select_vps "$1"
main 