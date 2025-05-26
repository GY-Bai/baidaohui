#!/bin/bash

# SJ服务器Redis连接诊断工具
# 专门用于诊断baidaohui-sso-api (端口5004) 的Redis连接问题

echo "🔍 SJ服务器Redis连接诊断开始..."
echo "=================================="

# 检查Redis服务状态
echo "1. 检查Redis服务状态..."
if systemctl is-active --quiet redis-server; then
    echo "  ✅ Redis服务正在运行"
else
    echo "  ❌ Redis服务未运行"
    echo "  尝试启动Redis服务..."
    sudo systemctl start redis-server
    sleep 2
    if systemctl is-active --quiet redis-server; then
        echo "  ✅ Redis服务启动成功"
    else
        echo "  ❌ Redis服务启动失败"
    fi
fi

# 检查Redis端口监听
echo "2. 检查Redis端口监听..."
if netstat -tlnp | grep -q ":6379"; then
    echo "  ✅ Redis端口6379正在监听"
    netstat -tlnp | grep ":6379"
else
    echo "  ❌ Redis端口6379未监听"
fi

# 测试Redis连接
echo "3. 测试Redis连接..."
if redis-cli ping > /dev/null 2>&1; then
    echo "  ✅ Redis连接正常"
    echo "  Redis版本: $(redis-cli --version)"
else
    echo "  ❌ Redis连接失败"
fi

# 检查Redis配置
echo "4. 检查Redis配置..."
REDIS_CONF="/etc/redis/redis.conf"
if [ -f "$REDIS_CONF" ]; then
    echo "  Redis配置文件: $REDIS_CONF"
    echo "  绑定地址: $(grep -E '^bind' $REDIS_CONF || echo '未配置')"
    echo "  端口: $(grep -E '^port' $REDIS_CONF || echo '默认6379')"
else
    echo "  ❌ Redis配置文件不存在"
fi

# 检查防火墙
echo "5. 检查防火墙设置..."
if command -v ufw > /dev/null; then
    echo "  UFW状态: $(sudo ufw status | head -1)"
    if sudo ufw status | grep -q "6379"; then
        echo "  ✅ 端口6379已在防火墙中开放"
    else
        echo "  ⚠️  端口6379未在防火墙中明确开放"
    fi
fi

# 检查Docker容器中的Redis
echo "6. 检查Docker容器中的Redis..."
if docker ps | grep -q redis; then
    echo "  ✅ 发现Redis Docker容器"
    docker ps | grep redis
else
    echo "  ℹ️  未发现Redis Docker容器"
fi

# 检查SSO API服务状态
echo "7. 检查SSO API服务状态..."
if curl -s http://localhost:5004/health > /dev/null 2>&1; then
    echo "  ✅ SSO API服务响应正常"
else
    echo "  ❌ SSO API服务无响应"
    echo "  健康检查结果:"
    curl -s http://localhost:5004/health || echo "  连接失败"
fi

# 检查系统资源
echo "8. 检查系统资源..."
echo "  内存使用: $(free -h | grep Mem | awk '{print $3"/"$2}')"
echo "  磁盘使用: $(df -h / | tail -1 | awk '{print $5}')"
echo "  负载: $(uptime | awk -F'load average:' '{print $2}')"

echo "=================================="
echo "🔍 SJ服务器Redis诊断完成"
echo ""
echo "💡 建议的修复步骤:"
echo "1. 如果Redis服务未运行，运行: sudo systemctl start redis-server"
echo "2. 如果端口未监听，检查Redis配置文件"
echo "3. 如果连接被拒绝，检查防火墙设置"
echo "4. 重启SSO API服务: bash scripts/sj-restart-sso.sh" 