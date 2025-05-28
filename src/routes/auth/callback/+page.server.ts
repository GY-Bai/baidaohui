import { redirect } from '@sveltejs/kit';
import { validateAuth, roleSubdomains } from '../../lib/auth';
import type { UserRole } from '../../lib/auth';

export const load = async ({ url, cookies, fetch }) => {
  // 检查是否在正确的主域名
  const hostname = url.hostname;
  
  // 如果不是主域名，重定向到主域名
  if (hostname !== 'baidaohui.com' && hostname !== 'localhost') {
    throw redirect(302, 'https://baidaohui.com/auth/callback' + url.search);
  }

  // 获取OAuth回调参数
  const code = url.searchParams.get('code');
  const state = url.searchParams.get('state');
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

    try {
    // 调用后端auth-service处理OAuth回调
      const response = await fetch('/api/auth/callback', {
        method: 'POST',
        headers: {
        'Content-Type': 'application/json',
        },
      body: JSON.stringify({
        code,
        state,
        redirect_uri: `${url.origin}/auth/callback`
      })
      });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      const errorMessage = errorData.message || '认证失败';
      throw redirect(302, `/login?error=auth_failed&message=${encodeURIComponent(errorMessage)}`);
    }

        const { user, access_token } = await response.json();
        
    // 设置HttpOnly Cookie
        cookies.set('access_token', access_token, {
          httpOnly: true,
          secure: true,
      sameSite: 'lax',
          maxAge: 60 * 60 * 24 * 7, // 7天
      path: '/',
      domain: '.baidaohui.com' // 跨子域共享
    });

    // 根据用户角色重定向到对应子域
    const targetDomain = roleSubdomains[user.role as UserRole];
    if (targetDomain) {
      throw redirect(302, `https://${targetDomain}`);
    } else {
      throw redirect(302, '/login?error=invalid_role&message=无效的用户角色');
    }

  } catch (error) {
    console.error('OAuth回调处理失败:', error);
    
    // 如果是重定向错误，直接抛出
    if (error instanceof Response) {
      throw error;
    }
    
    // 其他错误重定向到登录页面
    throw redirect(302, '/login?error=callback_failed&message=登录回调处理失败');
  }
}; 