import { redirect } from '@sveltejs/kit';
import { getSession, isCorrectPath } from '$lib/auth';

export const load = async ({ url }: any) => {
  // 获取当前会话
  const session = await getSession();
  
  // 如果未登录，重定向到登录页
  if (!session) {
    throw redirect(302, '/login');
  }
  
  // 检查用户角色是否为Firstmate
  if (session.role !== 'Firstmate') {
    // 如果角色不匹配，重定向到登录页并显示错误
    throw redirect(302, '/login?error=unauthorized&message=您无权访问，请使用正确账号登录');
  }
  
  // 检查当前路径是否正确
  if (!isCorrectPath('Firstmate')) {
    // 如果路径不匹配，重定向到正确的路径
    throw redirect(302, '/firstmate');
  }
  
  return {
    session
  };
}; 