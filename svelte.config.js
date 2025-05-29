// svelte.config.js
import adapter from '@sveltejs/adapter-cloudflare';
import sveltePreprocess from 'svelte-preprocess';

/** @type {import('@sveltejs/kit').Config} */
const config = {
  preprocess: sveltePreprocess(),
  kit: {
    adapter: adapter({
      // 指定输出目录为 build，匹配 wrangler.toml 中的配置
      output: 'build'
    }),
    alias: {
      $lib: 'src/lib'
    },
    paths: {
      base: '' // 确保根路径正确
    }
  }
};

export default config;