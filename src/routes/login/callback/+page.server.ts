import { redirect } from '@sveltejs/kit';
import type { ServerLoad } from '@sveltejs/kit';

export const load: ServerLoad = async ({ url }) => {
  // 获取Supabase OAuth回调参数
  const code = url.searchParams.get('code');
  const error = url.searchParams.get('error');
  const error_description = url.searchParams.get('error_description');

  // 如果有错误，重定向到登录页面并显示错误
  if (error) {
    const errorMessage = error_description || '登录过程中出现错误';
    throw redirect(302, `/login?error=${error}&message=${encodeURIComponent(errorMessage)}`);
  }

  // 如果没有授权码，重定向到登录页面
  if (!code) {
    throw redirect(302, '/login?error=missing_code&message=缺少授权码');
  }

  // 成功获取到code，让客户端处理Supabase认证
  return {
    code: code
  };
}; 