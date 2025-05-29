export const prerender = false;
import type { ServerLoad } from '@sveltejs/kit';
import { redirect } from '@sveltejs/kit';

// 根路径服务器加载：直接重定向到登录页面
export const load: ServerLoad = async (event) => {
  // 在预渲染阶段不要重定向，直接返回空数据
  if (import.meta.env.PRERENDERING) {
    return {};
  }

  // 正常请求时，服务器重定向到登录页
  throw redirect(302, '/login');
};
