import Mailjet from 'node-mailjet';

// Mailjet配置
const MJ_APIKEY_PUBLIC = process.env.MJ_APIKEY_PUBLIC;
const MJ_APIKEY_PRIVATE = process.env.MJ_APIKEY_PRIVATE;
const FROM_EMAIL = process.env.FROM_EMAIL;
const REPLY_TO_EMAIL = process.env.REPLY_TO_EMAIL || FROM_EMAIL;

// 初始化Mailjet客户端
const mailjet = Mailjet.apiConnect(MJ_APIKEY_PUBLIC, MJ_APIKEY_PRIVATE);

/**
 * 使用Mailjet发送邮件
 * @param {string} to - 收件人邮箱
 * @param {string} subject - 邮件主题
 * @param {string} text - 纯文本内容
 * @param {string} html - HTML内容（可选）
 * @returns {Promise<boolean>} 发送是否成功
 */
export async function sendMail(to, subject, text, html = null) {
  try {
    const messageData = {
      From: {
        Email: FROM_EMAIL,
        Name: '百刀会通知'
      },
      To: [{ Email: to }],
      Subject: subject,
      TextPart: text,
      ReplyTo: {
        Email: REPLY_TO_EMAIL,
        Name: '百刀会客服'
      }
    };

    // 如果提供了HTML内容，添加到邮件中
    if (html) {
      messageData.HTMLPart = html;
    }

    const result = await mailjet
      .post('send', { version: 'v3.1' })
      .request({
        Messages: [messageData],
      });

    if (result.response.status === 200) {
      console.log('邮件发送成功:', to);
      return true;
    } else {
      console.error('Mailjet API错误:', result.response.status, result.response.statusText);
      return false;
    }
  } catch (error) {
    console.error('邮件发送失败:', error);
    return false;
  }
}

/**
 * 发送验证码邮件
 * @param {string} to - 收件人邮箱
 * @param {string} code - 验证码
 * @returns {Promise<boolean>} 发送是否成功
 */
export async function sendVerificationEmail(to, code) {
  const subject = "百刀会 - 邮箱验证码";
  const text = `您的验证码是：${code}，有效期为10分钟。`;
  const html = `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
      <h2 style="color: #2563eb; text-align: center;">百刀会邮箱验证</h2>
      <div style="background-color: #f8fafc; padding: 20px; border-radius: 8px; margin: 20px 0;">
        <p>您好！</p>
        <p>您正在进行邮箱验证，您的验证码是：</p>
        <div style="text-align: center; margin: 20px 0;">
          <span style="font-size: 24px; font-weight: bold; color: #dc2626; background-color: #fef2f2; padding: 10px 20px; border-radius: 4px; letter-spacing: 2px;">
            ${code}
          </span>
        </div>
        <p>验证码有效期为10分钟，请及时使用。</p>
        <p>如果您没有请求此验证码，请忽略此邮件。</p>
      </div>
      <div style="text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #e5e7eb;">
        <p style="color: #6b7280; font-size: 14px;">
          此邮件由系统自动发送，请勿回复。<br>
          © 2024 百刀会. 保留所有权利。
        </p>
      </div>
    </div>
  `;

  return await sendMail(to, subject, text, html);
}

/**
 * 发送算命回复通知邮件
 * @param {string} to - 收件人邮箱
 * @param {string} orderId - 订单号
 * @param {string} replyContent - 回复内容
 * @param {string} masterName - 大师名称
 * @returns {Promise<boolean>} 发送是否成功
 */
export async function sendFortuneReplyEmail(to, orderId, replyContent, masterName = '大师') {
  const subject = `百刀会 - 您的算命申请已回复 - 订单${orderId}`;
  const text = `
您好！

您的算命申请（订单号：${orderId}）已收到回复：

${replyContent}

回复时间：${new Date().toLocaleString('zh-CN')}
回复人：${masterName}

感谢您使用百刀会的服务！

百刀会团队
  `;

  const html = `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
      <h2 style="color: #4CAF50; text-align: center;">百刀会</h2>
      <h3>您的算命申请已收到回复</h3>
      
      <div style="background-color: #f8f9fa; border-left: 4px solid #4CAF50; padding: 15px; margin: 20px 0;">
        <strong>订单信息：</strong><br>
        订单号：${orderId}<br>
        回复时间：${new Date().toLocaleString('zh-CN')}<br>
        回复人：${masterName}
      </div>
      
      <div style="background-color: #fff3cd; border: 1px solid #ffeaa7; border-radius: 8px; padding: 20px; margin: 20px 0;">
        <h4 style="color: #856404; margin-top: 0;">🔮 大师回复</h4>
        <div style="white-space: pre-wrap; line-height: 1.8;">${replyContent}</div>
      </div>
      
      <div style="text-align: center; margin: 20px 0;">
        <a href="https://fan.baidaohui.com/fortune" style="background-color: #4CAF50; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; font-weight: bold;">查看完整回复</a>
      </div>
      
      <div style="background-color: #f0f0f0; padding: 15px; margin: 20px 0; font-size: 14px;">
        <strong>温馨提示：</strong>
        <ul>
          <li>此回复仅供参考，请理性对待</li>
          <li>如有疑问，可通过会员私信功能联系大师</li>
          <li>感谢您对百刀会的信任与支持</li>
        </ul>
      </div>
      
      <div style="text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee; color: #666; font-size: 14px;">
        <p>此邮件由系统自动发送，请勿直接回复</p>
        <p>© 2024 百刀会 - 专业的命理咨询平台</p>
      </div>
    </div>
  `;

  return await sendMail(to, subject, text, html);
} 