#!/bin/bash

echo "=== 百道会Docker环境诊断 ==="
echo

# 检查Docker版本
echo "1. Docker版本信息："
docker --version
docker-compose --version
echo

# 检查Docker服务状态
echo "2. Docker服务状态："
systemctl is-active docker 2>/dev/null || echo "Docker服务状态检查失败"
echo

# 检查磁盘空间
echo "3. 磁盘空间："
df -h
echo

# 检查内存使用
echo "4. 内存使用："
free -h
echo

# 检查网络端口
echo "5. 端口占用情况："
netstat -tlnp | grep -E ':(80|443|5000|6379|5222|5280|9181)' 2>/dev/null || echo "netstat命令不可用"
echo

# 检查Docker镜像
echo "6. Docker镜像："
docker images
echo

# 检查Docker容器
echo "7. Docker容器："
docker ps -a
echo

# 检查Docker网络
echo "8. Docker网络："
docker network ls
echo

# 检查Docker卷
echo "9. Docker卷："
docker volume ls
echo

# 检查配置文件
echo "10. 配置文件检查："
echo "nginx配置文件："
ls -la nginx/ 2>/dev/null || echo "nginx目录不存在"
echo "prosody配置文件："
ls -la prosody/ 2>/dev/null || echo "prosody目录不存在"
echo

# 检查应用目录
echo "11. 应用目录检查："
echo "API应用："
ls -la ../../apps/api/ 2>/dev/null || echo "API目录不存在"
echo

# 检查最近的Docker日志
echo "12. 最近的Docker日志："
docker system events --since 10m --until now 2>/dev/null | tail -10 || echo "无法获取Docker事件日志"
echo

echo "=== 诊断完成 ===" 