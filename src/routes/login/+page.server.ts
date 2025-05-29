import { redirect } from '@sveltejs/kit';
import { redirectAuthenticatedUser } from '$lib/auth';
import type { ServerLoad } from '@sveltejs/kit';

export const load: ServerLoad = async ({ url, cookies, fetch }) => {
  // 在子目录架构下，不需要检查域名
  
  // 获取URL参数中的错误信息
  const error = url.searchParams.get('error');
  const message = url.searchParams.get('message');
  
  // 检查后端服务状态（短超时）
  let backendStatus = 'unknown';
  
  try {
    // 尝试ping后端服务，设置短超时避免Worker资源耗尽
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 3000); // 3秒超时
    
    const response = await fetch('/api/sso/session', {
      method: 'GET',
      credentials: 'include',
      signal: controller.signal
    });
    
    clearTimeout(timeoutId);
    
    // 检查响应状态码
    if (response.status === 503) {
      backendStatus = 'unavailable';
    } else if (response.ok) {
      backendStatus = 'available';
      // 只有在后端可用时才检查认证状态
      try {
        await redirectAuthenticatedUser(url, cookies, fetch);
      } catch (authError) {
        console.log('认证检查失败:', authError);
      }
    } else {
      backendStatus = 'unavailable';
    }
  } catch (fetchError) {
    // 如果fetch失败，说明后端服务不可用，但不阻塞页面加载
    backendStatus = 'unavailable';
    console.log('后端服务不可用:', fetchError);
  }
  
  return {
    error,
    message,
    backendStatus
  };
}; 