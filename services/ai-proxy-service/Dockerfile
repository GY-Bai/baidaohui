FROM node:18-alpine

# 设置工作目录
WORKDIR /app

# 设置环境变量
ENV NODE_ENV=production
ENV NPM_CONFIG_LOGLEVEL=warn

# 安装系统依赖
RUN apk add --no-cache \
    curl \
    && rm -rf /var/cache/apk/*

# 复制package文件
COPY package*.json ./

# 安装Node.js依赖
RUN npm install --only=production && npm cache clean --force

# 复制应用代码
COPY . .

# 创建日志目录
RUN mkdir -p /var/log && chown node:node /var/log

# 切换到非root用户
USER node

# 暴露端口
EXPOSE 5012

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:5012/health || exit 1

# 启动应用
CMD ["node", "app.js"] 