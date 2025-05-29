# 百刀会 Nginx API 代理
FROM nginx:1.27-alpine

# 设置工作目录
WORKDIR /etc/nginx

# 复制自定义配置
COPY api.conf /etc/nginx/conf.d/api.conf

# 删除默认配置
RUN rm -f /etc/nginx/conf.d/default.conf

# 创建日志目录
RUN mkdir -p /var/log/nginx

# 设置权限
RUN chown -R nginx:nginx /var/log/nginx

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost/api/health || exit 1

# 暴露端口
EXPOSE 80

# 启动命令
CMD ["nginx", "-g", "daemon off;"] 