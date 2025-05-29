// svelte.config.js
import adapter from '@sveltejs/adapter-cloudflare';
import sveltePreprocess from 'svelte-preprocess';

/** @type {import('@sveltejs/kit').Config} */
const config = {
  preprocess: sveltePreprocess(),
  kit: {
    adapter: adapter({
      // 指定Cloudflare Pages输出目录
      platformProxy: {
        persist: false
      }
    }),
    alias: {
      $lib: 'src/lib'
    },
    paths: {
      base: '' // 确保根路径正确
    },
    outDir: 'build'
  }
};

export default config;