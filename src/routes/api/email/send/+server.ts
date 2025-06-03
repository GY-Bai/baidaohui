import { json } from '@sveltejs/kit';
import type { RequestHandler } from '@sveltejs/kit';

// 使用统一的API网关域名
const apiBaseUrl = 'https://api.baidaohui.com';

export const POST: RequestHandler = async ({ request, cookies }) => {
    try {
        const data = await request.json();
        
        // 从Cookie获取用户token（如果需要）
        const accessToken = cookies.get('access_token');
        
        // 转发请求到邮件服务（添加超时保护）
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), 10000); // 邮件发送可能需要更长时间
        
        const response = await fetch(`${apiBaseUrl}/email/send`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                ...(accessToken && { 'Authorization': `Bearer ${accessToken}` })
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
        console.error('邮件发送失败:', error);
        return json({ error: '邮件服务暂时不可用' }, { status: 500 });
    }
}; 