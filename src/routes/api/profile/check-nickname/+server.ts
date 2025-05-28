import { json } from '@sveltejs/kit';
import type { RequestHandler } from '@sveltejs/kit';

export const GET: RequestHandler = async ({ url, fetch }) => {
  try {
    const nickname = url.searchParams.get('nickname');
    
    if (!nickname) {
      return json({ error: '昵称不能为空' }, { status: 400 });
    }

    // 转发到后端服务
    const response = await fetch(`${process.env.AUTH_SERVICE_URL || 'http://localhost:5001'}/api/profile/check-nickname?nickname=${encodeURIComponent(nickname)}`);
    
    if (!response.ok) {
      const error = await response.json();
      return json(error, { status: response.status });
    }

    const result = await response.json();
    return json(result);
  } catch (error) {
    console.error('检查昵称失败:', error);
    return json({ error: '服务暂时不可用' }, { status: 500 });
  }
}; 