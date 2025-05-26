#!/bin/bash

# 快速修复健康检查问题的脚本

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
    echo -e "${BLUE}⚡ 健康检查问题快速修复脚本${NC}"
    echo ""
    echo "使用方法："
    echo "  $0 [VPS选择] [修复级别]"
    echo ""
    echo "VPS选择："
    echo "  1    - SJ 服务器 (Profile, Auth, Chat, SSO API)"
    echo "  2    - Buffalo 服务器 (Fortune API)"
    echo ""
    echo "修复级别："
    echo "  1    - 轻度修复 (重启容器)"
    echo "  2    - 中度修复 (重新构建)"
    echo "  3    - 重度修复 (强力清理后重建)"
    echo ""
    echo "示例："
    echo "  $0 1 1    # 轻度修复 SJ 服务器"
    echo "  $0 2 2    # 中度修复 Buffalo 服务器"
    echo "  $0 1 3    # 重度修复 SJ 服务器"
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

    echo -e "${BLUE}⚡ 快速修复 $SERVER_NAME 健康检查问题...${NC}"
}

# 选择修复级别
select_fix_level() {
    if [ -z "$2" ]; then
        echo -e "${YELLOW}请选择修复级别：${NC}"
        echo "1) 轻度修复 (重启容器) - 适用于临时问题"
        echo "2) 中度修复 (重新构建) - 适用于配置问题"
        echo "3) 重度修复 (强力清理后重建) - 适用于严重问题"
        read -p "请输入选择 (1, 2 或 3): " FIX_LEVEL
    else
        FIX_LEVEL="$2"
    fi

    case "$FIX_LEVEL" in
        "1"|"2"|"3")
            echo -e "${BLUE}选择的修复级别：$FIX_LEVEL${NC}"
            ;;
        *)
            echo -e "${RED}无效的修复级别，请输入 1, 2 或 3${NC}"
            show_usage
            exit 1
            ;;
    esac
}

# 检查当前状态
check_current_status() {
    echo -e "\n${BLUE}=== 检查当前状态 ===${NC}"
    
    for container in "${CONTAINERS[@]}"; do
        if docker ps --format "{{.Names}}" | grep -q "^${container}$"; then
            echo -e "${GREEN}✅ $container: 运行中${NC}"
        else
            echo -e "${RED}❌ $container: 未运行${NC}"
        fi
    done
}

# 轻度修复：重启容器
light_fix() {
    echo -e "\n${BLUE}=== 执行轻度修复：重启容器 ===${NC}"
    
    # 重启每个容器
    for container in "${CONTAINERS[@]}"; do
        if docker ps --format "{{.Names}}" | grep -q "^${container}$"; then
            echo -e "${YELLOW}重启 $container...${NC}"
            docker restart "$container"
            
            # 等待容器启动
            echo "等待容器启动..."
            sleep 10
            
            # 检查容器状态
            if docker ps --format "{{.Names}}" | grep -q "^${container}$"; then
                echo -e "${GREEN}✅ $container 重启成功${NC}"
            else
                echo -e "${RED}❌ $container 重启失败${NC}"
            fi
        else
            echo -e "${YELLOW}$container 未运行，尝试启动...${NC}"
            # 尝试使用 docker-compose 启动
            cd infra/docker
            if [ "$VPS_CHOICE" = "1" ]; then
                docker-compose -f docker-compose.sj.yml up -d $(echo $container | sed 's/baidaohui-//' | sed 's/-api//')
            else
                docker-compose -f docker-compose.buffalo.yml up -d fortune-api
            fi
            cd ../..
        fi
    done
}

# 中度修复：重新构建
medium_fix() {
    echo -e "\n${BLUE}=== 执行中度修复：重新构建 ===${NC}"
    
    # 使用现有的修复脚本
    echo "使用修复脚本重新构建服务..."
    ./scripts/fix-supabase-compatibility.sh "$VPS_CHOICE" rebuild
}

# 重度修复：强力清理后重建
heavy_fix() {
    echo -e "\n${BLUE}=== 执行重度修复：强力清理后重建 ===${NC}"
    
    # 使用现有的修复脚本进行强力清理
    echo "执行强力清理..."
    ./scripts/fix-supabase-compatibility.sh "$VPS_CHOICE" clean
    
    echo "重新构建所有服务..."
    ./scripts/fix-supabase-compatibility.sh "$VPS_CHOICE"
}

# 安装必要工具到容器
install_health_check_tools() {
    echo -e "\n${BLUE}=== 安装健康检查工具 ===${NC}"
    
    for container in "${CONTAINERS[@]}"; do
        if docker ps --format "{{.Names}}" | grep -q "^${container}$"; then
            echo -e "${YELLOW}为 $container 安装工具...${NC}"
            
            # 更新包列表并安装 curl
            docker exec "$container" bash -c "
                apt-get update > /dev/null 2>&1 || true
                apt-get install -y curl wget netcat-openbsd net-tools > /dev/null 2>&1 || true
            " || echo "工具安装失败，但继续执行..."
            
            echo -e "${GREEN}✅ $container 工具安装完成${NC}"
        fi
    done
}

# 测试健康端点
test_health_endpoints() {
    echo -e "\n${BLUE}=== 测试健康端点 ===${NC}"
    
    # 等待服务完全启动
    echo "等待服务完全启动..."
    sleep 15
    
    for check in "${HEALTH_CHECKS[@]}"; do
        container_name=$(echo $check | cut -d':' -f1)
        port=$(echo $check | cut -d':' -f2)
        
        if docker ps --format "{{.Names}}" | grep -q "^${container_name}$"; then
            echo -e "\n${BLUE}测试 $container_name:$port${NC}"
            
            # 检查端口是否监听
            if docker exec "$container_name" netstat -tln 2>/dev/null | grep -q ":$port "; then
                echo -e "${GREEN}✅ 端口 $port 正在监听${NC}"
                
                # 测试健康端点
                if timeout 10 docker exec "$container_name" curl -f "http://localhost:$port/health" > /dev/null 2>&1; then
                    echo -e "${GREEN}✅ 健康检查通过${NC}"
                else
                    echo -e "${YELLOW}⚠️  健康检查失败，但端口正在监听${NC}"
                    
                    # 尝试其他方法
                    if docker exec "$container_name" nc -z localhost "$port" 2>/dev/null; then
                        echo -e "${GREEN}✅ 端口连接测试成功${NC}"
                    else
                        echo -e "${RED}❌ 端口连接测试失败${NC}"
                    fi
                fi
            else
                echo -e "${RED}❌ 端口 $port 未监听${NC}"
                
                # 显示容器日志的最后几行
                echo "容器最近日志："
                docker logs "$container_name" --tail=5 2>&1 | head -5
            fi
        else
            echo -e "${RED}❌ $container_name 未运行${NC}"
        fi
    done
}

# 生成修复报告
generate_fix_report() {
    echo -e "\n${BLUE}=== 修复报告 ===${NC}"
    
    local success_count=0
    local total_count=${#HEALTH_CHECKS[@]}
    
    for check in "${HEALTH_CHECKS[@]}"; do
        container_name=$(echo $check | cut -d':' -f1)
        port=$(echo $check | cut -d':' -f2)
        
        if docker ps --format "{{.Names}}" | grep -q "^${container_name}$"; then
            if timeout 5 docker exec "$container_name" curl -f "http://localhost:$port/health" > /dev/null 2>&1; then
                echo -e "${GREEN}✅ $container_name: 健康检查通过${NC}"
                ((success_count++))
            else
                echo -e "${YELLOW}⚠️  $container_name: 健康检查失败${NC}"
            fi
        else
            echo -e "${RED}❌ $container_name: 容器未运行${NC}"
        fi
    done
    
    echo -e "\n${BLUE}修复结果：$success_count/$total_count 个服务健康检查通过${NC}"
    
    if [ "$success_count" -eq "$total_count" ]; then
        echo -e "${GREEN}🎉 所有服务修复成功！${NC}"
        return 0
    elif [ "$success_count" -gt 0 ]; then
        echo -e "${YELLOW}⚠️  部分服务修复成功，建议尝试更高级别的修复${NC}"
        return 1
    else
        echo -e "${RED}❌ 修复失败，建议尝试重度修复或查看详细日志${NC}"
        return 2
    fi
}

# 主修复流程
main_fix() {
    check_current_status
    
    case "$FIX_LEVEL" in
        "1")
            light_fix
            ;;
        "2")
            medium_fix
            ;;
        "3")
            heavy_fix
            ;;
    esac
    
    install_health_check_tools
    test_health_endpoints
    
    if ! generate_fix_report; then
        echo -e "\n${YELLOW}如果问题仍然存在，建议：${NC}"
        echo "1. 运行诊断脚本：./scripts/diagnose-health-issues.sh $VPS_CHOICE"
        echo "2. 查看详细日志：./scripts/fix-supabase-compatibility.sh $VPS_CHOICE logs"
        echo "3. 尝试更高级别的修复"
        
        if [ "$FIX_LEVEL" != "3" ]; then
            echo -e "\n${BLUE}是否尝试更高级别的修复？ (y/n)${NC}"
            read -p "输入选择: " choice
            if [ "$choice" = "y" ] || [ "$choice" = "Y" ]; then
                if [ "$FIX_LEVEL" = "1" ]; then
                    FIX_LEVEL="2"
                    echo -e "${YELLOW}升级到中度修复...${NC}"
                    main_fix
                elif [ "$FIX_LEVEL" = "2" ]; then
                    FIX_LEVEL="3"
                    echo -e "${YELLOW}升级到重度修复...${NC}"
                    main_fix
                fi
            fi
        fi
    fi
}

# 处理命令行参数
if [ $# -eq 0 ]; then
    show_usage
    exit 0
fi

# 选择 VPS 和修复级别
select_vps "$1"
select_fix_level "$1" "$2"

# 执行修复
main_fix

echo -e "\n${GREEN}快速修复完成！${NC}" 