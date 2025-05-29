import type { Handle } from '@sveltejs/kit';
import { redirect } from '@sveltejs/kit';

const ROLE_SUBDOMAIN_MAP: Record<string, string> = {
  Fan: 'fan',
  Member: 'member',
  Master: 'master',
  Firstmate: 'firstmate',
  Seller: 'seller'
};

export const handle: Handle = async ({ event, resolve }) => {
  const { request, url, fetch } = event;
  const host = url.hostname.toLowerCase();

  // 绕过构建阶段的 prerender 请求
  if (request.headers.get('x-sveltekit-prerender')) {
    return resolve(event);
  }

  const path = url.pathname;

  // 1. 子域名访问 → 重定向到对应目录
  for (const role in ROLE_SUBDOMAIN_MAP) {
    const sub = ROLE_SUBDOMAIN_MAP[role];
    if (host === `${sub}.baidaohui.com`) {
      if (path.startsWith(`/${sub}`)) return resolve(event);
      throw redirect(302, `/${sub}${path === '/' ? '' : path}`);
    }
  }

  // 2. 根域名、www 或 localhost → 登录逻辑
  const isApex = host === 'baidaohui.com' || host === 'www.baidaohui.com' || host === 'localhost' || host.startsWith('127.0.0.1');
  if (!isApex) throw redirect(302, '/login');

  // 3. session 获取
  try {
    const res = await fetch('/api/sso/session', { method: 'GET', credentials: 'include' });
    if (res.ok) {
      const { user } = await res.json();
      const sub = ROLE_SUBDOMAIN_MAP[user.role as keyof typeof ROLE_SUBDOMAIN_MAP];
      if (sub) throw redirect(302, `https://${sub}.baidaohui.com`);
    }
  } catch {
    // 忽略错误
  }

  // 4. 未登录且非登录页 → /login
  if (!path.startsWith('/login')) throw redirect(302, '/login');

  // 5. 登录页 → 渲染
  return resolve(event);
};