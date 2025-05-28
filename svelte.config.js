import adapter from '@sveltejs/adapter-cloudflare';

/** @type {import('@sveltejs/kit').Config} */
const config = {
	kit: {
		adapter: adapter({
			// Cloudflare Pages 配置
			routes: {
				include: ['/*'],
				exclude: ['/api/*', '/_app/*', '/favicon.png', '/robots.txt', '/sitemap.xml']
			}
		})
	}
};

export default config; 