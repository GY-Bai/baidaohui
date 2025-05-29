import { redirect } from '@sveltejs/kit';
import { redirectAuthenticatedUser } from '$lib/auth';
import type { ServerLoad } from '@sveltejs/kit';

export const load: ServerLoad = async ({ url, cookies, fetch }) => {
  // 在子目录架构下，不需要检查域名
  
  // 检查用户是否已认证，如果是则重定向到对应角色页面
  await redirectAuthenticatedUser(url, cookies, fetch);

  // 获取URL参数中的错误信息
  const error = url.searchParams.get('error');
  const message = url.searchParams.get('message');
  
  // 检查后端服务状态
  let backendStatus = 'unknown';
  
  try {
    // 尝试ping后端服务
    const response = await fetch('/api/sso/session', {
      method: 'GET',
      credentials: 'include'
    });
    
    // 检查响应状态码
    if (response.status === 503) {
      // 503表示服务不可用
      backendStatus = 'unavailable';
    } else if (response.ok) {
      // 200-299表示服务可用
      backendStatus = 'available';
    } else {
      // 其他错误状态码也认为服务不可用
      backendStatus = 'unavailable';
    }
  } catch (fetchError) {
    // 如果fetch失败，说明后端服务不可用
    backendStatus = 'unavailable';
    console.log('后端服务不可用:', fetchError);
  }
  
  return {
    error,
    message,
    backendStatus
  };
}; 