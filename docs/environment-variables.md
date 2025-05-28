# 环境变量配置指南

## 🔧 必需的环境变量

### Supabase 配置
```bash
# Supabase项目URL - 在Supabase Dashboard的Settings > API中找到
VITE_SUPABASE_URL=https://your-project-id.supabase.co

# Supabase匿名密钥 - 在Supabase Dashboard的Settings > API中找到
VITE_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

### 应用配置
```bash
# 应用主域名
VITE_APP_URL=https://www.baidaohui.com

# API基础URL
VITE_API_BASE_URL=https://api.baidaohui.com

# 环境标识
VITE_ENVIRONMENT=production
NODE_ENV=production
```

## 🌐 Cloudflare Pages 环境变量设置

### 在 Cloudflare Dashboard 中设置：

1. 进入您的 Pages 项目
2. 点击 **Settings** > **Environment variables**
3. 添加以下变量：

#### Production 环境
```
VITE_SUPABASE_URL = https://your-project-id.supabase.co
VITE_SUPABASE_ANON_KEY = eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
VITE_APP_URL = https://www.baidaohui.com
VITE_API_BASE_URL = https://api.baidaohui.com
VITE_ENVIRONMENT = production
NODE_ENV = production
NODE_VERSION = 18
```

#### Preview 环境（可选）
```
VITE_SUPABASE_URL = https://your-staging-project.supabase.co
VITE_SUPABASE_ANON_KEY = eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
VITE_APP_URL = https://preview.baidaohui.com
VITE_API_BASE_URL = https://api-staging.baidaohui.com
VITE_ENVIRONMENT = staging
NODE_ENV = development
```

## 📋 获取 Supabase 配置步骤

### 1. 登录 Supabase Dashboard
访问 [https://supabase.com/dashboard](https://supabase.com/dashboard)

### 2. 选择您的项目
点击您的 `baidaohui` 项目

### 3. 获取 API 配置
1. 在左侧导航栏点击 **Settings**
2. 点击 **API**
3. 复制以下信息：
   - **Project URL** → `VITE_SUPABASE_URL`
   - **anon public** key → `VITE_SUPABASE_ANON_KEY`

### 4. 配置 Google OAuth

#### 在 Supabase 中：
1. 进入 **Authentication** > **Providers**
2. 启用 **Google** 提供商
3. 配置重定向URL：
   ```
   https://www.baidaohui.com/auth/callback
   https://fan.baidaohui.com/auth/callback
   https://member.baidaohui.com/auth/callback
   https://master.baidaohui.com/auth/callback
   https://firstmate.baidaohui.com/auth/callback
   https://seller.baidaohui.com/auth/callback
   ```

#### 在 Google Cloud Console 中：
1. 访问 [Google Cloud Console](https://console.cloud.google.com/)
2. 创建或选择项目
3. 启用 Google+ API
4. 创建 OAuth 2.0 客户端ID
5. 配置授权重定向URI：
   ```
   https://your-project-id.supabase.co/auth/v1/callback
   ```

## 🔒 安全注意事项

### 环境变量安全性
- ✅ `VITE_` 前缀的变量会暴露给客户端，只放公开信息
- ❌ 不要在 `VITE_` 变量中放置敏感信息（如私钥）
- ✅ 服务器端敏感配置使用无前缀的环境变量

### Supabase 安全配置
1. **启用 RLS (Row Level Security)**
2. **配置适当的数据库策略**
3. **定期轮换 API 密钥**
4. **监控 API 使用情况**

## 🧪 本地开发配置

### 创建 .env.local 文件
```bash
# 复制示例文件
cp .env.example .env.local

# 编辑配置
nano .env.local
```

### 本地开发环境变量
```bash
VITE_SUPABASE_URL=https://your-project-id.supabase.co
VITE_SUPABASE_ANON_KEY=your-anon-key
VITE_APP_URL=http://localhost:5173
VITE_API_BASE_URL=http://localhost:3000
VITE_ENVIRONMENT=development
NODE_ENV=development
```

## 🚀 部署检查清单

- [ ] Supabase 项目已创建
- [ ] Google OAuth 已配置
- [ ] Cloudflare Pages 环境变量已设置
- [ ] 重定向URL已配置
- [ ] 本地 .env.local 文件已创建
- [ ] 构建测试通过
- [ ] 登录功能测试通过

## 🔧 故障排除

### 常见错误

#### 1. "Missing Supabase environment variables"
**解决方案**: 检查 `VITE_SUPABASE_URL` 和 `VITE_SUPABASE_ANON_KEY` 是否正确设置

#### 2. Google 登录失败
**解决方案**: 
- 检查 Google OAuth 配置
- 验证重定向URL设置
- 确认 Supabase 中 Google 提供商已启用

#### 3. 构建失败
**解决方案**:
- 确认所有必需的环境变量都已设置
- 检查变量名称拼写
- 验证 NODE_VERSION 设置为 18

### 调试命令
```bash
# 检查环境变量
echo $VITE_SUPABASE_URL
echo $VITE_SUPABASE_ANON_KEY

# 本地构建测试
npm run build

# 本地预览
npm run preview
``` 