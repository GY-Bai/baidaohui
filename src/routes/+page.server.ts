import { redirect } from '@sveltejs/kit';
import type { ServerLoad } from '@sveltejs/kit';

export const load: ServerLoad = async ({ url, cookies, fetch }) => {
  // 检查当前域名
  const hostname = url.hostname;
  
  // 如果是子域名，重定向到对应的角色页面
  if (hostname.includes('fan.')) {
    throw redirect(302, '/fan');
  } else if (hostname.includes('member.')) {
    throw redirect(302, '/member');
  } else if (hostname.includes('master.')) {
    throw redirect(302, '/master');
  } else if (hostname.includes('firstmate.')) {
    throw redirect(302, '/firstmate');
  } else if (hostname.includes('seller.')) {
    throw redirect(302, '/seller');
  }
  
  // 主域名访问，检查是否已登录（仅在后端服务可用时）
  try {
    // 检查是否在开发环境或后端服务是否可用
    const isProduction = url.hostname !== 'localhost' && !url.hostname.includes('127.0.0.1');
    
    if (isProduction) {
      // 生产环境：尝试检查会话，但如果失败则降级处理
      try {
        const response = await fetch('/api/sso/session', {
          method: 'GET',
          credentials: 'include'
        });
        
        if (response.ok) {
          const { user } = await response.json();
          
          // 如果已登录，根据角色重定向到对应子域名
          const roleSubdomains = {
            'Fan': 'fan.baidaohui.com',
            'Member': 'member.baidaohui.com',
            'Master': 'master.baidaohui.com',
            'Firstmate': 'firstmate.baidaohui.com',
            'Seller': 'seller.baidaohui.com'
          };
          
          const targetDomain = roleSubdomains[user.role as keyof typeof roleSubdomains];
          if (targetDomain && hostname !== 'localhost') {
            throw redirect(302, `https://${targetDomain}`);
          }
        }
      } catch (apiError) {
        // API调用失败，记录错误但继续执行降级逻辑
        console.log('后端服务不可用，使用降级处理:', apiError);
      }
    }
  } catch (error) {
    // 任何其他错误，记录但不阻止页面加载
    console.log('会话检查失败，使用降级处理:', error);
  }
  
  // 降级处理：直接重定向到登录页面
  // 这样即使后端服务不可用，用户也能看到登录界面
  throw redirect(302, '/login');
}; 