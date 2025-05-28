# Cloudflare Pages 部署指南

## 概述

本指南描述如何使用Cloudflare Pages和Functions来分担VPS服务器压力，通过边缘计算和R2存储优化性能。

## 架构优势

### 1. 边缘计算优化
- **Cloudflare Pages Functions**: 在全球边缘节点处理API请求
- **R2存储**: 低延迟的对象存储，自动CDN分发
- **智能缓存**: 多层缓存策略，减少数据库查询

### 2. 成本优化
- **免费额度**: Pages和R2都有慷慨的免费额度
- **按需付费**: 超出免费额度后按实际使用量计费
- **VPS减负**: 减少VPS的CPU和内存使用

### 3. 性能提升
- **全球分发**: 用户就近访问边缘节点
- **自动缓存**: Cloudflare自动缓存静态内容
- **压缩优化**: 自动Gzip/Brotli压缩

## 部署步骤

### 1. 创建Cloudflare Pages项目

```bash
# 安装Wrangler CLI
npm install -g wrangler

# 登录Cloudflare
wrangler login

# 创建Pages项目
wrangler pages project create baidaohui-pages
```

### 2. 配置R2存储桶

```bash
# 创建R2存储桶
wrangler r2 bucket create baidaohui-storage

# 配置CORS（如果需要）
wrangler r2 bucket cors put baidaohui-storage --file cors.json
```

### 3. 部署Pages Functions

```bash
# 部署到生产环境
wrangler pages deploy ./cloudflare/pages-functions --project-name baidaohui-pages

# 配置环境变量
wrangler pages secret put R2_BUCKET --project-name baidaohui-pages
```

### 4. 配置域名绑定

```bash
# 绑定自定义域名
wrangler pages domain add baidaohui.com --project-name baidaohui-pages
```

## Pages Functions API

### 产品API
- **路径**: `/api/products`
- **功能**: 从R2获取产品列表，支持分页和过滤
- **缓存**: 5分钟浏览器缓存 + Cloudflare边缘缓存

### 统计API
- **路径**: `/api/stats`
- **功能**: 从R2获取实时统计数据
- **缓存**: 1分钟浏览器缓存

### 汇率API
- **路径**: `/api/exchange-rates`
- **功能**: 从R2获取汇率信息
- **缓存**: 1小时浏览器缓存

## R2数据同步

### 同步服务
- **服务**: r2-sync-service (端口5011)
- **位置**: 水牛城VPS
- **功能**: 定时将MongoDB数据同步到R2

### 同步内容
1. **products.json**: 产品列表数据
2. **stats.json**: 统计和汇率数据
3. **invites.json**: 邀请链接公开信息
4. **user-stats.json**: 用户统计数据

### 同步频率
- **产品数据**: 每10分钟
- **统计数据**: 每1分钟
- **邀请链接**: 每5分钟
- **用户统计**: 每1小时

## 流量路由策略

### 1. 静态内容
```
用户请求 → Cloudflare Pages → R2存储 → 边缘缓存
```

### 2. 动态API
```
用户请求 → Cloudflare Pages Functions → R2数据 → 响应
```

### 3. 实时功能
```
用户请求 → Cloudflare → Nginx → VPS服务
```

## 监控和维护

### 1. Pages Analytics
- 访问Cloudflare Dashboard查看Pages分析
- 监控请求量、错误率、响应时间
- 查看地理分布和设备统计

### 2. R2使用情况
```bash
# 查看存储桶使用情况
wrangler r2 bucket list

# 查看对象列表
wrangler r2 object list baidaohui-storage
```

### 3. 同步状态监控
```bash
# 检查同步服务状态
curl http://216.144.233.104:5011/sync/status

# 手动触发同步
curl -X POST http://216.144.233.104:5011/sync/all
```

## 成本估算

### Cloudflare Pages (免费额度)
- **请求**: 100,000次/月
- **带宽**: 无限制
- **构建**: 500次/月

### Cloudflare R2 (免费额度)
- **存储**: 10GB
- **Class A操作**: 1,000,000次/月
- **Class B操作**: 10,000,000次/月
- **出站流量**: 10GB/月

### 预期使用量
- **日均请求**: ~10,000次 (月均300,000次)
- **存储使用**: ~100MB (产品图片和数据)
- **月度成本**: 基本在免费额度内

## 故障转移

### 1. Pages Functions故障
```nginx
# Nginx配置回退到VPS服务
location /api/products {
    try_files $uri @vps_fallback;
}

location @vps_fallback {
    proxy_pass http://static_api_service;
}
```

### 2. R2存储故障
- R2同步服务自动回退到MongoDB
- 静态API服务提供兜底数据
- 前端显示缓存数据

### 3. 监控告警
```bash
# 设置健康检查
curl -f https://baidaohui.pages.dev/api/products || alert
```

## 优化建议

### 1. 缓存策略
- 产品数据：长缓存（5-10分钟）
- 统计数据：短缓存（1分钟）
- 汇率数据：超长缓存（1小时）

### 2. 数据压缩
- 启用Gzip/Brotli压缩
- 优化JSON数据结构
- 图片使用WebP格式

### 3. 性能监控
- 设置Core Web Vitals监控
- 监控API响应时间
- 跟踪缓存命中率

## 安全考虑

### 1. API安全
- 设置适当的CORS策略
- 实施速率限制
- 验证请求来源

### 2. 数据安全
- 敏感数据不存储在R2
- 使用环境变量管理密钥
- 定期轮换访问令牌

### 3. 访问控制
- 限制R2存储桶访问权限
- 使用IAM角色管理权限
- 启用访问日志记录

## 🚀 单个 Pages 项目处理多子域名架构

### 项目概述
- **一个 Pages 项目**: `baidaohui`
- **多个子域名**: 都指向同一个项目
- **路由处理**: 通过 SvelteKit 客户端路由

### 📋 Cloudflare Pages 设置步骤

#### 1. 创建主项目
```yaml
项目名称: baidaohui
GitHub 仓库: GY-Bai/baidaohui
生产分支: main

构建设置:
  框架预设: SvelteKit
  构建命令: npm run build
  构建输出目录: .svelte-kit/output/client
  根目录: /
  
环境变量:
  NODE_VERSION: 18
  NODE_ENV: production
```

#### 2. 配置自定义域名
在 Pages 项目的 "Custom domains" 部分添加：
```
✅ baidaohui.com (主域名)
✅ www.baidaohui.com
✅ fan.baidaohui.com
✅ member.baidaohui.com
✅ master.baidaohui.com
✅ firstmate.baidaohui.com
✅ seller.baidaohui.com
```

#### 3. 设置重定向规则
在 Pages 项目的 "Redirects" 部分：
```
# 主域名重定向到 www
baidaohui.com/* → https://www.baidaohui.com/:splat (301)

# 子域名路由重定向（可选）
fan.baidaohui.com → https://www.baidaohui.com/fan (302)
member.baidaohui.com → https://www.baidaohui.com/member (302)
master.baidaohui.com → https://www.baidaohui.com/master (302)
firstmate.baidaohui.com → https://www.baidaohui.com/firstmate (302)
seller.baidaohui.com → https://www.baidaohui.com/seller (302)

# SPA 路由支持
/* → /index.html (200)
```

### 🔧 SvelteKit 路由配置

您的应用结构应该是：
```
src/routes/
├── +layout.svelte          # 主布局
├── +page.svelte            # 首页
├── fan/
│   └── +page.svelte        # Fan 页面
├── member/
│   └── +page.svelte        # Member 页面
├── master/
│   └── +page.svelte        # Master 页面
├── firstmate/
│   └── +page.svelte        # Firstmate 页面
└── seller/
    └── +page.svelte        # Seller 页面
```

### 🌐 域名解析方案

#### 方案 A: 重定向到主域名（推荐）
```
fan.baidaohui.com → www.baidaohui.com/fan
member.baidaohui.com → www.baidaohui.com/member
master.baidaohui.com → www.baidaohui.com/master
```

**优点**:
- SEO 友好
- 统一的域名管理
- 简化分析和监控

#### 方案 B: 子域名直接显示内容
```
fan.baidaohui.com → 显示 Fan 内容（URL 不变）
member.baidaohui.com → 显示 Member 内容（URL 不变）
```

**实现方式**: 在 SvelteKit 中检测 hostname 并路由到对应组件

### 📊 推荐的最终配置

#### Cloudflare Pages 设置
```yaml
项目名称: baidaohui
构建命令: npm run build
输出目录: .svelte-kit/output/client

自定义域名:
  - baidaohui.com
  - www.baidaohui.com
  - fan.baidaohui.com
  - member.baidaohui.com
  - master.baidaohui.com
  - firstmate.baidaohui.com
  - seller.baidaohui.com

重定向规则:
  - baidaohui.com/* → https://www.baidaohui.com/:splat (301)
  - /* → /index.html (200)  # SPA 支持
```

### 🚀 部署流程
1. 推送代码到 GitHub `main` 分支
2. Cloudflare Pages 自动构建
3. 所有域名自动更新

### 💡 优势总结
- ✅ **简化管理**: 只需维护一个 Pages 项目
- ✅ **成本效益**: 不需要多个项目的费用
- ✅ **统一部署**: 一次部署更新所有子域名
- ✅ **共享资源**: CSS、JS 文件可以缓存复用
- ✅ **SEO 优化**: 统一的站点地图和分析 