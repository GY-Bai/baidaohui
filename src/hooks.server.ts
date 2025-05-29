import type { Handle } from '@sveltejs/kit';
import { redirect } from '@sveltejs/kit';

const ROLE_PATH_MAP: Record<string, string> = {
  Fan: '/fan',
  Member: '/member',
  Master: '/master',
  Firstmate: '/firstmate',
  Seller: '/seller'
};

// 带超时的fetch函数
async function fetchWithTimeout(url: string, options: RequestInit & { timeout?: number } = {}) {
  const { timeout = 3000, ...fetchOptions } = options;
  
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), timeout);
  
  try {
    const response = await fetch(url, {
      ...fetchOptions,
      signal: controller.signal
    });
    clearTimeout(timeoutId);
    return response;
  } catch (error) {
    clearTimeout(timeoutId);
    throw error;
  }
}

export const handle: Handle = async ({ event, resolve }) => {
  const { request, url, fetch } = event;

  // 绕过构建阶段的 prerender 请求
  if (request.headers.get('x-sveltekit-prerender')) {
    return resolve(event);
  }

  const path = url.pathname;

  // 检查是否访问受保护的角色路径
  const isRolePath = Object.values(ROLE_PATH_MAP).some(rolePath => path.startsWith(rolePath));

  if (isRolePath) {
    // 获取当前访问的角色路径
    const currentRolePath = Object.values(ROLE_PATH_MAP).find(rolePath => path.startsWith(rolePath));
    const expectedRole = Object.keys(ROLE_PATH_MAP).find(role => ROLE_PATH_MAP[role] === currentRolePath);

    try {
      // 验证用户会话和角色权限（添加超时保护）
      const res = await fetchWithTimeout('/api/sso/session', { 
        method: 'GET', 
        credentials: 'include',
        timeout: 3000 // 3秒超时
      });
      
      if (!res.ok) {
        // 未登录，重定向到登录页
        throw redirect(302, '/login');
      }

      const { user } = await res.json();
      
      if (!user) {
        // 无用户信息，重定向到登录页
        throw redirect(302, '/login');
      }

      // 检查用户角色是否匹配当前路径
      if (user.role !== expectedRole) {
        // 角色不匹配，重定向到用户对应的角色页面
        const userRolePath = ROLE_PATH_MAP[user.role];
        if (userRolePath) {
          throw redirect(302, userRolePath);
        } else {
          // 未知角色，重定向到登录页
          throw redirect(302, '/login');
        }
      }

      // 权限验证通过，继续处理请求
      return resolve(event);
    } catch (error) {
      // 如果是重定向错误，直接抛出
      if (error instanceof Response) {
        throw error;
      }
      
      // 其他错误（如网络错误），重定向到登录页
      console.error('认证验证失败:', error);
      throw redirect(302, '/login');
    }
  }

  // 对于根路径 "/" 的处理
  if (path === '/') {
    try {
      // 尝试获取用户会话（添加超时保护）
      const res = await fetchWithTimeout('/api/sso/session', { 
        method: 'GET', 
        credentials: 'include',
        timeout: 3000 // 3秒超时
      });
      
      if (res.ok) {
        const { user } = await res.json();
        if (user && user.role) {
          // 已登录用户，重定向到对应角色页面
          const userRolePath = ROLE_PATH_MAP[user.role];
          if (userRolePath) {
            throw redirect(302, userRolePath);
          }
        }
      }
    } catch (error) {
      // 忽略会话获取错误，继续到登录页
      console.log('获取会话失败，将显示登录页');
    }
    
    // 未登录或获取会话失败，重定向到登录页
    throw redirect(302, '/login');
  }

  // 登录页面和API路径无需验证，直接处理
  if (path.startsWith('/login') || path.startsWith('/api') || path.startsWith('/auth')) {
    return resolve(event);
  }

  // 其他路径重定向到登录页
  throw redirect(302, '/login');
};