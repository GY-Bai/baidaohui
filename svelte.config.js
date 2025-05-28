import adapter from '@sveltejs/adapter-cloudflare';

/** @type {import('@sveltejs/kit').Config} */
const config = {
	kit: {
		adapter: adapter({
			// 确保输出到正确的目录
			routes: {
				include: ['/*'],
				exclude: ['/api/*']
			}
		})
	}
};

export default config; 