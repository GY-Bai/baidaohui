from flask import Blueprint, request, jsonify, make_response, redirect
import jwt
import os
import requests
from datetime import datetime, timedelta
import logging

auth_bp = Blueprint('auth', __name__)
logger = logging.getLogger(__name__)

SUPABASE_URL = os.getenv('SUPABASE_URL')
SUPABASE_SERVICE_KEY = os.getenv('SUPABASE_SERVICE_KEY')
JWT_SECRET = os.getenv('JWT_SECRET', 'your-secret-key')
FRONTEND_URL = os.getenv('FRONTEND_URL', 'https://baidaohui.com')

# 角色到子域的映射
ROLE_SUBDOMAIN_MAP = {
    'Fan': 'fan.baidaohui.com',
    'Member': 'member.baidaohui.com', 
    'Master': 'master.baidaohui.com',
    'Firstmate': 'firstmate.baidaohui.com',
    'Seller': 'seller.baidaohui.com'
}

@auth_bp.route('/callback', methods=['POST'])
def oauth_callback():
    """处理OAuth回调，验证Token并生成JWT"""
    try:
        data = request.get_json()
        access_token = data.get('access_token')
        
        if not access_token:
            return jsonify({'error': '缺少access_token'}), 400
            
        # 调用Supabase验证Token
        headers = {
            'Authorization': f'Bearer {access_token}',
            'apikey': SUPABASE_SERVICE_KEY
        }
        
        response = requests.get(f'{SUPABASE_URL}/auth/v1/user', headers=headers)
        
        if response.status_code != 200:
            return jsonify({'error': '无效的access_token'}), 401
            
        user_data = response.json()
        user_id = user_data.get('id')
        email = user_data.get('email')
        
        # 从用户元数据或数据库获取角色信息
        # 这里假设角色存储在user_metadata中，实际可能需要查询数据库
        role = user_data.get('user_metadata', {}).get('role', 'Fan')
        
        # 生成JWT
        payload = {
            'sub': user_id,
            'email': email,
            'role': role,
            'exp': datetime.utcnow() + timedelta(days=7),
            'iat': datetime.utcnow()
        }
        
        jwt_token = jwt.encode(payload, JWT_SECRET, algorithm='HS256')
        
        # 创建响应并设置HttpOnly Cookie
        redirect_url = f"https://{ROLE_SUBDOMAIN_MAP.get(role, 'baidaohui.com')}"
        response = make_response(jsonify({
            'success': True,
            'user': {
                'id': user_id,
                'email': email,
                'role': role
            },
            'redirect_url': redirect_url
        }))
        
        response.set_cookie(
            'access_token',
            jwt_token,
            httponly=True,
            secure=True,
            samesite='Lax',
            domain='.baidaohui.com',
            max_age=7*24*60*60  # 7天
        )
        
        logger.info(f"用户 {email} 登录成功，角色: {role}")
        return response
        
    except Exception as e:
        logger.error(f"OAuth回调处理失败: {str(e)}")
        return jsonify({'error': '登录处理失败'}), 500

@auth_bp.route('/validate', methods=['POST'])
def validate_token():
    """验证JWT Token，供其他服务调用"""
    try:
        # 从Cookie或Authorization头获取token
        token = request.cookies.get('access_token')
        if not token:
            auth_header = request.headers.get('Authorization')
            if auth_header and auth_header.startswith('Bearer '):
                token = auth_header.split(' ')[1]
        
        if not token:
            return jsonify({'error': '未找到token'}), 401
            
        # 验证JWT
        payload = jwt.decode(token, JWT_SECRET, algorithms=['HS256'])
        
        return jsonify({
            'valid': True,
            'user': {
                'id': payload['sub'],
                'email': payload['email'],
                'role': payload['role']
            }
        })
        
    except jwt.ExpiredSignatureError:
        return jsonify({'error': 'Token已过期'}), 401
    except jwt.InvalidTokenError:
        return jsonify({'error': '无效的Token'}), 401
    except Exception as e:
        logger.error(f"Token验证失败: {str(e)}")
        return jsonify({'error': 'Token验证失败'}), 500

@auth_bp.route('/logout', methods=['POST'])
def logout():
    """用户登出"""
    response = make_response(jsonify({'success': True, 'message': '登出成功'}))
    response.set_cookie(
        'access_token',
        '',
        httponly=True,
        secure=True,
        samesite='Lax',
        domain='.baidaohui.com',
        expires=0
    )
    return response

@auth_bp.route('/check-role', methods=['GET'])
def check_role():
    """检查用户角色权限"""
    try:
        token = request.cookies.get('access_token')
        if not token:
            return jsonify({'error': '未登录'}), 401
            
        payload = jwt.decode(token, JWT_SECRET, algorithms=['HS256'])
        user_role = payload['role']
        
        # 从请求参数获取要访问的子域
        requested_subdomain = request.args.get('subdomain')
        
        # 检查角色权限
        allowed_subdomain = ROLE_SUBDOMAIN_MAP.get(user_role)
        
        if requested_subdomain and f"{requested_subdomain}.baidaohui.com" != allowed_subdomain:
            return jsonify({
                'error': '您无权访问，请使用正确账号登录',
                'redirect_url': f"https://{allowed_subdomain}"
            }), 403
            
        return jsonify({
            'valid': True,
            'role': user_role,
            'allowed_subdomain': allowed_subdomain
        })
        
    except jwt.ExpiredSignatureError:
        return jsonify({'error': 'Token已过期'}), 401
    except jwt.InvalidTokenError:
        return jsonify({'error': '无效的Token'}), 401
    except Exception as e:
        logger.error(f"角色检查失败: {str(e)}")
        return jsonify({'error': '角色检查失败'}), 500 