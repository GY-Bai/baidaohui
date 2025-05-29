import type { Handle } from '@sveltejs/kit';
import { redirect } from '@sveltejs/kit';

const ROLE_PATH_MAP: Record<string, string> = {
  Fan: '/fan',
  Member: '/member',
  Master: '/master',
  Firstmate: '/firstmate',
  Seller: '/seller'
};

export const handle: Handle = async ({ event, resolve }) => {
  const { request, url } = event;

  // 绕过构建阶段的 prerender 请求
  if (request.headers.get('x-sveltekit-prerender')) {
    return resolve(event);
  }

  const path = url.pathname;

  // 允许健康检查页面直接访问（用于调试）
  if (path.startsWith('/health')) {
    return resolve(event);
  }

  // 登录页面和API路径无需验证，直接处理
  if (path.startsWith('/login') || path.startsWith('/api') || path.startsWith('/auth')) {
    return resolve(event);
  }

  // 暂时将所有其他路径重定向到登录页，避免循环调用后端服务
  if (path === '/' || Object.values(ROLE_PATH_MAP).some(rolePath => path.startsWith(rolePath))) {
    throw redirect(302, '/login');
  }

  // 其他路径也重定向到登录页
  throw redirect(302, '/login');
};