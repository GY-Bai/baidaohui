#!/bin/bash

echo "=== 修复有问题的服务 ==="
echo

# 进入Docker目录
cd "$(dirname "$0")"

echo "1. 停止有问题的服务..."
# SJ服务器
docker-compose -f docker-compose.sj.yml stop profile-api auth-api 2>/dev/null
# Buffalo服务器  
docker-compose -f docker-compose.buffalo.yml stop fortune-api celery-worker celery-beat 2>/dev/null

echo "2. 移除有问题的容器..."
docker-compose -f docker-compose.sj.yml rm -f profile-api auth-api 2>/dev/null
docker-compose -f docker-compose.buffalo.yml rm -f fortune-api celery-worker celery-beat 2>/dev/null

echo "3. 重新构建镜像..."
# SJ服务器
docker-compose -f docker-compose.sj.yml build --no-cache profile-api auth-api 2>/dev/null
# Buffalo服务器
docker-compose -f docker-compose.buffalo.yml build --no-cache fortune-api celery-worker celery-beat 2>/dev/null

echo "4. 启动修复后的服务..."
# SJ服务器
docker-compose -f docker-compose.sj.yml up -d profile-api auth-api 2>/dev/null
# Buffalo服务器
docker-compose -f docker-compose.buffalo.yml up -d fortune-api celery-worker celery-beat 2>/dev/null

echo "5. 等待服务启动..."
sleep 15

echo "6. 检查服务状态..."
echo "SJ服务器状态："
docker-compose -f docker-compose.sj.yml ps profile-api auth-api 2>/dev/null || echo "SJ服务器不在此机器上"
echo
echo "Buffalo服务器状态："
docker-compose -f docker-compose.buffalo.yml ps fortune-api celery-worker celery-beat 2>/dev/null || echo "Buffalo服务器不在此机器上"

echo
echo "=== 修复完成 ==="
echo "如果服务仍然有问题，请运行 ./check-logs.sh 查看详细日志" 