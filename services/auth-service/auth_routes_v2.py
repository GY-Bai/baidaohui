"""
Auth Service V2 路由
专注于JWT验证、用户信息查询和Supabase token代理功能
用户CRUD操作全部在Supabase，本地只做缓存和代理
"""

from flask import Blueprint, request, jsonify, make_response
import jwt
import os
import hashlib
import logging
from datetime import datetime, timedelta
from typing import Dict, Any, Optional
from user_manager import user_manager
from supabase_client import supabase_client

auth_bp = Blueprint('auth_v2', __name__)
logger = logging.getLogger(__name__)

# 配置
JWT_SECRET = os.getenv('JWT_SECRET', 'your-secret-key')
SUPABASE_JWT_SECRET = os.getenv('SUPABASE_JWT_SECRET')
DOMAIN = os.getenv('DOMAIN', 'baidaohui.com')

def get_jwt_secrets():
    """获取所有可用的JWT密钥"""
    secrets = []
    if SUPABASE_JWT_SECRET:
        secrets.append(SUPABASE_JWT_SECRET)
    if JWT_SECRET:
        secrets.append(JWT_SECRET)
    return secrets

def verify_jwt_token(token: str) -> Optional[Dict[str, Any]]:
    """验证JWT token，支持多种密钥"""
    for secret in get_jwt_secrets():
        try:
            payload = jwt.decode(token, secret, algorithms=['HS256'])
            return payload
        except jwt.ExpiredSignatureError:
            return {'error': 'token_expired'}
        except jwt.InvalidTokenError:
            continue
    return {'error': 'invalid_token'}

def extract_token_from_request() -> Optional[str]:
    """从请求中提取JWT token"""
    # 1. 从Authorization header获取
    auth_header = request.headers.get('Authorization')
    if auth_header and auth_header.startswith('Bearer '):
        return auth_header.split(' ')[1]
    
    # 2. 从Cookie获取
    token = request.cookies.get('access_token') or request.cookies.get('sb-access-token')
    if token:
        return token
    
    return None

def get_token_hash(token: str) -> str:
    """获取token的hash值用于缓存"""
    return hashlib.sha256(token.encode()).hexdigest()[:32]

# ================================
# JWT验证相关接口
# ================================

@auth_bp.route('/validate', methods=['GET', 'POST'])
def validate_token():
    """验证JWT Token"""
    try:
        token = extract_token_from_request()
        if not token:
            return jsonify({
                'valid': False,
                'error': 'no_token',
                'message': '未提供认证token'
            }), 401
        
        # 验证JWT
        payload = verify_jwt_token(token)
        if 'error' in payload:
            return jsonify({
                'valid': False,
                'error': payload['error'],
                'message': '无效的token'
            }), 401
        
        user_id = payload.get('sub')
        if not user_id:
            return jsonify({
                'valid': False,
                'error': 'invalid_payload',
                'message': 'Token缺少用户ID'
            }), 401
        
        # 从本地缓存获取用户信息
        user_info = user_manager.get_user_by_id(user_id)
        if not user_info:
            return jsonify({
                'valid': False,
                'error': 'user_not_found',
                'message': '用户不存在'
            }), 404
        
        # 缓存会话信息
        token_hash = get_token_hash(token)
        expires_at = datetime.fromtimestamp(payload.get('exp', 0))
        user_manager.cache_user_session(user_id, token_hash, expires_at)
        
        return jsonify({
            'valid': True,
            'user': {
                'id': user_info['id'],
                'email': user_info['email'],
                'role': user_info['role'],
                'nickname': user_info['nickname']
            },
            'token_info': {
                'expires_at': expires_at.isoformat(),
                'issued_at': datetime.fromtimestamp(payload.get('iat', 0)).isoformat()
            }
        })
        
    except Exception as e:
        logger.error(f'Token验证失败: {str(e)}')
        return jsonify({
            'valid': False,
            'error': 'validation_failed',
            'message': '验证失败'
        }), 500

@auth_bp.route('/verify-role', methods=['POST'])
def verify_role():
    """验证用户角色权限"""
    try:
        data = request.get_json()
        required_roles = data.get('required_roles', [])
        
        token = extract_token_from_request()
        if not token:
            return jsonify({'authorized': False, 'error': 'no_token'}), 401
        
        payload = verify_jwt_token(token)
        if 'error' in payload:
            return jsonify({'authorized': False, 'error': payload['error']}), 401
        
        user_id = payload.get('sub')
        user_info = user_manager.get_user_by_id(user_id)
        
        if not user_info:
            return jsonify({'authorized': False, 'error': 'user_not_found'}), 404
        
        user_role = user_info['role']
        
        # 角色权限检查
        if not required_roles or user_role in required_roles:
            return jsonify({
                'authorized': True,
                'user_role': user_role,
                'user_id': user_id
            })
        else:
            return jsonify({
                'authorized': False,
                'error': 'insufficient_role',
                'user_role': user_role,
                'required_roles': required_roles
            }), 403
        
    except Exception as e:
        logger.error(f'角色验证失败: {str(e)}')
        return jsonify({'authorized': False, 'error': 'verification_failed'}), 500

# ================================
# 用户信息查询接口（为其他服务提供）
# ================================

@auth_bp.route('/user/<user_id>', methods=['GET'])
def get_user_info(user_id):
    """获取用户信息（供其他服务调用）"""
    try:
        # 验证调用者权限
        token = extract_token_from_request()
        if token:
            payload = verify_jwt_token(token)
            if 'error' not in payload:
                caller_id = payload.get('sub')
                caller_info = user_manager.get_user_by_id(caller_id)
                
                # 只有Master/Firstmate可以查询其他用户信息，普通用户只能查询自己
                if caller_info and (caller_info['role'] in ['Master', 'Firstmate'] or caller_id == user_id):
                    user_info = user_manager.get_user_by_id(user_id)
                    if user_info:
                        return jsonify({
                            'success': True,
                            'user': {
                                'id': user_info['id'],
                                'email': user_info['email'],
                                'role': user_info['role'],
                                'nickname': user_info['nickname'],
                                'created_at': user_info['created_at'],
                                'updated_at': user_info['updated_at']
                            }
                        })
                    else:
                        return jsonify({'success': False, 'error': 'user_not_found'}), 404
        
        return jsonify({'success': False, 'error': 'unauthorized'}), 401
        
    except Exception as e:
        logger.error(f'获取用户信息失败: {str(e)}')
        return jsonify({'success': False, 'error': 'query_failed'}), 500

@auth_bp.route('/user/by-email/<email>', methods=['GET'])
def get_user_by_email(email):
    """通过邮箱获取用户信息"""
    try:
        # 验证调用者权限
        token = extract_token_from_request()
        if token:
            payload = verify_jwt_token(token)
            if 'error' not in payload:
                caller_id = payload.get('sub')
                caller_info = user_manager.get_user_by_id(caller_id)
                
                # 只有Master/Firstmate可以查询用户信息
                if caller_info and caller_info['role'] in ['Master', 'Firstmate']:
                    user_info = user_manager.get_user_by_email(email)
                    if user_info:
                        return jsonify({
                            'success': True,
                            'user': {
                                'id': user_info['id'],
                                'email': user_info['email'],
                                'role': user_info['role'],
                                'nickname': user_info['nickname']
                            }
                        })
                    else:
                        return jsonify({'success': False, 'error': 'user_not_found'}), 404
        
        return jsonify({'success': False, 'error': 'unauthorized'}), 401
        
    except Exception as e:
        logger.error(f'通过邮箱获取用户信息失败: {str(e)}')
        return jsonify({'success': False, 'error': 'query_failed'}), 500

@auth_bp.route('/users/by-role/<role>', methods=['GET'])
def get_users_by_role(role):
    """获取指定角色的用户列表"""
    try:
        # 验证调用者权限
        token = extract_token_from_request()
        if not token:
            return jsonify({'success': False, 'error': 'unauthorized'}), 401
        
        payload = verify_jwt_token(token)
        if 'error' in payload:
            return jsonify({'success': False, 'error': payload['error']}), 401
        
        caller_id = payload.get('sub')
        caller_info = user_manager.get_user_by_id(caller_id)
        
        # 只有Master/Firstmate可以查询用户列表
        if not caller_info or caller_info['role'] not in ['Master', 'Firstmate']:
            return jsonify({'success': False, 'error': 'insufficient_permissions'}), 403
        
        limit = int(request.args.get('limit', 100))
        users = user_manager.get_users_by_role(role, limit)
        
        user_list = []
        for user in users:
            user_list.append({
                'id': user['id'],
                'email': user['email'],
                'role': user['role'],
                'nickname': user['nickname'],
                'created_at': user['created_at']
            })
        
        return jsonify({
            'success': True,
            'users': user_list,
            'total': len(user_list),
            'role_filter': role
        })
        
    except Exception as e:
        logger.error(f'获取角色用户列表失败: {str(e)}')
        return jsonify({'success': False, 'error': 'query_failed'}), 500

# ================================
# Supabase代理接口
# ================================

@auth_bp.route('/supabase/rpc/<function_name>', methods=['POST'])
def supabase_rpc_proxy(function_name):
    """Supabase RPC函数代理"""
    try:
        # 验证调用者权限
        token = extract_token_from_request()
        if not token:
            return jsonify({'error': 'unauthorized'}), 401
        
        payload = verify_jwt_token(token)
        if 'error' in payload:
            return jsonify({'error': payload['error']}), 401
        
        # 获取请求参数
        data = request.get_json() or {}
        
        # 调用Supabase RPC函数
        result = supabase_client._call_rpc(function_name, data)
        
        return jsonify(result)
        
    except Exception as e:
        logger.error(f'Supabase RPC代理失败: {str(e)}')
        return jsonify({'error': 'proxy_failed'}), 500

@auth_bp.route('/supabase/role-change', methods=['POST'])
def supabase_role_change_proxy():
    """用户角色变更代理（调用后清理本地缓存）"""
    try:
        # 验证调用者权限
        token = extract_token_from_request()
        if not token:
            return jsonify({'error': 'unauthorized'}), 401
        
        payload = verify_jwt_token(token)
        if 'error' in payload:
            return jsonify({'error': payload['error']}), 401
        
        caller_id = payload.get('sub')
        caller_info = user_manager.get_user_by_id(caller_id)
        
        # 只有Master可以调整角色
        if not caller_info or caller_info['role'] != 'Master':
            return jsonify({'error': 'insufficient_permissions'}), 403
        
        data = request.get_json()
        target_user_id = data.get('userId')
        target_email = data.get('email')
        new_role = data.get('newRole')
        reason = data.get('reason', '管理员调整')
        
        # 调用Supabase角色变更函数
        if target_email:
            result = supabase_client.admin_change_role_by_email(target_email, new_role, reason)
        elif target_user_id:
            result = supabase_client.admin_change_user_role(target_user_id, new_role, reason)
        else:
            return jsonify({'error': 'missing_user_identifier'}), 400
        
        # 如果成功，清理本地缓存
        if result.get('success'):
            affected_user_id = result.get('user_id') or target_user_id
            if affected_user_id:
                user_manager.invalidate_user_cache(affected_user_id)
                # 强制重新同步一次
                user_manager.sync_users_from_supabase(force=True)
        
        return jsonify(result)
        
    except Exception as e:
        logger.error(f'角色变更代理失败: {str(e)}')
        return jsonify({'error': 'role_change_failed'}), 500

# ================================
# 缓存管理接口
# ================================

@auth_bp.route('/cache/sync', methods=['POST'])
def sync_user_cache():
    """强制同步用户缓存"""
    try:
        # 验证调用者权限
        token = extract_token_from_request()
        if not token:
            return jsonify({'error': 'unauthorized'}), 401
        
        payload = verify_jwt_token(token)
        if 'error' in payload:
            return jsonify({'error': payload['error']}), 401
        
        caller_id = payload.get('sub')
        caller_info = user_manager.get_user_by_id(caller_id)
        
        # 只有Master/Firstmate可以强制同步
        if not caller_info or caller_info['role'] not in ['Master', 'Firstmate']:
            return jsonify({'error': 'insufficient_permissions'}), 403
        
        # 执行同步
        success = user_manager.sync_users_from_supabase(force=True)
        
        if success:
            return jsonify({
                'success': True,
                'message': '用户缓存同步成功',
                'sync_time': datetime.now().isoformat()
            })
        else:
            return jsonify({
                'success': False,
                'error': '同步失败'
            }), 500
        
    except Exception as e:
        logger.error(f'同步用户缓存失败: {str(e)}')
        return jsonify({'error': 'sync_failed'}), 500

@auth_bp.route('/cache/status', methods=['GET'])
def get_cache_status():
    """获取缓存状态"""
    try:
        # 验证调用者权限
        token = extract_token_from_request()
        if token:
            payload = verify_jwt_token(token)
            if 'error' not in payload:
                caller_id = payload.get('sub')
                caller_info = user_manager.get_user_by_id(caller_id)
                
                if caller_info and caller_info['role'] in ['Master', 'Firstmate']:
                    status = user_manager.get_sync_status()
                    return jsonify({
                        'success': True,
                        'cache_status': status
                    })
        
        return jsonify({'error': 'unauthorized'}), 401
        
    except Exception as e:
        logger.error(f'获取缓存状态失败: {str(e)}')
        return jsonify({'error': 'status_query_failed'}), 500

@auth_bp.route('/cache/invalidate/<user_id>', methods=['POST'])
def invalidate_user_cache(user_id):
    """使指定用户缓存失效"""
    try:
        # 验证调用者权限
        token = extract_token_from_request()
        if not token:
            return jsonify({'error': 'unauthorized'}), 401
        
        payload = verify_jwt_token(token)
        if 'error' in payload:
            return jsonify({'error': payload['error']}), 401
        
        caller_id = payload.get('sub')
        caller_info = user_manager.get_user_by_id(caller_id)
        
        # 只有Master可以清理缓存
        if not caller_info or caller_info['role'] != 'Master':
            return jsonify({'error': 'insufficient_permissions'}), 403
        
        user_manager.invalidate_user_cache(user_id)
        
        return jsonify({
            'success': True,
            'message': f'用户 {user_id} 缓存已清除'
        })
        
    except Exception as e:
        logger.error(f'清理用户缓存失败: {str(e)}')
        return jsonify({'error': 'cache_invalidation_failed'}), 500

# ================================
# 健康检查
# ================================

@auth_bp.route('/health', methods=['GET'])
def health_check():
    """健康检查"""
    try:
        # 检查本地缓存
        cache_status = user_manager.get_sync_status()
        
        # 检查Supabase连接
        supabase_healthy = True
        try:
            test_result = supabase_client._call_rpc('admin_list_users', {'limit_count': 1})
            supabase_healthy = not ('error' in test_result)
        except:
            supabase_healthy = False
        
        return jsonify({
            'status': 'healthy' if supabase_healthy else 'degraded',
            'timestamp': datetime.now().isoformat(),
            'service': 'auth-service-v2',
            'supabase_connection': 'ok' if supabase_healthy else 'error',
            'cache_status': {
                'total_users': cache_status.get('total_users', 0),
                'last_sync': cache_status.get('last_sync', {}).get('sync_time') if cache_status.get('last_sync') else None
            }
        })
        
    except Exception as e:
        return jsonify({
            'status': 'unhealthy',
            'error': str(e),
            'timestamp': datetime.now().isoformat(),
            'service': 'auth-service-v2'
        }), 500 