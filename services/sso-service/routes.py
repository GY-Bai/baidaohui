from flask import Blueprint, request, jsonify, make_response, redirect
import jwt
import requests
import json
from datetime import datetime, timedelta
import logging
import os

sso_bp = Blueprint('sso', __name__)

# 从app.py导入配置
SUPABASE_URL = os.getenv('SUPABASE_URL')
SUPABASE_SERVICE_KEY = os.getenv('SUPABASE_SERVICE_KEY')
JWT_SECRET = os.getenv('JWT_SECRET', 'your-secret-key')
DOMAIN = os.getenv('DOMAIN', 'baidaohui.com')

logger = logging.getLogger(__name__)

# 角色对应的路径映射（替换子域名映射）
ROLE_PATHS = {
    'Fan': '/fan',
    'Member': '/member',
    'Master': '/master',
    'Firstmate': '/firstmate',
    'Seller': '/seller'
}

@sso_bp.route('/session', methods=['GET'])
def get_session():
    """获取当前用户会话信息"""
    try:
        # 从Cookie获取token
        token = request.cookies.get('access_token')
        
        if not token:
            return jsonify({'session': None}), 200
        
        # 验证JWT
        try:
            payload = jwt.decode(token, JWT_SECRET, algorithms=['HS256'])
        except jwt.ExpiredSignatureError:
            return jsonify({'session': None, 'error': 'Token已过期'}), 200
        except jwt.InvalidTokenError:
            return jsonify({'session': None, 'error': '无效的token'}), 200
        
        # 返回用户会话信息
        return jsonify({
            'user': {
                'id': payload['sub'],
                'email': payload['email'],
                'role': payload['role'],
                'nickname': payload.get('nickname')
            },
            'expires_at': payload['exp']
        })
        
    except Exception as e:
        logger.error(f'获取会话失败: {str(e)}')
        return jsonify({'session': None, 'error': '获取会话失败'}), 500

@sso_bp.route('/validate', methods=['POST'])
def validate_session():
    """验证会话并检查路径权限"""
    try:
        data = request.get_json()
        expected_role = data.get('expected_role')
        current_path = data.get('current_path')
        
        # 从Cookie获取token
        token = request.cookies.get('access_token')
        
        if not token:
            return jsonify({
                'valid': False,
                'error': '未登录',
                'redirect_url': '/login'
            }), 401
        
        # 验证JWT
        try:
            payload = jwt.decode(token, JWT_SECRET, algorithms=['HS256'])
        except jwt.ExpiredSignatureError:
            return jsonify({
                'valid': False,
                'error': 'Token已过期',
                'redirect_url': '/login'
            }), 401
        except jwt.InvalidTokenError:
            return jsonify({
                'valid': False,
                'error': '无效的token',
                'redirect_url': '/login'
            }), 401
        
        user_role = payload['role']
        
        # 检查角色权限
        if expected_role and user_role != expected_role:
            correct_path = ROLE_PATHS.get(user_role)
            return jsonify({
                'valid': False,
                'error': '角色不匹配',
                'user_role': user_role,
                'expected_role': expected_role,
                'redirect_url': correct_path if correct_path else '/login'
            }), 403
        
        # 检查路径权限
        expected_path = ROLE_PATHS.get(user_role)
        if current_path and expected_path:
            # 检查当前路径是否以期望路径开头
            if not current_path.startswith(expected_path):
                return jsonify({
                    'valid': False,
                    'error': '路径不匹配',
                    'current_path': current_path,
                    'expected_path': expected_path,
                    'redirect_url': expected_path
                }), 403
        
        return jsonify({
            'valid': True,
            'user': {
                'id': payload['sub'],
                'email': payload['email'],
                'role': payload['role'],
                'nickname': payload.get('nickname')
            }
        })
        
    except Exception as e:
        logger.error(f'会话验证失败: {str(e)}')
        return jsonify({
            'valid': False,
            'error': '验证失败',
            'redirect_url': '/login'
        }), 500

@sso_bp.route('/set-session', methods=['POST'])
def set_session():
    """设置会话（更新为单域名架构）"""
    try:
        data = request.get_json()
        user_data = data.get('user')
        
        if not user_data:
            return jsonify({'error': '缺少用户数据'}), 400
        
        # 生成JWT令牌
        jwt_payload = {
            'sub': user_data['id'],
            'email': user_data['email'],
            'role': user_data['role'],
            'nickname': user_data.get('nickname'),
            'iat': datetime.utcnow(),
            'exp': datetime.utcnow() + timedelta(days=7)
        }
        
        jwt_token = jwt.encode(jwt_payload, JWT_SECRET, algorithm='HS256')
        
        # 创建响应
        response = make_response(jsonify({
            'success': True,
            'user': user_data,
            'target_path': ROLE_PATHS.get(user_data['role'])
        }))
        
        # 设置Cookie（单域名，无需跨子域）
        response.set_cookie(
            'access_token',
            jwt_token,
            max_age=7*24*60*60,  # 7天
            httponly=True,
            secure=True,
            samesite='Lax',
            domain=DOMAIN  # 单域名
        )
        
        logger.info(f'设置会话成功: {user_data["email"]} ({user_data["role"]})')
        return response
        
    except Exception as e:
        logger.error(f'设置会话失败: {str(e)}')
        return jsonify({'error': '设置会话失败'}), 500

@sso_bp.route('/clear-session', methods=['POST'])
def clear_session():
    """清除会话"""
    try:
        response = make_response(jsonify({'success': True, 'message': '会话已清除'}))
        
        # 清除Cookie
        response.set_cookie(
            'access_token',
            '',
            max_age=0,
            httponly=True,
            secure=True,
            samesite='Lax',
            domain=DOMAIN
        )
        
        return response
        
    except Exception as e:
        logger.error(f'清除会话失败: {str(e)}')
        return jsonify({'error': '清除会话失败'}), 500

@sso_bp.route('/redirect-to-role', methods=['GET'])
def redirect_to_role():
    """根据用户角色重定向到对应路径"""
    try:
        # 从Cookie获取token
        token = request.cookies.get('access_token')
        
        if not token:
            return redirect('/login')
        
        # 验证JWT
        try:
            payload = jwt.decode(token, JWT_SECRET, algorithms=['HS256'])
        except jwt.InvalidTokenError:
            return redirect('/login')
        
        user_role = payload['role']
        target_path = ROLE_PATHS.get(user_role)
        
        if target_path:
            return redirect(target_path)
        else:
            return redirect('/login')
        
    except Exception as e:
        logger.error(f'角色重定向失败: {str(e)}')
        return redirect('/login')

@sso_bp.route('/check-path', methods=['GET'])
def check_path():
    """检查当前路径是否匹配用户角色"""
    try:
        current_path = request.args.get('path')
        
        # 从Cookie获取token
        token = request.cookies.get('access_token')
        
        if not token:
            return jsonify({
                'valid': False,
                'redirect_url': '/login'
            })
        
        # 验证JWT
        try:
            payload = jwt.decode(token, JWT_SECRET, algorithms=['HS256'])
        except jwt.InvalidTokenError:
            return jsonify({
                'valid': False,
                'redirect_url': '/login'
            })
        
        user_role = payload['role']
        expected_path = ROLE_PATHS.get(user_role)
        
        # 检查路径是否匹配
        if current_path and expected_path and current_path.startswith(expected_path):
            return jsonify({'valid': True})
        else:
            return jsonify({
                'valid': False,
                'redirect_url': expected_path if expected_path else '/login'
            })
        
    except Exception as e:
        logger.error(f'路径检查失败: {str(e)}')
        return jsonify({
            'valid': False,
            'redirect_url': '/login'
        }) 