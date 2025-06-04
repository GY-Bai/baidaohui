import { goto } from '$app/navigation';
import { canAccessPath, isAuthenticated, redirectToRolePage } from './lib/utils/auth';
import type { HandleClientError } from '@sveltejs/kit';
import { supabase } from '$lib/supabaseClient';

// 需要认证的路径前缀
const PROTECTED_PATHS = ['/fan/', '/member/', '/master/', '/firstmate/', '/seller/'];

// 公开路径（不需要认证）
const PUBLIC_PATHS = ['/', '/demo/'];

/**
 * 检查路径是否需要认证
 */
function isProtectedPath(pathname: string): boolean {
  return PROTECTED_PATHS.some(prefix => pathname.startsWith(prefix));
}

/**
 * 检查路径是否为公开路径
 */
function isPublicPath(pathname: string): boolean {
  return PUBLIC_PATHS.some(prefix => pathname.startsWith(prefix));
}

/**
 * 路由守卫逻辑
 */
export function checkRouteAccess(pathname: string): boolean {
  // 公开路径始终允许访问
  if (isPublicPath(pathname)) {
    return true;
  }
  
  // 受保护的路径需要认证
  if (isProtectedPath(pathname)) {
    if (!isAuthenticated()) {
      // 未登录，重定向到登录页
      goto('/');
      return false;
    }
    
    if (!canAccessPath(pathname)) {
      // 权限不足，重定向到用户对应的页面
      const defaultPath = redirectToRolePage();
      goto(defaultPath);
      return false;
    }
  }
  
  return true;
}

/**
 * 客户端错误处理
 */
export const handleError: HandleClientError = ({ error, event }) => {
  console.error('Client error:', error);
  
  // 在生产环境中，可以在这里报告错误到监控服务
  
  return {
    message: '发生了未知错误，请刷新页面重试',
    code: 'UNKNOWN_ERROR'
  };
};

async function refreshUserSession() {
  const { data, error } = await supabase.auth.refreshSession();
  if (error) console.error('刷新会话失败:', error);
  else console.log('会话已刷新，角色应已更新');
  // 在需要的地方调用，例如在页面加载后
} 