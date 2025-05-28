const { writeFileSync } = require('fs');
const { join } = require('path');

const redirectsPath = join(__dirname, '.svelte-kit/cloudflare/_redirects');

// 根据Cloudflare Pages文档，我们需要使用正确的重定向语法
// 状态码200用于代理，但不能用于静态资源路径
// 我们应该让SvelteKit的适配器处理路由，而不是手动重定向
const correctRedirects = `# Cloudflare Pages 重定向规则
# SvelteKit SPA 模式 - 所有路由都指向 index.html
/* /index.html 200
`;

try {
  writeFileSync(redirectsPath, correctRedirects);
  console.log('✅ 重定向文件已修复，使用正确的SPA模式');
} catch (error) {
  console.error('❌ 修复重定向文件失败:', error);
  process.exit(1);
} 