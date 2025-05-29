import type { Handle } from '@sveltejs/kit';
import { redirect } from '@sveltejs/kit';

export const handle: Handle = async ({ event, resolve }) => {
  const { request, url } = event;

  // 绕过构建阶段的 prerender 请求
  if (request.headers.get('x-sveltekit-prerender')) {
    return resolve(event);
  }

  const path = url.pathname;

  // 允许的公共路径：登录、健康检查、API、认证回调
  const publicPaths = ['/login', '/health', '/api', '/auth'];
  
  if (publicPaths.some(publicPath => path.startsWith(publicPath))) {
    return resolve(event);
  }

  // 根路径重定向到登录页
  if (path === '/') {
    throw redirect(302, '/login');
  }

  // 角色页面路径（/fan, /member, /master, /firstmate, /seller）
  // 暂时都重定向到登录页，让客户端处理认证
  const rolePaths = ['/fan', '/member', '/master', '/firstmate', '/seller'];
  if (rolePaths.some(rolePath => path.startsWith(rolePath))) {
    throw redirect(302, '/login');
  }

  // 其他未知路径也重定向到登录页
  throw redirect(302, '/login');
};