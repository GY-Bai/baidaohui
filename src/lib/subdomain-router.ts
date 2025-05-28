// 子域名路由器 - 可选功能
// 如果您希望子域名直接显示对应内容而不重定向

import { goto } from '$app/navigation';
import { browser } from '$app/environment';

export interface SubdomainConfig {
  subdomain: string;
  route: string;
  title: string;
}

export const subdomainConfigs: SubdomainConfig[] = [
  { subdomain: 'fan', route: '/fan', title: 'Fan Portal' },
  { subdomain: 'member', route: '/member', title: 'Member Portal' },
  { subdomain: 'master', route: '/master', title: 'Master Portal' },
  { subdomain: 'firstmate', route: '/firstmate', title: 'Firstmate Portal' },
  { subdomain: 'seller', route: '/seller', title: 'Seller Portal' }
];

/**
 * 检测当前子域名并返回对应配置
 */
export function detectSubdomain(): SubdomainConfig | null {
  if (!browser) return null;
  
  const hostname = window.location.hostname;
  const parts = hostname.split('.');
  
  // 检查是否是子域名 (例如: fan.baidaohui.com)
  if (parts.length >= 3) {
    const subdomain = parts[0];
    return subdomainConfigs.find(config => config.subdomain === subdomain) || null;
  }
  
  return null;
}

/**
 * 根据子域名自动路由
 * 在 +layout.svelte 中调用此函数
 */
export function handleSubdomainRouting() {
  if (!browser) return;
  
  const config = detectSubdomain();
  if (config) {
    const currentPath = window.location.pathname;
    
    // 如果当前路径不是对应的路由，则自动跳转
    if (!currentPath.startsWith(config.route)) {
      goto(config.route);
    }
    
    // 更新页面标题
    document.title = config.title;
  }
}

/**
 * 获取当前用户角色（基于子域名或路径）
 */
export function getCurrentUserRole(): string | null {
  if (!browser) return null;
  
  // 首先检查子域名
  const subdomainConfig = detectSubdomain();
  if (subdomainConfig) {
    return subdomainConfig.subdomain;
  }
  
  // 然后检查路径
  const pathname = window.location.pathname;
  for (const config of subdomainConfigs) {
    if (pathname.startsWith(config.route)) {
      return config.subdomain;
    }
  }
  
  return null;
}

/**
 * 检查用户是否有权限访问当前页面
 */
export function checkAccess(userRole: string, requiredRole: string): boolean {
  // 这里可以添加更复杂的权限逻辑
  return userRole === requiredRole;
} 