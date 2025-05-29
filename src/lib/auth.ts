import { createClient } from '@supabase/supabase-js';
import { browser } from '$app/environment';
import { goto } from '$app/navigation';
import { redirect } from '@sveltejs/kit';
import type { Cookies } from '@sveltejs/kit';

// 从环境变量获取Supabase配置
const supabaseUrl = import.meta.env.VITE_SUPABASE_URL || 'https://placeholder.supabase.co';
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY || 'placeholder_key';

// 只在运行时检查环境变量（不在构建时）
function checkEnvironmentVariables() {
  if (browser && (!import.meta.env.VITE_SUPABASE_URL || !import.meta.env.VITE_SUPABASE_ANON_KEY)) {
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

// 角色对应的路径映射（替换子域名映射）
export const rolePaths: Record<UserRole, string> = {
  Fan: '/fan',
  Member: '/member',
  Master: '/master',
  Firstmate: '/firstmate',
  Seller: '/seller'
};

// Google登录
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

// 获取当前会话
export async function getSession(): Promise<User | null> {
  if (!checkEnvironmentVariables()) {
    console.error('Supabase configuration is missing');
    return null;
  }
  
  try {
    const { data: { session }, error } = await supabase.auth.getSession();
    
    if (error) throw error;
    if (!session) return null;

    // 从用户元数据或数据库获取角色信息
    const role = session.user.user_metadata?.role || 'Fan';
    
    return {
      id: session.user.id,
      email: session.user.email || '',
      role: role as UserRole,
      nickname: session.user.user_metadata?.nickname
    };
  } catch (error) {
    console.error('获取会话失败:', error);
    return null;
  }
}

// 获取访问令牌
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

// 登出
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

// 验证用户认证状态
export async function validateAuth(cookies: Cookies, fetch: typeof globalThis.fetch): Promise<User | null> {
  try {
    const response = await fetch('/api/sso/session', {
      credentials: 'include'
    });
    
    // 如果是503状态码，说明后端服务不可用，返回null但不报错
    if (response.status === 503) {
      console.log('后端服务暂时不可用');
      return null;
    }
    
    if (!response.ok) {
      return null;
    }

    const { session } = await response.json();
    if (!session) {
      return null;
    }

    return {
      id: session.user.id,
      email: session.user.email,
      role: session.user.role as UserRole,
      nickname: session.user.nickname
    };
  } catch (error) {
    console.error('验证失败:', error);
    return null;
  }
}

// 通用路由守卫函数（更新为路径检查）
export async function createRouteGuard(
  expectedRole: UserRole,
  url: URL,
  cookies: Cookies,
  fetch: typeof globalThis.fetch
) {
  const currentPath = url.pathname;
  const expectedPath = rolePaths[expectedRole];
  
  // 检查是否在正确的路径
  if (!currentPath.startsWith(expectedPath)) {
    throw redirect(302, '/login');
  }

  try {
    // 使用SSO服务验证会话
    const response = await fetch('/api/sso/validate', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      credentials: 'include',
      body: JSON.stringify({
        expected_role: expectedRole,
        current_path: currentPath
      })
    });

    const result = await response.json();

    if (!result.valid) {
      // 根据错误类型进行重定向
      if (result.redirect_url) {
        throw redirect(302, result.redirect_url);
      } else {
        throw redirect(302, '/login');
      }
    }

    return { user: result.user };
  } catch (error) {
    console.error('路由守卫验证失败:', error);
    
    // 如果是重定向错误，直接抛出
    if (error instanceof Response) {
      throw error;
    }
    
    // 其他错误重定向到登录页
    throw redirect(302, '/login');
  }
}

// 检查用户是否已认证并重定向到对应角色页面
export async function redirectAuthenticatedUser(
  url: URL,
  cookies: Cookies,
  fetch: typeof globalThis.fetch
) {
  const user = await validateAuth(cookies, fetch);
  
  if (user) {
    const targetPath = rolePaths[user.role];
    if (targetPath) {
      throw redirect(302, targetPath);
    }
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

// API调用工具函数
export async function apiCall(endpoint: string, options: RequestInit = {}) {
  const token = await getAccessToken();
  
  const defaultHeaders = {
    'Content-Type': 'application/json',
    ...(token && { 'Authorization': `Bearer ${token}` })
  };

  const response = await fetch(`/api${endpoint}`, {
    ...options,
    headers: {
      ...defaultHeaders,
      ...options.headers
    }
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(error || `HTTP ${response.status}`);
  }

  return response.json();
}

// WebSocket连接工具
export function createWebSocketConnection(namespace: string = '') {
  return new Promise((resolve, reject) => {
    getAccessToken().then(token => {
      if (!token) {
        reject(new Error('未找到访问令牌'));
        return;
      }

      // 这里使用socket.io-client连接
      // 实际项目中需要安装socket.io-client包
      const socket = {
        emit: (event: string, data: any) => console.log('emit:', event, data),
        on: (event: string, callback: Function) => console.log('on:', event),
        disconnect: () => console.log('disconnect')
      };
      
      resolve(socket);
    }).catch(reject);
  });
}

// 文件上传工具
export async function uploadFile(file: File, endpoint: string): Promise<string> {
  const token = await getAccessToken();
  
  const formData = new FormData();
  formData.append('file', file);
  
  const response = await fetch(`/api${endpoint}`, {
    method: 'POST',
    headers: {
      ...(token && { 'Authorization': `Bearer ${token}` })
    },
    body: formData
  });
  
  if (!response.ok) {
    throw new Error('文件上传失败');
  }
  
  const result = await response.json();
  return result.url;
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