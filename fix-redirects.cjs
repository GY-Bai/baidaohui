const { unlinkSync, existsSync } = require('fs');
const { join } = require('path');

const redirectsPath = join(__dirname, '.svelte-kit/cloudflare/_redirects');

// 删除_redirects文件，让SvelteKit的Worker处理所有路由
// 这避免了与_routes.json的冲突，因为Worker已经包含了SPA路由逻辑
try {
  if (existsSync(redirectsPath)) {
    unlinkSync(redirectsPath);
    console.log('✅ 已删除_redirects文件，让SvelteKit Worker处理所有路由');
  } else {
    console.log('✅ _redirects文件不存在，无需删除');
  }
} catch (error) {
  console.error('❌ 删除重定向文件失败:', error);
  process.exit(1);
} 