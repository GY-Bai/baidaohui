# 项目架构澄清文档

## 🏗️ 真实项目架构

### 混合架构说明
您的 `baidaohui` 项目采用**前后端分离 + 微服务**架构：

```
前端 (SvelteKit)          后端微服务群
     ↓                         ↓
Cloudflare Pages    ←→    VPS服务器 (Docker)
     ↓                         ↓
Supabase Auth           MongoDB + Redis
```

## 📁 项目结构分析

### 前端部分 (项目根目录)
```
src/                    # SvelteKit 前端代码
├── routes/            # 页面路由
├── components/        # 组件
├── lib/auth.ts       # Supabase 认证
package.json          # 前端依赖
svelte.config.js      # SvelteKit 配置
wrangler.toml         # Cloudflare Pages 配置
```

### 后端部分 (services/ 目录)
```
services/
├── auth-service/      # 认证服务 (Python Flask)
├── sso-service/       # SSO服务 (Python Flask)  
├── chat-service/      # 聊天服务
├── fortune-service/   # 算命服务
├── ecommerce-api-service/  # 电商API
├── payment-service/   # 支付服务
├── invite-service/    # 邀请服务
└── key-service/       # 密钥管理服务
```

### 基础设施部分
```
infra/
├── docker-compose.san-jose.yml  # 圣何塞VPS部署
├── docker-compose.buffalo.yml   # 水牛城VPS部署
├── nginx.conf                   # API网关配置
└── env.example                  # 后端环境变量模板
```

## 🔧 环境变量配置

### ✅ 前端环境变量 (Cloudflare Pages)
```bash
# 必需 - Supabase配置
VITE_SUPABASE_URL=https://your-project.supabase.co
VITE_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIs...

# 可选 - API配置
VITE_API_BASE_URL=https://api.baidaohui.com
VITE_APP_URL=https://baidaohui.com
```

### ✅ 后端环境变量 (VPS Docker)
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

## 🔄 认证流程

### 双重认证系统
1. **前端认证**: Supabase OAuth → 获取用户基本信息
2. **后端认证**: JWT Token → 访问微服务API

### 完整流程
```
用户登录 → Supabase OAuth → 前端获取session
    ↓
前端调用后端API → 后端验证Supabase JWT → 返回数据
    ↓
前端显示用户界面 ← 后端微服务处理业务逻辑
```

## 🚀 部署策略

### 当前状态
- ✅ **前端**: 可独立部署到Cloudflare Pages
- ⏳ **后端**: 需要部署到VPS服务器

### 前端独立运行
前端可以在没有后端的情况下运行：
- 显示登录界面
- 处理Supabase认证
- 显示"后端服务不可用"提示

### 完整功能需要后端
以下功能需要后端微服务：
- 聊天功能 (chat-service)
- 算命申请 (fortune-service)
- 电商数据 (ecommerce-api-service)
- 邀请链接 (invite-service)
- 支付处理 (payment-service)

## 📋 部署清单

### 1. 前端部署 (立即可做)
```bash
# 在Cloudflare Pages中配置环境变量
VITE_SUPABASE_URL=your_supabase_url
VITE_SUPABASE_ANON_KEY=your_supabase_anon_key

# 部署前端
git push origin main  # 触发自动部署
```

### 2. 后端部署 (需要VPS)
```bash
# 配置环境变量文件
cp infra/env.example infra/.env
# 编辑 .env 文件，填入真实配置

# 部署到VPS
docker-compose -f infra/docker-compose.san-jose.yml up -d
```

## 💡 当前建议

### 立即可做
1. **配置前端环境变量** - 在Cloudflare Pages中添加Supabase配置
2. **部署前端** - 用户可以看到登录界面和状态提示
3. **配置自定义域名** - 添加所有子域名到Cloudflare Pages

### 后续步骤
1. **准备VPS服务器** - 安装Docker和Docker Compose
2. **配置后端环境变量** - 根据`infra/env.example`创建`.env`文件
3. **部署后端微服务** - 使用Docker Compose部署所有服务
4. **测试完整流程** - 验证前后端集成

## 🔍 总结

您的项目确实需要**两套环境变量配置**：
- **前端配置**: 只需要Supabase的公开配置
- **后端配置**: 需要完整的微服务配置

这不是矛盾，而是**分层架构**的体现！ 