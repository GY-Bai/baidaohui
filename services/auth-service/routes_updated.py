"""
更新后的auth-service路由
使用统一的Supabase客户端，避免直接数据库操作导致的数据冲突
"""

from flask import Blueprint, request, jsonify, make_response, redirect
import jwt
import json
from datetime import datetime, timedelta
import uuid
import logging
from supabase_client import supabase_client

auth_bp = Blueprint('auth', __name__)
logger = logging.getLogger(__name__)

# 配置
JWT_SECRET = os.getenv('JWT_SECRET', 'your-secret-key')
FRONTEND_URL = os.getenv('FRONTEND_URL', 'https://baidaohui.com')
DOMAIN = os.getenv('DOMAIN', 'baidaohui.com')

# 角色对应的子域名映射
ROLE_SUBDOMAINS = {
    'Fan': 'fan.baidaohui.com',
    'Member': 'member.baidaohui.com', 
    'Master': 'master.baidaohui.com',
    'Firstmate': 'firstmate.baidaohui.com',
    'Seller': 'seller.baidaohui.com'
}

@auth_bp.route('/validate', methods=['GET'])
def validate_token():
    """验证JWT Token并检查域名权限"""
    try:
        # 从Cookie或Header获取token
        token = request.cookies.get('access_token')
        if not token:
            auth_header = request.headers.get('Authorization')
            if auth_header and auth_header.startswith('Bearer '):
                token = auth_header.split(' ')[1]
        
        if not token:
            return jsonify({'error': '未提供token', 'redirect_url': 'https://baidaohui.com/login'}), 401
        
        # 验证JWT
        try:
            payload = jwt.decode(token, JWT_SECRET, algorithms=['HS256'])
        except jwt.ExpiredSignatureError:
            return jsonify({'error': 'Token已过期', 'redirect_url': 'https://baidaohui.com/login'}), 401
        except jwt.InvalidTokenError:
            return jsonify({'error': '无效的token', 'redirect_url': 'https://baidaohui.com/login'}), 401
        
        user_role = payload['role']
        
        # 检查请求来源域名（如果提供）
        origin = request.headers.get('Origin') or request.headers.get('Referer', '')
        current_domain = None
        
        if origin:
            # 从Origin或Referer中提取域名
            import re
            domain_match = re.search(r'https?://([^/]+)', origin)
            if domain_match:
                current_domain = domain_match.group(1)
        
        # 验证域名权限
        expected_domain = ROLE_SUBDOMAINS.get(user_role)
        domain_mismatch = False
        
        if current_domain and expected_domain:
            # 允许localhost用于开发环境
            if current_domain != expected_domain and current_domain != 'localhost':
                domain_mismatch = True
        
        response_data = {
            'valid': True,
            'user': {
                'id': payload['sub'],
                'email': payload['email'],
                'role': payload['role'],
                'nickname': payload.get('nickname')
            }
        }
        
        # 如果域名不匹配，返回正确的重定向URL
        if domain_mismatch:
            response_data['domain_mismatch'] = True
            response_data['redirect_url'] = f'https://{expected_domain}'
            return jsonify(response_data), 200
        
        return jsonify(response_data)
        
    except Exception as e:
        logger.error(f'Token验证失败: {str(e)}')
        return jsonify({'error': '验证失败', 'redirect_url': 'https://baidaohui.com/login'}), 500

@auth_bp.route('/sync-role', methods=['POST'])
def sync_user_role():
    """强制同步用户角色（从Supabase获取最新角色）"""
    try:
        # 验证JWT token
        token = request.headers.get('Authorization', '').replace('Bearer ', '')
        if not token:
            return jsonify({'error': '缺少认证token'}), 401
        
        payload = jwt.decode(token, JWT_SECRET, algorithms=['HS256'])
        current_user_id = payload['sub']
        current_user_role = payload['role']
        
        data = request.get_json()
        target_user_id = data.get('userId')
        force_sync = data.get('forceSync', False)
        
        if not target_user_id:
            return jsonify({'error': '缺少用户ID'}), 400
        
        # 权限检查：只能同步自己的角色，或者Master可以同步所有用户
        if current_user_id != target_user_id and current_user_role != 'Master':
            return jsonify({'error': '无权限执行此操作'}), 403
        
        # 通过Supabase客户端获取最新的用户信息
        profile_result = supabase_client.get_user_profile(target_user_id)
        
        if not profile_result.get('success', True):  # 某些函数可能不返回success字段
            if 'error' in profile_result:
                return jsonify({'error': 'Supabase查询失败'}), 500
        
        # 检查是否有用户信息
        if 'error' in profile_result:
            return jsonify({'error': '用户不存在'}), 404
        
        # 从结果中提取用户信息
        user_info = profile_result
        if isinstance(profile_result, dict) and 'id' in profile_result:
            # 直接的用户信息
            supabase_role = profile_result.get('role', 'Fan')
            user_email = profile_result.get('email', '')
            user_nickname = profile_result.get('nickname', '')
        else:
            # 可能是包装的响应
            return jsonify({'error': '用户信息格式错误'}), 500
        
        # 如果是当前用户且角色有变化，生成新的JWT token
        if current_user_id == target_user_id and current_user_role != supabase_role:
            new_payload = {
                'sub': target_user_id,
                'email': user_email,
                'role': supabase_role,
                'nickname': user_nickname,
                'iat': datetime.utcnow(),
                'exp': datetime.utcnow() + timedelta(days=7)
            }
            
            new_token = jwt.encode(new_payload, JWT_SECRET, algorithm='HS256')
            
            response = make_response(jsonify({
                'success': True,
                'message': '角色同步成功',
                'user': {
                    'id': target_user_id,
                    'email': user_email,
                    'role': supabase_role,
                    'nickname': user_nickname
                },
                'token_updated': True,
                'old_role': current_user_role,
                'new_role': supabase_role
            }))
            
            # 设置新的token cookie
            response.set_cookie(
                'access_token',
                new_token,
                max_age=7*24*60*60,
                httponly=True,
                secure=True,
                samesite='Lax',
                domain=f'.{DOMAIN}'
            )
            
            logger.info(f"用户角色同步: {user_email} {current_user_role} -> {supabase_role}")
            return response
        else:
            return jsonify({
                'success': True,
                'message': '角色无需更新' if current_user_role == supabase_role else '角色同步成功',
                'user': {
                    'id': target_user_id,
                    'email': user_email,
                    'role': supabase_role,
                    'nickname': user_nickname
                },
                'token_updated': False
            })
        
    except jwt.InvalidTokenError:
        return jsonify({'error': '无效的token'}), 401
    except Exception as e:
        logger.error(f"角色同步失败: {str(e)}")
        return jsonify({'error': f'同步失败: {str(e)}'}), 500

@auth_bp.route('/invite/use', methods=['POST'])
def use_invite_link():
    """使用邀请链接进行角色升级"""
    try:
        data = request.get_json()
        invite_token = data.get('invite_token')
        
        if not invite_token:
            return jsonify({'error': '缺少邀请链接token'}), 400
        
        # 验证用户登录状态
        token = request.cookies.get('access_token')
        if not token:
            auth_header = request.headers.get('Authorization')
            if auth_header and auth_header.startswith('Bearer '):
                token = auth_header.split(' ')[1]
        
        if not token:
            return jsonify({'error': '用户未登录'}), 401
        
        try:
            payload = jwt.decode(token, JWT_SECRET, algorithms=['HS256'])
            user_id = payload['sub']
            current_role = payload['role']
            user_email = payload['email']
        except jwt.InvalidTokenError:
            return jsonify({'error': '无效的token'}), 401
        
        # 通过Supabase客户端处理邀请链接升级
        upgrade_result = supabase_client.upgrade_user_role_by_invite(user_id, invite_token)
        
        if not upgrade_result.get('success', False):
            return jsonify(upgrade_result), 400
        
        # 获取升级后的新角色
        new_role = upgrade_result.get('new_role')
        if new_role and new_role != current_role:
            # 生成新的JWT token
            new_payload = {
                'sub': user_id,
                'email': user_email,
                'role': new_role,
                'nickname': payload.get('nickname'),
                'iat': datetime.utcnow(),
                'exp': datetime.utcnow() + timedelta(days=7)
            }
            
            new_token = jwt.encode(new_payload, JWT_SECRET, algorithm='HS256')
            
            response = make_response(jsonify({
                'success': True,
                'message': f'角色升级成功：{current_role} -> {new_role}',
                'old_role': current_role,
                'new_role': new_role,
                'redirect_url': f"https://{ROLE_SUBDOMAINS.get(new_role, ROLE_SUBDOMAINS['Fan'])}",
                'token_updated': True
            }))
            
            # 设置新的token cookie
            response.set_cookie(
                'access_token',
                new_token,
                max_age=7*24*60*60,
                httponly=True,
                secure=True,
                samesite='Lax',
                domain=f'.{DOMAIN}'
            )
            
            logger.info(f"邀请链接升级成功: {user_email} {current_role} -> {new_role}")
            return response
        else:
            return jsonify(upgrade_result)
        
    except Exception as e:
        logger.error(f"使用邀请链接失败: {str(e)}")
        return jsonify({'error': '邀请链接处理失败'}), 500

@auth_bp.route('/admin/change-role', methods=['POST'])
def admin_change_role():
    """管理员调整用户角色（通过Supabase统一处理）"""
    try:
        # 验证管理员权限
        token = request.headers.get('Authorization', '').replace('Bearer ', '')
        if not token:
            return jsonify({'error': '缺少认证token'}), 401
        
        payload = jwt.decode(token, JWT_SECRET, algorithms=['HS256'])
        admin_role = payload['role']
        
        if admin_role != 'Master':
            return jsonify({'error': '权限不足，只有Master可以调整角色'}), 403
        
        data = request.get_json()
        target_email = data.get('email')
        target_user_id = data.get('userId')
        new_role = data.get('newRole')
        reason = data.get('reason', '管理员调整')
        
        if not new_role:
            return jsonify({'error': '缺少新角色'}), 400
        
        if not target_email and not target_user_id:
            return jsonify({'error': '缺少用户标识'}), 400
        
        # 通过Supabase客户端调整角色
        if target_email:
            result = supabase_client.admin_change_role_by_email(target_email, new_role, reason)
        else:
            result = supabase_client.admin_change_user_role(target_user_id, new_role, reason)
        
        if result.get('success'):
            # 如果成功，标记用户需要重新登录
            if result.get('user_id'):
                supabase_client.force_user_relogin(
                    result['user_id'], 
                    f'角色已更新为{new_role}，请重新登录'
                )
            
            logger.info(f"管理员角色调整成功: {target_email or target_user_id} -> {new_role}")
        
        return jsonify(result)
        
    except jwt.InvalidTokenError:
        return jsonify({'error': '无效的token'}), 401
    except Exception as e:
        logger.error(f"管理员角色调整失败: {str(e)}")
        return jsonify({'error': '角色调整失败'}), 500

@auth_bp.route('/check-relogin', methods=['GET'])
def check_force_relogin():
    """检查用户是否被标记需要重新登录"""
    try:
        token = request.cookies.get('access_token')
        if not token:
            return jsonify({'force_relogin': False})
        
        payload = jwt.decode(token, JWT_SECRET, algorithms=['HS256'])
        user_id = payload['sub']
        
        # 通过Supabase客户端检查
        result = supabase_client._call_rpc('check_force_relogin', {})
        
        return jsonify(result)
        
    except jwt.InvalidTokenError:
        return jsonify({'force_relogin': False})
    except Exception as e:
        logger.error(f"检查重新登录状态失败: {str(e)}")
        return jsonify({'force_relogin': False})

@auth_bp.route('/logout', methods=['POST'])
def logout():
    """用户登出"""
    try:
        response = make_response(jsonify({'success': True, 'message': '登出成功'}))
        
        # 清除Cookie
        response.set_cookie(
            'access_token',
            '',
            max_age=0,
            httponly=True,
            secure=True,
            samesite='Lax',
            domain=f'.{DOMAIN}'
        )
        
        return response
        
    except Exception as e:
        logger.error(f'登出失败: {str(e)}')
        return jsonify({'error': '登出失败'}), 500

# 添加健康检查
@auth_bp.route('/health', methods=['GET'])
def health_check():
    """健康检查"""
    try:
        # 测试Supabase连接
        test_result = supabase_client._call_rpc('test_rls_policies', {})
        
        return jsonify({
            'status': 'healthy',
            'timestamp': datetime.utcnow().isoformat(),
            'supabase_connection': 'ok' if test_result else 'error',
            'service': 'auth-service'
        })
    except Exception as e:
        return jsonify({
            'status': 'unhealthy',
            'error': str(e),
            'timestamp': datetime.utcnow().isoformat(),
            'service': 'auth-service'
        }), 500 