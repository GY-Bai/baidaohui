// 用户角色类型定义
export type UserRole = 'fan' | 'member' | 'master' | 'firstmate' | 'seller';

// 用户信息接口
export interface User {
  id: string;
  email: string;
  role: UserRole;
  nickname?: string;
  avatar?: string;
  verified: boolean;
  createdAt: Date;
}

// 模拟用户存储 (在实际应用中这应该来自Supabase)
let currentUser: User | null = null;

/**
 * 获取当前用户
 */
export function getCurrentUser(): User | null {
  return currentUser;
}

/**
 * 设置当前用户 (模拟登录)
 */
export function setCurrentUser(user: User | null): void {
  currentUser = user;
}

/**
 * 检查用户是否已登录
 */
export function isAuthenticated(): boolean {
  return currentUser !== null;
}

/**
 * 检查用户是否有特定角色
 */
export function hasRole(role: UserRole): boolean {
  return currentUser?.role === role;
}

/**
 * 检查用户是否有访问特定路径的权限
 */
export function canAccessPath(path: string): boolean {
  if (!isAuthenticated()) {
    return false;
  }

  const user = getCurrentUser()!;
  
  // 根据路径前缀判断权限
  if (path.startsWith('/fan/')) {
    return ['fan', 'member', 'master', 'firstmate'].includes(user.role);
  }
  
  if (path.startsWith('/member/')) {
    return ['member', 'master', 'firstmate'].includes(user.role);
  }
  
  if (path.startsWith('/master/')) {
    return ['master', 'firstmate'].includes(user.role);
  }
  
  if (path.startsWith('/firstmate/')) {
    return user.role === 'firstmate';
  }
  
  if (path.startsWith('/seller/')) {
    return user.role === 'seller';
  }
  
  return true; // 公开路径
}

/**
 * 获取用户应该重定向到的默认路径
 */
export function getDefaultPath(role: UserRole): string {
  const rolePaths = {
    fan: '/fan/fortune',
    member: '/member/fortune', 
    master: '/master/invite',
    firstmate: '/firstmate/invite',
    seller: '/seller/keys'
  };
  
  return rolePaths[role] || '/';
}

/**
 * 根据当前用户角色重定向到合适的页面
 */
export function redirectToRolePage(): string {
  const user = getCurrentUser();
  if (!user) {
    return '/'; // 未登录，重定向到登录页
  }
  
  return getDefaultPath(user.role);
}

/**
 * 模拟Google OAuth登录
 */
export async function signInWithGoogle(): Promise<User> {
  // 模拟登录延迟
  await new Promise(resolve => setTimeout(resolve, 1000));
  
  // 模拟成功登录并返回用户信息
  const mockUser: User = {
    id: 'user_' + Date.now(),
    email: 'user@example.com',
    role: 'fan', // 默认为fan用户
    nickname: '新用户',
    verified: true,
    createdAt: new Date()
  };
  
  setCurrentUser(mockUser);
  return mockUser;
}

/**
 * 登出
 */
export function signOut(): void {
  setCurrentUser(null);
}

/**
 * 检查是否需要升级权限
 */
export function needsUpgrade(requiredRole: UserRole): boolean {
  const user = getCurrentUser();
  if (!user) return true;
  
  const roleHierarchy = {
    fan: 0,
    member: 1,
    master: 2,
    firstmate: 2,
    seller: 1
  };
  
  return roleHierarchy[user.role] < roleHierarchy[requiredRole];
}

/**
 * 获取角色显示名称
 */
export function getRoleDisplayName(role: UserRole): string {
  const roleNames = {
    fan: 'Fan 用户',
    member: '会员用户', 
    master: '主播',
    firstmate: '助理',
    seller: '商户'
  };
  
  return roleNames[role];
}

/**
 * 检查功能权限
 */
export function hasPermission(feature: string): boolean {
  const user = getCurrentUser();
  if (!user) return false;
  
  const permissions = {
    fan: ['fortune', 'shopping', 'profile'],
    member: ['fortune', 'shopping', 'profile', 'private_chat'],
    master: ['fortune', 'shopping', 'profile', 'private_chat', 'manage_fortune', 'manage_chat', 'manage_ecommerce', 'invite_links'],
    firstmate: ['fortune', 'shopping', 'profile', 'private_chat', 'manage_fortune', 'manage_chat', 'manage_ecommerce', 'invite_links', 'activity_log'],
    seller: ['api_keys', 'info_settings', 'tutorials']
  };
  
  return permissions[user.role]?.includes(feature) || false;
} 