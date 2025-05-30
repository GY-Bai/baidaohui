#!/bin/bash

# HTTP 521错误诊断脚本
# 用于诊断Cloudflare到源服务器的连接问题

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔍 HTTP 521错误诊断${NC}"
echo "=================================="
echo ""

# 1. 检查DNS解析
echo -e "${YELLOW}1. DNS解析检查${NC}"
echo -n "  api.baidaohui.com 解析结果: "
if nslookup api.baidaohui.com | grep -q "107.172.87.113"; then
    echo -e "${GREEN}✅ 正确解析到VPS IP${NC}"
else
    echo -e "${RED}❌ DNS解析异常${NC}"
    nslookup api.baidaohui.com
fi
echo ""

# 2. 直接测试VPS IP
echo -e "${YELLOW}2. 直接VPS连接测试${NC}"
VPS_IP="107.172.87.113"

echo -n "  HTTP端口80测试: "
if curl -s --connect-timeout 5 http://$VPS_IP > /dev/null 2>&1; then
    echo -e "${GREEN}✅ 可连接${NC}"
else
    echo -e "${RED}❌ 连接失败${NC}"
fi

echo -n "  HTTPS端口443测试: "
if curl -s --connect-timeout 5 -k https://$VPS_IP > /dev/null 2>&1; then
    echo -e "${GREEN}✅ 可连接${NC}"
else
    echo -e "${RED}❌ 连接失败${NC}"
fi
echo ""

# 3. 通过Cloudflare测试
echo -e "${YELLOW}3. Cloudflare代理测试${NC}"
echo -n "  通过CF访问: "
response=$(curl -s -I https://api.baidaohui.com 2>&1 || true)
if echo "$response" | grep -q "521"; then
    echo -e "${RED}❌ HTTP 521错误${NC}"
elif echo "$response" | grep -q "cf-ray"; then
    echo -e "${GREEN}✅ 通过Cloudflare正常${NC}"
else
    echo -e "${YELLOW}⚠️  响应异常${NC}"
fi

if echo "$response" | grep -q "cf-ray"; then
    cf_ray=$(echo "$response" | grep "cf-ray" | awk '{print $2}')
    echo "  CF-Ray: $cf_ray"
fi
echo ""

# 4. 端口开放检查
echo -e "${YELLOW}4. 端口开放检查${NC}"
for port in 80 443; do
    echo -n "  端口 $port: "
    if timeout 5 bash -c "</dev/tcp/$VPS_IP/$port" 2>/dev/null; then
        echo -e "${GREEN}✅ 开放${NC}"
    else
        echo -e "${RED}❌ 关闭或被阻止${NC}"
    fi
done
echo ""

# 5. SSL证书检查
echo -e "${YELLOW}5. SSL证书检查${NC}"
echo -n "  SSL证书状态: "
ssl_info=$(echo | timeout 5 openssl s_client -connect $VPS_IP:443 -servername api.baidaohui.com 2>/dev/null | grep "Verify return code")
if echo "$ssl_info" | grep -q "ok"; then
    echo -e "${GREEN}✅ 证书有效${NC}"
elif echo "$ssl_info" | grep -q "self signed"; then
    echo -e "${YELLOW}⚠️  自签名证书${NC}"
else
    echo -e "${RED}❌ 证书问题${NC}"
fi
echo ""

# 6. HTTP响应头检查
echo -e "${YELLOW}6. HTTP响应头检查${NC}"
echo "直接访问VPS的响应头:"
curl -s -I http://$VPS_IP/health 2>/dev/null | head -5 || echo "  无响应或错误"
echo ""

# 7. 建议的修复步骤
echo -e "${BLUE}📋 修复建议${NC}"
echo "=================================="
echo ""
echo "如果看到HTTP 521错误，请按以下步骤修复："
echo ""
echo -e "${YELLOW}在VPS上执行:${NC}"
echo "1. 检查nginx是否运行:"
echo "   sudo systemctl status nginx"
echo ""
echo "2. 检查防火墙设置:"
echo "   sudo ufw status"
echo "   sudo ufw allow 80/tcp"
echo "   sudo ufw allow 443/tcp"
echo ""
echo "3. 检查nginx配置:"
echo "   sudo nginx -t"
echo "   sudo tail -f /var/log/nginx/error.log"
echo ""
echo "4. 重启nginx服务:"
echo "   sudo systemctl restart nginx"
echo ""
echo -e "${YELLOW}在Cloudflare控制台:${NC}"
echo "1. SSL/TLS → Overview → 设置为 'Full' 模式"
echo "2. Caching → Configuration → 启用 'Development Mode'"
echo "3. 添加页面规则绕过API缓存"
echo ""
echo -e "${YELLOW}临时解决方案:${NC}"
echo "1. 将DNS记录设置为 'DNS only' (灰色云朵)"
echo "2. 直接测试源服务器: http://$VPS_IP"
echo ""
echo "详细配置指南请查看: docs/cloudflare-521-fix.md" 