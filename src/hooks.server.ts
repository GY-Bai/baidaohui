import type { Handle } from '@sveltejs/kit';
import { redirect } from '@sveltejs/kit';

export const handle: Handle = async ({ event, resolve }) => {
  const { request, url } = event;

  // 绕过构建阶段的 prerender 请求
  if (request.headers.get('x-sveltekit-prerender')) {
    return resolve(event);
  }

  const path = url.pathname;

  // 根路径重定向到登录页
  if (path === '/') {
    throw redirect(302, '/login');
  }

  // 允许所有路径通过，让客户端处理认证
  // 这样角色页面可以正常加载，认证检查在客户端的 onMount 中进行
  return resolve(event);
};