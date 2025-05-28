from flask import Flask, request, jsonify
from flask_cors import CORS
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import os
import logging
from datetime import datetime
import requests

app = Flask(__name__)
CORS(app)

# 配置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# 邮件配置
SMTP_SERVER = os.getenv('SMTP_SERVER', 'smtp.gmail.com')
SMTP_PORT = int(os.getenv('SMTP_PORT', '587'))
SMTP_USERNAME = os.getenv('SMTP_USERNAME')
SMTP_PASSWORD = os.getenv('SMTP_PASSWORD')
FROM_EMAIL = os.getenv('FROM_EMAIL', SMTP_USERNAME)

# 验证必要的环境变量
if not SMTP_USERNAME or not SMTP_PASSWORD:
    logger.error("SMTP配置不完整，请检查环境变量")

@app.route('/health', methods=['GET'])
def health_check():
    """健康检查"""
    return jsonify({
        'status': 'healthy',
        'service': 'email-service',
        'timestamp': datetime.utcnow().isoformat()
    })

@app.route('/send', methods=['POST'])
def send_email():
    """发送邮件"""
    try:
        data = request.get_json()
        
        # 验证必需字段
        required_fields = ['to', 'subject', 'content']
        for field in required_fields:
            if not data.get(field):
                return jsonify({
                    'success': False,
                    'error': f'缺少必需字段: {field}'
                }), 400
        
        to_email = data['to']
        subject = data['subject']
        content = data['content']
        content_type = data.get('content_type', 'text')  # 'text' 或 'html'
        
        # 创建邮件
        msg = MIMEMultipart()
        msg['From'] = FROM_EMAIL
        msg['To'] = to_email
        msg['Subject'] = subject
        
        # 添加邮件内容
        if content_type == 'html':
            msg.attach(MIMEText(content, 'html', 'utf-8'))
        else:
            msg.attach(MIMEText(content, 'plain', 'utf-8'))
        
        # 发送邮件
        with smtplib.SMTP(SMTP_SERVER, SMTP_PORT) as server:
            server.starttls()
            server.login(SMTP_USERNAME, SMTP_PASSWORD)
            server.send_message(msg)
        
        logger.info(f"邮件发送成功: {to_email}")
        
        return jsonify({
            'success': True,
            'message': '邮件发送成功'
        })
        
    except Exception as e:
        logger.error(f"发送邮件失败: {str(e)}")
        return jsonify({
            'success': False,
            'error': f'发送邮件失败: {str(e)}'
        }), 500

@app.route('/send-verification', methods=['POST'])
def send_verification_email():
    """发送验证邮件"""
    try:
        data = request.get_json()
        
        to_email = data.get('email')
        verification_code = data.get('code')
        
        if not to_email or not verification_code:
            return jsonify({
                'success': False,
                'error': '缺少邮箱地址或验证码'
            }), 400
        
        # 邮件内容
        subject = "百道会 - 邮箱验证码"
        content = f"""
        <html>
        <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
            <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                <h2 style="color: #2563eb; text-align: center;">百道会邮箱验证</h2>
                
                <div style="background-color: #f8fafc; padding: 20px; border-radius: 8px; margin: 20px 0;">
                    <p>您好！</p>
                    <p>您正在进行邮箱验证，您的验证码是：</p>
                    <div style="text-align: center; margin: 20px 0;">
                        <span style="font-size: 24px; font-weight: bold; color: #dc2626; background-color: #fef2f2; padding: 10px 20px; border-radius: 4px; letter-spacing: 2px;">
                            {verification_code}
                        </span>
                    </div>
                    <p>验证码有效期为10分钟，请及时使用。</p>
                    <p>如果您没有请求此验证码，请忽略此邮件。</p>
                </div>
                
                <div style="text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #e5e7eb;">
                    <p style="color: #6b7280; font-size: 14px;">
                        此邮件由系统自动发送，请勿回复。<br>
                        © 2024 百道会. 保留所有权利。
                    </p>
                </div>
            </div>
        </body>
        </html>
        """
        
        # 发送邮件
        return send_email_internal(to_email, subject, content, 'html')
        
    except Exception as e:
        logger.error(f"发送验证邮件失败: {str(e)}")
        return jsonify({
            'success': False,
            'error': f'发送验证邮件失败: {str(e)}'
        }), 500

@app.route('/send-notification', methods=['POST'])
def send_notification_email():
    """发送通知邮件"""
    try:
        data = request.get_json()
        
        to_email = data.get('email')
        notification_type = data.get('type')
        notification_data = data.get('data', {})
        
        if not to_email or not notification_type:
            return jsonify({
                'success': False,
                'error': '缺少邮箱地址或通知类型'
            }), 400
        
        # 根据通知类型生成邮件内容
        subject, content = generate_notification_content(notification_type, notification_data)
        
        if not subject or not content:
            return jsonify({
                'success': False,
                'error': '不支持的通知类型'
            }), 400
        
        # 发送邮件
        return send_email_internal(to_email, subject, content, 'html')
        
    except Exception as e:
        logger.error(f"发送通知邮件失败: {str(e)}")
        return jsonify({
            'success': False,
            'error': f'发送通知邮件失败: {str(e)}'
        }), 500

def send_email_internal(to_email, subject, content, content_type='text'):
    """内部邮件发送函数"""
    try:
        # 创建邮件
        msg = MIMEMultipart()
        msg['From'] = FROM_EMAIL
        msg['To'] = to_email
        msg['Subject'] = subject
        
        # 添加邮件内容
        if content_type == 'html':
            msg.attach(MIMEText(content, 'html', 'utf-8'))
        else:
            msg.attach(MIMEText(content, 'plain', 'utf-8'))
        
        # 发送邮件
        with smtplib.SMTP(SMTP_SERVER, SMTP_PORT) as server:
            server.starttls()
            server.login(SMTP_USERNAME, SMTP_PASSWORD)
            server.send_message(msg)
        
        logger.info(f"邮件发送成功: {to_email}")
        
        return jsonify({
            'success': True,
            'message': '邮件发送成功'
        })
        
    except Exception as e:
        logger.error(f"发送邮件失败: {str(e)}")
        return jsonify({
            'success': False,
            'error': f'发送邮件失败: {str(e)}'
        }), 500

def generate_notification_content(notification_type, data):
    """生成通知邮件内容"""
    
    if notification_type == 'payment_success':
        subject = "百道会 - 支付成功通知"
        content = f"""
        <html>
        <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
            <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                <h2 style="color: #059669; text-align: center;">支付成功</h2>
                
                <div style="background-color: #f0fdf4; padding: 20px; border-radius: 8px; margin: 20px 0;">
                    <p>您好！</p>
                    <p>您的支付已成功完成：</p>
                    <ul>
                        <li><strong>订单号：</strong>{data.get('order_id', 'N/A')}</li>
                        <li><strong>金额：</strong>¥{data.get('amount', 'N/A')}</li>
                        <li><strong>服务：</strong>{data.get('service', 'N/A')}</li>
                        <li><strong>时间：</strong>{data.get('timestamp', datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S'))}</li>
                    </ul>
                    <p>感谢您使用百道会的服务！</p>
                </div>
                
                <div style="text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #e5e7eb;">
                    <p style="color: #6b7280; font-size: 14px;">
                        此邮件由系统自动发送，请勿回复。<br>
                        © 2024 百道会. 保留所有权利。
                    </p>
                </div>
            </div>
        </body>
        </html>
        """
        return subject, content
    
    elif notification_type == 'fortune_completed':
        subject = "百道会 - 算命服务完成"
        content = f"""
        <html>
        <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
            <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                <h2 style="color: #7c3aed; text-align: center;">算命服务完成</h2>
                
                <div style="background-color: #faf5ff; padding: 20px; border-radius: 8px; margin: 20px 0;">
                    <p>您好！</p>
                    <p>您的算命服务已完成，请登录查看详细结果。</p>
                    <ul>
                        <li><strong>服务类型：</strong>{data.get('service_type', 'N/A')}</li>
                        <li><strong>完成时间：</strong>{data.get('timestamp', datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S'))}</li>
                    </ul>
                    <p>感谢您的信任！</p>
                </div>
                
                <div style="text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #e5e7eb;">
                    <p style="color: #6b7280; font-size: 14px;">
                        此邮件由系统自动发送，请勿回复。<br>
                        © 2024 百道会. 保留所有权利。
                    </p>
                </div>
            </div>
        </body>
        </html>
        """
        return subject, content
    
    return None, None

if __name__ == '__main__':
    port = int(os.getenv('PORT', 5008))
    app.run(host='0.0.0.0', port=port, debug=False) 