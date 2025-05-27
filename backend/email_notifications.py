#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
邮件通知服务
使用 Cloudflare Email Routing + Flask-Mail 实现模板化邮件发送
支持角色升级、算命回复、退款确认、电商购物通知等场景
"""

import os
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from email.mime.base import MIMEBase
from email import encoders
from jinja2 import Environment, FileSystemLoader
from typing import Dict, List, Optional
import logging
from datetime import datetime
import json

# 配置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class EmailNotificationService:
    """邮件通知服务类"""
    
    def __init__(self):
        # 邮件配置
        self.smtp_server = os.getenv('SMTP_SERVER', 'smtp.gmail.com')
        self.smtp_port = int(os.getenv('SMTP_PORT', '587'))
        self.smtp_username = os.getenv('SMTP_USERNAME')
        self.smtp_password = os.getenv('SMTP_PASSWORD')
        
        # 发件人配置
        self.sender_emails = {
            'member_upgrade': 'inform1@baidaohui.com',
            'fortune_reply': 'inform2@baidaohui.com', 
            'refund': 'inform3@baidaohui.com',
            'order': 'inform8@baidaohui.com'
        }
        
        # 初始化Jinja2模板环境
        template_dir = os.path.join(os.path.dirname(__file__), '..', 'templates', 'email')
        self.jinja_env = Environment(loader=FileSystemLoader(template_dir))
        
    def _get_smtp_connection(self):
        """获取SMTP连接"""
        try:
            server = smtplib.SMTP(self.smtp_server, self.smtp_port)
            server.starttls()
            server.login(self.smtp_username, self.smtp_password)
            return server
        except Exception as e:
            logger.error(f"SMTP连接失败: {e}")
            raise
    
    def _render_template(self, template_name: str, context: Dict) -> str:
        """渲染邮件模板"""
        try:
            template = self.jinja_env.get_template(template_name)
            return template.render(**context)
        except Exception as e:
            logger.error(f"模板渲染失败 {template_name}: {e}")
            raise
    
    def _send_email(self, 
                   sender: str,
                   recipient: str, 
                   subject: str, 
                   html_content: str,
                   attachments: Optional[List[Dict]] = None) -> bool:
        """发送邮件"""
        try:
            msg = MIMEMultipart('alternative')
            msg['From'] = sender
            msg['To'] = recipient
            msg['Subject'] = subject
            
            # 添加HTML内容
            html_part = MIMEText(html_content, 'html', 'utf-8')
            msg.attach(html_part)
            
            # 添加附件
            if attachments:
                for attachment in attachments:
                    with open(attachment['path'], 'rb') as f:
                        part = MIMEBase('application', 'octet-stream')
                        part.set_payload(f.read())
                        encoders.encode_base64(part)
                        part.add_header(
                            'Content-Disposition',
                            f'attachment; filename= {attachment["filename"]}'
                        )
                        msg.attach(part)
            
            # 发送邮件
            with self._get_smtp_connection() as server:
                server.send_message(msg)
                
            logger.info(f"邮件发送成功: {recipient}")
            return True
            
        except Exception as e:
            logger.error(f"邮件发送失败 {recipient}: {e}")
            return False
    
    def send_member_upgrade_notification(self, 
                                       user_email: str,
                                       user_nickname: str,
                                       upgrade_time: str,
                                       invite_token: str) -> bool:
        """发送Member角色升级通知"""
        context = {
            'user_nickname': user_nickname,
            'upgrade_time': upgrade_time,
            'member_url': 'https://member.baidaohui.com',
            'invite_token': invite_token,
            'current_year': datetime.now().year
        }
        
        html_content = self._render_template('member_upgrade.html', context)
        
        return self._send_email(
            sender=self.sender_emails['member_upgrade'],
            recipient=user_email,
            subject='🎉 恭喜！您已成功升级为Member会员',
            html_content=html_content
        )
    
    def send_fortune_reply_notification(self,
                                      user_email: str,
                                      user_nickname: str,
                                      order_id: str,
                                      reply_content: str,
                                      master_nickname: str,
                                      reply_time: str) -> bool:
        """发送算命申请回复通知"""
        context = {
            'user_nickname': user_nickname,
            'order_id': order_id,
            'reply_content': reply_content,
            'master_nickname': master_nickname,
            'reply_time': reply_time,
            'fortune_url': 'https://member.baidaohui.com/fortune',
            'current_year': datetime.now().year
        }
        
        html_content = self._render_template('fortune_reply.html', context)
        
        return self._send_email(
            sender=self.sender_emails['fortune_reply'],
            recipient=user_email,
            subject=f'📿 您的算命申请已有回复 - 订单#{order_id}',
            html_content=html_content
        )
    
    def send_refund_notification(self,
                               user_email: str,
                               user_nickname: str,
                               order_id: str,
                               refund_amount: float,
                               currency: str,
                               refund_reason: str,
                               refund_time: str) -> bool:
        """发送退款确认通知"""
        context = {
            'user_nickname': user_nickname,
            'order_id': order_id,
            'refund_amount': refund_amount,
            'currency': currency,
            'refund_reason': refund_reason,
            'refund_time': refund_time,
            'support_email': 'support@baidaohui.com',
            'current_year': datetime.now().year
        }
        
        html_content = self._render_template('refund.html', context)
        
        return self._send_email(
            sender=self.sender_emails['refund'],
            recipient=user_email,
            subject=f'💰 退款确认通知 - 订单#{order_id}',
            html_content=html_content
        )
    
    def send_order_notification(self,
                              user_email: str,
                              user_nickname: str,
                              order_id: str,
                              product_name: str,
                              product_price: float,
                              currency: str,
                              store_name: str,
                              order_time: str,
                              payment_method: str) -> bool:
        """发送电商购物通知"""
        context = {
            'user_nickname': user_nickname,
            'order_id': order_id,
            'product_name': product_name,
            'product_price': product_price,
            'currency': currency,
            'store_name': store_name,
            'order_time': order_time,
            'payment_method': payment_method,
            'order_url': f'https://member.baidaohui.com/orders/{order_id}',
            'current_year': datetime.now().year
        }
        
        html_content = self._render_template('order.html', context)
        
        return self._send_email(
            sender=self.sender_emails['order'],
            recipient=user_email,
            subject=f'🛒 订单确认 - {product_name}',
            html_content=html_content
        )
    
    def send_bulk_notification(self, 
                             notification_type: str,
                             recipients: List[Dict],
                             template_context: Dict) -> Dict:
        """批量发送通知"""
        results = {
            'success': 0,
            'failed': 0,
            'errors': []
        }
        
        for recipient in recipients:
            try:
                context = {**template_context, **recipient}
                
                if notification_type == 'member_upgrade':
                    success = self.send_member_upgrade_notification(**context)
                elif notification_type == 'fortune_reply':
                    success = self.send_fortune_reply_notification(**context)
                elif notification_type == 'refund':
                    success = self.send_refund_notification(**context)
                elif notification_type == 'order':
                    success = self.send_order_notification(**context)
                else:
                    raise ValueError(f"不支持的通知类型: {notification_type}")
                
                if success:
                    results['success'] += 1
                else:
                    results['failed'] += 1
                    
            except Exception as e:
                results['failed'] += 1
                results['errors'].append({
                    'recipient': recipient.get('user_email', 'unknown'),
                    'error': str(e)
                })
                logger.error(f"批量发送失败: {e}")
        
        return results

# 全局邮件服务实例
email_service = EmailNotificationService()

# Flask应用集成示例
def create_flask_app():
    """创建Flask应用并集成邮件服务"""
    from flask import Flask, request, jsonify
    
    app = Flask(__name__)
    
    @app.route('/api/email/member-upgrade', methods=['POST'])
    def send_member_upgrade():
        """发送Member升级通知API"""
        data = request.get_json()
        
        required_fields = ['user_email', 'user_nickname', 'upgrade_time', 'invite_token']
        if not all(field in data for field in required_fields):
            return jsonify({'error': '缺少必要字段'}), 400
        
        success = email_service.send_member_upgrade_notification(**data)
        
        if success:
            return jsonify({'message': '邮件发送成功'}), 200
        else:
            return jsonify({'error': '邮件发送失败'}), 500
    
    @app.route('/api/email/fortune-reply', methods=['POST'])
    def send_fortune_reply():
        """发送算命回复通知API"""
        data = request.get_json()
        
        required_fields = ['user_email', 'user_nickname', 'order_id', 'reply_content', 'master_nickname', 'reply_time']
        if not all(field in data for field in required_fields):
            return jsonify({'error': '缺少必要字段'}), 400
        
        success = email_service.send_fortune_reply_notification(**data)
        
        if success:
            return jsonify({'message': '邮件发送成功'}), 200
        else:
            return jsonify({'error': '邮件发送失败'}), 500
    
    @app.route('/api/email/refund', methods=['POST'])
    def send_refund():
        """发送退款通知API"""
        data = request.get_json()
        
        required_fields = ['user_email', 'user_nickname', 'order_id', 'refund_amount', 'currency', 'refund_reason', 'refund_time']
        if not all(field in data for field in required_fields):
            return jsonify({'error': '缺少必要字段'}), 400
        
        success = email_service.send_refund_notification(**data)
        
        if success:
            return jsonify({'message': '邮件发送成功'}), 200
        else:
            return jsonify({'error': '邮件发送失败'}), 500
    
    @app.route('/api/email/order', methods=['POST'])
    def send_order():
        """发送订单通知API"""
        data = request.get_json()
        
        required_fields = ['user_email', 'user_nickname', 'order_id', 'product_name', 'product_price', 'currency', 'store_name', 'order_time', 'payment_method']
        if not all(field in data for field in required_fields):
            return jsonify({'error': '缺少必要字段'}), 400
        
        success = email_service.send_order_notification(**data)
        
        if success:
            return jsonify({'message': '邮件发送成功'}), 200
        else:
            return jsonify({'error': '邮件发送失败'}), 500
    
    @app.route('/api/email/bulk', methods=['POST'])
    def send_bulk():
        """批量发送邮件API"""
        data = request.get_json()
        
        if 'notification_type' not in data or 'recipients' not in data:
            return jsonify({'error': '缺少必要字段'}), 400
        
        results = email_service.send_bulk_notification(
            notification_type=data['notification_type'],
            recipients=data['recipients'],
            template_context=data.get('template_context', {})
        )
        
        return jsonify(results), 200
    
    return app

if __name__ == '__main__':
    # 测试运行
    app = create_flask_app()
    app.run(debug=True, host='0.0.0.0', port=5000) 