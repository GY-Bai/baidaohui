import { redirect } from '@sveltejs/kit';
import type { ServerLoad } from '@sveltejs/kit';

export const load: ServerLoad = async ({ url }) => {
  // 获取Supabase OAuth回调参数
  const code = url.searchParams.get('code');
  const error = url.searchParams.get('error');
  const error_description = url.searchParams.get('error_description');

  // 如果有明确的错误，重定向到登录页面并显示错误
  if (error) {
    const errorMessage = error_description || '登录过程中出现错误';
    throw redirect(302, `/login?error=${error}&message=${encodeURIComponent(errorMessage)}`);
  }

  // 返回可用的参数，让客户端处理（即使没有code也允许）
  return {
    code: code || null,
    // 允许客户端尝试获取现有会话，即使没有授权码
    allowSessionCheck: true
  };
}; 