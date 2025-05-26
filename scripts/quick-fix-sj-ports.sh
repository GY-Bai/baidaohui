#!/bin/bash

# SJ服务器端口问题快速修复脚本
# 专为远程服务器设计的一键修复方案

set -e

echo "🚀 SJ服务器端口问题快速修复"
echo "=================================="

# 检查是否在正确目录
if [ ! -f "infra/docker/docker-compose.sj.yml" ]; then
    echo "❌ 错误：请在项目根目录运行此脚本"
    echo "当前目录: $(pwd)"
    exit 1
fi

# 创建备份
echo "📦 创建配置备份..."
mkdir -p infra/docker/backups
timestamp=$(date +"%Y%m%d_%H%M%S")
backup_file="infra/docker/backups/docker-compose.sj.yml.backup.${timestamp}"
cp infra/docker/docker-compose.sj.yml "$backup_file"
echo "✅ 配置已备份到: $backup_file"

# 修复shop-api端口映射
echo "🔧 修复shop-api端口映射..."
if ! grep -A 10 "shop-api:" infra/docker/docker-compose.sj.yml | grep -q "ports:"; then
    sed -i '/container_name: baidaohui-shop-api/a\    ports:\n      - "5005:5005"' infra/docker/docker-compose.sj.yml
    echo "✅ shop-api端口映射已添加 (5005:5005)"
else
    echo "ℹ️  shop-api端口映射已存在"
fi

# 移除prosody的80端口暴露（简化版本）
echo "🔧 修复prosody 80端口冲突..."
# 使用sed移除prosody配置中的80/tcp和443/tcp行
sed -i '/prosody:/,/^  [a-zA-Z]/ {
    /80\/tcp/d
    /443\/tcp/d
    /5281\/tcp/d
    /5347\/tcp/d
}' infra/docker/docker-compose.sj.yml
echo "✅ prosody 80端口冲突已修复"

# 重启服务
echo "🔄 重启Docker服务..."
cd infra/docker

# 停止服务
echo "⏹️  停止服务..."
if command -v docker-compose >/dev/null 2>&1; then
    docker-compose -f docker-compose.sj.yml down
elif command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    docker compose -f docker-compose.sj.yml down
else
    echo "❌ 未找到docker-compose命令"
    exit 1
fi

# 等待停止
sleep 5

# 启动服务
echo "🚀 启动服务..."
if command -v docker-compose >/dev/null 2>&1; then
    docker-compose -f docker-compose.sj.yml up -d
else
    docker compose -f docker-compose.sj.yml up -d
fi

cd ../..

# 等待服务启动
echo "⏳ 等待服务启动（30秒）..."
sleep 30

# 验证结果
echo "🔍 验证修复结果..."
echo "📋 容器状态："
docker ps --filter "name=baidaohui" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "🌐 端口访问测试："
ports=(5001 5002 5003 5004 5005)
names=("auth-api" "profile-api" "chat-api" "sso-api" "shop-api")

for i in "${!ports[@]}"; do
    port="${ports[$i]}"
    name="${names[$i]}"
    echo -n "  $name (端口 $port): "
    
    if command -v curl >/dev/null 2>&1; then
        if curl -f -s --connect-timeout 10 "http://localhost:$port/health" >/dev/null 2>&1; then
            echo "✅ 可访问"
        else
            echo "❌ 无法访问"
        fi
    else
        # 使用nc检查端口
        if command -v nc >/dev/null 2>&1; then
            if nc -z localhost $port 2>/dev/null; then
                echo "✅ 端口开放"
            else
                echo "❌ 端口未开放"
            fi
        else
            echo "❓ 无法测试"
        fi
    fi
done

echo ""
echo "🎉 修复完成！"
echo ""
echo "修复内容："
echo "✅ 为shop-api添加了端口映射 (5005:5005)"
echo "✅ 移除了prosody容器内的80端口暴露"
echo "✅ 重启了所有Docker服务"
echo ""
echo "现在可以访问："
echo "- Auth API: http://localhost:5001"
echo "- Profile API: http://localhost:5002"
echo "- Chat API: http://localhost:5003"
echo "- SSO API: http://localhost:5004"
echo "- Shop API: http://localhost:5005"
echo ""
echo "如果需要回滚，请运行："
echo "cp $backup_file infra/docker/docker-compose.sj.yml"
echo "cd infra/docker && docker-compose -f docker-compose.sj.yml restart" 