#!/bin/bash

# Auth Service V2 启动脚本
echo "🚀 启动 Auth Service V2..."

# 检查Python环境
if ! command -v python3 &> /dev/null; then
    echo "❌ 错误: 未找到 Python 3"
    exit 1
fi

# 检查虚拟环境
if [ ! -d "venv" ]; then
    echo "📦 创建虚拟环境..."
    python3 -m venv venv
fi

# 激活虚拟环境
echo "🔧 激活虚拟环境..."
source venv/bin/activate

# 安装依赖
echo "📥 安装依赖..."
pip install -r requirements_v2.txt

# 检查环境变量
echo "🔍 检查环境变量..."
required_vars=("SUPABASE_URL" "SUPABASE_SERVICE_KEY")
missing_vars=()

for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        missing_vars+=("$var")
    fi
done

if [ ${#missing_vars[@]} -ne 0 ]; then
    echo "❌ 错误: 缺少必要的环境变量:"
    printf '%s\n' "${missing_vars[@]}"
    echo ""
    echo "请设置以下环境变量:"
    echo "export SUPABASE_URL='https://your-project.supabase.co'"
    echo "export SUPABASE_SERVICE_KEY='your-service-role-key'"
    echo "export SUPABASE_JWT_SECRET='your-supabase-jwt-secret'"
    echo "export JWT_SECRET='your-jwt-secret'"
    exit 1
fi

# 显示配置信息
echo "✅ 环境变量检查通过"
echo "📊 配置信息:"
echo "  - Supabase URL: $SUPABASE_URL"
echo "  - JWT Secret: $(echo $JWT_SECRET | cut -c1-8)..."
echo "  - Domain: ${DOMAIN:-baidaohui.com}"
echo "  - Port: ${PORT:-5001}"
echo "  - Sync Interval: ${USER_SYNC_INTERVAL:-300}秒"

# 启动服务
echo ""
echo "🔥 启动 Auth Service V2..."
python app_v2.py 