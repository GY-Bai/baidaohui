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

// 获取当前会话 - 强制从数据库查询最新角色
export async function getSession(): Promise<User | null> {
  if (!checkEnvironmentVariables()) {
    console.error('Supabase configuration is missing');
    return null;
  }
  
  try {
    const { data: { session }, error } = await supabase.auth.getSession();
    
    if (error) throw error;
    if (!session) return null;

    console.log('🔍 获取到Supabase会话，用户ID:', session.user.id);

    // 🚀 关键修改：使用公共视图查询角色，避免RLS权限问题
    const { data: profile, error: profileError } = await supabase
      .from('profiles_public_roles')
      .select('role')
      .eq('id', session.user.id)
      .single();

    if (profileError) {
      console.error('❌ 查询用户角色失败:', profileError.message, profileError);
      // 如果查询失败，使用默认角色，但记录错误
      console.warn('⚠️ 使用默认角色 Fan，原因:', profileError.message);
    }

    const currentRole = profile?.role || 'Fan';
    const userMetadataRole = session.user.user_metadata?.role || 'Fan';
    
    // 🔍 调试日志：对比数据库角色和metadata角色
    if (currentRole !== userMetadataRole) {
      console.log(`🔄 角色不同步检测：`);
      console.log(`   数据库角色: ${currentRole}`);
      console.log(`   Metadata角色: ${userMetadataRole}`);
      console.log(`   ✅ 使用数据库角色: ${currentRole}`);
    } else {
      console.log(`✅ 角色同步正常: ${currentRole}`);
    }

    return {
      id: session.user.id,
      email: session.user.email || '',
      role: currentRole as UserRole, // 🎯 使用数据库中的最新角色
      nickname: session.user.user_metadata?.nickname || session.user.user_metadata?.full_name
    };
  } catch (error) {
    console.error('❌ 获取会话失败:', error);
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
      console.log('🔍 检测到URL中的access_token，等待Supabase处理...');
      
      // 等待Supabase处理URL片段
      await new Promise(resolve => setTimeout(resolve, 100));
      
      // 清理URL（移除片段）
      const cleanUrl = window.location.pathname + window.location.search;
      window.history.replaceState({}, document.title, cleanUrl);
    }

    // 🚀 关键改进：获取处理后的会话（现在会查询最新角色）
    console.log('🔄 OAuth回调：开始获取最新用户角色...');
    const user = await getSession();
    
    if (user) {
      console.log(`✅ OAuth回调：成功获取用户会话`);
      console.log(`   用户ID: ${user.id}`);
      console.log(`   邮箱: ${user.email}`);
      console.log(`   角色: ${user.role}`);
      console.log(`   昵称: ${user.nickname || '未设置'}`);
    } else {
      console.log('⚠️ OAuth回调：未能获取用户会话');
    }

    return user;
  } catch (error) {
    console.error('❌ 处理认证回调失败:', error);
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

// 客户端路由守卫 - 增强角色验证
export async function clientSideRouteGuard(requiredRole?: UserRole): Promise<boolean> {
  if (!browser) {
    console.log('⚠️ 非浏览器环境，跳过客户端路由守卫');
    return false;
  }

  try {
    console.log(`🛡️ 客户端路由守卫：检查访问权限`);
    console.log(`   当前页面: ${window.location.pathname}`);
    console.log(`   要求角色: ${requiredRole || '任意'}`);
    
    // 🚀 获取最新的用户会话（现在会查询数据库中的最新角色）
    const user = await getSession();
    
    if (!user) {
      console.log('❌ 客户端路由守卫：用户未登录，重定向到登录页');
      goto('/login');
      return false;
    }

    console.log(`✅ 客户端路由守卫：用户已登录`);
    console.log(`   用户ID: ${user.id}`);
    console.log(`   邮箱: ${user.email}`);
    console.log(`   当前角色: ${user.role}`);

    // 🎯 如果指定了必需角色，进行角色验证
    if (requiredRole && user.role !== requiredRole) {
      console.log(`🚫 客户端路由守卫：角色不匹配`);
      console.log(`   当前角色: ${user.role}`);
      console.log(`   要求角色: ${requiredRole}`);
      console.log(`🔄 重定向到正确的角色页面...`);
      
      // 重定向到用户实际角色对应的页面
      redirectToRolePath(user.role);
      return false;
    }

    console.log(`✅ 客户端路由守卫：访问权限验证通过`);
    return true;
  } catch (error) {
    console.error('❌ 客户端路由守卫：验证过程出错:', error);
    goto('/login');
    return false;
  }
}

// 根据角色重定向到对应路径
export function redirectToRolePath(role: UserRole) {
  if (!browser) {
    console.log('⚠️ 非浏览器环境，跳过重定向');
    return;
  }
  
  const path = rolePaths[role];
  console.log(`🎯 重定向到角色页面:`);
  console.log(`   当前角色: ${role}`);
  console.log(`   目标路径: ${path}`);
  console.log(`   当前路径: ${window.location.pathname}`);
  
  if (path) {
    // 检查是否已经在正确的页面
    if (window.location.pathname === path) {
      console.log('✅ 已在正确页面，无需重定向');
      return;
    }
    
    console.log(`🚀 执行重定向: ${window.location.pathname} -> ${path}`);
    goto(path);
  } else {
    console.error(`❌ 未找到角色 ${role} 对应的路径，重定向到登录页`);
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

// 强制刷新用户角色（用于管理员修改角色后的同步）
export async function refreshUserRole(): Promise<User | null> {
  if (!browser) {
    console.log('⚠️ 非浏览器环境，跳过角色刷新');
    return null;
  }

  try {
    console.log('🔄 强制刷新用户角色...');
    const { data: { session }, error: sessionError } = await supabase.auth.getSession();
    if (sessionError) throw sessionError;
    if (!session) {
      console.log('用户未登录，无法刷新角色');
      return null;
    }

    // 🚀 使用公共视图查询角色，避免RLS权限问题
    const { data: profile, error: profileError } = await supabase
      .from('profiles_public_roles')
      .select('role')
      .eq('id', session.user.id)
      .single();

    if (profileError) {
      console.error('❌ 强制刷新角色失败:', profileError);
      return null;
    }

    const newRole = profile?.role || 'Fan';
    const oldRole = session.user.user_metadata?.role || 'Fan';

    if (newRole !== oldRole) {
      console.log(`🎯 检测到角色变更: ${oldRole} -> ${newRole}`);
      console.log(`🚀 准备重定向到新角色页面...`);
      
      // 重定向到新角色页面
      setTimeout(() => {
        redirectToRolePath(newRole as UserRole);
      }, 100);
    } else {
      console.log(`✅ 角色无变化: ${newRole}`);
    }

    return {
      id: session.user.id,
      email: session.user.email || '',
      role: newRole as UserRole,
      nickname: session.user.user_metadata?.nickname || session.user.user_metadata?.full_name
    };
  } catch (error) {
    console.error('❌ 强制刷新用户角色失败:', error);
    return null;
  }
}

// 角色变更监听器（可在页面中使用）
export function startRoleChangeListener(intervalMs: number = 30000): () => void {
  if (!browser) {
    console.log('⚠️ 非浏览器环境，无法启动角色监听器');
    return () => {};
  }

  let currentRole: string | null = null;
  let intervalId: NodeJS.Timeout;

  const checkRoleChange = async () => {
    try {
      const user = await getSession();
      
      if (!user) {
        // 用户已登出
        if (currentRole) {
          console.log('👋 角色监听器：检测到用户登出');
          goto('/login');
        }
        currentRole = null;
        return;
      }

      // 初始化当前角色
      if (currentRole === null) {
        currentRole = user.role;
        console.log(`🎯 角色监听器：初始化角色 ${currentRole}`);
        return;
      }

      // 检查角色是否变更
      if (user.role !== currentRole) {
        console.log(`🔄 角色监听器：检测到角色变更 ${currentRole} -> ${user.role}`);
        currentRole = user.role;
        
        // 检查当前页面是否匹配新角色
        const currentPath = window.location.pathname;
        const expectedPath = rolePaths[user.role as UserRole];
        
        if (currentPath !== expectedPath) {
          console.log(`🚀 角色监听器：重定向到新角色页面 ${expectedPath}`);
          redirectToRolePath(user.role as UserRole);
        }
      }
    } catch (error) {
      console.error('❌ 角色监听器：检查角色变更失败:', error);
    }
  };

  // 立即执行一次检查
  checkRoleChange();

  // 设置定期检查
  intervalId = setInterval(checkRoleChange, intervalMs);
  console.log(`🔄 角色监听器：已启动，检查间隔 ${intervalMs}ms`);

  // 返回清理函数
  return () => {
    if (intervalId) {
      clearInterval(intervalId);
      console.log('🛑 角色监听器：已停止');
    }
  };
}