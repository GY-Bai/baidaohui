#!/bin/bash

# SJ服务器Supervisor问题一键修复脚本
# 解决 "supervisord: executable file not found in $PATH" 错误

echo "🚀 SJ服务器Supervisor问题一键修复"
echo "=================================="

# 检查Docker
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker未运行，请启动Docker服务"
    exit 1
fi

echo "📦 创建配置备份..."
mkdir -p infra/docker/backups
timestamp=$(date +"%Y%m%d_%H%M%S")
backup_file="infra/docker/backups/docker-compose.sj.yml.backup.$timestamp"
cp infra/docker/docker-compose.sj.yml "$backup_file"
echo "✅ 配置已备份到: $backup_file"

echo "🔧 禁用supervisor服务..."
cd infra/docker

# 注释掉supervisor服务配置
sed -i.tmp '/# Supervisor 进程管理/,/memory: 13M/s/^/  # /' docker-compose.sj.yml
rm -f docker-compose.sj.yml.tmp

echo "✅ supervisor服务已禁用"

echo "🧹 清理supervisor容器..."
# 停止并删除supervisor容器
docker-compose -f docker-compose.sj.yml stop supervisor 2>/dev/null || true
docker-compose -f docker-compose.sj.yml rm -f supervisor 2>/dev/null || true

echo "🔄 重启Docker服务..."
echo "⏹️  停止服务..."
docker-compose -f docker-compose.sj.yml down --remove-orphans

echo "🚀 启动服务..."
docker-compose -f docker-compose.sj.yml up -d

cd ../..

echo "⏳ 等待服务启动（30秒）..."
sleep 30

echo "📊 检查服务状态..."
cd infra/docker
docker-compose -f docker-compose.sj.yml ps
cd ../..

echo ""
echo "✅ SJ服务器supervisor问题修复完成！"
echo ""
echo "📋 修复总结："
echo "- supervisor容器启动问题已解决（通过禁用supervisor服务）"
echo "- 所有其他服务应该正常运行"
echo "- 如果仍有问题，请运行: ./scripts/fix-sj-supervisor-error.sh diagnose"
echo ""
echo "🔍 验证服务："
echo "- Auth API: http://localhost:5001"
echo "- Profile API: http://localhost:5002"
echo "- Chat API: http://localhost:5003"
echo "- SSO API: http://localhost:5004"
echo "- Shop API: http://localhost:5005"
echo "- Nginx: http://localhost:80" 