# 部署状态说明

> ⚠️ **架构说明**: 项目采用前后端分离架构。详细说明请查看 `architecture-clarification.md`

## 🚀 当前部署情况

### ✅ 前端部署状态
- **Cloudflare Pages**: 已配置并可正常部署
- **域名配置**: 需要在Cloudflare中添加自定义域名
- **构建配置**: 已修复，无需环境变量即可构建
- **环境变量**: 需要配置 Supabase 认证相关变量

### ⏳ 后端部署状态
- **状态**: 尚未部署 (微服务架构)
- **影响**: 用户访问网站会看到"后端服务不可用"的提示
- **功能**: 登录按钮被禁用，显示"服务部署中，请稍后再试"

## 🔍 当前用户体验

### 访问 baidaohui.com
1. **正常流程**: 重定向到 `/login` 页面
2. **显示内容**: 
   - 星空背景的登录界面
   - "后端服务暂时不可用" 警告
   - 禁用的登录按钮
   - "服务部署中，请稍后再试" 提示

### 访问子域名 (如 fan.baidaohui.com)
1. **正常流程**: 重定向到对应角色页面 (如 `/fan`)
2. **实际结果**: 由于后端服务不可用，可能显示错误页面

## 📋 部署清单

### 1. 前端部署 (立即可做)

#### 环境变量配置
```bash
# 在 Cloudflare Pages 中配置
VITE_SUPABASE_URL=https://your-project.supabase.co
VITE_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIs...
```

#### 自定义域名配置
需要在 Cloudflare Pages 中添加：
- `baidaohui.com` (主域名)
- `www.baidaohui.com`
- `fan.baidaohui.com`
- `member.baidaohui.com`
- `master.baidaohui.com`
- `firstmate.baidaohui.com`
- `seller.baidaohui.com`

### 2. 后端部署 (需要VPS服务器)

#### 需要部署的微服务
```
services/auth-service/          # 认证服务
services/sso-service/           # SSO服务
services/chat-service/          # 聊天服务
services/fortune-service/       # 算命服务
services/ecommerce-api-service/ # 电商API
services/payment-service/       # 支付服务
services/invite-service/        # 邀请服务
services/key-service/           # 密钥管理
```

#### 后端环境变量配置
```bash
# Supabase配置 (后端也需要)
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_KEY=eyJhbGciOiJIUzI1NiIs...  # 服务端密钥
SUPABASE_JWT_SECRET=your-jwt-secret

# 数据库配置
MONGODB_URI=mongodb://localhost:27017/baidaohui
REDIS_URL=redis://localhost:6379

# 服务配置
JWT_SECRET=your-jwt-secret
DOMAIN=baidaohui.com
FRONTEND_URL=https://baidaohui.com

# 支付配置
STRIPE_SECRET_KEY=sk_...
STRIPE_WEBHOOK_SECRET=whsec_...

# 邮件配置
SMTP_HOST=smtp.gmail.com
SMTP_USER=your-email@gmail.com
SMTP_PASS=your-app-password
```

## 🎯 部署后的预期效果

### 仅前端部署完成
- ✅ 用户可以访问网站
- ✅ 看到专业的登录界面
- ✅ 了解服务状态
- ❌ 无法使用业务功能

### 前后端都部署完成
1. **登录功能**: Google OAuth登录正常工作
2. **角色重定向**: 根据用户角色自动重定向到对应子域名
3. **会话管理**: 用户状态持久化
4. **API功能**: 所有业务功能正常运行

### 域名访问流程
```
用户访问 baidaohui.com
    ↓
检查登录状态 (Supabase + 后端API)
    ↓
未登录 → 显示登录页面
已登录 → 重定向到角色子域名
    ↓
fan.baidaohui.com (粉丝)
member.baidaohui.com (会员)
master.baidaohui.com (大师)
firstmate.baidaohui.com (大副)
seller.baidaohui.com (卖家)
```

## 🛠️ 推荐的部署顺序

### 阶段1: 前端部署 (立即可做)
```bash
# 1. 配置 Cloudflare Pages 环境变量
VITE_SUPABASE_URL=your_supabase_url
VITE_SUPABASE_ANON_KEY=your_supabase_anon_key

# 2. 提交当前修复
git add .
git commit -m "修复后端服务不可用时的用户体验"
git push origin main

# 3. 配置自定义域名
# 在 Cloudflare Pages 中添加所有域名
# 配置 DNS CNAME 记录
```

### 阶段2: 后端部署 (需要VPS)
```bash
# 1. 准备VPS服务器
# 安装 Docker 和 Docker Compose

# 2. 配置环境变量
cp infra/env.example infra/.env
# 编辑 .env 文件，填入真实配置

# 3. 部署微服务
docker-compose -f infra/docker-compose.san-jose.yml up -d

# 4. 测试完整流程
# 验证登录功能、角色重定向、API端点
```

## 💡 当前状态总结

### ✅ 已完成
- 前端代码完整，支持降级运行
- 构建配置修复，可正常部署
- A11y问题修复，符合可访问性标准
- 用户体验优化，提供友好的状态提示

### ⏳ 待完成
- 前端环境变量配置 (Supabase)
- 自定义域名配置
- 后端微服务部署
- 完整功能测试

### 🎯 优先级
1. **高优先级**: 配置前端环境变量并部署
2. **中优先级**: 配置自定义域名
3. **低优先级**: 部署后端微服务 (需要VPS资源)

这样的分阶段部署策略让您可以先让用户看到网站，然后逐步完善功能！ 