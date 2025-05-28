import { json } from '@sveltejs/kit';

const SSO_SERVICE_URL = process.env.SSO_SERVICE_URL || 'http://localhost:5002';

export async function POST({ request }) {
  try {
    const body = await request.json();
    
    // 转发请求到SSO服务
    const response = await fetch(`${SSO_SERVICE_URL}/sso/validate`, {
      method: 'POST',
      headers: {
        'Cookie': request.headers.get('cookie') || '',
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(body)
    });

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
      error: '服务不可用',
      redirect_url: 'https://baidaohui.com/login'
    }, { status: 500 });
  }
} 