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
  
  // 主域名访问，检查是否已登录
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
  } catch (error) {
    // 如果检查会话失败，继续显示主页
    console.log('会话检查失败，显示主页');
  }
  
  // 未登录或检查失败，重定向到登录页面
  throw redirect(302, '/login');
}; 