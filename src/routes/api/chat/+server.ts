import { json } from '@sveltejs/kit';
import type { RequestHandler } from '@sveltejs/kit';

// 使用统一的API网关域名
const apiBaseUrl = 'https://api.baidaohui.com';

export const GET: RequestHandler = async ({ url, fetch, cookies }) => {
  try {
    // 获取查询参数
    const searchParams = url.searchParams.toString();
    
    // 获取认证token
    const token = cookies.get('access_token');
    if (!token) {
      return json({ error: '未授权' }, { status: 401 });
    }
    
    // 转发到聊天服务（添加超时保护）
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 8000);
    
    const response = await fetch(`${apiBaseUrl}/chat/${searchParams ? '?' + searchParams : ''}`, {
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
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
    console.error('聊天服务请求失败:', error);
    return json({ error: '聊天服务暂时不可用' }, { status: 500 });
  }
};

export const POST: RequestHandler = async ({ request, fetch, cookies }) => {
  try {
    const data = await request.json();
    
    // 获取认证token
    const token = cookies.get('access_token');
    if (!token) {
      return json({ error: '未授权' }, { status: 401 });
    }
    
    // 转发到聊天服务（添加超时保护）
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 10000);
    
    const response = await fetch(`${apiBaseUrl}/chat/`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`
      },
      body: JSON.stringify(data),
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
    console.error('聊天服务请求失败:', error);
    return json({ error: '聊天服务暂时不可用' }, { status: 500 });
  }
}; 