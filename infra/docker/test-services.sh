#!/bin/bash

echo "=== 测试服务健康状态 ==="
echo

# 进入Docker目录
cd "$(dirname "$0")"

echo "1. 测试SJ服务器健康检查..."
echo "Profile API健康检查："
curl -s http://localhost/health 2>/dev/null | grep -q "profile-service" && echo "✅ Profile API 正常" || echo "❌ Profile API 异常"

echo "Auth API健康检查："
curl -s http://localhost/health 2>/dev/null | grep -q "auth-service" && echo "✅ Auth API 正常" || echo "❌ Auth API 异常"

echo
echo "2. 测试Buffalo服务器健康检查..."
echo "Fortune API健康检查："
curl -s http://localhost:5000/health 2>/dev/null | grep -q "fortune-service" && echo "✅ Fortune API 正常" || echo "❌ Fortune API 异常"

echo
echo "3. 检查Redis连接..."
docker-compose -f docker-compose.sj.yml exec -T redis redis-cli ping 2>/dev/null | grep -q "PONG" && echo "✅ SJ Redis 正常" || echo "❌ SJ Redis 异常"
docker-compose -f docker-compose.buffalo.yml exec -T redis redis-cli ping 2>/dev/null | grep -q "PONG" && echo "✅ Buffalo Redis 正常" || echo "❌ Buffalo Redis 异常"

echo
echo "4. 检查数据库连接..."
docker-compose -f docker-compose.sj.yml exec -T prestashop-db mysql -u prestashop -pprestashop_password -e "SELECT 1;" 2>/dev/null | grep -q "1" && echo "✅ MySQL 正常" || echo "❌ MySQL 异常"

echo
echo "5. 检查容器状态..."
echo "SJ服务器容器状态："
docker-compose -f docker-compose.sj.yml ps --format "table {{.Name}}\t{{.State}}\t{{.Status}}" 2>/dev/null || echo "SJ服务器不在此机器上"

echo
echo "Buffalo服务器容器状态："
docker-compose -f docker-compose.buffalo.yml ps --format "table {{.Name}}\t{{.State}}\t{{.Status}}" 2>/dev/null || echo "Buffalo服务器不在此机器上"

echo
echo "=== 测试完成 ===" 