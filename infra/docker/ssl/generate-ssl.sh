#!/bin/bash

# 创建SSL证书目录
mkdir -p /tmp/ssl

# 生成私钥
openssl genrsa -out /tmp/ssl/baidaohui.key 2048

# 生成证书签名请求配置文件
cat > /tmp/ssl/cert.conf <<EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = v3_req

[dn]
C=CN
ST=Beijing
L=Beijing
O=Baidaohui
OU=IT Department
CN=*.baidaohui.com

[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = *.baidaohui.com
DNS.2 = baidaohui.com
DNS.3 = chat.baidaohui.com
DNS.4 = api.baidaohui.com
DNS.5 = buyer.shop.baidaohui.com
DNS.6 = fortune.baidaohui.com
EOF

# 生成证书签名请求
openssl req -new -key /tmp/ssl/baidaohui.key -out /tmp/ssl/baidaohui.csr -config /tmp/ssl/cert.conf

# 生成自签名证书
openssl x509 -req -in /tmp/ssl/baidaohui.csr -signkey /tmp/ssl/baidaohui.key -out /tmp/ssl/baidaohui.crt -days 365 -extensions v3_req -extfile /tmp/ssl/cert.conf

# 复制证书到当前目录
cp /tmp/ssl/baidaohui.crt ./baidaohui.crt
cp /tmp/ssl/baidaohui.key ./baidaohui.key

# 清理临时文件
rm -rf /tmp/ssl

echo "SSL证书已生成："
echo "证书文件: ./baidaohui.crt"
echo "私钥文件: ./baidaohui.key" 