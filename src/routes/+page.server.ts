import type { ServerLoad } from '@sveltejs/kit';
import { redirect } from '@sveltejs/kit';

// 根路径服务器加载：直接重定向到登录页面
export const load: ServerLoad = async ({ url }) => {
  // 服务器端重定向到登录页
  throw redirect(302, '/login');
};
