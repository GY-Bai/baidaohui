// svelte.config.js - 极简配置，避免CI依赖问题
import adapter from '@sveltejs/adapter-cloudflare';

/** @type {import('@sveltejs/kit').Config} */
const config = {
  kit: {
    adapter: adapter({
      platformProxy: {
        persist: false
      }
    }),
    alias: {
      $lib: 'src/lib',
      $components: 'src/components'
    },
    paths: {
      base: ''
    },
    outDir: 'build'
  }
};

export default config;