import adapter from '@sveltejs/adapter-cloudflare';

/** @type {import('@sveltejs/kit').Config} */
const config = {
	kit: {
		adapter: adapter({
			// 确保静态资源正确处理
			routes: {
				include: ['/*'],
				exclude: ['<all>']
			}
		})
	}
};

export default config; 