#!/bin/bash

# 快速修复端口问题脚本
# 重启服务并检查端口绑定

echo "🔧 快速修复端口问题"
echo "=================================="

cd "$(dirname "$0")/../infra/docker"

# 停止服务
echo "⏹️  停止服务..."
docker-compose -f docker-compose.sj.yml stop profile-api auth-api chat-api sso-api

# 等待停止
sleep 5

# 强制删除容器
echo "🗑️  删除容器..."
docker rm -f baidaohui-profile-api baidaohui-auth-api baidaohui-chat-api baidaohui-sso-api 2>/dev/null || true

# 检查端口是否被释放
echo "🔍 检查端口状态..."
ports=(5001 5002 5003 5004)
for port in "${ports[@]}"; do
    if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
        echo "  ⚠️  端口 $port 仍被占用"
        netstat -tlnp 2>/dev/null | grep ":$port "
    else
        echo "  ✅ 端口 $port 已释放"
    fi
done

# 重新启动服务
echo "🚀 重新启动服务..."
docker-compose -f docker-compose.sj.yml up -d profile-api auth-api chat-api sso-api

# 等待启动
echo "⏳ 等待服务启动（30秒）..."
sleep 30

# 检查容器状态
echo "📋 检查容器状态..."
docker ps --filter "name=baidaohui" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# 测试端口访问
echo "🌐 测试端口访问..."
for port in "${ports[@]}"; do
    echo -n "  端口 $port: "
    if curl -f -s --connect-timeout 10 http://localhost:$port/health > /dev/null 2>&1; then
        echo "✅ 可访问"
    else
        echo "❌ 无法访问"
    fi
done

echo ""
echo "🔧 修复完成"
echo ""
echo "如果问题仍然存在，请运行："
echo "  bash scripts/remote-diagnose.sh" 