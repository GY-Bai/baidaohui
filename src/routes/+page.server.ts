export const prerender = false;
import type { ServerLoad } from '@sveltejs/kit';
import { redirect } from '@sveltejs/kit';
import { validateAuth } from '$lib/auth';

// 根路径服务器加载：检查认证状态并重定向
export const load: ServerLoad = async ({ cookies, fetch }) => {
  // 在预渲染阶段不要重定向，直接返回空数据
  if (import.meta.env.PRERENDERING) {
    return {};
  }

  try {
    // 检查用户是否已认证
    const user = await validateAuth(cookies, fetch);
    
    if (user) {
      // 用户已认证，重定向到对应角色页面
      const rolePaths: Record<string, string> = {
        Fan: '/fan',
        Member: '/member',
        Master: '/master',
        Firstmate: '/firstmate',
        Seller: '/seller'
      };
      
      const targetPath = rolePaths[user.role];
      if (targetPath) {
        throw redirect(302, targetPath);
      }
    }
    
    // 用户未认证，重定向到登录页
    throw redirect(302, '/login');
  } catch (error) {
    // 如果是重定向错误，直接抛出
    if (error instanceof Response) {
      throw error;
    }
    
    // 其他错误，重定向到登录页
    throw redirect(302, '/login');
  }
};
