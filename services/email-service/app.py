from flask import Flask, request, jsonify
from flask_cors import CORS
import os
import logging
import smtplib
import ssl
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from email.mime.base import MIMEBase
from email import encoders
import jwt
import requests
from datetime import datetime
from jinja2 import Environment, FileSystemLoader
import json

app = Flask(__name__)
CORS(app, supports_credentials=True)

# 配置
SMTP_SERVER = os.getenv('SMTP_SERVER', 'smtp.gmail.com')
SMTP_PORT = int(os.getenv('SMTP_PORT', '587'))
SMTP_USERNAME = os.getenv('SMTP_USERNAME')  # 您的发送邮箱
SMTP_PASSWORD = os.getenv('SMTP_PASSWORD')  # 应用密码
JWT_SECRET = os.getenv('JWT_SECRET', 'your-secret-key')
AUTH_SERVICE_URL = os.getenv('AUTH_SERVICE_URL', 'http://localhost:5001')
DOMAIN = os.getenv('DOMAIN', 'baidaohui.com')

# Cloudflare Email Routing 配置
CF_EMAIL_DOMAIN = os.getenv('CF_EMAIL_DOMAIN', 'baidaohui.com')  # 您的CF域名
CF_API_TOKEN = os.getenv('CF_API_TOKEN')  # Cloudflare API Token
CF_ZONE_ID = os.getenv('CF_ZONE_ID')  # Cloudflare Zone ID

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# 初始化Jinja2模板环境
template_env = Environment(loader=FileSystemLoader('templates'))

class EmailService:
    def __init__(self):
        self.smtp_server = SMTP_SERVER
        self.smtp_port = SMTP_PORT
        self.username = SMTP_USERNAME
        self.password = SMTP_PASSWORD
        
    def get_user_email_from_jwt(self, jwt_token: str) -> str:
        """从JWT令牌中提取用户邮箱"""
        try:
            payload = jwt.decode(jwt_token, JWT_SECRET, algorithms=['HS256'])
            return payload.get('email')
        except jwt.InvalidTokenError:
            logger.error("无效的JWT令牌")
            return None
    
    def get_user_email_from_user_id(self, user_id: str) -> str:
        """根据用户ID获取邮箱地址"""
        try:
            # 调用auth-service获取用户信息
            response = requests.get(f'{AUTH_SERVICE_URL}/auth/user/{user_id}')
            if response.ok:
                user_data = response.json()
                return user_data.get('email')
        except Exception as e:
            logger.error(f"获取用户邮箱失败: {str(e)}")
        return None
    
    def send_email(self, to_email: str, subject: str, html_content: str, text_content: str = None) -> bool:
        """发送邮件"""
        try:
            # 创建邮件消息
            message = MIMEMultipart("alternative")
            message["Subject"] = subject
            # 设置发件人显示为@baidaohui.com，但实际通过Gmail SMTP发送
            message["From"] = f"百道会 <noreply@{CF_EMAIL_DOMAIN}>"
            message["Reply-To"] = f"support@{CF_EMAIL_DOMAIN}"  # 回复地址设为CF域名
            message["To"] = to_email
            
            # 添加文本内容
            if text_content:
                text_part = MIMEText(text_content, "plain", "utf-8")
                message.attach(text_part)
            
            # 添加HTML内容
            html_part = MIMEText(html_content, "html", "utf-8")
            message.attach(html_part)
            
            # 发送邮件
            context = ssl.create_default_context()
            with smtplib.SMTP(self.smtp_server, self.smtp_port) as server:
                server.starttls(context=context)
                server.login(self.username, self.password)
                server.sendmail(self.username, to_email, message.as_string())
            
            logger.info(f"邮件发送成功: {to_email}")
            return True
            
        except Exception as e:
            logger.error(f"邮件发送失败: {str(e)}")
            return False
    
    def render_template(self, template_name: str, **kwargs) -> str:
        """渲染邮件模板"""
        try:
            template = template_env.get_template(template_name)
            return template.render(**kwargs)
        except Exception as e:
            logger.error(f"模板渲染失败: {str(e)}")
            return ""

# 全局邮件服务实例
email_service = EmailService()

from routes import email_bp
app.register_blueprint(email_bp, url_prefix='/email')

@app.route('/health')
def health():
    return jsonify({'status': 'healthy', 'service': 'email-service'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5003, debug=True) 