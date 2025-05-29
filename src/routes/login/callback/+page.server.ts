import { redirect } from '@sveltejs/kit';
import { validateAuth, rolePaths } from '$lib/auth';
import type { UserRole } from '$lib/auth';

export const load = async ({ url, cookies, fetch }) => {
  // 在子目录架构下，不需要检查域名
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
        redirect_uri: `${url.origin}/login/callback`
      })
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      const errorMessage = errorData.message || '认证失败';
      throw redirect(302, `/login?error=auth_failed&message=${encodeURIComponent(errorMessage)}`);
    }

    const { user, access_token } = await response.json();
    
    // 设置HttpOnly Cookie（子目录架构下使用单域名）
    cookies.set('access_token', access_token, {
      httpOnly: true,
      secure: true,
      sameSite: 'lax',
      maxAge: 60 * 60 * 24 * 7, // 7天
      path: '/'
      // 移除domain设置，使用默认单域名
    });

    // 根据用户角色重定向到对应路径
    const targetPath = rolePaths[user.role as UserRole];
    if (targetPath) {
      throw redirect(302, targetPath);
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