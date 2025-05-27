import { createClient } from '@supabase/supabase-js';
import { browser } from '$app/environment';
import { goto } from '$app/navigation';

const supabaseUrl = 'https://your-project.supabase.co';
const supabaseAnonKey = 'your-anon-key';

export const supabase = createClient(supabaseUrl, supabaseAnonKey);

export type UserRole = 'Fan' | 'Member' | 'Master' | 'Firstmate' | 'Seller';

export interface UserSession {
  user: {
    id: string;
    email: string;
    role: UserRole;
  };
}

// 角色对应的子域名映射
const roleSubdomains: Record<UserRole, string> = {
  Fan: 'fan.baidaohui.com',
  Member: 'member.baidaohui.com', 
  Master: 'master.baidaohui.com',
  Firstmate: 'firstmate.baidaohui.com',
  Seller: 'seller.baidaohui.com'
};

// Google登录
export async function signInWithGoogle() {
  try {
    const { data, error } = await supabase.auth.signInWithOAuth({
      provider: 'google',
      options: {
        redirectTo: `${window.location.origin}/auth/callback`
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
export async function getSession(): Promise<UserSession | null> {
  try {
    const { data: { session }, error } = await supabase.auth.getSession();
    
    if (error) throw error;
    if (!session) return null;

    // 从用户元数据或数据库获取角色信息
    const role = session.user.user_metadata?.role || 'Fan';
    
    return {
      user: {
        id: session.user.id,
        email: session.user.email || '',
        role: role as UserRole
      }
    };
  } catch (error) {
    console.error('获取会话失败:', error);
    return null;
  }
}

// 登出
export async function signOut() {
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

// 角色校验和重定向
export async function validateRoleAndRedirect(requiredRole: UserRole) {
  const session = await getSession();
  
  if (!session) {
    if (browser) {
      goto('/login');
    }
    return false;
  }
  
  if (session.user.role !== requiredRole) {
    if (browser) {
      // 显示错误提示
      alert('您无权访问，请使用正确账号登录');
      goto('/login');
    }
    return false;
  }
  
  return true;
}

// 根据角色重定向到对应子域
export function redirectToRoleDomain(role: UserRole) {
  if (browser) {
    const subdomain = roleSubdomains[role];
    window.location.href = `https://${subdomain}`;
  }
}

// 检查当前域名是否匹配用户角色
export function isCorrectDomain(role: UserRole): boolean {
  if (!browser) return true;
  
  const currentHost = window.location.host;
  const expectedHost = roleSubdomains[role];
  
  return currentHost === expectedHost;
} 