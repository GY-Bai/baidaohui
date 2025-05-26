/**
 * Cloudflare Email Workers 微服务
 * 监听 Redis stream 'notifications'，发送 inform1/2/3/8 邮件模版
 */

// Cloudflare Workers 类型定义
interface ScheduledEvent {
  scheduledTime: number;
  cron: string;
}

interface ExecutionContext {
  waitUntil(promise: Promise<any>): void;
  passThroughOnException(): void;
}

interface Env {
  // Cloudflare Email Routing 配置
  EMAIL_ROUTING_API_TOKEN: string;
  EMAIL_ROUTING_ZONE_ID: string;
  
  // Redis 配置
  REDIS_URL: string;
  REDIS_PASSWORD?: string;
  
  // 邮件配置
  FROM_EMAIL: string;
  REPLY_TO_EMAIL: string;
  
  // 外部服务
  SUPABASE_URL: string;
  SUPABASE_SERVICE_ROLE_KEY: string;
}

interface NotificationMessage {
  type: 'inform1' | 'inform2' | 'inform3' | 'inform8';
  to_email: string;
  user_name: string;
  data: Record<string, any>;
  timestamp: number;
  message_id: string;
}

interface EmailTemplate {
  subject: string;
  html: string;
  text: string;
}

// 邮件模板
const EMAIL_TEMPLATES: Record<string, (data: any) => EmailTemplate> = {
  inform1: (data) => ({
    subject: '🎉 欢迎加入百刀会会员！',
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 30px; text-align: center;">
          <h1 style="color: white; margin: 0; font-size: 28px;">🎉 恭喜您！</h1>
          <p style="color: white; margin: 10px 0 0 0; font-size: 18px;">您已成功升级为百刀会会员</p>
        </div>
        
        <div style="padding: 30px; background: #f8f9fa;">
          <h2 style="color: #333; margin-bottom: 20px;">亲爱的 ${data.user_name}，</h2>
          
          <p style="color: #666; line-height: 1.6; margin-bottom: 20px;">
            感谢您使用邀请链接加入百刀会！您的账户已成功升级为会员，现在可以享受以下特权：
          </p>
          
          <ul style="color: #666; line-height: 1.8; margin-bottom: 25px;">
            <li>💬 与主播进行私信聊天</li>
            <li>🔮 提交算命申请并查看历史</li>
            <li>🛍️ 访问专属购物商城</li>
            <li>👤 完整的个人中心功能</li>
          </ul>
          
          <div style="text-align: center; margin: 30px 0;">
            <a href="https://member.baiduohui.com" 
               style="background: #667eea; color: white; padding: 15px 30px; text-decoration: none; border-radius: 5px; font-weight: bold;">
              立即体验会员功能
            </a>
          </div>
          
          <p style="color: #999; font-size: 14px; margin-top: 30px;">
            如有任何问题，请联系我们的客服团队。<br>
            邀请码：${data.invite_code || 'N/A'}<br>
            升级时间：${new Date(data.upgrade_time).toLocaleString('zh-CN')}
          </p>
        </div>
      </div>
    `,
    text: `
恭喜您成功升级为百刀会会员！

亲爱的 ${data.user_name}，

感谢您使用邀请链接加入百刀会！您现在可以享受以下会员特权：

• 与主播进行私信聊天
• 提交算命申请并查看历史  
• 访问专属购物商城
• 完整的个人中心功能

立即访问：https://member.baiduohui.com

邀请码：${data.invite_code || 'N/A'}
升级时间：${new Date(data.upgrade_time).toLocaleString('zh-CN')}

如有任何问题，请联系我们的客服团队。
    `
  }),

  inform2: (data) => ({
    subject: '🔮 您的算命申请已有回复',
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <div style="background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%); padding: 30px; text-align: center;">
          <h1 style="color: white; margin: 0; font-size: 28px;">🔮 算命回复</h1>
          <p style="color: white; margin: 10px 0 0 0; font-size: 18px;">您的申请已得到回复</p>
        </div>
        
        <div style="padding: 30px; background: #f8f9fa;">
          <h2 style="color: #333; margin-bottom: 20px;">亲爱的 ${data.user_name}，</h2>
          
          <p style="color: #666; line-height: 1.6; margin-bottom: 20px;">
            您的算命申请（订单号：${data.order_number}）已得到回复！
          </p>
          
          <div style="background: white; padding: 20px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #f5576c;">
            <h3 style="color: #333; margin-top: 0;">申请信息</h3>
            <p style="color: #666; margin: 5px 0;"><strong>金额：</strong>${data.amount} ${data.currency}</p>
            <p style="color: #666; margin: 5px 0;"><strong>提交时间：</strong>${new Date(data.submit_time).toLocaleString('zh-CN')}</p>
            <p style="color: #666; margin: 5px 0;"><strong>回复时间：</strong>${new Date(data.reply_time).toLocaleString('zh-CN')}</p>
          </div>
          
          <div style="text-align: center; margin: 30px 0;">
            <a href="https://member.baiduohui.com/fortune/history/${data.order_id}" 
               style="background: #f5576c; color: white; padding: 15px 30px; text-decoration: none; border-radius: 5px; font-weight: bold;">
              查看完整回复
            </a>
          </div>
          
          <p style="color: #999; font-size: 14px; margin-top: 30px;">
            请及时查看您的算命结果。如有疑问，可通过私信功能联系主播。
          </p>
        </div>
      </div>
    `,
    text: `
您的算命申请已有回复！

亲爱的 ${data.user_name}，

您的算命申请（订单号：${data.order_number}）已得到回复！

申请信息：
• 金额：${data.amount} ${data.currency}
• 提交时间：${new Date(data.submit_time).toLocaleString('zh-CN')}
• 回复时间：${new Date(data.reply_time).toLocaleString('zh-CN')}

查看完整回复：https://member.baiduohui.com/fortune/history/${data.order_id}

请及时查看您的算命结果。如有疑问，可通过私信功能联系主播。
    `
  }),

  inform3: (data) => ({
    subject: '💰 退款确认通知',
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <div style="background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%); padding: 30px; text-align: center;">
          <h1 style="color: white; margin: 0; font-size: 28px;">💰 退款确认</h1>
          <p style="color: white; margin: 10px 0 0 0; font-size: 18px;">您的退款申请已处理</p>
        </div>
        
        <div style="padding: 30px; background: #f8f9fa;">
          <h2 style="color: #333; margin-bottom: 20px;">亲爱的 ${data.user_name}，</h2>
          
          <p style="color: #666; line-height: 1.6; margin-bottom: 20px;">
            您的退款申请已成功处理，退款将在3-5个工作日内到账。
          </p>
          
          <div style="background: white; padding: 20px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #00f2fe;">
            <h3 style="color: #333; margin-top: 0;">退款详情</h3>
            <p style="color: #666; margin: 5px 0;"><strong>订单号：</strong>${data.order_number}</p>
            <p style="color: #666; margin: 5px 0;"><strong>退款金额：</strong>${data.refund_amount} ${data.currency}</p>
            <p style="color: #666; margin: 5px 0;"><strong>退款方式：</strong>${data.refund_method}</p>
            <p style="color: #666; margin: 5px 0;"><strong>处理时间：</strong>${new Date(data.refund_time).toLocaleString('zh-CN')}</p>
            <p style="color: #666; margin: 5px 0;"><strong>退款原因：</strong>${data.refund_reason}</p>
          </div>
          
          <div style="background: #e3f2fd; padding: 15px; border-radius: 5px; margin: 20px 0;">
            <p style="color: #1976d2; margin: 0; font-size: 14px;">
              <strong>注意：</strong>退款将原路返回到您的支付账户，请注意查收。如有疑问，请联系客服。
            </p>
          </div>
          
          <p style="color: #999; font-size: 14px; margin-top: 30px;">
            感谢您对百刀会的支持与理解。
          </p>
        </div>
      </div>
    `,
    text: `
退款确认通知

亲爱的 ${data.user_name}，

您的退款申请已成功处理，退款将在3-5个工作日内到账。

退款详情：
• 订单号：${data.order_number}
• 退款金额：${data.refund_amount} ${data.currency}
• 退款方式：${data.refund_method}
• 处理时间：${new Date(data.refund_time).toLocaleString('zh-CN')}
• 退款原因：${data.refund_reason}

注意：退款将原路返回到您的支付账户，请注意查收。如有疑问，请联系客服。

感谢您对百刀会的支持与理解。
    `
  }),

  inform8: (data) => ({
    subject: '🛍️ 购物订单通知',
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <div style="background: linear-gradient(135deg, #fa709a 0%, #fee140 100%); padding: 30px; text-align: center;">
          <h1 style="color: white; margin: 0; font-size: 28px;">🛍️ 购物通知</h1>
          <p style="color: white; margin: 10px 0 0 0; font-size: 18px;">您的订单状态已更新</p>
        </div>
        
        <div style="padding: 30px; background: #f8f9fa;">
          <h2 style="color: #333; margin-bottom: 20px;">亲爱的 ${data.user_name}，</h2>
          
          <p style="color: #666; line-height: 1.6; margin-bottom: 20px;">
            您在百刀会商城的订单状态已更新：
          </p>
          
          <div style="background: white; padding: 20px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #fa709a;">
            <h3 style="color: #333; margin-top: 0;">订单信息</h3>
            <p style="color: #666; margin: 5px 0;"><strong>订单号：</strong>${data.order_number}</p>
            <p style="color: #666; margin: 5px 0;"><strong>订单状态：</strong>${data.order_status}</p>
            <p style="color: #666; margin: 5px 0;"><strong>订单金额：</strong>${data.total_amount} ${data.currency}</p>
            <p style="color: #666; margin: 5px 0;"><strong>更新时间：</strong>${new Date(data.update_time).toLocaleString('zh-CN')}</p>
          </div>
          
          ${data.tracking_number ? `
          <div style="background: #e8f5e8; padding: 15px; border-radius: 5px; margin: 20px 0;">
            <p style="color: #2e7d32; margin: 0; font-size: 14px;">
              <strong>物流信息：</strong>您的订单已发货，快递单号：${data.tracking_number}
            </p>
          </div>
          ` : ''}
          
          <div style="text-align: center; margin: 30px 0;">
            <a href="https://buyer.shop.baiduohui.com/order/${data.order_id}" 
               style="background: #fa709a; color: white; padding: 15px 30px; text-decoration: none; border-radius: 5px; font-weight: bold;">
              查看订单详情
            </a>
          </div>
          
          <p style="color: #999; font-size: 14px; margin-top: 30px;">
            如有任何问题，请联系我们的客服团队。
          </p>
        </div>
      </div>
    `,
    text: `
购物订单通知

亲爱的 ${data.user_name}，

您在百刀会商城的订单状态已更新：

订单信息：
• 订单号：${data.order_number}
• 订单状态：${data.order_status}
• 订单金额：${data.total_amount} ${data.currency}
• 更新时间：${new Date(data.update_time).toLocaleString('zh-CN')}

${data.tracking_number ? `物流信息：您的订单已发货，快递单号：${data.tracking_number}` : ''}

查看订单详情：https://buyer.shop.baiduohui.com/order/${data.order_id}

如有任何问题，请联系我们的客服团队。
    `
  })
};

export default {
  async scheduled(event: ScheduledEvent, env: Env, ctx: ExecutionContext): Promise<void> {
    ctx.waitUntil(processNotifications(env));
  },

  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);
    
    if (url.pathname === '/health') {
      try {
        // 检查必需的环境变量
        const requiredEnvVars = ['REDIS_URL', 'FROM_EMAIL', 'EMAIL_ROUTING_API_TOKEN', 'EMAIL_ROUTING_ZONE_ID'];
        const missingVars = requiredEnvVars.filter(varName => !env[varName]);
        
        if (missingVars.length > 0) {
          return new Response(JSON.stringify({
            status: 'unhealthy',
            service: 'notifications-worker',
            timestamp: new Date().toISOString(),
            version: '1.0.0',
            error: `Missing environment variables: ${missingVars.join(', ')}`
          }), { 
            status: 500,
            headers: { 'Content-Type': 'application/json' }
          });
        }
        
        // 尝试连接Redis
        try {
          const redis = await connectRedis(env);
          // 简单的ping测试
          await redis.xread('BLOCK', 0, 'COUNT', 1, 'STREAMS', 'notifications', '$');
        } catch (error) {
          return new Response(JSON.stringify({
            status: 'unhealthy',
            service: 'notifications-worker',
            timestamp: new Date().toISOString(),
            version: '1.0.0',
            error: `Redis connection failed: ${error.message}`
          }), { 
            status: 500,
            headers: { 'Content-Type': 'application/json' }
          });
        }
        
        return new Response(JSON.stringify({
          status: 'healthy',
          service: 'notifications-worker',
          timestamp: new Date().toISOString(),
          version: '1.0.0',
          services: {
            redis: 'ok',
            environment: 'ok'
          }
        }), { 
          status: 200,
          headers: { 'Content-Type': 'application/json' }
        });
        
      } catch (error) {
        return new Response(JSON.stringify({
          status: 'unhealthy',
          service: 'notifications-worker',
          timestamp: new Date().toISOString(),
          version: '1.0.0',
          error: error.message
        }), { 
          status: 500,
          headers: { 'Content-Type': 'application/json' }
        });
      }
    }
    
    if (url.pathname === '/process' && request.method === 'POST') {
      ctx.waitUntil(processNotifications(env));
      return new Response('Processing started', { status: 200 });
    }
    
    return new Response('Not Found', { status: 404 });
  }
};

async function processNotifications(env: Env): Promise<void> {
  try {
    console.log('Starting notification processing...');
    
    // 连接Redis
    const redis = await connectRedis(env);
    
    // 读取通知流
    const messages = await redis.xread('BLOCK', 1000, 'STREAMS', 'notifications', '$');
    
    if (!messages || messages.length === 0) {
      console.log('No new notifications');
      return;
    }
    
    for (const stream of messages) {
      const [streamName, streamMessages] = stream;
      
      for (const message of streamMessages) {
        const [messageId, fields] = message;
        
        try {
          // 解析消息
          const notification = parseNotificationMessage(fields);
          
          // 发送邮件
          await sendEmail(env, notification);
          
          // 确认消息已处理
          await redis.xack('notifications', 'email-worker', messageId);
          
          console.log(`Processed notification ${messageId} for ${notification.to_email}`);
          
        } catch (error) {
          console.error(`Failed to process message ${messageId}:`, error);
          
          // 将失败的消息移到死信队列
          await redis.xadd('notifications:failed', '*', ...fields, 'error', error.message, 'failed_at', Date.now());
        }
      }
    }
    
  } catch (error) {
    console.error('Error processing notifications:', error);
  }
}

async function connectRedis(env: Env): Promise<any> {
  // 这里应该使用实际的Redis客户端
  // 由于Cloudflare Workers的限制，可能需要使用HTTP API或其他方式
  // 这是一个简化的示例
  
  const redisUrl = new URL(env.REDIS_URL);
  
  // 使用Redis HTTP API或其他兼容的方式
  return {
    async xread(...args: any[]) {
      // 实现Redis XREAD命令
      const response = await fetch(`${redisUrl.origin}/xread`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${env.REDIS_PASSWORD}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ command: 'XREAD', args })
      });
      
      if (!response.ok) {
        throw new Error(`Redis XREAD failed: ${response.statusText}`);
      }
      
      return await response.json();
    },
    
    async xack(...args: any[]) {
      // 实现Redis XACK命令
      const response = await fetch(`${redisUrl.origin}/xack`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${env.REDIS_PASSWORD}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ command: 'XACK', args })
      });
      
      return await response.json();
    },
    
    async xadd(...args: any[]) {
      // 实现Redis XADD命令
      const response = await fetch(`${redisUrl.origin}/xadd`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${env.REDIS_PASSWORD}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ command: 'XADD', args })
      });
      
      return await response.json();
    }
  };
}

function parseNotificationMessage(fields: string[]): NotificationMessage {
  const data: Record<string, string> = {};
  
  for (let i = 0; i < fields.length; i += 2) {
    data[fields[i]] = fields[i + 1];
  }
  
  return {
    type: data.type as any,
    to_email: data.to_email,
    user_name: data.user_name,
    data: JSON.parse(data.data || '{}'),
    timestamp: parseInt(data.timestamp),
    message_id: data.message_id
  };
}

async function sendEmail(env: Env, notification: NotificationMessage): Promise<void> {
  try {
    // 获取邮件模板
    const templateFn = EMAIL_TEMPLATES[notification.type];
    if (!templateFn) {
      throw new Error(`Unknown notification type: ${notification.type}`);
    }
    
    const template = templateFn(notification.data);
    
    // 构建邮件数据
    const emailData = {
      from: env.FROM_EMAIL,
      to: notification.to_email,
      reply_to: env.REPLY_TO_EMAIL,
      subject: template.subject,
      html: template.html,
      text: template.text,
      headers: {
        'X-Notification-Type': notification.type,
        'X-Message-ID': notification.message_id,
        'X-Timestamp': notification.timestamp.toString()
      }
    };
    
    // 使用Cloudflare Email Routing API发送邮件
    const response = await fetch(`https://api.cloudflare.com/client/v4/zones/${env.EMAIL_ROUTING_ZONE_ID}/email/routing/addresses`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${env.EMAIL_ROUTING_API_TOKEN}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(emailData)
    });
    
    if (!response.ok) {
      const error = await response.text();
      throw new Error(`Email sending failed: ${response.status} ${error}`);
    }
    
    console.log(`Email sent successfully to ${notification.to_email} (${notification.type})`);
    
  } catch (error) {
    console.error(`Failed to send email to ${notification.to_email}:`, error);
    throw error;
  }
} 