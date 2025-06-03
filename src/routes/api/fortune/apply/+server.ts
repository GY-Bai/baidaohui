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

    // 获取FormData
    const formData = await request.formData();
    
    // 转发到算命服务（添加超时保护）
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 15000); // 算命申请可能需要更长处理时间
    
    const response = await fetch(`${apiBaseUrl}/fortune/apply`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`
      },
      body: formData,
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
    console.error('算命申请失败:', error);
    return json({ error: '算命服务暂时不可用' }, { status: 500 });
  }
}; 