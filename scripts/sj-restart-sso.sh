#!/bin/bash

# SJ服务器SSO API服务重启工具
# 专门用于重启baidaohui-sso-api (端口5004) 服务

echo "🔄 SJ服务器SSO API服务重启开始..."
echo "=================================="

# 函数：检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 函数：检查端口是否被占用
check_port() {
    local port=$1
    if netstat -tlnp | grep -q ":$port "; then
        return 0
    else
        return 1
    fi
}

# 1. 检查当前SSO API服务状态
echo "1. 检查当前SSO API服务状态..."
if check_port 5004; then
    echo "  ✅ 端口5004正在被使用"
    PID=$(netstat -tlnp | grep ":5004 " | awk '{print $7}' | cut -d'/' -f1)
    if [ -n "$PID" ]; then
        echo "  进程ID: $PID"
        echo "  进程信息: $(ps -p $PID -o pid,ppid,cmd --no-headers 2>/dev/null || echo '无法获取')"
    fi
else
    echo "  ❌ 端口5004未被使用"
fi

# 2. 停止现有服务
echo "2. 停止现有SSO API服务..."

# 尝试通过Docker Compose停止
if [ -f "docker-compose.yml" ]; then
    echo "  🔄 尝试通过Docker Compose停止..."
    docker-compose stop sso-api 2>/dev/null || docker-compose stop api 2>/dev/null || echo "  ⚠️  未找到对应的服务名"
fi

# 尝试通过PM2停止
if command_exists pm2; then
    echo "  🔄 尝试通过PM2停止..."
    pm2 stop sso-api 2>/dev/null || echo "  ⚠️  PM2中未找到sso-api进程"
fi

# 强制杀死占用端口5004的进程
if check_port 5004; then
    echo "  🔄 强制停止占用端口5004的进程..."
    PID=$(netstat -tlnp | grep ":5004 " | awk '{print $7}' | cut -d'/' -f1)
    if [ -n "$PID" ]; then
        kill -TERM "$PID" 2>/dev/null
        sleep 3
        if kill -0 "$PID" 2>/dev/null; then
            echo "  🔄 进程仍在运行，强制杀死..."
            kill -KILL "$PID" 2>/dev/null
        fi
        echo "  ✅ 进程已停止"
    fi
fi

# 等待端口释放
echo "  ⏳ 等待端口释放..."
for i in {1..10}; do
    if ! check_port 5004; then
        echo "  ✅ 端口5004已释放"
        break
    fi
    sleep 1
done

# 3. 检查Redis连接
echo "3. 检查Redis连接..."
if redis-cli ping > /dev/null 2>&1; then
    echo "  ✅ Redis连接正常"
else
    echo "  ❌ Redis连接失败，尝试启动Redis..."
    sudo systemctl start redis-server 2>/dev/null || echo "  ⚠️  无法启动Redis服务"
    sleep 2
fi

# 4. 启动SSO API服务
echo "4. 启动SSO API服务..."

# 尝试通过Docker Compose启动
if [ -f "docker-compose.yml" ]; then
    echo "  🔄 尝试通过Docker Compose启动..."
    if docker-compose up -d sso-api 2>/dev/null; then
        echo "  ✅ Docker Compose启动成功"
    elif docker-compose up -d api 2>/dev/null; then
        echo "  ✅ Docker Compose启动成功 (api服务)"
    else
        echo "  ❌ Docker Compose启动失败"
    fi
fi

# 尝试通过PM2启动
if command_exists pm2; then
    echo "  🔄 尝试通过PM2启动..."
    if pm2 start sso-api 2>/dev/null; then
        echo "  ✅ PM2启动成功"
    elif pm2 restart all 2>/dev/null; then
        echo "  ✅ PM2重启所有服务成功"
    else
        echo "  ❌ PM2启动失败"
    fi
fi

# 5. 等待服务启动
echo "5. 等待服务启动..."
for i in {1..30}; do
    if check_port 5004; then
        echo "  ✅ 端口5004已启动"
        break
    fi
    echo "  ⏳ 等待服务启动... ($i/30)"
    sleep 2
done

# 6. 验证服务健康状态
echo "6. 验证服务健康状态..."
sleep 5

for i in {1..10}; do
    HEALTH_RESPONSE=$(curl -s http://localhost:5004/health 2>/dev/null)
    if echo "$HEALTH_RESPONSE" | grep -q '"status":"healthy"'; then
        echo "  ✅ SSO API服务健康检查通过"
        echo "  响应: $HEALTH_RESPONSE"
        break
    elif echo "$HEALTH_RESPONSE" | grep -q "Error.*connecting to.*Redis"; then
        echo "  ❌ SSO API无法连接Redis (尝试 $i/10)"
        if [ $i -eq 10 ]; then
            echo "  响应: $HEALTH_RESPONSE"
        fi
    else
        echo "  ⏳ 等待服务完全启动... ($i/10)"
        if [ $i -eq 10 ]; then
            echo "  响应: $HEALTH_RESPONSE"
        fi
    fi
    sleep 3
done

# 7. 最终状态检查
echo "7. 最终状态检查..."
echo "  端口状态:"
for port in 5001 5002 5003 5004; do
    if check_port $port; then
        echo "    端口 $port: ✅ 可访问"
    else
        echo "    端口 $port: ❌ 无法访问"
    fi
done

echo "=================================="
echo "🔄 SJ服务器SSO API服务重启完成"
echo ""
echo "📋 服务状态总结:"
echo "- 端口5004状态: $(check_port 5004 && echo '✅ 运行中' || echo '❌ 未运行')"
echo "- Redis连接: $(redis-cli ping 2>/dev/null || echo 'FAILED')"
echo "- 健康检查: $(curl -s http://localhost:5004/health >/dev/null && echo '✅ 正常' || echo '❌ 异常')"
echo ""
echo "如果服务仍有问题，请运行:"
echo "- 诊断: bash scripts/sj-redis-diagnose.sh"
echo "- 修复: bash scripts/sj-fix-redis.sh" 