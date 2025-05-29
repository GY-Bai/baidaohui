FROM node:18-alpine

WORKDIR /app

# 复制package文件
COPY package*.json ./

# 复制TypeScript配置
COPY tsconfig.json ./

# 安装所有依赖（包括dev依赖用于构建）
RUN npm install

# 复制源代码
COPY . .

# 构建TypeScript
RUN npm run build

# 删除开发依赖，只保留生产依赖
RUN npm prune --production && npm cache clean --force

# 暴露端口
EXPOSE 5004

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:5004/health', (res) => { process.exit(res.statusCode === 200 ? 0 : 1) })"

# 启动应用
CMD ["npm", "start"] 