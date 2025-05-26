FROM python:3.11-slim

# 安装supervisor和必要的工具
RUN apt-get update && \
    apt-get install -y supervisor && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 创建必要的目录
RUN mkdir -p /var/log/supervisor

# 复制配置文件
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# 暴露supervisor端口
EXPOSE 9001

# 启动supervisor
CMD ["supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"] 