// svelte.config.js - 超级简化配置，确保CI稳定性
import adapter from '@sveltejs/adapter-cloudflare';

/** @type {import('@sveltejs/kit').Config} */
const config = {
  kit: {
    adapter: adapter(),
    alias: {
      '$components': 'src/components',
      '$lib': 'src/lib'
    }
  }
};

export default config;