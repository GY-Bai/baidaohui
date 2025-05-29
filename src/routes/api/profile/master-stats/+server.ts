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

    // 转发到后端服务
    const response = await fetch(`${import.meta.env.AUTH_SERVICE_URL || import.meta.env.VITE_AUTH_SERVICE_URL || 'http://localhost:5001'}/api/profile/master-stats?userId=${encodeURIComponent(userId)}`, {
      headers: {
        'Authorization': `Bearer ${token}`
      }
    });
    
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