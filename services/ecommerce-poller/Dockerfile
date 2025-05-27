FROM node:18-alpine

WORKDIR /app

# 复制package文件
COPY package*.json ./

# 安装依赖
RUN npm ci --only=production

# 复制TypeScript配置
COPY tsconfig.json ./

# 复制源代码
COPY . .

# 构建TypeScript
RUN npm run build

# 暴露端口
EXPOSE 5004

# 启动应用
CMD ["npm", "start"] 