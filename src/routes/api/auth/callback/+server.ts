import { json } from '@sveltejs/kit';

const AUTH_SERVICE_URL = import.meta.env.AUTH_SERVICE_URL || import.meta.env.VITE_AUTH_SERVICE_URL || 'http://107.172.87.113:5001';
const SSO_SERVICE_URL = import.meta.env.SSO_SERVICE_URL || import.meta.env.VITE_SSO_SERVICE_URL || 'http://107.172.87.113:5002';

export async function POST({ request, cookies }) {
  try {
    const body = await request.json();
    
    // 转发OAuth回调到auth-service（添加超时保护）
    const controller1 = new AbortController();
    const timeoutId1 = setTimeout(() => controller1.abort(), 10000); // 10秒超时
    
    const authResponse = await fetch(`${AUTH_SERVICE_URL}/auth/callback`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(body),
      signal: controller1.signal
    });
    
    clearTimeout(timeoutId1);

    if (!authResponse.ok) {
      const errorData = await authResponse.json();
      return json(errorData, { status: authResponse.status });
    }

    const authData = await authResponse.json();
    
    // 使用SSO服务设置跨子域会话（添加超时保护）
    const controller2 = new AbortController();
    const timeoutId2 = setTimeout(() => controller2.abort(), 5000); // 5秒超时
    
    const ssoResponse = await fetch(`${SSO_SERVICE_URL}/sso/set-session`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        user: authData.user
      }),
      signal: controller2.signal
    });
    
    clearTimeout(timeoutId2);

    if (!ssoResponse.ok) {
      console.error('设置SSO会话失败');
      return json({ error: '设置会话失败' }, { status: 500 });
    }

    const ssoData = await ssoResponse.json();
    
    // 获取Set-Cookie头并设置到响应中
    const setCookieHeader = ssoResponse.headers.get('set-cookie');
    
    const response = json({
      user: authData.user,
      access_token: authData.access_token,
      target_domain: authData.target_domain
    });

    if (setCookieHeader) {
      response.headers.set('Set-Cookie', setCookieHeader);
    }

    return response;
    
  } catch (error) {
    console.error('OAuth回调处理失败:', error);
    return json({ error: 'OAuth回调处理失败' }, { status: 500 });
  }
} 