#!/bin/bash

# SJ服务器Redis自动修复工具
# 专门用于修复baidaohui-sso-api (端口5004) 的Redis连接问题

echo "🔧 SJ服务器Redis自动修复开始..."
echo "=================================="

# 函数：检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 函数：安装Redis
install_redis() {
    echo "📦 安装Redis..."
    if command_exists apt-get; then
        sudo apt-get update
        sudo apt-get install -y redis-server
    elif command_exists yum; then
        sudo yum install -y redis
    else
        echo "❌ 不支持的包管理器，请手动安装Redis"
        return 1
    fi
}

# 1. 检查并安装Redis
echo "1. 检查Redis安装..."
if command_exists redis-server; then
    echo "  ✅ Redis已安装"
else
    echo "  ❌ Redis未安装，正在安装..."
    install_redis
fi

# 2. 启动Redis服务
echo "2. 启动Redis服务..."
if systemctl is-active --quiet redis-server; then
    echo "  ✅ Redis服务已运行"
else
    echo "  🔄 启动Redis服务..."
    sudo systemctl start redis-server
    sudo systemctl enable redis-server
    sleep 3
    
    if systemctl is-active --quiet redis-server; then
        echo "  ✅ Redis服务启动成功"
    else
        echo "  ❌ Redis服务启动失败，尝试手动启动..."
        sudo redis-server --daemonize yes
        sleep 2
    fi
fi

# 3. 配置Redis
echo "3. 配置Redis..."
REDIS_CONF="/etc/redis/redis.conf"
if [ -f "$REDIS_CONF" ]; then
    # 备份原配置
    sudo cp "$REDIS_CONF" "$REDIS_CONF.backup.$(date +%Y%m%d_%H%M%S)"
    
    # 确保Redis监听localhost
    if ! grep -q "^bind 127.0.0.1" "$REDIS_CONF"; then
        echo "  🔧 配置Redis绑定地址..."
        sudo sed -i 's/^# bind 127.0.0.1/bind 127.0.0.1/' "$REDIS_CONF"
        sudo sed -i 's/^bind .*/bind 127.0.0.1/' "$REDIS_CONF"
    fi
    
    # 确保端口配置正确
    if ! grep -q "^port 6379" "$REDIS_CONF"; then
        echo "  🔧 配置Redis端口..."
        sudo sed -i 's/^# port 6379/port 6379/' "$REDIS_CONF"
        sudo sed -i 's/^port .*/port 6379/' "$REDIS_CONF"
    fi
    
    echo "  ✅ Redis配置完成"
else
    echo "  ⚠️  Redis配置文件不存在，使用默认配置"
fi

# 4. 重启Redis服务
echo "4. 重启Redis服务..."
sudo systemctl restart redis-server
sleep 3

# 5. 验证Redis连接
echo "5. 验证Redis连接..."
if redis-cli ping > /dev/null 2>&1; then
    echo "  ✅ Redis连接正常"
    echo "  Redis信息: $(redis-cli info server | grep redis_version)"
else
    echo "  ❌ Redis连接仍然失败"
    echo "  尝试使用Docker启动Redis..."
    
    if command_exists docker; then
        # 停止可能存在的Redis容器
        docker stop redis-sj 2>/dev/null || true
        docker rm redis-sj 2>/dev/null || true
        
        # 启动新的Redis容器
        docker run -d --name redis-sj -p 6379:6379 redis:alpine
        sleep 5
        
        if redis-cli ping > /dev/null 2>&1; then
            echo "  ✅ Docker Redis启动成功"
        else
            echo "  ❌ Docker Redis启动失败"
        fi
    fi
fi

# 6. 检查防火墙
echo "6. 检查防火墙..."
if command_exists ufw; then
    if sudo ufw status | grep -q "Status: active"; then
        echo "  🔧 配置防火墙规则..."
        sudo ufw allow 6379/tcp
        echo "  ✅ 防火墙规则已添加"
    fi
fi

# 7. 重启SSO API服务
echo "7. 重启SSO API服务..."
if [ -f "docker-compose.yml" ]; then
    echo "  🔄 使用docker-compose重启服务..."
    docker-compose restart sso-api 2>/dev/null || docker-compose restart api 2>/dev/null || echo "  ⚠️  未找到对应的服务名"
elif command_exists pm2; then
    echo "  🔄 使用PM2重启服务..."
    pm2 restart sso-api 2>/dev/null || pm2 restart all
else
    echo "  ⚠️  请手动重启SSO API服务"
fi

# 8. 最终验证
echo "8. 最终验证..."
sleep 5
echo "  测试Redis连接..."
if redis-cli ping > /dev/null 2>&1; then
    echo "  ✅ Redis连接正常"
else
    echo "  ❌ Redis连接失败"
fi

echo "  测试SSO API健康检查..."
HEALTH_RESPONSE=$(curl -s http://localhost:5004/health 2>/dev/null)
if echo "$HEALTH_RESPONSE" | grep -q '"status":"healthy"'; then
    echo "  ✅ SSO API服务正常"
    echo "  响应: $HEALTH_RESPONSE"
elif echo "$HEALTH_RESPONSE" | grep -q "Error.*connecting to.*Redis"; then
    echo "  ❌ SSO API仍然无法连接Redis"
    echo "  响应: $HEALTH_RESPONSE"
else
    echo "  ⚠️  SSO API响应异常"
    echo "  响应: $HEALTH_RESPONSE"
fi

echo "=================================="
echo "🔧 SJ服务器Redis修复完成"
echo ""
echo "📋 修复总结:"
echo "- Redis服务状态: $(systemctl is-active redis-server 2>/dev/null || echo '未知')"
echo "- Redis连接测试: $(redis-cli ping 2>/dev/null || echo 'FAILED')"
echo "- SSO API端口: $(curl -s http://localhost:5004/health >/dev/null && echo '✅ 可访问' || echo '❌ 无法访问')"
echo ""
echo "如果问题仍然存在，请运行: bash scripts/sj-redis-diagnose.sh" 