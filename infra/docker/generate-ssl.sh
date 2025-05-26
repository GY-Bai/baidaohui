#!/bin/bash

# 创建SSL目录
mkdir -p ssl

# 生成私钥
openssl genrsa -out ssl/key.pem 2048

# 生成证书签名请求
openssl req -new -key ssl/key.pem -out ssl/cert.csr -subj "/C=CN/ST=Beijing/L=Beijing/O=Baidaohui Inc./CN=*.baidaohui.com"

# 生成自签名证书
openssl x509 -req -in ssl/cert.csr -signkey ssl/key.pem -out ssl/cert.pem -days 365

# 清理临时文件
rm ssl/cert.csr

echo "SSL证书已生成完成！"
echo "证书文件: ssl/cert.pem"
echo "私钥文件: ssl/key.pem" 