#!/bin/bash

# 诊断健康检查失败问题的脚本

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
    echo -e "${BLUE}🔍 健康检查问题诊断脚本${NC}"
    echo ""
    echo "使用方法："
    echo "  $0 [VPS选择]"
    echo ""
    echo "VPS选择："
    echo "  1    - SJ 服务器 (Profile, Auth, Chat, SSO API)"
    echo "  2    - Buffalo 服务器 (Fortune API)"
    echo ""
    echo "示例："
    echo "  $0 1    # 诊断 SJ 服务器"
    echo "  $0 2    # 诊断 Buffalo 服务器"
}

# 选择 VPS
select_vps() {
    if [ -z "$1" ]; then
        echo -e "${YELLOW}请选择要诊断的 VPS：${NC}"
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

    echo -e "${BLUE}🔍 诊断 $SERVER_NAME 健康检查问题...${NC}"
}

# 检查容器基本状态
check_container_basic_status() {
    echo -e "\n${BLUE}=== 1. 容器基本状态检查 ===${NC}"
    
    for container in "${CONTAINERS[@]}"; do
        echo -e "\n${BLUE}--- $container ---${NC}"
        
        if docker ps --format "{{.Names}}" | grep -q "^${container}$"; then
            echo -e "${GREEN}✅ 容器正在运行${NC}"
            
            # 显示容器详细信息
            echo "状态: $(docker ps --format "{{.Status}}" --filter "name=^${container}$")"
            echo "镜像: $(docker ps --format "{{.Image}}" --filter "name=^${container}$")"
            echo "端口: $(docker ps --format "{{.Ports}}" --filter "name=^${container}$")"
            
            # 检查容器资源使用情况
            echo "资源使用:"
            docker stats --no-stream --format "table {{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" "$container"
            
        else
            echo -e "${RED}❌ 容器未运行${NC}"
            
            # 检查是否存在已停止的容器
            if docker ps -a --format "{{.Names}}" | grep -q "^${container}$"; then
                echo "容器状态: $(docker ps -a --format "{{.Status}}" --filter "name=^${container}$")"
                echo -e "${YELLOW}⚠️  容器存在但已停止${NC}"
            else
                echo -e "${RED}❌ 容器不存在${NC}"
            fi
        fi
    done
}

# 检查容器内部进程
check_container_processes() {
    echo -e "\n${BLUE}=== 2. 容器内部进程检查 ===${NC}"
    
    for container in "${CONTAINERS[@]}"; do
        if docker ps --format "{{.Names}}" | grep -q "^${container}$"; then
            echo -e "\n${BLUE}--- $container 进程 ---${NC}"
            
            # 检查容器内运行的进程
            echo "运行中的进程:"
            docker exec "$container" ps aux 2>/dev/null || echo "无法获取进程信息"
            
            # 检查端口监听情况
            echo -e "\n监听的端口:"
            docker exec "$container" netstat -tlnp 2>/dev/null || echo "无法获取端口信息"
            
        fi
    done
}

# 检查应用日志
check_application_logs() {
    echo -e "\n${BLUE}=== 3. 应用日志检查 ===${NC}"
    
    for container in "${CONTAINERS[@]}"; do
        if docker ps --format "{{.Names}}" | grep -q "^${container}$"; then
            echo -e "\n${BLUE}--- $container 最近日志 ---${NC}"
            
            # 显示最近的日志
            echo "最近 20 行日志:"
            docker logs "$container" --tail=20 2>&1 | head -20
            
            echo -e "\n错误日志 (最近 50 行):"
            docker logs "$container" --tail=50 2>&1 | grep -i "error\|exception\|traceback\|failed" | head -10 || echo "未发现明显错误"
            
            echo -e "\n启动相关日志:"
            docker logs "$container" 2>&1 | grep -i "starting\|started\|listening\|server" | tail -5 || echo "未发现启动信息"
            
        fi
    done
}

# 检查健康端点详细信息
check_health_endpoints_detailed() {
    echo -e "\n${BLUE}=== 4. 健康端点详细检查 ===${NC}"
    
    for check in "${HEALTH_CHECKS[@]}"; do
        container_name=$(echo $check | cut -d':' -f1)
        port=$(echo $check | cut -d':' -f2)
        
        if docker ps --format "{{.Names}}" | grep -q "^${container_name}$"; then
            echo -e "\n${BLUE}--- $container_name:$port ---${NC}"
            
            # 检查端口是否在容器内监听
            echo "检查端口 $port 是否在容器内监听:"
            if docker exec "$container_name" netstat -tln 2>/dev/null | grep ":$port " >/dev/null; then
                echo -e "${GREEN}✅ 端口 $port 正在监听${NC}"
            elif docker exec "$container_name" ss -tln 2>/dev/null | grep ":$port " >/dev/null; then
                echo -e "${GREEN}✅ 端口 $port 正在监听 (通过 ss 检测)${NC}"
            else
                echo -e "${RED}❌ 端口 $port 未监听${NC}"
            fi
            
            # 使用 Python 进行容器内部健康检查
            echo -e "\n从容器内部测试健康端点 (使用 Python):"
            python_health_check="
import urllib.request
import json
import sys
try:
    with urllib.request.urlopen('http://localhost:$port/health', timeout=10) as response:
        data = response.read().decode('utf-8')
        print('HTTP Status:', response.status)
        print('Response:', data)
        if response.status == 200:
            sys.exit(0)
        else:
            sys.exit(1)
except Exception as e:
    print('Error:', str(e))
    sys.exit(1)
"
            if docker exec "$container_name" python -c "$python_health_check" 2>&1; then
                echo -e "${GREEN}✅ 容器内部健康检查成功${NC}"
            else
                echo -e "${RED}❌ 容器内部健康检查失败${NC}"
            fi
            
            # 从宿主机外部测试健康端点
            echo -e "\n从宿主机外部测试健康端点:"
            if curl -s -m 10 "http://localhost:$port/health" >/dev/null 2>&1; then
                echo -e "${GREEN}✅ 外部健康检查成功${NC}"
                echo "响应内容:"
                curl -s -m 10 "http://localhost:$port/health" | head -3
            else
                echo -e "${RED}❌ 外部健康检查失败${NC}"
            fi
            
            # 使用 Python socket 检查端口连接
            echo -e "\n端口连接测试 (使用 Python socket):"
            python_port_check="
import socket
import sys
try:
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(5)
    result = sock.connect_ex(('localhost', $port))
    sock.close()
    if result == 0:
        print('端口 $port 可连接')
        sys.exit(0)
    else:
        print('端口 $port 不可连接')
        sys.exit(1)
except Exception as e:
    print('连接测试失败:', str(e))
    sys.exit(1)
"
            if docker exec "$container_name" python -c "$python_port_check" 2>&1; then
                echo -e "${GREEN}✅ 端口连接测试成功${NC}"
            else
                echo -e "${YELLOW}⚠️  端口连接测试失败${NC}"
            fi
            
        else
            echo -e "\n${RED}--- $container_name (未运行) ---${NC}"
        fi
    done
}

# 检查环境变量和配置
check_environment_config() {
    echo -e "\n${BLUE}=== 5. 环境变量和配置检查 ===${NC}"
    
    for container in "${CONTAINERS[@]}"; do
        if docker ps --format "{{.Names}}" | grep -q "^${container}$"; then
            echo -e "\n${BLUE}--- $container 环境变量 ---${NC}"
            
            # 显示重要的环境变量
            echo "重要环境变量:"
            docker exec "$container" env | grep -E "(PORT|HOST|DEBUG|SUPABASE|DATABASE)" | sort || echo "未发现相关环境变量"
            
            # 检查 Python 版本和包
            echo -e "\nPython 环境:"
            docker exec "$container" python --version 2>/dev/null || echo "无法获取 Python 版本"
            
            echo -e "\nSupabase 包版本:"
            docker exec "$container" pip show supabase 2>/dev/null | grep "Version:" || echo "未安装 supabase 包"
            
            echo -e "\nhttpx 包版本:"
            docker exec "$container" pip show httpx 2>/dev/null | grep "Version:" || echo "未安装 httpx 包"
            
        fi
    done
}

# 检查网络连接
check_network_connectivity() {
    echo -e "\n${BLUE}=== 6. 网络连接检查 ===${NC}"
    
    for container in "${CONTAINERS[@]}"; do
        if docker ps --format "{{.Names}}" | grep -q "^${container}$"; then
            echo -e "\n${BLUE}--- $container 网络 ---${NC}"
            
            # 检查容器网络配置
            echo "网络配置:"
            docker exec "$container" ip addr show 2>/dev/null | grep -E "(inet |UP)" || echo "无法获取网络配置"
            
            # 使用 Python 检查 DNS 解析
            echo -e "\nDNS 解析测试 (使用 Python):"
            python_dns_check="
import socket
import sys
try:
    result = socket.gethostbyname('google.com')
    print(f'DNS 解析成功: google.com -> {result}')
    sys.exit(0)
except Exception as e:
    print(f'DNS 解析失败: {str(e)}')
    sys.exit(1)
"
            if docker exec "$container" python -c "$python_dns_check" 2>&1; then
                echo -e "${GREEN}✅ DNS 解析正常${NC}"
            else
                echo -e "${YELLOW}⚠️  DNS 解析可能有问题${NC}"
            fi
            
            # 使用 Python 检查外部连接
            echo -e "\n外部连接测试 (使用 Python):"
            python_connection_check="
import socket
import sys
try:
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(5)
    result = sock.connect_ex(('8.8.8.8', 53))
    sock.close()
    if result == 0:
        print('外部连接测试成功 (8.8.8.8:53)')
        sys.exit(0)
    else:
        print('外部连接测试失败')
        sys.exit(1)
except Exception as e:
    print(f'连接测试失败: {str(e)}')
    sys.exit(1)
"
            if docker exec "$container" python -c "$python_connection_check" 2>&1; then
                echo -e "${GREEN}✅ 外部网络连接正常${NC}"
            else
                echo -e "${YELLOW}⚠️  外部网络连接可能有问题${NC}"
            fi
            
        fi
    done
}

# 生成修复建议
generate_fix_suggestions() {
    echo -e "\n${BLUE}=== 7. 修复建议 ===${NC}"
    
    echo -e "\n${YELLOW}基于诊断结果，建议尝试以下修复步骤：${NC}"
    
    echo -e "\n${BLUE}1. 重启容器：${NC}"
    echo "   ./scripts/fix-supabase-compatibility.sh $VPS_CHOICE stop"
    echo "   ./scripts/fix-supabase-compatibility.sh $VPS_CHOICE start"
    
    echo -e "\n${BLUE}2. 重新构建服务：${NC}"
    echo "   ./scripts/fix-supabase-compatibility.sh $VPS_CHOICE rebuild"
    
    echo -e "\n${BLUE}3. 强力清理后重建：${NC}"
    echo "   ./scripts/fix-supabase-compatibility.sh $VPS_CHOICE clean"
    echo "   ./scripts/fix-supabase-compatibility.sh $VPS_CHOICE"
    
    echo -e "\n${BLUE}4. 检查特定容器日志：${NC}"
    for container in "${CONTAINERS[@]}"; do
        echo "   docker logs $container --tail=100"
    done
    
    echo -e "\n${BLUE}5. 手动测试健康端点：${NC}"
    echo "   从宿主机外部测试："
    for check in "${HEALTH_CHECKS[@]}"; do
        container_name=$(echo $check | cut -d':' -f1)
        port=$(echo $check | cut -d':' -f2)
        echo "   curl -v http://localhost:$port/health"
    done
    echo "   从容器内部测试（使用 Python）："
    for check in "${HEALTH_CHECKS[@]}"; do
        container_name=$(echo $check | cut -d':' -f1)
        port=$(echo $check | cut -d':' -f2)
        echo "   docker exec $container_name python -c \"import urllib.request; print(urllib.request.urlopen('http://localhost:$port/health').read().decode())\""
    done
    
    echo -e "\n${BLUE}6. 如果问题持续，尝试 ContainerConfig 专用修复：${NC}"
    echo "   ./scripts/fix-containerconfig-error.sh $VPS_CHOICE"
}

# 主函数
main() {
    check_container_basic_status
    check_container_processes
    check_application_logs
    check_health_endpoints_detailed
    check_environment_config
    check_network_connectivity
    generate_fix_suggestions
    
    echo -e "\n${GREEN}诊断完成！请根据上述信息和建议进行修复。${NC}"
}

# 处理命令行参数
if [ $# -eq 0 ]; then
    show_usage
    exit 0
fi

# 选择 VPS 并运行诊断
select_vps "$1"
main 