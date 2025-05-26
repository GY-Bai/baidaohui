import { createClient, type User, type AuthChangeEvent, type Session } from '@supabase/supabase-js';

// Supabase 配置 - 使用环境变量或回退到默认值
const supabaseUrl = import.meta.env.VITE_SUPABASE_URL || 'https://pvjowkjksutkhpsomwvv.supabase.co';
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB2am93a2prc3V0a2hwc29td3Z2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc4NzYxMzEsImV4cCI6MjA2MzQ1MjEzMX0.m98BRjqAnpjVpyDxUC-9LRrU4B3SRXYdHMO3Dez-qyc';

// 创建 Supabase 客户端
export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: true
  }
});

// 导出配置常量
export { supabaseUrl, supabaseAnonKey };

// 辅助函数：获取当前用户
export async function getCurrentUser(): Promise<User | null> {
  try {
    const { data: { user }, error } = await supabase.auth.getUser();
    if (error) throw error;
    return user;
  } catch (error) {
    console.error('获取用户信息失败:', error);
    return null;
  }
}

// 辅助函数：获取用户角色
export async function getUserRole(user: User | null = null): Promise<string> {
  try {
    if (!user) {
      user = await getCurrentUser();
    }
    if (!user) return 'fan';
    
    // 从用户元数据中获取角色
    return user.user_metadata?.role || user.app_metadata?.role || 'fan';
  } catch (error) {
    console.error('获取用户角色失败:', error);
    return 'fan';
  }
}

// 辅助函数：角色跳转
export function redirectToRolePage(user: User): void {
  const role = user.user_metadata?.role || user.app_metadata?.role || 'fan';
  
  const roleSubdomains: Record<string, string> = {
    fan: 'fan.baiduohui.com',
    member: 'member.baiduohui.com', 
    master: 'master.baiduohui.com',
    firstmate: 'firstmate.baiduohui.com'
  };
  
  const targetDomain = roleSubdomains[role] || 'fan.baiduohui.com';
  window.location.assign(`https://${targetDomain}`);
}

// 辅助函数：登出
export async function signOut(): Promise<void> {
  try {
    const { error } = await supabase.auth.signOut();
    if (error) throw error;
    
    // 跳转到登录页面
    window.location.assign('https://baiduohui.com');
  } catch (error) {
    console.error('登出失败:', error);
    // 即使登出失败也跳转到登录页面
    window.location.assign('https://baiduohui.com');
  }
}

// 导出类型
export type { User, AuthChangeEvent, Session }; 