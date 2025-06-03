import { json } from '@sveltejs/kit';
import type { RequestHandler } from '@sveltejs/kit';

// 使用统一的API网关域名
const apiBaseUrl = 'https://api.baidaohui.com';

export const GET: RequestHandler = async ({ url, fetch, cookies }) => {
  try {
    // 获取查询参数
    const searchParams = url.searchParams.toString();
    
    // 获取认证token - 算命服务的某些接口可能不需要认证
    const token = cookies.get('access_token');
    
    // 转发到算命服务（添加超时保护）
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 10000);
    
    const headers: Record<string, string> = {
      'Content-Type': 'application/json'
    };
    
    if (token) {
      headers['Authorization'] = `Bearer ${token}`;
    }
    
    const response = await fetch(`${apiBaseUrl}/fortune${searchParams ? '?' + searchParams : ''}`, {
      headers,
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
    console.error('算命服务请求失败:', error);
    return json({ error: '算命服务暂时不可用' }, { status: 500 });
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
    
    // 转发到算命服务（添加超时保护）
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 15000); // 算命服务可能需要更长处理时间
    
    const response = await fetch(`${apiBaseUrl}/fortune`, {
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
    console.error('算命服务请求失败:', error);
    return json({ error: '算命服务暂时不可用' }, { status: 500 });
  }
}; 