# 百刀会登录门户部署指导

## 项目结构
```
auth-portal/
├── index.html          # 主登录页面
├── login.js           # 登录逻辑
├── set-profile.html   # 昵称设置页面
├── profile.js         # 昵称设置逻辑
├── .env              # 环境变量配置
├── package.json      # 项目配置
├── wrangler.toml     # Cloudflare Pages 配置
└── README.md         # 本文档
```

## 环境配置

### 1. 创建 `.env` 文件
```env
SUPABASE_URL=your_supabase_project_url
SUPABASE_ANON_KEY=your_supabase_anon_key
```

### 2. 更新 JavaScript 文件中的环境变量
在 `login.js` 和 `profile.js` 中，将以下行替换为实际值：
```javascript
const SUPABASE_URL = 'https://your-project.supabase.co';
const SUPABASE_ANON_KEY = 'your-anon-key-here';
```

## Supabase 设置

### 1. 启用 Google OAuth
在 Supabase Dashboard:
1. 进入 Authentication > Settings > Auth Providers
2. 启用 Google 提供商
3. 配置 Google OAuth 客户端 ID 和密钥
4. 添加重定向 URL: `https://your-domain.com`

### 2. 创建 RPC 函数
在 Supabase SQL Editor 中执行：
```sql
CREATE OR REPLACE FUNCTION get_role(uid uuid)
RETURNS text
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT 
    CASE 
      WHEN EXISTS (SELECT 1 FROM user_roles WHERE user_id = uid AND role = 'anchor') THEN 'anchor'
      WHEN EXISTS (SELECT 1 FROM user_roles WHERE user_id = uid AND role = 'firstmate') THEN 'firstmate'
      WHEN EXISTS (SELECT 1 FROM user_roles WHERE user_id = uid AND role = 'member') THEN 'member'
      ELSE 'fan'
    END;
$$;
```

### 3. 用户角色表（可选）
如果使用数据库存储角色：
```sql
CREATE TABLE user_roles (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  role text NOT NULL CHECK (role IN ('fan', 'member', 'anchor', 'firstmate')),
  created_at timestamp with time zone DEFAULT now(),
  UNIQUE(user_id, role)
);

-- 启用 RLS
ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;

-- 创建策略
CREATE POLICY "Users can read own roles" ON user_roles
  FOR SELECT USING (auth.uid() = user_id);
```

## 本地开发

### 1. 安装依赖
```bash
npm install -g @cloudflare/wrangler
npm init -y
```

### 2. 创建 `package.json`
```json
{
  "name": "auth-portal",
  "version": "1.0.0",
  "scripts": {
    "preview": "python3 -m http.server 8000",
    "dev": "python3 -m http.server 8000"
  },
  "devDependencies": {
    "@cloudflare/wrangler": "^3.0.0"
  }
}
```

### 3. 本地预览
```bash
npm run preview
# 访问 http://localhost:8000
```

## Cloudflare Pages 部署

### 1. 创建 `wrangler.toml`
```toml
name = "auth-portal"
compatibility_date = "2024-01-01"

[env.production]
vars = { }

[[env.production.kv_namespaces]]
binding = "AUTH_CACHE"
id = "your-kv-namespace-id"
preview_id = "your-preview-kv-namespace-id"
```

### 2. 部署命令
```bash
# 首次部署
wrangler pages deploy . --project-name=auth-portal

# 后续更新
wrangler pages deploy .
```

### 3. 环境变量设置
在 Cloudflare Dashboard 的 Pages 项目中设置：
- `SUPABASE_URL`: 你的 Supabase 项目 URL
- `SUPABASE_ANON_KEY`: 你的 Supabase 匿名密钥

## 域名配置

### 1. 自定义域名
在 Cloudflare Pages 项目设置中添加自定义域名。

### 2. 更新 Supabase 重定向 URL
在 Supabase Authentication 设置中更新：
- Site URL: `https://your-domain.com`
- Redirect URLs: `https://your-domain.com`

## 测试清单

### 功能测试
- [ ] Google 登录按钮正常显示
- [ ] 点击登录按钮触发 Google OAuth
- [ ] 登录成功后正确检测用户角色
- [ ] 根据角色正确重定向到对应域名
- [ ] 未设置昵称时跳转到设置页面
- [ ] 昵称设置功能正常工作
- [ ] 错误处理和用户反馈正常

### 兼容性测试
- [ ] 桌面端 Chrome/Firefox/Safari 正常
- [ ] 移动端 iOS Safari 正常
- [ ] 移动端 Android Chrome 正常
- [ ] 响应式布局在各屏幕尺寸下正常

### 性能测试
- [ ] 页面加载速度 < 2秒
- [ ] 登录流程响应时间 < 3秒
- [ ] 重定向时间 < 1秒

## 故障排除

### 常见问题

1. **Google 登录失败**
   - 检查 Google OAuth 配置
   - 确认重定向 URL 正确
   - 检查域名是否在 Google Console 中授权

2. **角色检测失败**
   - 确认 RPC 函数已创建
   - 检查用户权限设置
   - 查看浏览器控制台错误信息

3. **重定向失败**
   - 确认目标域名可访问
   - 检查角色映射配置
   - 验证网络连接

4. **昵称设置失败**
   - 检查 Supabase 用户更新权限
   - 验证昵称验证规则
   - 查看网络请求状态

### 调试方法
1. 打开浏览器开发者工具
2. 查看 Console 标签页的错误信息
3. 查看 Network 标签页的请求状态
4. 检查 Supabase Dashboard 的日志

## 安全注意事项

1. **环境变量保护**
   - 不要将 `.env` 文件提交到版本控制
   - 使用 Cloudflare Pages 环境变量功能

2. **域名验证**
   - 确保重定向 URL 在白名单中
   - 验证目标域名的有效性

3. **用户数据保护**
   - 遵循 GDPR 和相关隐私法规
   - 最小化收集的用户信息

## 监控和维护

### 监控指标
- 登录成功率
- 页面加载时间
- 错误发生率
- 用户重定向分布

### 定期维护
- 更新依赖包版本
- 检查 SSL 证书状态
- 监控 API 使用量
- 备份配置文件

## 支持

如遇到问题，请检查：
1. [Supabase 文档](https://supabase.com/docs)
2. [Cloudflare Pages 文档](https://developers.cloudflare.com/pages/)
3. 项目 GitHub Issues

---

**版本**: 1.0.0  
**最后更新**: 2024年12月  
**维护者**: 开发团队