// vite.config.js - 极简配置，依赖SvelteKit内置路径解析
import { sveltekit } from '@sveltejs/kit/vite';

/** @type {import('vite').UserConfig} */
export default {
  plugins: [sveltekit()]
};
