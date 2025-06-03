import { browser } from '$app/environment';

export const load = async () => {
  // 只在客户端进行认证检查，服务端跳过
  if (!browser) {
    return {};
  }
  
  // 客户端会话检查会在页面组件的 onMount 中处理
  return {};
}; 