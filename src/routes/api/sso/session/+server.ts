import { json } from '@sveltejs/kit';

const SSO_SERVICE_URL = import.meta.env.SSO_SERVICE_URL || import.meta.env.VITE_SSO_SERVICE_URL || 'http://localhost:5002';

export const GET = async ({ request, cookies }) => {
  try {
    // 转发请求到SSO服务
    const response = await fetch(`${SSO_SERVICE_URL}/sso/session`, {
      method: 'GET',
      headers: {
        'Cookie': request.headers.get('cookie') || '',
        'Content-Type': 'application/json'
      }
    });

    const data = await response.json();
    
    return json(data, { 
      status: response.status,
      headers: {
        'Set-Cookie': response.headers.get('set-cookie') || ''
      }
    });
  } catch (error) {
    console.error('SSO会话请求失败:', error);
    // 返回503状态码表示服务不可用
    return json({ 
      session: null, 
      error: '后端服务不可用',
      service_available: false 
    }, { status: 503 });
  }
}; 