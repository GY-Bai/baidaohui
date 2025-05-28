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
  const { url, fetch } = event;
  const hostname = url.hostname.toLowerCase();
  const pathname = url.pathname;

  // 1. 子域名访问 → 重定向到对应目录
  for (const role in ROLE_SUBDOMAIN_MAP) {
    const sub = ROLE_SUBDOMAIN_MAP[role];
    if (hostname === `${sub}.baidaohui.com`) {
      // 已经处于正确路径，继续渲染
      if (pathname.startsWith(`/${sub}`)) {
        return resolve(event);
      }
      // 跳转到子目录首页
      throw redirect(302, `/${sub}` + (pathname === '/' ? '' : pathname));
    }
  }

  // 2. 根域名访问或 www 域名
  const isApex = hostname === 'baidaohui.com' || hostname === 'www.baidaohui.com';
  if (!isApex) {
    // 非法域名，跳登录
    throw redirect(302, '/login');
  }

  // 3. 登录检查
  try {
    const res = await fetch('/api/sso/session', {
      method: 'GET',
      credentials: 'include'
    });
    if (res.ok) {
      const { user } = await res.json();
      const roleKey = user.role as keyof typeof ROLE_SUBDOMAIN_MAP;
      const subdomain = ROLE_SUBDOMAIN_MAP[roleKey];
      if (subdomain) {
        // 重定向到子域名入口
        throw redirect(302, `https://${subdomain}.baidaohui.com`);
      }
    }
  } catch (e) {
    // session 获取失败或者未登录，跳登录
  }

  // 4. 未登录或权限不对 → 跳登录页
  if (!pathname.startsWith('/login')) {
    throw redirect(302, '/login');
  }

  // 5. 继续处理登录相关路由
  return resolve(event);
};
