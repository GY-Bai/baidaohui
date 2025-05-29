// vite.config.js
import { defineConfig } from 'vite';
import { sveltekit } from '@sveltejs/kit/vite';
import commonjs from '@rollup/plugin-commonjs';
import path from 'path';

/** @type {import('vite').UserConfig} */
export default defineConfig({
plugins: [
sveltekit(),
commonjs({
include: /node_modules/,
defaultIsModuleExports: true,
transformMixedEsModules: true,
namedExports: {
'node_modules/@supabase/postgrest-js/dist/cjs/index.js': [
'PostgrestClient',
'createClient',
'PostgrestFilterBuilder',
'PostgrestQueryBuilder'
]
}
})
],
resolve: {
alias: {
'$components': path.resolve(__dirname, 'src/components')
}
},
optimizeDeps: {
include: ['@supabase/supabase-js', '@supabase/postgrest-js']
},
build: {
rollupOptions: {
external: ['@supabase/postgrest-js']
}
}
});
