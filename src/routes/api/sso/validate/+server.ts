import { json } from '@sveltejs/kit';
const SSO_SERVICE_URL = import.meta.env.SSO_SERVICE_URL || import.meta.env.VITE_SSO_SERVICE_URL || 'http://107.172.87.113:5002';

export const POST = async ({ request }) => {
  try {
    const body = await request.json();
    
    // 设置请求超时
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 5000);
    
    // 转发请求到SSO服务
    const response = await fetch(`${SSO_SERVICE_URL}/sso/validate`, {
      method: 'POST',
      headers: {
        'Cookie': request.headers.get('cookie') || '',
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(body),
      signal: controller.signal
    });

    clearTimeout(timeoutId);
    const data = await response.json();
    
    return json(data, { 
      status: response.status,
      headers: {
        'Set-Cookie': response.headers.get('set-cookie') || ''
      }
    });
  } catch (error) {
    console.error('SSO验证请求失败:', error);
    return json({ 
      valid: false, 
      error: '验证服务不可用',
      redirect_url: 'https://www.baidaohui.com/login'
    }, { status: 503 });
  }
}; 