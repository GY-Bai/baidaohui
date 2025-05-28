from flask import Blueprint, request, jsonify
import logging
from datetime import datetime
import json

email_bp = Blueprint('email', __name__)
logger = logging.getLogger(__name__)

# 从app.py导入邮件服务
from app import email_service

@email_bp.route('/send-fortune-reply', methods=['POST'])
def send_fortune_reply():
    """发送算命回复通知邮件"""
    try:
        data = request.get_json()
        user_id = data.get('user_id')
        order_id = data.get('order_id')
        reply_content = data.get('reply_content')
        master_name = data.get('master_name', 'Master')
        
        if not all([user_id, order_id, reply_content]):
            return jsonify({'error': '缺少必要参数'}), 400
        
        # 获取用户邮箱
        user_email = email_service.get_user_email_from_user_id(user_id)
        if not user_email:
            return jsonify({'error': '无法获取用户邮箱'}), 404
        
        # 渲染邮件模板
        html_content = email_service.render_template('fortune_reply.html', 
            order_id=order_id,
            reply_content=reply_content,
            master_name=master_name,
            reply_time=datetime.now().strftime('%Y年%m月%d日 %H:%M')
        )
        
        text_content = f"""
        您好！
        
        您的算命申请（订单号：{order_id}）已收到回复：
        
        {reply_content}
        
        回复时间：{datetime.now().strftime('%Y年%m月%d日 %H:%M')}
        回复人：{master_name}
        
        感谢您使用百道会服务！
        
        百道会团队
        """
        
        # 发送邮件
        success = email_service.send_email(
            to_email=user_email,
            subject=f"【百道会】您的算命申请已回复 - 订单{order_id}",
            html_content=html_content,
            text_content=text_content
        )
        
        if success:
            return jsonify({'success': True, 'message': '邮件发送成功'})
        else:
            return jsonify({'error': '邮件发送失败'}), 500
            
    except Exception as e:
        logger.error(f"发送算命回复邮件失败: {str(e)}")
        return jsonify({'error': '发送邮件失败'}), 500

@email_bp.route('/send-order-notification', methods=['POST'])
def send_order_notification():
    """发送订单通知邮件"""
    try:
        data = request.get_json()
        user_id = data.get('user_id')
        order_id = data.get('order_id')
        order_type = data.get('order_type')  # 'fortune', 'ecommerce'
        status = data.get('status')
        amount = data.get('amount')
        currency = data.get('currency')
        
        if not all([user_id, order_id, order_type, status]):
            return jsonify({'error': '缺少必要参数'}), 400
        
        # 获取用户邮箱
        user_email = email_service.get_user_email_from_user_id(user_id)
        if not user_email:
            return jsonify({'error': '无法获取用户邮箱'}), 404
        
        # 根据订单类型和状态确定邮件内容
        if order_type == 'fortune':
            if status == 'Queued-payed':
                subject = f"【百道会】算命订单支付成功 - {order_id}"
                template_name = 'fortune_payment_success.html'
            elif status == 'Queued-upload':
                subject = f"【百道会】算命订单凭证已提交 - {order_id}"
                template_name = 'fortune_upload_success.html'
            elif status == 'Completed':
                subject = f"【百道会】算命订单已完成 - {order_id}"
                template_name = 'fortune_completed.html'
            else:
                subject = f"【百道会】算命订单状态更新 - {order_id}"
                template_name = 'fortune_status_update.html'
        else:
            subject = f"【百道会】订单状态更新 - {order_id}"
            template_name = 'order_status_update.html'
        
        # 渲染邮件模板
        html_content = email_service.render_template(template_name,
            order_id=order_id,
            status=status,
            amount=amount,
            currency=currency,
            update_time=datetime.now().strftime('%Y年%m月%d日 %H:%M')
        )
        
        # 发送邮件
        success = email_service.send_email(
            to_email=user_email,
            subject=subject,
            html_content=html_content
        )
        
        if success:
            return jsonify({'success': True, 'message': '邮件发送成功'})
        else:
            return jsonify({'error': '邮件发送失败'}), 500
            
    except Exception as e:
        logger.error(f"发送订单通知邮件失败: {str(e)}")
        return jsonify({'error': '发送邮件失败'}), 500

@email_bp.route('/send-role-upgrade', methods=['POST'])
def send_role_upgrade():
    """发送角色升级通知邮件"""
    try:
        data = request.get_json()
        user_id = data.get('user_id')
        old_role = data.get('old_role')
        new_role = data.get('new_role')
        upgrade_reason = data.get('upgrade_reason', '')
        
        if not all([user_id, old_role, new_role]):
            return jsonify({'error': '缺少必要参数'}), 400
        
        # 获取用户邮箱
        user_email = email_service.get_user_email_from_user_id(user_id)
        if not user_email:
            return jsonify({'error': '无法获取用户邮箱'}), 404
        
        # 角色中文映射
        role_names = {
            'Fan': '粉丝',
            'Member': '会员',
            'Master': '大师',
            'Firstmate': '助理',
            'Seller': '商户'
        }
        
        # 渲染邮件模板
        html_content = email_service.render_template('role_upgrade.html',
            old_role=role_names.get(old_role, old_role),
            new_role=role_names.get(new_role, new_role),
            upgrade_reason=upgrade_reason,
            upgrade_time=datetime.now().strftime('%Y年%m月%d日 %H:%M')
        )
        
        # 发送邮件
        success = email_service.send_email(
            to_email=user_email,
            subject=f"【百道会】恭喜！您已升级为{role_names.get(new_role, new_role)}",
            html_content=html_content
        )
        
        if success:
            return jsonify({'success': True, 'message': '邮件发送成功'})
        else:
            return jsonify({'error': '邮件发送失败'}), 500
            
    except Exception as e:
        logger.error(f"发送角色升级邮件失败: {str(e)}")
        return jsonify({'error': '发送邮件失败'}), 500

@email_bp.route('/send-welcome', methods=['POST'])
def send_welcome():
    """发送欢迎邮件"""
    try:
        data = request.get_json()
        user_id = data.get('user_id')
        user_name = data.get('user_name', '')
        
        if not user_id:
            return jsonify({'error': '缺少用户ID'}), 400
        
        # 获取用户邮箱
        user_email = email_service.get_user_email_from_user_id(user_id)
        if not user_email:
            return jsonify({'error': '无法获取用户邮箱'}), 404
        
        # 渲染邮件模板
        html_content = email_service.render_template('welcome.html',
            user_name=user_name or user_email.split('@')[0],
            join_time=datetime.now().strftime('%Y年%m月%d日')
        )
        
        # 发送邮件
        success = email_service.send_email(
            to_email=user_email,
            subject="【百道会】欢迎加入百道会！",
            html_content=html_content
        )
        
        if success:
            return jsonify({'success': True, 'message': '邮件发送成功'})
        else:
            return jsonify({'error': '邮件发送失败'}), 500
            
    except Exception as e:
        logger.error(f"发送欢迎邮件失败: {str(e)}")
        return jsonify({'error': '发送邮件失败'}), 500

@email_bp.route('/send-custom', methods=['POST'])
def send_custom():
    """发送自定义邮件"""
    try:
        data = request.get_json()
        user_id = data.get('user_id')
        jwt_token = data.get('jwt_token')
        subject = data.get('subject')
        content = data.get('content')
        template_data = data.get('template_data', {})
        
        if not subject or not content:
            return jsonify({'error': '缺少邮件主题或内容'}), 400
        
        # 获取用户邮箱
        user_email = None
        if user_id:
            user_email = email_service.get_user_email_from_user_id(user_id)
        elif jwt_token:
            user_email = email_service.get_user_email_from_jwt(jwt_token)
        
        if not user_email:
            return jsonify({'error': '无法获取用户邮箱'}), 404
        
        # 如果content是模板名称，则渲染模板
        if content.endswith('.html'):
            html_content = email_service.render_template(content, **template_data)
        else:
            html_content = content
        
        # 发送邮件
        success = email_service.send_email(
            to_email=user_email,
            subject=subject,
            html_content=html_content
        )
        
        if success:
            return jsonify({'success': True, 'message': '邮件发送成功'})
        else:
            return jsonify({'error': '邮件发送失败'}), 500
            
    except Exception as e:
        logger.error(f"发送自定义邮件失败: {str(e)}")
        return jsonify({'error': '发送邮件失败'}), 500

@email_bp.route('/test', methods=['POST'])
def test_email():
    """测试邮件发送"""
    try:
        data = request.get_json()
        to_email = data.get('to_email')
        
        if not to_email:
            return jsonify({'error': '缺少收件人邮箱'}), 400
        
        # 发送测试邮件
        html_content = """
        <h2>百道会邮件服务测试</h2>
        <p>这是一封测试邮件，用于验证邮件服务是否正常工作。</p>
        <p>发送时间：{}</p>
        <p>如果您收到这封邮件，说明邮件服务配置正确。</p>
        """.format(datetime.now().strftime('%Y年%m月%d日 %H:%M:%S'))
        
        success = email_service.send_email(
            to_email=to_email,
            subject="【百道会】邮件服务测试",
            html_content=html_content
        )
        
        if success:
            return jsonify({'success': True, 'message': '测试邮件发送成功'})
        else:
            return jsonify({'error': '测试邮件发送失败'}), 500
            
    except Exception as e:
        logger.error(f"发送测试邮件失败: {str(e)}")
        return jsonify({'error': '发送邮件失败'}), 500 