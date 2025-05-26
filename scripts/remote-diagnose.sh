#!/bin/bash

# 远程服务器端口诊断脚本
# 在远程服务器上运行此脚本来诊断端口问题

echo "🔍 Docker 容器端口诊断"
echo "=================================="

# 检查容器状态
echo "📋 容器状态："
docker ps --filter "name=baidaohui" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""

# 检查端口绑定详情
echo "🔌 端口绑定详情："
containers=("baidaohui-auth-api" "baidaohui-profile-api" "baidaohui-chat-api" "baidaohui-sso-api")
ports=(5001 5002 5003 5004)

for i in "${!containers[@]}"; do
    container="${containers[$i]}"
    port="${ports[$i]}"
    
    echo "检查 $container (端口 $port):"
    
    # 检查容器是否运行
    if docker ps --filter "name=$container" --format "{{.Names}}" | grep -q "$container"; then
        echo "  ✅ 容器运行中"
        
        # 检查端口绑定
        port_info=$(docker port "$container" 2>/dev/null || echo "无端口绑定")
        echo "  📍 端口绑定: $port_info"
        
        # 尝试从容器内部访问
        if docker exec "$container" curl -f -s http://localhost:$port/health > /dev/null 2>&1; then
            echo "  ✅ 容器内健康检查通过"
        else
            echo "  ❌ 容器内健康检查失败"
            # 显示详细错误
            echo "  详细信息:"
            docker exec "$container" curl -v http://localhost:$port/health 2>&1 | head -5
        fi
        
    else
        echo "  ❌ 容器未运行"
    fi
    echo ""
done

# 检查宿主机端口
echo "🖥️  宿主机端口检查："
for port in "${ports[@]}"; do
    if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
        echo "  ✅ 端口 $port 在宿主机上监听"
        netstat -tlnp 2>/dev/null | grep ":$port " | head -1
    else
        echo "  ❌ 端口 $port 在宿主机上未监听"
    fi
done
echo ""

# 尝试从宿主机访问
echo "🌐 宿主机访问测试："
for port in "${ports[@]}"; do
    echo -n "  端口 $port: "
    if curl -f -s --connect-timeout 5 http://localhost:$port/health > /dev/null 2>&1; then
        echo "✅ 可访问"
    else
        echo "❌ 无法访问"
        # 显示详细错误
        echo "    详细信息: $(curl -s --connect-timeout 5 http://localhost:$port/health 2>&1 | head -1)"
    fi
done
echo ""

# 检查 Docker 网络
echo "🌐 Docker 网络："
docker network ls | grep baidaohui
echo ""

# 检查防火墙状态
echo "🔥 防火墙状态："
if command -v ufw >/dev/null 2>&1; then
    ufw status
elif command -v firewall-cmd >/dev/null 2>&1; then
    firewall-cmd --list-ports
else
    echo "未检测到常见防火墙工具"
fi
echo ""

echo "🔍 诊断完成"
echo ""
echo "如果端口无法访问，请尝试："
echo "1. 重启容器: docker-compose -f docker-compose.sj.yml restart"
echo "2. 检查日志: docker-compose -f docker-compose.sj.yml logs [service-name]"
echo "3. 检查防火墙设置" 