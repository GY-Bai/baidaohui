import { json } from '@sveltejs/kit';
import type { RequestHandler } from '@sveltejs/kit';

export const GET: RequestHandler = async ({ url, fetch, cookies }) => {
  try {
    const userId = url.searchParams.get('userId');
    
    if (!userId) {
      return json({ error: '用户ID不能为空' }, { status: 400 });
    }

    // 获取认证token
    const token = cookies.get('access_token');
    if (!token) {
      return json({ error: '未授权' }, { status: 401 });
    }

    // 使用统一的API网关域名
    const apiBaseUrl = 'https://api.baidaohui.com';
    
    // 转发到后端服务（添加超时保护）
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 5000);
    
    const response = await fetch(`${apiBaseUrl}/auth/api/profile/master-stats?userId=${encodeURIComponent(userId)}`, {
      headers: {
        'Authorization': `Bearer ${token}`
      },
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
    console.error('获取Master统计失败:', error);
    return json({ error: '服务暂时不可用' }, { status: 500 });
  }
}; 