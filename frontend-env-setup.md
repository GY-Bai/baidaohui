# 前端环境变量配置指南

> ⚠️ **重要说明**: 这是**前端部分**的环境变量配置。项目还有后端微服务需要单独配置。
> 详细架构说明请查看 `architecture-clarification.md`

## 🎯 Cloudflare Pages 环境变量配置

### 必需的环境变量
在 Cloudflare Pages 项目设置中，需要配置以下环境变量：

```bash
# Supabase 配置 (必需) - 前端认证使用
VITE_SUPABASE_URL=https://your-project.supabase.co
VITE_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.your-anon-key
```

### 可选的环境变量
```bash
# 应用配置 (可选)
VITE_APP_URL=https://baidaohui.com
VITE_API_BASE_URL=https://api.baidaohui.com

# 开发环境配置 (可选)
VITE_DEBUG=false
```

## 🏗️ 架构说明

### 前端独立运行
配置了上述环境变量后，前端可以独立运行：
- ✅ 显示登录界面
- ✅ 处理 Supabase 用户认证
- ✅ 显示后端服务状态
- ✅ 提供降级用户体验

### 完整功能需要后端
以下功能需要后端微服务支持：
- 聊天功能
- 算命申请处理
- 电商数据同步
- 邀请链接生成
- 支付处理

## 🔧 配置步骤

### 1. 获取 Supabase 配置
1. 登录 [Supabase Dashboard](https://supabase.com/dashboard)
2. 选择您的项目
3. 进入 Settings → API
4. 复制以下信息：
   - **Project URL** → `VITE_SUPABASE_URL`
   - **anon public** key → `VITE_SUPABASE_ANON_KEY`

### 2. 在 Cloudflare Pages 中配置
1. 登录 Cloudflare Dashboard
2. 进入 Pages 项目
3. 点击 Settings → Environment variables
4. 添加环境变量：
   - 变量名：`VITE_SUPABASE_URL`
   - 值：您的 Supabase Project URL
   - 变量名：`VITE_SUPABASE_ANON_KEY`
   - 值：您的 Supabase anon key

### 3. 重新部署
配置完环境变量后，触发重新部署：
- 推送代码到 GitHub，或
- 在 Cloudflare Pages 中手动触发部署

## 📝 重要说明

### ✅ 前端环境变量 (本文档涵盖)
- `VITE_SUPABASE_URL` - Supabase 项目 URL
- `VITE_SUPABASE_ANON_KEY` - Supabase 匿名密钥

### ❌ 后端环境变量 (需要单独配置)
`infra/env.example` 文件中的变量是为后端微服务设计的：
- `MONGODB_URI` - MongoDB 连接字符串
- `JWT_SECRET` - JWT 密钥
- `AUTH_SERVICE_PORT` - 后端服务端口
- `SUPABASE_SERVICE_KEY` - Supabase 服务端密钥
- 等等...

### 🔒 安全注意事项
- `VITE_` 前缀的变量会暴露给客户端，只放置公开信息
- 不要在前端环境变量中放置敏感密钥
- Supabase anon key 是安全的，设计为客户端使用

## 🚀 部署后验证

部署完成后，检查环境变量是否生效：
1. 打开浏览器开发者工具
2. 在 Console 中输入：
   ```javascript
   console.log(import.meta.env.VITE_SUPABASE_URL);
   ```
3. 应该显示您配置的 Supabase URL

## 🔄 与后端的关系

- **前端** (Cloudflare Pages)：使用 Supabase 进行用户认证
- **后端** (微服务)：使用 MongoDB 和其他服务进行业务逻辑
- **连接方式**：前端通过 Supabase JWT 与后端 API 通信

当后端服务部署完成后，前端会自动连接到后端 API，无需额外配置。

## 📋 下一步

1. **立即可做**: 配置前端环境变量并部署
2. **后续步骤**: 参考 `architecture-clarification.md` 了解完整架构
3. **后端部署**: 根据 `infra/env.example` 配置后端微服务 