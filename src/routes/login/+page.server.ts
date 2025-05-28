import { redirect } from '@sveltejs/kit';
import { redirectAuthenticatedUser } from '../../lib/auth';

export const load = async ({ url, cookies, fetch }) => {
  // 检查是否在正确的主域名
  const hostname = url.hostname;
  
  // 如果不是主域名，重定向到主域名登录页
  if (hostname !== 'baidaohui.com' && hostname !== 'localhost') {
    throw redirect(302, 'https://baidaohui.com/login');
  }

  // 检查用户是否已认证，如果是则重定向到对应角色页面
  await redirectAuthenticatedUser(url, cookies, fetch);

  // 检查URL参数中的错误信息
  const error = url.searchParams.get('error');
  const message = url.searchParams.get('message');

  return {
    error,
    message
  };
}; 