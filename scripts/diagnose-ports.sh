#!/bin/bash

# 端口诊断脚本
# 用于检查 Docker 容器的端口绑定状态

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 Docker 容器端口诊断${NC}"
echo "=================================="

# 检查 Docker 是否运行
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}[ERROR]${NC} Docker 未运行"
    exit 1
fi

echo -e "${GREEN}✅ Docker 运行正常${NC}"
echo ""

# 检查容器状态
echo -e "${BLUE}📋 容器状态：${NC}"
docker ps -a --filter "name=baidaohui" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""

# 检查端口绑定
echo -e "${BLUE}🔌 端口绑定详情：${NC}"
containers=("baidaohui-auth-api" "baidaohui-profile-api" "baidaohui-chat-api" "baidaohui-sso-api")
ports=(5001 5002 5003 5004)

for i in "${!containers[@]}"; do
    container="${containers[$i]}"
    port="${ports[$i]}"
    
    echo -e "${YELLOW}检查 $container (端口 $port):${NC}"
    
    # 检查容器是否运行
    if docker ps --filter "name=$container" --format "{{.Names}}" | grep -q "$container"; then
        echo -e "  ${GREEN}✅ 容器运行中${NC}"
        
        # 检查端口绑定
        port_info=$(docker port "$container" 2>/dev/null || echo "无端口绑定")
        echo -e "  📍 端口绑定: $port_info"
        
        # 检查容器内部端口监听
        if docker exec "$container" netstat -tlnp 2>/dev/null | grep -q ":$port "; then
            echo -e "  ${GREEN}✅ 容器内端口 $port 正在监听${NC}"
        else
            echo -e "  ${RED}❌ 容器内端口 $port 未监听${NC}"
        fi
        
        # 尝试从容器内部访问
        if docker exec "$container" curl -f -s http://localhost:$port/health > /dev/null 2>&1; then
            echo -e "  ${GREEN}✅ 容器内健康检查通过${NC}"
        else
            echo -e "  ${RED}❌ 容器内健康检查失败${NC}"
        fi
        
    else
        echo -e "  ${RED}❌ 容器未运行${NC}"
    fi
    echo ""
done

# 检查宿主机端口
echo -e "${BLUE}🖥️  宿主机端口检查：${NC}"
for port in "${ports[@]}"; do
    if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
        echo -e "  ${GREEN}✅ 端口 $port 在宿主机上监听${NC}"
        netstat -tlnp 2>/dev/null | grep ":$port " | head -1
    else
        echo -e "  ${RED}❌ 端口 $port 在宿主机上未监听${NC}"
    fi
done
echo ""

# 尝试从宿主机访问
echo -e "${BLUE}🌐 宿主机访问测试：${NC}"
for port in "${ports[@]}"; do
    echo -n "  端口 $port: "
    if curl -f -s --connect-timeout 5 http://localhost:$port/health > /dev/null 2>&1; then
        echo -e "${GREEN}✅ 可访问${NC}"
    else
        echo -e "${RED}❌ 无法访问${NC}"
    fi
done
echo ""

# 显示 Docker Compose 状态
echo -e "${BLUE}📊 Docker Compose 状态：${NC}"
cd "$(dirname "$0")/../infra/docker"
if [ -f "docker-compose.sj.yml" ]; then
    docker-compose -f docker-compose.sj.yml ps
else
    echo -e "${RED}❌ docker-compose.sj.yml 文件未找到${NC}"
fi

echo ""
echo -e "${BLUE}🔍 诊断完成${NC}"
echo "如果发现问题，请尝试："
echo "1. 重启容器: ./scripts/fix-supabase-compatibility.sh 1 start"
echo "2. 重新构建: ./scripts/fix-supabase-compatibility.sh 1 rebuild"
echo "3. 查看日志: ./scripts/fix-supabase-compatibility.sh 1 logs" 