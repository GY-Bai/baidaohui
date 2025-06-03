import { json } from '@sveltejs/kit';
import type { RequestHandler } from '@sveltejs/kit';

export const GET: RequestHandler = async ({ url, fetch }) => {
  try {
    const nickname = url.searchParams.get('nickname');
    
    if (!nickname) {
      return json({ error: '昵称不能为空' }, { status: 400 });
    }

    // 使用统一的API网关域名
    const apiBaseUrl = 'https://api.baidaohui.com';
    
    // 转发到后端服务（添加超时保护）
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 5000);
    
    const response = await fetch(`${apiBaseUrl}/auth/api/profile/check-nickname?nickname=${encodeURIComponent(nickname)}`, {
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
    console.error('检查昵称失败:', error);
    return json({ error: '服务暂时不可用' }, { status: 500 });
  }
}; 