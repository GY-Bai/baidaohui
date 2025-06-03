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
    // 构建回调URL，确保与Supabase配置一致
    const baseUrl = import.meta.env.VITE_APP_URL || window.location.origin;
    const redirectUrl = `${baseUrl}/login/callback`;
    
    console.log('Google登录重定向URL:', redirectUrl);
    
    const { data, error } = await supabase.auth.signInWithOAuth({
      provider: 'google',
      options: {
        redirectTo: redirectUrl
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

// 处理URL片段中的会话（用于OAuth回调）
export async function handleAuthCallback(): Promise<User | null> {
  if (!browser || !checkEnvironmentVariables()) {
    return null;
  }

  try {
    // 检查URL是否包含认证片段
    const hashParams = new URLSearchParams(window.location.hash.substring(1));
    const accessToken = hashParams.get('access_token');
    
    if (accessToken) {
      console.log('检测到URL中的access_token，等待Supabase处理...');
      
      // 等待Supabase处理URL片段
      await new Promise(resolve => setTimeout(resolve, 100));
      
      // 清理URL（移除片段）
      const cleanUrl = window.location.pathname + window.location.search;
      window.history.replaceState({}, document.title, cleanUrl);
    }

    // 获取处理后的会话
    return await getSession();
  } catch (error) {
    console.error('处理认证回调失败:', error);
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
  if (!browser) {
    console.log('非浏览器环境，跳过重定向');
    return;
  }
  
  const path = rolePaths[role];
  console.log(`重定向到角色页面: ${role} -> ${path}`);
  
  if (path) {
    goto(path);
  } else {
    console.error(`未找到角色 ${role} 对应的路径`);
    goto('/login');
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

// 简化的API调用函数，用于后端服务通信
export async function apiCall(endpoint: string, options: RequestInit = {}) {
  if (!browser) {
    throw new Error('API调用只能在浏览器环境中使用');
  }

  try {
    // 获取Supabase访问令牌
    const token = await getAccessToken();
    
    if (!token) {
      throw new Error('未找到访问令牌，请重新登录');
    }

    // 默认配置
    const defaultOptions: RequestInit = {
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`,
        ...options.headers,
      },
      credentials: 'include',
      ...options,
    };

    // 构建完整URL (假设后端服务在特定端点)
    const baseUrl = import.meta.env.VITE_API_BASE_URL || 'https://api.baidaohui.com';
    const url = endpoint.startsWith('http') ? endpoint : `${baseUrl}${endpoint}`;

    const response = await fetch(url, defaultOptions);

    if (!response.ok) {
      if (response.status === 401) {
        // 认证失败，重定向到登录页
        goto('/login');
        throw new Error('认证失败，请重新登录');
      }
      throw new Error(`API调用失败: ${response.statusText}`);
    }

    // 如果响应是空的，返回null
    const text = await response.text();
    if (!text) {
      return null;
    }

    try {
      return JSON.parse(text);
    } catch {
      return text;
    }
  } catch (error) {
    console.error('API调用错误:', error);
    throw error;
  }
} 