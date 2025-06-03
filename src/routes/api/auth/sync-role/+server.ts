import { json } from '@sveltejs/kit';
import type { RequestHandler } from '@sveltejs/kit';

// 使用统一的API网关域名
const apiBaseUrl = 'https://api.baidaohui.com';

export const POST: RequestHandler = async ({ request, fetch, cookies }) => {
  try {
    // 获取认证token
    const token = cookies.get('access_token');
    if (!token) {
      return json({ error: '未授权' }, { status: 401 });
    }

    const data = await request.json();
    const { userId, forceSync = false } = data;

    if (!userId) {
      return json({ error: '缺少用户ID' }, { status: 400 });
    }
    
    // 转发到认证服务的角色同步接口（添加超时保护）
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 10000);
    
    const response = await fetch(`${apiBaseUrl}/auth/sync-role`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`
      },
      body: JSON.stringify({
        userId,
        forceSync
      }),
      signal: controller.signal
    });
    
    clearTimeout(timeoutId);
    
    if (!response.ok) {
      const error = await response.json();
      return json(error, { status: response.status });
    }

    const result = await response.json();
    return json(result);
  } catch (error) {
    console.error('角色同步失败:', error);
    return json({ error: '认证服务暂时不可用' }, { status: 500 });
  }
}; 