# 百刀会 Nginx API 代理
FROM nginx:1.27-alpine

# 设置工作目录
WORKDIR /etc/nginx

# 安装curl（健康检查需要）
RUN apk add --no-cache curl

# 创建SSL目录
RUN mkdir -p /etc/ssl

# 复制自定义配置为默认配置
COPY api-with-ssl-simple.conf /etc/nginx/conf.d/default.conf

# 复制Cloudflare Origin CA证书文件
COPY certs/origin.pem /etc/ssl/origin.pem
COPY certs/origin-key.pem /etc/ssl/origin-key.pem

# 设置证书文件权限
RUN chmod 644 /etc/ssl/origin.pem && chmod 600 /etc/ssl/origin-key.pem

# 创建日志目录
RUN mkdir -p /var/log/nginx

# 设置权限
RUN chown -R nginx:nginx /var/log/nginx

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost/health || exit 1

# 暴露端口
EXPOSE 80 443

# 启动命令
CMD ["nginx", "-g", "daemon off;"] 