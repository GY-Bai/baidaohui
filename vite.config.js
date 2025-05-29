// vite.config.js - 简化版本，避免CI环境问题
import { sveltekit } from '@sveltejs/kit/vite';
import path from 'path';

/** @type {import('vite').UserConfig} */
export default {
  plugins: [sveltekit()],
  resolve: {
    alias: {
      '$components': path.resolve(process.cwd(), 'src/components')
    }
  },
  optimizeDeps: {
    include: ['@supabase/supabase-js']
  }
};
