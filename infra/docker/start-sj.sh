#!/bin/bash

echo "正在启动百道会SJ服务器..."

# 进入Docker目录
cd "$(dirname "$0")"

# 生成SSL证书（如果不存在）
if [ ! -f "ssl/baidaohui.crt" ] || [ ! -f "ssl/baidaohui.key" ]; then
    echo "生成SSL证书..."
    cd ssl && ./generate-ssl.sh && cd ..
fi

# 停止现有容器
echo "停止现有容器..."
docker-compose -f docker-compose.sj.yml down

# 清理未使用的镜像和容器
echo "清理Docker资源..."
docker system prune -f

# 构建并启动服务
echo "构建并启动服务..."
docker-compose -f docker-compose.sj.yml up --build -d

# 等待服务启动
echo "等待服务启动..."
sleep 10

# 检查服务状态
echo "检查服务状态..."
docker-compose -f docker-compose.sj.yml ps

echo "SJ服务器启动完成！"
echo "访问地址："
echo "- 聊天服务: https://chat.baidaohui.com"
echo "- API服务: https://api.baidaohui.com"
echo "- 电商平台: https://buyer.shop.baidaohui.com" 