// svelte.config.js - 修复Cloudflare Pages配置
import adapter from '@sveltejs/adapter-cloudflare';

/** @type {import('@sveltejs/kit').Config} */
const config = {
  kit: {
    adapter: adapter({
      // 使用默认配置，输出到 .svelte-kit/cloudflare 目录
      routes: {
        include: ['/*'],
        exclude: ['<all>']
      }
    }),
    alias: {
      '$components': 'src/components',
      '$lib': 'src/lib'
    },
    // 修复预渲染问题
    prerender: {
      handleHttpError: 'warn',
      handleMissingId: 'warn'
    }
  }
};

export default config;