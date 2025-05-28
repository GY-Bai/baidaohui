import adapter from '@sveltejs/adapter-cloudflare';

/** @type {import('@sveltejs/kit').Config} */
const config = {
	kit: {
		adapter: adapter({
			// Cloudflare Pages 配置
			routes: {
				include: ['/*'],
				exclude: ['/api/*', '/_app/*', '/favicon.png', '/robots.txt', '/sitemap.xml']
			},
			// 禁用默认的重定向规则，避免无限循环
			platformProxy: {
				persist: false
			}
		})
	}
};

export default config; 