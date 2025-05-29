import { json } from '@sveltejs/kit';
import type { RequestHandler } from '@sveltejs/kit';

const EMAIL_SERVICE_URL = import.meta.env.EMAIL_SERVICE_URL || import.meta.env.VITE_EMAIL_SERVICE_URL || 'http://216.144.233.104:5008';

export const POST: RequestHandler = async ({ request, cookies }) => {
    try {
        const data = await request.json();
        
        // 从Cookie获取用户token（如果需要）
        const accessToken = cookies.get('access_token');
        
        // 转发请求到邮件服务（添加超时保护）
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), 10000); // 邮件发送可能需要更长时间
        
        const response = await fetch(`${EMAIL_SERVICE_URL}/email/send-custom`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                ...(accessToken && { 'Authorization': `Bearer ${accessToken}` })
            },
            body: JSON.stringify({
                ...data,
                jwt_token: accessToken // 传递JWT用于获取用户邮箱
            }),
            signal: controller.signal
        });
        
        clearTimeout(timeoutId);
        const result = await response.json();
        
        if (!response.ok) {
            return json({ error: result.error || '邮件发送失败' }, { status: response.status });
        }
        
        return json(result);
        
    } catch (error) {
        console.error('邮件发送代理失败:', error);
        return json({ error: '邮件服务不可用' }, { status: 500 });
    }
}; 