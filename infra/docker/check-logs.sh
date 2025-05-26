#!/bin/bash

echo "=== 检查服务日志 ==="
echo

# 检查SJ服务器的问题服务
echo "1. SJ服务器 - Profile API 日志："
echo "----------------------------------------"
docker-compose -f docker-compose.sj.yml logs --tail=20 profile-api 2>/dev/null || echo "无法获取profile-api日志"
echo

echo "2. SJ服务器 - Auth API 日志："
echo "----------------------------------------"
docker-compose -f docker-compose.sj.yml logs --tail=20 auth-api 2>/dev/null || echo "无法获取auth-api日志"
echo

# 检查Buffalo服务器的问题服务
echo "3. Buffalo服务器 - Fortune API 日志："
echo "----------------------------------------"
docker-compose -f docker-compose.buffalo.yml logs --tail=20 fortune-api 2>/dev/null || echo "无法获取fortune-api日志"
echo

echo "4. Buffalo服务器 - Celery Worker 日志："
echo "----------------------------------------"
docker-compose -f docker-compose.buffalo.yml logs --tail=20 celery-worker 2>/dev/null || echo "无法获取celery-worker日志"
echo

echo "5. Buffalo服务器 - Celery Beat 日志："
echo "----------------------------------------"
docker-compose -f docker-compose.buffalo.yml logs --tail=20 celery-beat 2>/dev/null || echo "无法获取celery-beat日志"
echo

echo "=== 日志检查完成 ===" 