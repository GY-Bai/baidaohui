import { createClient } from '@supabase/supabase-js';
import { browser } from '$app/environment';
import { goto } from '$app/navigation';
import { redirect } from '@sveltejs/kit';

// 从环境变量获取Supabase配置
const supabaseUrl = import.meta.env.VITE_SUPABASE_URL || 'https://placeholder.supabase.co';
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY || 'placeholder_key';

// 只在运行时检查环境变量（不在构建时）
function checkEnvironmentVariables() {
  const hasUrl = import.meta.env.VITE_SUPABASE_URL && import.meta.env.VITE_SUPABASE_URL !== 'https://placeholder.supabase.co';
  const hasKey = import.meta.env.VITE_SUPABASE_ANON_KEY && import.meta.env.VITE_SUPABASE_ANON_KEY !== 'placeholder_key';
  
  if (browser && (!hasUrl || !hasKey)) {
    console.error('Missing Supabase environment variables. Please check VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY');
    return false;
  }
  return true;
}

export const supabase = createClient(supabaseUrl, supabaseAnonKey);

export type UserRole = 'Fan' | 'Member' | 'Master' | 'Firstmate' | 'Seller';

export interface User {
  id: string;
  email: string;
  role: UserRole;
  nickname?: string;
}

export interface UserSession {
  user: User;
  access_token?: string;
}

// 角色对应的路径映射
export const rolePaths: Record<UserRole, string> = {
  Fan: '/fan',
  Member: '/member',
  Master: '/master',
  Firstmate: '/firstmate',
  Seller: '/seller'
};

// Google登录 - 纯Supabase实现
export async function signInWithGoogle() {
  if (!checkEnvironmentVariables()) {
    throw new Error('Supabase configuration is missing');
  }
  
  try {
    const { data, error } = await supabase.auth.signInWithOAuth({
      provider: 'google',
      options: {
        redirectTo: `${import.meta.env.VITE_APP_URL || window.location.origin}/login/callback`
      }
    });
    
    if (error) throw error;
    return data;
  } catch (error) {
    console.error('登录失败:', error);
    throw error;
  }
}

// 获取当前会话 - 纯Supabase实现
export async function getSession(): Promise<User | null> {
  if (!checkEnvironmentVariables()) {
    console.error('Supabase configuration is missing');
    return null;
  }
  
  try {
    const { data: { session }, error } = await supabase.auth.getSession();
    
    if (error) throw error;
    if (!session) return null;

    // 从用户元数据获取角色信息，默认为Fan
    const role = session.user.user_metadata?.role || 'Fan';
    
    return {
      id: session.user.id,
      email: session.user.email || '',
      role: role as UserRole,
      nickname: session.user.user_metadata?.nickname || session.user.user_metadata?.full_name
    };
  } catch (error) {
    console.error('获取会话失败:', error);
    return null;
  }
}

// 获取Supabase访问令牌
export async function getAccessToken(): Promise<string | null> {
  if (!checkEnvironmentVariables()) {
    console.error('Supabase configuration is missing');
    return null;
  }
  
  try {
    const { data: { session }, error } = await supabase.auth.getSession();
    if (error) throw error;
    return session?.access_token || null;
  } catch (error) {
    console.error('获取访问令牌失败:', error);
    return null;
  }
}

// 登出 - 纯Supabase实现
export async function signOut() {
  if (!checkEnvironmentVariables()) {
    console.error('Supabase configuration is missing');
    return;
  }
  
  try {
    const { error } = await supabase.auth.signOut();
    if (error) throw error;
    
    if (browser) {
      goto('/login');
    }
  } catch (error) {
    console.error('登出失败:', error);
    throw error;
  }
}

// 简化的客户端路由守卫
export async function clientSideRouteGuard(expectedRole: UserRole): Promise<boolean> {
  if (!browser) return true;
  
  try {
    const user = await getSession();
    
    if (!user) {
      // 未登录，重定向到登录页
      goto('/login');
      return false;
    }
    
    if (user.role !== expectedRole) {
      // 角色不匹配，重定向到对应角色页面
      redirectToRolePath(user.role);
      return false;
    }
    
    // 检查是否在正确的路径
    if (!isCorrectPath(expectedRole)) {
      redirectToRolePath(expectedRole);
      return false;
    }
    
    return true;
  } catch (error) {
    console.error('角色验证失败:', error);
    goto('/login');
    return false;
  }
}

// 根据角色重定向到对应路径
export function redirectToRolePath(role: UserRole) {
  if (browser) {
    const path = rolePaths[role];
    goto(path);
  }
}

// 检查当前路径是否匹配用户角色
export function isCorrectPath(role: UserRole): boolean {
  if (!browser) return true;
  
  const currentPath = window.location.pathname;
  const expectedPath = rolePaths[role];
  
  return currentPath.startsWith(expectedPath);
}

// 格式化时间
export function formatTime(timestamp: string | Date): string {
  return new Date(timestamp).toLocaleTimeString('zh-CN', {
    hour: '2-digit',
    minute: '2-digit'
  });
}

// 格式化日期
export function formatDate(timestamp: string | Date): string {
  return new Date(timestamp).toLocaleDateString('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit'
  });
}

// 格式化货币
export function formatCurrency(amount: number, currency: string = 'CAD'): string {
  return new Intl.NumberFormat('zh-CN', {
    style: 'currency',
    currency: currency
  }).format(amount);
}

// 客户端角色验证和重定向
export async function validateRoleAndRedirect(expectedRole: UserRole): Promise<boolean> {
  if (!browser) return true;
  
  try {
    const user = await getSession();
    
    if (!user) {
      // 未登录，重定向到登录页
      goto('/login');
      return false;
    }
    
    if (user.role !== expectedRole) {
      // 角色不匹配，重定向到对应角色页面
      redirectToRolePath(user.role);
      return false;
    }
    
    // 检查是否在正确的路径
    if (!isCorrectPath(expectedRole)) {
      redirectToRolePath(expectedRole);
      return false;
    }
    
    return true;
  } catch (error) {
    console.error('角色验证失败:', error);
    goto('/login');
    return false;
  }
} 