#!/bin/bash

# 生成自签名SSL证书脚本
# 用于本地开发和测试环境

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔐 生成SSL自签名证书${NC}"
echo "=================================="
echo ""

# 证书配置
CERT_DOMAIN="api.baidaohui.com"
CERT_DIR="infra/ssl"
CERT_KEY="$CERT_DIR/private/api.baidaohui.com.key"
CERT_CRT="$CERT_DIR/certs/api.baidaohui.com.pem"

# 创建目录
mkdir -p "$CERT_DIR/certs" "$CERT_DIR/private"

echo -e "${YELLOW}正在生成SSL证书...${NC}"
echo "域名: $CERT_DOMAIN"
echo "证书路径: $CERT_CRT"
echo "私钥路径: $CERT_KEY"
echo ""

# 生成私钥
openssl genrsa -out "$CERT_KEY" 2048

# 生成证书签名请求配置
cat > "$CERT_DIR/cert.conf" <<EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = v3_req

[dn]
C=US
ST=California
L=San Jose
O=BaiDaoHui
OU=IT Department
CN=$CERT_DOMAIN

[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = $CERT_DOMAIN
DNS.2 = *.baidaohui.com
DNS.3 = localhost
IP.1 = 127.0.0.1
IP.2 = 107.172.87.113
EOF

# 生成自签名证书
openssl req -new -x509 -key "$CERT_KEY" -out "$CERT_CRT" -days 365 -config "$CERT_DIR/cert.conf" -extensions v3_req

# 设置权限
chmod 600 "$CERT_KEY"
chmod 644 "$CERT_CRT"

echo -e "${GREEN}✅ SSL证书生成成功！${NC}"
echo ""
echo -e "${YELLOW}证书信息:${NC}"
openssl x509 -in "$CERT_CRT" -text -noout | grep -E "(Subject:|DNS:|IP Address:)"
echo ""
echo -e "${YELLOW}下一步:${NC}"
echo "1. 部署服务时，nginx将自动使用这些证书"
echo "2. 在浏览器中访问时，需要接受自签名证书警告"
echo "3. 生产环境建议使用Let's Encrypt或购买正式证书"
echo ""
echo -e "${BLUE}测试命令:${NC}"
echo "curl -k https://api.baidaohui.com/health"
echo "curl -k https://107.172.87.113/health" 