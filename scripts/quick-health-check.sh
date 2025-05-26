#!/bin/bash

# 快速健康检查脚本 - 修复版本
# 使用 Python 内置模块，不依赖容器内的 curl/wget 等外部命令

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 显示使用说明
show_usage() {
    echo -e "${BLUE}🔍 快速健康检查脚本${NC}"
    echo ""
    echo "使用方法："
    echo "  $0 [VPS选择]"
    echo ""
    echo "VPS选择："
    echo "  1    - SJ 服务器 (Profile, Auth, Chat, SSO API)"
    echo "  2    - Buffalo 服务器 (Fortune API)"
    echo "  all  - 检查所有服务器"
    echo ""
    echo "示例："
    echo "  $0 1      # 检查 SJ 服务器"
    echo "  $0 2      # 检查 Buffalo 服务器"
    echo "  $0 all    # 检查所有服务器"
}

# 检查单个服务的健康状态
check_service_health() {
    local container_name="$1"
    local port="$2"
    local service_name="$3"
    
    echo -e "\n${BLUE}--- $service_name ($container_name:$port) ---${NC}"
    
    # 检查容器是否运行
    if ! docker ps --format "{{.Names}}" | grep -q "^${container_name}$"; then
        echo -e "${RED}❌ 容器未运行${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ 容器正在运行${NC}"
    
    # 从宿主机外部检查健康端点
    echo -n "外部健康检查: "
    if curl -s -m 10 "http://localhost:$port/health" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ 成功${NC}"
        # 显示响应内容
        local response=$(curl -s -m 10 "http://localhost:$port/health")
        echo "响应: $response"
    else
        echo -e "${RED}❌ 失败${NC}"
        
        # 使用 Python 从容器内部检查
        echo -n "容器内部检查: "
        local python_check="
import urllib.request
import sys
try:
    with urllib.request.urlopen('http://localhost:$port/health', timeout=10) as response:
        data = response.read().decode('utf-8')
        print('Status:', response.status, 'Response:', data)
        sys.exit(0 if response.status == 200 else 1)
except Exception as e:
    print('Error:', str(e))
    sys.exit(1)
"
        if docker exec "$container_name" python -c "$python_check" 2>&1; then
            echo -e "${GREEN}✅ 容器内部检查成功${NC}"
        else
            echo -e "${RED}❌ 容器内部检查也失败${NC}"
            
            # 检查端口是否监听
            echo -n "端口监听检查: "
            if docker exec "$container_name" netstat -tln 2>/dev/null | grep ":$port " >/dev/null; then
                echo -e "${GREEN}✅ 端口 $port 正在监听${NC}"
            elif docker exec "$container_name" ss -tln 2>/dev/null | grep ":$port " >/dev/null; then
                echo -e "${GREEN}✅ 端口 $port 正在监听${NC}"
            else
                echo -e "${RED}❌ 端口 $port 未监听${NC}"
            fi
        fi
    fi
}

# 检查 SJ 服务器
check_sj_server() {
    echo -e "${BLUE}🔍 检查 SJ 服务器健康状态...${NC}"
    
    check_service_health "baidaohui-profile-api" "5002" "Profile API"
    check_service_health "baidaohui-auth-api" "5001" "Auth API"
    check_service_health "baidaohui-chat-api" "5003" "Chat API"
    check_service_health "baidaohui-sso-api" "5004" "SSO API"
}

# 检查 Buffalo 服务器
check_buffalo_server() {
    echo -e "${BLUE}🔍 检查 Buffalo 服务器健康状态...${NC}"
    
    check_service_health "buffalo-fortune-api" "5000" "Fortune API"
}

# 主函数
main() {
    local choice="$1"
    
    case "$choice" in
        "1")
            check_sj_server
            ;;
        "2")
            check_buffalo_server
            ;;
        "all")
            check_sj_server
            check_buffalo_server
            ;;
        *)
            echo -e "${RED}无效的选择，请输入 1、2 或 all${NC}"
            show_usage
            exit 1
            ;;
    esac
    
    echo -e "\n${GREEN}健康检查完成！${NC}"
}

# 处理命令行参数
if [ $# -eq 0 ]; then
    show_usage
    exit 0
fi

main "$1" 