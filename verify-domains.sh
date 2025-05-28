#!/bin/bash

# 域名验证脚本
echo "🌐 验证百道会自定义域名配置..."

domains=(
    "www.baidaohui.com"
    "fan.baidaohui.com"
    "member.baidaohui.com"
    "master.baidaohui.com"
    "firstmate.baidaohui.com"
    "seller.baidaohui.com"
)

for domain in "${domains[@]}"; do
    echo "检查 $domain..."
    
    # 检查 DNS 解析
    echo "  DNS 解析:"
    nslookup $domain
    
    # 检查 HTTPS 响应
    echo "  HTTPS 状态:"
    curl -I -s -o /dev/null -w "    状态码: %{http_code}\n    响应时间: %{time_total}s\n" https://$domain
    
    echo "  ✅ $domain 检查完成"
    echo "---"
done

echo "🎉 所有域名检查完成！" 