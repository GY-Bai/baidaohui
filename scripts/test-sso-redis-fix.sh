#!/bin/bash

# SJ服务器SSO API Redis修复验证脚本

echo "🔍 验证SSO API Redis配置修复..."

# 检查修复后的代码
if grep -q "redis.from_url" apps/api/sso/supabase_presta.py; then
    echo "✅ Redis配置已修复：使用环境变量"
else
    echo "❌ Redis配置未修复：仍使用硬编码"
fi

# 检查环境变量支持
if grep -q "import os" apps/api/sso/supabase_presta.py; then
    echo "✅ 已导入os模块：支持环境变量"
else
    echo "❌ 未导入os模块：不支持环境变量"
fi

# 检查默认端口
if grep -q "6380" apps/api/sso/supabase_presta.py; then
    echo "✅ 默认端口已改为6380"
else
    echo "❌ 默认端口仍为6379"
fi

echo ""
echo "📋 修复验证完成" 