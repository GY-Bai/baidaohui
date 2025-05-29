import type { ServerLoad } from '@sveltejs/kit';

export const load: ServerLoad = async ({ url }) => {
  // 获取URL参数中的错误信息
  const error = url.searchParams.get('error');
  const message = url.searchParams.get('message');
  
  return {
    error,
    message
  };
}; 