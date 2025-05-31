# 百刀会 Nginx API 代理
FROM nginx:1.27-alpine

# 设置工作目录
WORKDIR /etc/nginx

# 安装curl和openssl
RUN apk add --no-cache curl openssl

# 创建SSL目录
RUN mkdir -p /etc/ssl

# 复制自定义配置为默认配置
COPY api-with-ssl-simple.conf /etc/nginx/conf.d/default.conf

# 创建日志目录
RUN mkdir -p /var/log/nginx

# 设置权限
RUN chown -R nginx:nginx /var/log/nginx

# 生成自签名证书（临时解决方案）
RUN openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/origin-key.pem \
    -out /etc/ssl/origin.pem \
    -subj "/C=US/ST=CA/L=San Francisco/O=BaiDaoHui/CN=api.baidaohui.com"

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost/health || exit 1

# 暴露端口
EXPOSE 80 443

# 启动命令
CMD ["nginx", "-g", "daemon off;"] 