#!/bin/bash

# SJ服务器快速修复工具
# 专门用于快速修复baidaohui-sso-api (端口5004) 的Redis连接问题

echo "⚡ SJ服务器快速修复开始..."
echo "=================================="
echo "目标: 修复端口5004 (baidaohui-sso-api) 的Redis连接问题"
echo ""

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

# 快速诊断
echo "🔍 快速诊断..."
echo "- Redis服务状态: $(systemctl is-active redis-server 2>/dev/null || echo '未知')"
echo "- Redis连接测试: $(redis-cli ping 2>/dev/null || echo 'FAILED')"
echo "- 端口5004状态: $(check_port 5004 && echo '运行中' || echo '未运行')"
echo ""

# 1. 修复Redis
echo "🔧 步骤1: 修复Redis服务..."
if ! redis-cli ping > /dev/null 2>&1; then
    echo "  Redis连接失败，正在修复..."
    
    # 启动Redis服务
    sudo systemctl start redis-server 2>/dev/null
    sudo systemctl enable redis-server 2>/dev/null
    sleep 2
    
    # 如果系统服务失败，尝试Docker
    if ! redis-cli ping > /dev/null 2>&1; then
        echo "  尝试使用Docker启动Redis..."
        if command_exists docker; then
            docker stop redis-sj 2>/dev/null || true
            docker rm redis-sj 2>/dev/null || true
            docker run -d --name redis-sj -p 6379:6379 redis:alpine
            sleep 3
        fi
    fi
    
    # 最终检查
    if redis-cli ping > /dev/null 2>&1; then
        echo "  ✅ Redis修复成功"
    else
        echo "  ❌ Redis修复失败"
    fi
else
    echo "  ✅ Redis连接正常"
fi

# 2. 重启SSO API服务
echo "🔧 步骤2: 重启SSO API服务..."

# 停止现有服务
if check_port 5004; then
    PID=$(netstat -tlnp | grep ":5004 " | awk '{print $7}' | cut -d'/' -f1)
    if [ -n "$PID" ]; then
        echo "  停止现有服务 (PID: $PID)..."
        kill -TERM "$PID" 2>/dev/null
        sleep 3
        if kill -0 "$PID" 2>/dev/null; then
            kill -KILL "$PID" 2>/dev/null
        fi
    fi
fi

# 启动服务
echo "  启动SSO API服务..."
if [ -f "docker-compose.yml" ]; then
    docker-compose up -d sso-api 2>/dev/null || docker-compose up -d api 2>/dev/null
elif command_exists pm2; then
    pm2 restart sso-api 2>/dev/null || pm2 restart all 2>/dev/null
fi

# 3. 等待并验证
echo "🔧 步骤3: 验证修复结果..."
echo "  等待服务启动..."
for i in {1..15}; do
    if check_port 5004; then
        echo "  ✅ 端口5004已启动"
        break
    fi
    sleep 2
done

# 健康检查
echo "  执行健康检查..."
sleep 3
for i in {1..5}; do
    HEALTH_RESPONSE=$(curl -s http://localhost:5004/health 2>/dev/null)
    if echo "$HEALTH_RESPONSE" | grep -q '"status":"healthy"'; then
        echo "  ✅ 健康检查通过"
        break
    elif echo "$HEALTH_RESPONSE" | grep -q "Error.*connecting to.*Redis"; then
        echo "  ❌ 仍然无法连接Redis"
        if [ $i -eq 5 ]; then
            echo "  需要进一步诊断"
        fi
    else
        echo "  ⏳ 等待服务完全启动... ($i/5)"
    fi
    sleep 2
done

# 4. 最终状态报告
echo "=================================="
echo "⚡ SJ服务器快速修复完成"
echo ""
echo "📊 最终状态报告:"
echo "端口状态检查:"
for port in 5001 5002 5003 5004; do
    if check_port $port; then
        STATUS="✅ 可访问"
        if [ $port -eq 5004 ]; then
            HEALTH=$(curl -s http://localhost:$port/health 2>/dev/null)
            if echo "$HEALTH" | grep -q '"status":"healthy"'; then
                STATUS="✅ 可访问 (健康)"
            elif echo "$HEALTH" | grep -q "Error.*Redis"; then
                STATUS="⚠️  可访问 (Redis问题)"
            else
                STATUS="⚠️  可访问 (状态未知)"
            fi
        fi
    else
        STATUS="❌ 无法访问"
    fi
    echo "  端口 $port: $STATUS"
done

echo ""
echo "Redis状态: $(redis-cli ping 2>/dev/null || echo 'FAILED')"
echo ""

# 根据结果给出建议
HEALTH_5004=$(curl -s http://localhost:5004/health 2>/dev/null)
if echo "$HEALTH_5004" | grep -q '"status":"healthy"'; then
    echo "🎉 修复成功！所有服务正常运行。"
elif echo "$HEALTH_5004" | grep -q "Error.*Redis"; then
    echo "⚠️  端口5004可访问但Redis连接仍有问题。"
    echo "建议运行详细诊断: bash scripts/sj-redis-diagnose.sh"
elif check_port 5004; then
    echo "⚠️  端口5004可访问但健康检查异常。"
    echo "建议检查服务日志或运行: bash scripts/sj-restart-sso.sh"
else
    echo "❌ 端口5004仍然无法访问。"
    echo "建议运行完整修复: bash scripts/sj-fix-redis.sh"
fi

echo ""
echo "🛠️  可用的SJ服务器工具:"
echo "- 详细诊断: bash scripts/sj-redis-diagnose.sh"
echo "- 完整修复: bash scripts/sj-fix-redis.sh"
echo "- 重启服务: bash scripts/sj-restart-sso.sh"
echo "- 快速修复: bash scripts/sj-quick-fix.sh (当前脚本)" 