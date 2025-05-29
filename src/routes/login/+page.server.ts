import type { ServerLoad } from '@sveltejs/kit';

export const load: ServerLoad = async ({ url }) => {
  // 获取URL参数中的错误信息
  const error = url.searchParams.get('error');
  const message = url.searchParams.get('message');
  
  // 不进行任何API调用，避免Worker超时
  return {
    error,
    message,
    backendStatus: 'unknown' // 设置为未知状态，前端可以选择性地检查
  };
}; 