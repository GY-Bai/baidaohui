const { writeFileSync } = require('fs');
const { join } = require('path');

const redirectsPath = join(__dirname, '.svelte-kit/cloudflare/_redirects');

const correctRedirects = `# Cloudflare Pages 重定向规则

# API 路由不需要重定向
/api/* 200

# 静态资源不需要重定向  
/_app/* 200
/favicon.png 200
/robots.txt 200
/sitemap.xml 200

# 404 页面
/404.html 200

# 其他所有路由使用 SPA 模式（但不包括已存在的文件）
/* /index.html 200!
`;

try {
  writeFileSync(redirectsPath, correctRedirects);
  console.log('✅ 重定向文件已修复，避免无限循环');
} catch (error) {
  console.error('❌ 修复重定向文件失败:', error);
  process.exit(1);
} 