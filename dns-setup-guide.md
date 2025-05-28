# DNS配置指南 (修正版)

## 🎯 当前状况

- ✅ 域名 `baidaohui.com` 已在 Cloudflare 注册
- ✅ DNS服务器已指向 Cloudflare
- ❌ DNS记录尚未配置 (导致 DNS_PROBE_FINISHED_NXDOMAIN 错误)

## 🔧 正确的配置方案

### 方案选择

**推荐方案**: 使用 `www.baidaohui.com` 作为主域名

### 1. DNS 记录配置

在 Cloudflare DNS 管理页面添加以下记录：

#### 主域名记录 (用于重定向)
```
类型: A
名称: @ (或 baidaohui.com)
目标: 192.0.2.1 (占位符IP)
代理状态: 已代理 (橙色云朵)
```

#### www 主站记录
```
类型: CNAME  
名称: www
目标: your-pages-project.pages.dev
代理状态: 已代理 (橙色云朵)
```

#### 角色子域名记录
```
类型: CNAME
名称: fan
目标: your-pages-project.pages.dev
代理状态: 已代理 (橙色云朵)

类型: CNAME
名称: member  
目标: your-pages-project.pages.dev
代理状态: 已代理 (橙色云朵)

类型: CNAME
名称: master
目标: your-pages-project.pages.dev
代理状态: 已代理 (橙色云朵)

类型: CNAME
名称: firstmate
目标: your-pages-project.pages.dev
代理状态: 已代理 (橙色云朵)

类型: CNAME
名称: seller
目标: your-pages-project.pages.dev
代理状态: 已代理 (橙色云朵)
```

### 2. Cloudflare 重定向规则

在 Cloudflare Dashboard 中设置：

1. 进入 **Rules** > **Redirect Rules**
2. 创建新规则：
   - **名称**: "主域名重定向到 www"
   - **条件**: `(http.host eq "baidaohui.com")`
   - **动作**: Static redirect
   - **目标URL**: `https://www.baidaohui.com`
   - **状态码**: 301 (永久重定向)
   - **保留路径**: 是

### 3. Cloudflare Pages 自定义域名

在 Pages 项目中**只添加**以下域名：
- `www.baidaohui.com` (主域名)
- `fan.baidaohui.com`
- `member.baidaohui.com`
- `master.baidaohui.com`
- `firstmate.baidaohui.com`
- `seller.baidaohui.com`

**⚠️ 重要**: 不要在 Pages 中添加 `baidaohui.com`，因为它会通过重定向规则跳转到 `www.baidaohui.com`

## 🚀 配置后的访问流程

```
用户访问 baidaohui.com
    ↓
Cloudflare 重定向规则触发
    ↓
301 重定向到 www.baidaohui.com
    ↓
Pages 项目处理请求
    ↓
显示登录页面
```

## 🔧 故障排除

### 如果仍然出现重定向循环：

1. **检查 Pages 自定义域名**:
   - 确保没有添加 `baidaohui.com`
   - 只有 `www.baidaohui.com` 和子域名

2. **检查重定向规则**:
   - 确保只有一条规则：`baidaohui.com` → `www.baidaohui.com`
   - 没有反向重定向规则

3. **清除缓存**:
   ```bash
   # 清除浏览器缓存
   # 或使用无痕模式测试
   ```

### 验证配置

```bash
# 测试主域名重定向
curl -I http://baidaohui.com
# 应该返回: 301 Moved Permanently
# Location: https://www.baidaohui.com

# 测试www域名
curl -I https://www.baidaohui.com
# 应该返回: 200 OK

# 测试子域名
curl -I https://fan.baidaohui.com
# 应该返回: 200 OK
```

## ⏰ DNS传播时间

- **Cloudflare DNS**: 通常 1-5 分钟
- **重定向规则**: 立即生效
- **全球传播**: 最多 24-48 小时

## 🔄 下一步

1. **立即**: 按照上述方案配置DNS记录
2. **然后**: 设置重定向规则
3. **最后**: 在 Pages 中添加正确的自定义域名

这样配置后就不会有重定向循环了！ 