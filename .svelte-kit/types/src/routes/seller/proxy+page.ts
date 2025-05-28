// @ts-nocheck
import type { PageLoad } from './$types';
import { redirect } from '@sveltejs/kit';
import { getSession, isCorrectDomain } from '$lib/auth';

export const load = async ({ url }: Parameters<PageLoad>[0]) => {
  // 获取当前会话
  const session = await getSession();
  
  // 如果未登录，重定向到登录页
  if (!session) {
    throw redirect(302, '/login');
  }
  
  // 检查用户角色是否为Seller
  if (session.user.role !== 'Seller') {
    // 如果角色不匹配，重定向到登录页并显示错误
    throw redirect(302, '/login?error=unauthorized&message=您无权访问，请使用正确账号登录');
  }
  
  // 检查当前域名是否正确
  if (!isCorrectDomain('Seller')) {
    // 如果域名不匹配，重定向到正确的子域
    throw redirect(302, `https://seller.baidaohui.com${url.pathname}${url.search}`);
  }
  
  return {
    session
  };
}; 