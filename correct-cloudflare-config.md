# 正确的 Cloudflare 配置 (最终版本)

## 🚨 重要说明

**此文档是最终正确版本，请忽略其他可能冲突的配置文档！**

## 🎯 配置目标

- `baidaohui.com` → 重定向到 `www.baidaohui.com`
- `www.baidaohui.com` → 主站登录页面
- `fan.baidaohui.com` → Fan 角色页面
- `member.baidaohui.com` → Member 角色页面
- `master.baidaohui.com` → Master 角色页面
- `firstmate.baidaohui.com` → Firstmate 角色页面
- `seller.baidaohui.com` → Seller 角色页面

## 📋 完整配置步骤

### 步骤1: DNS 记录配置

在 Cloudflare DNS 管理中添加：

```
类型: A
名称: @
目标: 192.0.2.1
代理: 已代理 (橙色云朵)

类型: CNAME
名称: www
目标: your-pages-project.pages.dev
代理: 已代理 (橙色云朵)

类型: CNAME
名称: fan
目标: your-pages-project.pages.dev
代理: 已代理 (橙色云朵)

类型: CNAME
名称: member
目标: your-pages-project.pages.dev
代理: 已代理 (橙色云朵)

类型: CNAME
名称: master
目标: your-pages-project.pages.dev
代理: 已代理 (橙色云朵)

类型: CNAME
名称: firstmate
目标: your-pages-project.pages.dev
代理: 已代理 (橙色云朵)

类型: CNAME
名称: seller
目标: your-pages-project.pages.dev
代理: 已代理 (橙色云朵)
```

### 步骤2: 重定向规则

在 Cloudflare Dashboard > Rules > Redirect Rules 中创建：

```
规则名称: 主域名重定向
条件: (http.host eq "baidaohui.com")
动作: Static redirect
目标URL: https://www.baidaohui.com
状态码: 301
保留路径: 是
保留查询字符串: 是
```

### 步骤3: Pages 自定义域名

在 Cloudflare Pages 项目中**只添加**：

- ✅ `www.baidaohui.com`
- ✅ `fan.baidaohui.com`
- ✅ `member.baidaohui.com`
- ✅ `master.baidaohui.com`
- ✅ `firstmate.baidaohui.com`
- ✅ `seller.baidaohui.com`

**❌ 不要添加**: `baidaohui.com` (会造成重定向循环)

### 步骤4: 环境变量配置

在 Pages 项目设置中添加：

```
VITE_SUPABASE_URL=https://your-project.supabase.co
VITE_SUPABASE_ANON_KEY=your-supabase-anon-key
```

## 🔍 验证配置

### 测试命令

```bash
# 测试主域名重定向
curl -I http://baidaohui.com
# 期望: 301 Moved Permanently, Location: https://www.baidaohui.com

# 测试www主站
curl -I https://www.baidaohui.com
# 期望: 200 OK

# 测试子域名
curl -I https://fan.baidaohui.com
# 期望: 200 OK
```

### 浏览器测试

1. 访问 `http://baidaohui.com` → 应该重定向到 `https://www.baidaohui.com`
2. 访问 `https://www.baidaohui.com` → 应该显示登录页面
3. 访问 `https://fan.baidaohui.com` → 应该重定向到登录页面或显示Fan界面

## 🚨 常见错误及解决

### 错误1: "redirected you too many times"
**原因**: 在 Pages 中添加了 `baidaohui.com`
**解决**: 从 Pages 自定义域名中删除 `baidaohui.com`

### 错误2: "DNS_PROBE_FINISHED_NXDOMAIN"
**原因**: DNS记录未配置或传播未完成
**解决**: 检查DNS记录，等待传播完成

### 错误3: "This site can't be reached"
**原因**: Pages项目未部署或域名配置错误
**解决**: 确保Pages项目已部署，域名配置正确

## 📋 配置检查清单

- [ ] DNS A记录: `@` → `192.0.2.1`
- [ ] DNS CNAME记录: `www` → `your-pages-project.pages.dev`
- [ ] DNS CNAME记录: 所有子域名 → `your-pages-project.pages.dev`
- [ ] 重定向规则: `baidaohui.com` → `www.baidaohui.com`
- [ ] Pages自定义域名: 只包含 `www` 和子域名
- [ ] Pages环境变量: Supabase配置已添加
- [ ] Pages项目: 已成功部署

## 🎯 最终结果

配置完成后：
- 用户访问任何形式的域名都能正常工作
- 没有重定向循环
- 所有子域名都指向正确的角色页面
- 后端服务不可用时显示友好提示

**这是唯一正确的配置方案！** 