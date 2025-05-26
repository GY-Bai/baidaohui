#!/bin/bash

echo "正在启动Buffalo算命服务器..."

# 进入Docker目录
cd "$(dirname "$0")"

# 停止现有容器
echo "停止现有容器..."
docker-compose -f docker-compose.buffalo.yml down

# 清理未使用的镜像和容器
echo "清理Docker资源..."
docker system prune -f

# 构建并启动服务
echo "构建并启动服务..."
docker-compose -f docker-compose.buffalo.yml up --build -d

# 等待服务启动
echo "等待服务启动..."
sleep 10

# 检查服务状态
echo "检查服务状态..."
docker-compose -f docker-compose.buffalo.yml ps

echo "Buffalo服务器启动完成！"
echo "访问地址："
echo "- 算命服务: http://fortune.baidaohui.com"
echo "- 队列监控: http://localhost:9181" 