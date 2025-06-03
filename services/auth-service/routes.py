from flask import Blueprint, request, jsonify, make_response, redirect
import jwt
import json
from datetime import datetime, timedelta
import uuid
import requests
import logging
import os
from user_manager import user_manager

# 配置
JWT_SECRET = os.getenv('JWT_SECRET', 'your-secret-key')
DOMAIN = os.getenv('DOMAIN', 'baidaohui.com')

logger = logging.getLogger(__name__)

# 角色对应的子域名映射
ROLE_SUBDOMAINS = {
    'Fan': 'fan.baidaohui.com',
    'Member': 'member.baidaohui.com', 
    'Master': 'master.baidaohui.com',
    'Firstmate': 'firstmate.baidaohui.com',
    'Seller': 'seller.baidaohui.com'
}

auth_bp = Blueprint('auth', __name__)

@auth_bp.route('/callback', methods=['POST'])
def oauth_callback():
    """处理OAuth回调 - 已弃用，现在使用Supabase原生认证"""
    logger.warning("已弃用的OAuth回调接口被调用")
    return jsonify({
        'error': 'deprecated',
        'message': '此接口已弃用，前端现在直接使用Supabase原生认证',
        'recommendation': '请使用Supabase的exchangeCodeForSession方法'
    }), 410

@auth_bp.route('/login', methods=['POST'])
def login():
    """处理Google OAuth登录 - 已弃用，现在使用Supabase原生认证"""
    logger.warning("已弃用的登录接口被调用")
    return jsonify({
        'error': 'deprecated',
        'message': '此接口已弃用，前端现在直接使用Supabase原生认证',
        'recommendation': '请使用Supabase的signInWithOAuth方法'
    }), 410

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

@auth_bp.route('/check-role', methods=['GET'])
def check_role():
    """检查用户角色权限"""
    try:
        token = request.cookies.get('access_token')
        if not token:
            return jsonify({'error': '未登录'}), 401
        
        try:
            payload = jwt.decode(token, JWT_SECRET, algorithms=['HS256'])
        except jwt.InvalidTokenError:
            return jsonify({'error': '无效的token'}), 401
        
        required_role = request.args.get('role')
        user_role = payload['role']
        
        # 检查角色权限
        role_hierarchy = {
            'Fan': 1,
            'Member': 2,
            'Seller': 3,
            'Firstmate': 4,
            'Master': 5
        }
        
        user_level = role_hierarchy.get(user_role, 0)
        required_level = role_hierarchy.get(required_role, 0)
        
        has_permission = user_level >= required_level
        
        return jsonify({
            'has_permission': has_permission,
            'user_role': user_role,
            'required_role': required_role
        })
        
    except Exception as e:
        logger.error(f'角色检查失败: {str(e)}')
        return jsonify({'error': '检查失败'}), 500

@auth_bp.route('/refresh', methods=['POST'])
def refresh_token():
    """刷新Token"""
    try:
        token = request.cookies.get('access_token')
        if not token:
            return jsonify({'error': '未提供token'}), 401
        
        try:
            # 允许过期的token进行刷新（在一定时间内）
            payload = jwt.decode(token, JWT_SECRET, algorithms=['HS256'], options={"verify_exp": False})
        except jwt.InvalidTokenError:
            return jsonify({'error': '无效的token'}), 401
        
        # 检查token是否在可刷新时间内（7天内）
        exp_time = datetime.fromtimestamp(payload['exp'])
        if datetime.utcnow() - exp_time > timedelta(days=7):
            return jsonify({'error': 'Token过期时间过长，请重新登录'}), 401
        
        # 生成新token
        new_payload = {
            'sub': payload['sub'],
            'email': payload['email'],
            'role': payload['role'],
            'iat': datetime.utcnow(),
            'exp': datetime.utcnow() + timedelta(days=7)
        }
        
        new_token = jwt.encode(new_payload, JWT_SECRET, algorithm='HS256')
        
        response = make_response(jsonify({
            'success': True,
            'message': 'Token刷新成功'
        }))
        
        response.set_cookie(
            'access_token',
            new_token,
            max_age=7*24*60*60,
            httponly=True,
            secure=True,
            samesite='Lax',
            domain=f'.{DOMAIN}'
        )
        
        return response
        
    except Exception as e:
        logger.error(f'Token刷新失败: {str(e)}')
        return jsonify({'error': '刷新失败'}), 500

@auth_bp.route('/session-info', methods=['GET'])
def get_session_info():
    """获取当前会话信息"""
    try:
        token = request.cookies.get('access_token')
        if not token:
            return jsonify({'authenticated': False})
        
        try:
            payload = jwt.decode(token, JWT_SECRET, algorithms=['HS256'])
        except jwt.ExpiredSignatureError:
            return jsonify({'authenticated': False, 'reason': 'expired'})
        except jwt.InvalidTokenError:
            return jsonify({'authenticated': False, 'reason': 'invalid'})
        
        return jsonify({
            'authenticated': True,
            'user': {
                'id': payload['sub'],
                'email': payload['email'],
                'role': payload['role']
            },
            'expires_at': payload['exp']
        })
        
    except Exception as e:
        logger.error(f'获取会话信息失败: {str(e)}')
        return jsonify({'error': '获取失败'}), 500

@auth_bp.route('/user/<user_id>', methods=['GET'])
def get_user_info(user_id):
    """获取用户信息"""
    try:
        # 验证JWT token
        token = request.headers.get('Authorization', '').replace('Bearer ', '')
        if not token:
            return jsonify({'error': '缺少认证token'}), 401
        
        payload = jwt.decode(token, JWT_SECRET, algorithms=['HS256'])
        current_user_id = payload['sub']
        current_user_role = payload['role']
        
        # 权限检查：只能查看自己的信息，或者Master/Firstmate可以查看所有用户
        if current_user_id != user_id and current_user_role not in ['Master', 'Firstmate']:
            return jsonify({'error': '无权限访问'}), 403
        
        # 从Supabase获取用户信息
        supabase_url = os.getenv('SUPABASE_URL')
        supabase_key = os.getenv('SUPABASE_SERVICE_KEY')
        
        headers = {
            'apikey': supabase_key,
            'Authorization': f'Bearer {supabase_key}',
            'Content-Type': 'application/json'
        }
        
        # 获取用户基本信息
        response = requests.get(
            f'{supabase_url}/rest/v1/profiles?id=eq.{user_id}&select=*',
            headers=headers
        )
        
        if response.status_code == 200:
            profiles = response.json()
            if profiles:
                profile = profiles[0]
                return jsonify({
                    'id': profile['id'],
                    'email': profile.get('email', ''),
                    'role': profile.get('role', ''),
                    'nickname': profile.get('nickname', ''),
                    'created_at': profile.get('created_at', ''),
                    'updated_at': profile.get('updated_at', '')
                })
        
        return jsonify({'error': '用户不存在'}), 404
        
    except jwt.InvalidTokenError:
        return jsonify({'error': '无效的token'}), 401
    except Exception as e:
        logger.error(f"获取用户信息失败: {str(e)}")
        return jsonify({'error': '服务器内部错误'}), 500

@auth_bp.route('/profile/check-nickname', methods=['GET'])
def check_nickname_availability():
    """检查昵称可用性"""
    try:
        nickname = request.args.get('nickname', '').strip()
        
        if not nickname:
            return jsonify({'error': '昵称不能为空'}), 400
        
        if len(nickname) < 2:
            return jsonify({'available': False, 'reason': '昵称至少需要2个字符'}), 200
        
        if len(nickname) > 20:
            return jsonify({'available': False, 'reason': '昵称不能超过20个字符'}), 200
        
        # 检查昵称是否已被使用
        supabase_url = os.getenv('SUPABASE_URL')
        supabase_key = os.getenv('SUPABASE_SERVICE_KEY')
        
        headers = {
            'apikey': supabase_key,
            'Authorization': f'Bearer {supabase_key}',
            'Content-Type': 'application/json'
        }
        
        response = requests.get(
            f'{supabase_url}/rest/v1/profiles?nickname=eq.{nickname}&select=id',
            headers=headers
        )
        
        if response.status_code == 200:
            profiles = response.json()
            available = len(profiles) == 0
            
            return jsonify({
                'available': available,
                'reason': '昵称已被使用' if not available else None
            })
        
        return jsonify({'error': '检查昵称时出错'}), 500
        
    except Exception as e:
        logger.error(f"检查昵称可用性失败: {str(e)}")
        return jsonify({'error': '服务器内部错误'}), 500

@auth_bp.route('/profile/update-nickname', methods=['POST'])
def update_nickname():
    """更新用户昵称"""
    try:
        # 验证JWT token
        token = request.headers.get('Authorization', '').replace('Bearer ', '')
        if not token:
            return jsonify({'error': '缺少认证token'}), 401
        
        payload = jwt.decode(token, JWT_SECRET, algorithms=['HS256'])
        current_user_id = payload['sub']
        current_user_role = payload['role']
        
        data = request.get_json()
        user_id = data.get('userId')
        nickname = data.get('nickname', '').strip()
        
        if not user_id or not nickname:
            return jsonify({'error': '用户ID和昵称不能为空'}), 400
        
        # 权限检查：只能修改自己的昵称
        if current_user_id != user_id:
            return jsonify({'error': '只能修改自己的昵称'}), 403
        
        # 验证昵称格式
        if len(nickname) < 2 or len(nickname) > 20:
            return jsonify({'error': '昵称长度必须在2-20个字符之间'}), 400
        
        # 检查昵称是否已被其他用户使用
        supabase_url = os.getenv('SUPABASE_URL')
        supabase_key = os.getenv('SUPABASE_SERVICE_KEY')
        
        headers = {
            'apikey': supabase_key,
            'Authorization': f'Bearer {supabase_key}',
            'Content-Type': 'application/json'
        }
        
        # 检查昵称是否被其他用户使用
        check_response = requests.get(
            f'{supabase_url}/rest/v1/profiles?nickname=eq.{nickname}&id=neq.{user_id}&select=id',
            headers=headers
        )
        
        if check_response.status_code == 200:
            existing_profiles = check_response.json()
            if existing_profiles:
                return jsonify({'error': '昵称已被其他用户使用'}), 400
        
        # 更新昵称
        update_response = requests.patch(
            f'{supabase_url}/rest/v1/profiles?id=eq.{user_id}',
            headers=headers,
            json={
                'nickname': nickname,
                'updated_at': datetime.utcnow().isoformat()
            }
        )
        
        if update_response.status_code == 204:
            return jsonify({
                'success': True,
                'message': '昵称更新成功',
                'nickname': nickname
            })
        
        return jsonify({'error': '更新昵称失败'}), 500
        
    except jwt.InvalidTokenError:
        return jsonify({'error': '无效的token'}), 401
    except Exception as e:
        logger.error(f"更新昵称失败: {str(e)}")
        return jsonify({'error': '服务器内部错误'}), 500

@auth_bp.route('/profile/master-stats', methods=['GET'])
def get_master_stats():
    """获取Master统计数据"""
    try:
        # 验证JWT token
        token = request.headers.get('Authorization', '').replace('Bearer ', '')
        if not token:
            return jsonify({'error': '缺少认证token'}), 401
        
        payload = jwt.decode(token, JWT_SECRET, algorithms=['HS256'])
        current_user_id = payload['sub']
        current_user_role = payload['role']
        user_id = request.args.get('userId')
        
        # 权限检查：只有Master可以查看统计数据
        if current_user_role != 'Master' or current_user_id != user_id:
            return jsonify({'error': '无权限访问Master统计数据'}), 403
        
        # 获取统计数据
        stats = {
            'totalMembers': 0,
            'totalFortuneOrders': 0,
            'totalSellers': 0,
            'totalRevenue': 0,
            'joinDate': '',
            'lastLogin': ''
        }
        
        # 从Supabase获取用户数量统计
        supabase_url = os.getenv('SUPABASE_URL')
        supabase_key = os.getenv('SUPABASE_SERVICE_KEY')
        
        headers = {
            'apikey': supabase_key,
            'Authorization': f'Bearer {supabase_key}',
            'Content-Type': 'application/json'
        }
        
        # 获取Member数量
        member_response = requests.get(
            f'{supabase_url}/rest/v1/profiles?role=eq.Member&select=id',
            headers=headers
        )
        if member_response.status_code == 200:
            stats['totalMembers'] = len(member_response.json())
        
        # 获取Seller数量
        seller_response = requests.get(
            f'{supabase_url}/rest/v1/profiles?role=eq.Seller&select=id',
            headers=headers
        )
        if seller_response.status_code == 200:
            stats['totalSellers'] = len(seller_response.json())
        
        # 获取Master的注册时间
        master_response = requests.get(
            f'{supabase_url}/rest/v1/profiles?id=eq.{user_id}&select=created_at',
            headers=headers
        )
        if master_response.status_code == 200:
            master_data = master_response.json()
            if master_data:
                stats['joinDate'] = master_data[0].get('created_at', '')
        
        # 通过API获取算命订单统计
        try:
            fortune_api_url = os.getenv('FORTUNE_API_URL', 'http://216.144.233.104:5007')
            fortune_response = requests.get(
                f'{fortune_api_url}/fortune/stats',
                headers={'Authorization': f'Bearer {token}'},
                timeout=5
            )
            if fortune_response.status_code == 200:
                fortune_data = fortune_response.json()
                stats['totalFortuneOrders'] = fortune_data.get('total_orders', 0)
                stats['totalRevenue'] = fortune_data.get('total_revenue', 0)
            else:
                stats['totalFortuneOrders'] = 0
                stats['totalRevenue'] = 0
        except Exception as e:
            logger.warning(f"获取算命统计数据失败: {str(e)}")
            stats['totalFortuneOrders'] = 0
            stats['totalRevenue'] = 0
        
        # 设置最后登录时间为当前时间
        stats['lastLogin'] = datetime.utcnow().isoformat()
        
        return jsonify(stats)
        
    except jwt.InvalidTokenError:
        return jsonify({'error': '无效的token'}), 401
    except Exception as e:
        logger.error(f"获取Master统计数据失败: {str(e)}")
        return jsonify({'error': '服务器内部错误'}), 500

@auth_bp.route('/sync-role', methods=['POST'])
def sync_user_role():
    """强制同步用户角色（从Supabase到MongoDB）"""
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
        
        # 从Supabase获取最新的用户角色
        supabase_url = os.getenv('SUPABASE_URL')
        supabase_key = os.getenv('SUPABASE_SERVICE_KEY')
        
        if not supabase_url or not supabase_key:
            return jsonify({'error': 'Supabase配置缺失'}), 500
        
        headers = {
            'apikey': supabase_key,
            'Authorization': f'Bearer {supabase_key}',
            'Content-Type': 'application/json'
        }
        
        # 获取Supabase中的用户角色
        response = requests.get(
            f'{supabase_url}/rest/v1/profiles?id=eq.{target_user_id}&select=role,email,nickname',
            headers=headers
        )
        
        if response.status_code != 200:
            logger.error(f"从Supabase获取用户信息失败: {response.text}")
            return jsonify({'error': 'Supabase查询失败'}), 500
        
        profiles = response.json()
        if not profiles:
            return jsonify({'error': '用户不存在'}), 404
        
        supabase_profile = profiles[0]
        supabase_role = supabase_profile.get('role', 'Fan')
        user_email = supabase_profile.get('email', '')
        user_nickname = supabase_profile.get('nickname', '')
        
        # 清除本地缓存，强制重新同步
        user_manager.invalidate_user_cache(target_user_id)
        
        # 获取更新后的用户信息
        updated_user = user_manager.fetch_and_cache_user(target_user_id)
        
        if updated_user:
            logger.info(f"成功同步用户角色: {user_email} -> {supabase_role}")
            
            # 如果是当前用户，生成新的JWT token
            if current_user_id == target_user_id:
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
                
                return response
            else:
                return jsonify({
                    'success': True,
                    'message': '角色同步成功',
                    'user': {
                        'id': target_user_id,
                        'email': user_email,
                        'role': supabase_role,
                        'nickname': user_nickname
                    }
                })
        else:
            return jsonify({'error': '同步失败，无法获取更新后的用户信息'}), 500
        
    except jwt.InvalidTokenError:
        return jsonify({'error': '无效的token'}), 401
    except Exception as e:
        logger.error(f"角色同步失败: {str(e)}")
        return jsonify({'error': f'同步失败: {str(e)}'}), 500

@auth_bp.route('/profile/stats', methods=['GET'])
def get_profile_stats():
    """获取用户档案统计数据"""
    try:
        # 验证JWT token
        token = request.headers.get('Authorization', '').replace('Bearer ', '')
        if not token:
            return jsonify({'error': '缺少认证token'}), 401
        
        payload = jwt.decode(token, JWT_SECRET, algorithms=['HS256'])
        current_user_id = payload['sub']
        current_user_role = payload['role']
        
        # 获取用户基本信息
        user_info = user_manager.get_user_by_id(current_user_id)
        if not user_info:
            return jsonify({'error': '用户信息不存在'}), 404
        
        # 基础统计数据
        stats = {
            'userId': current_user_id,
            'email': user_info.get('email', ''),
            'role': user_info.get('role', 'Fan'),
            'nickname': user_info.get('nickname', ''),
            'joinDate': user_info.get('created_at', ''),
            'lastLogin': datetime.utcnow().isoformat(),
            'profileCompleteness': 0,
            'activityScore': 0
        }
        
        # 计算档案完整度
        completeness = 0
        if stats['email']:
            completeness += 25
        if stats['nickname']:
            completeness += 25
        if stats['role'] != 'Fan':
            completeness += 50
        stats['profileCompleteness'] = completeness
        
        # 根据角色添加特定统计
        if current_user_role == 'Master':
            # Master特有统计
            try:
                # 从Supabase获取用户数量统计
                supabase_url = os.getenv('SUPABASE_URL')
                supabase_key = os.getenv('SUPABASE_SERVICE_KEY')
                
                headers = {
                    'apikey': supabase_key,
                    'Authorization': f'Bearer {supabase_key}',
                    'Content-Type': 'application/json'
                }
                
                # 获取Member数量
                member_response = requests.get(
                    f'{supabase_url}/rest/v1/profiles?role=eq.Member&select=id',
                    headers=headers
                )
                if member_response.status_code == 200:
                    stats['totalMembers'] = len(member_response.json())
                
                # 通过API获取算命订单统计（如果fortune服务可用）
                try:
                    fortune_api_url = os.getenv('FORTUNE_API_URL', 'http://216.144.233.104:5007')
                    fortune_response = requests.get(
                        f'{fortune_api_url}/fortune/stats',
                        headers={'Authorization': f'Bearer {token}'},
                        timeout=5
                    )
                    if fortune_response.status_code == 200:
                        fortune_data = fortune_response.json()
                        stats['totalFortuneOrders'] = fortune_data.get('total_orders', 0)
                        stats['totalRevenue'] = fortune_data.get('total_revenue', 0)
                    else:
                        stats['totalFortuneOrders'] = 0
                        stats['totalRevenue'] = 0
                except:
                    stats['totalFortuneOrders'] = 0
                    stats['totalRevenue'] = 0
                    
                stats['activityScore'] = min(100, (stats.get('totalFortuneOrders', 0) * 5) + (stats.get('totalMembers', 0) * 2))
                
            except Exception as e:
                logger.warning(f"获取Master统计数据失败: {str(e)}")
                stats.update({
                    'totalMembers': 0,
                    'totalFortuneOrders': 0,
                    'totalRevenue': 0
                })
                
        elif current_user_role == 'Member':
            # Member特有统计
            try:
                # 通过API获取Member的算命订单数量
                try:
                    fortune_api_url = os.getenv('FORTUNE_API_URL', 'http://216.144.233.104:5007')
                    member_orders_response = requests.get(
                        f'{fortune_api_url}/fortune/user/{current_user_id}/stats',
                        headers={'Authorization': f'Bearer {token}'},
                        timeout=5
                    )
                    if member_orders_response.status_code == 200:
                        member_data = member_orders_response.json()
                        stats['myFortuneOrders'] = member_data.get('total_orders', 0)
                    else:
                        stats['myFortuneOrders'] = 0
                except:
                    stats['myFortuneOrders'] = 0
                
                # 通过API获取私聊消息数量
                try:
                    chat_api_url = os.getenv('CHAT_API_URL', 'http://chat-service:5003')
                    messages_response = requests.get(
                        f'{chat_api_url}/api/messages/user/{current_user_id}/stats',
                        headers={'Authorization': f'Bearer {token}'},
                        timeout=5
                    )
                    if messages_response.status_code == 200:
                        message_data = messages_response.json()
                        stats['privateMessages'] = message_data.get('private_message_count', 0)
                    else:
                        stats['privateMessages'] = 0
                except:
                    stats['privateMessages'] = 0
                
                stats['activityScore'] = min(100, (stats.get('myFortuneOrders', 0) * 20) + (stats.get('privateMessages', 0) * 2))
                
            except Exception as e:
                logger.warning(f"获取Member统计数据失败: {str(e)}")
                stats.update({
                    'myFortuneOrders': 0,
                    'privateMessages': 0
                })
                
        elif current_user_role == 'Seller':
            # Seller特有统计
            try:
                # 这里可以添加Seller相关的统计逻辑
                stats['salesCount'] = 0
                stats['revenue'] = 0
                stats['activityScore'] = 50  # 默认活跃度
                
            except Exception as e:
                logger.warning(f"获取Seller统计数据失败: {str(e)}")
                
        else:
            # Fan或其他角色的基础统计
            stats['activityScore'] = 20  # 基础活跃度
        
        return jsonify(stats)
        
    except jwt.InvalidTokenError:
        return jsonify({'error': '无效的token'}), 401
    except Exception as e:
        logger.error(f"获取档案统计数据失败: {str(e)}")
        return jsonify({'error': '服务器内部错误'}), 500

@auth_bp.route('/profile/update', methods=['POST'])
def update_profile():
    """更新用户档案信息"""
    try:
        # 验证JWT token
        token = request.headers.get('Authorization', '').replace('Bearer ', '')
        if not token:
            return jsonify({'error': '缺少认证token'}), 401
        
        payload = jwt.decode(token, JWT_SECRET, algorithms=['HS256'])
        current_user_id = payload['sub']
        current_user_role = payload['role']
        
        data = request.get_json()
        if not data:
            return jsonify({'error': '缺少更新数据'}), 400
        
        # 可更新的字段
        allowed_fields = ['nickname', 'bio', 'avatar_url', 'preferences']
        update_data = {}
        
        for field in allowed_fields:
            if field in data:
                update_data[field] = data[field]
        
        if not update_data:
            return jsonify({'error': '没有有效的更新字段'}), 400
        
        # 特殊处理昵称更新
        if 'nickname' in update_data:
            nickname = update_data['nickname'].strip()
            if not nickname:
                return jsonify({'error': '昵称不能为空'}), 400
            
            if len(nickname) > 20:
                return jsonify({'error': '昵称长度不能超过20个字符'}), 400
            
            # 检查昵称是否已被使用（通过Supabase）
            supabase_url = os.getenv('SUPABASE_URL')
            supabase_key = os.getenv('SUPABASE_SERVICE_KEY')
            
            headers = {
                'apikey': supabase_key,
                'Authorization': f'Bearer {supabase_key}',
                'Content-Type': 'application/json'
            }
            
            # 检查昵称唯一性
            check_response = requests.get(
                f'{supabase_url}/rest/v1/profiles?nickname=eq.{nickname}&id=neq.{current_user_id}&select=id',
                headers=headers
            )
            
            if check_response.status_code == 200:
                existing_users = check_response.json()
                if existing_users:
                    return jsonify({'error': '昵称已被使用'}), 409
        
        # 更新Supabase中的用户档案
        update_data['updated_at'] = datetime.utcnow().isoformat()
        
        update_response = requests.patch(
            f'{supabase_url}/rest/v1/profiles?id=eq.{current_user_id}',
            headers=headers,
            json=update_data
        )
        
        if update_response.status_code not in [200, 204]:
            logger.error(f"Supabase更新失败: {update_response.text}")
            return jsonify({'error': 'Supabase更新失败'}), 500
        
        # 清除本地缓存，强制重新同步
        user_manager.invalidate_user_cache(current_user_id)
        
        # 获取更新后的用户信息
        updated_user = user_manager.fetch_and_cache_user(current_user_id)
        
        if updated_user:
            # 如果昵称更新了，需要更新JWT token
            if 'nickname' in update_data:
                new_payload = {
                    'sub': current_user_id,
                    'email': updated_user.get('email', ''),
                    'role': updated_user.get('role', 'Fan'),
                    'nickname': updated_user.get('nickname', ''),
                    'iat': datetime.utcnow(),
                    'exp': datetime.utcnow() + timedelta(days=7)
                }
                
                new_token = jwt.encode(new_payload, JWT_SECRET, algorithm='HS256')
                
                response = make_response(jsonify({
                    'success': True,
                    'message': '档案更新成功',
                    'user': {
                        'id': current_user_id,
                        'email': updated_user.get('email', ''),
                        'role': updated_user.get('role', 'Fan'),
                        'nickname': updated_user.get('nickname', ''),
                        'bio': updated_user.get('bio', ''),
                        'avatar_url': updated_user.get('avatar_url', ''),
                        'preferences': updated_user.get('preferences', {})
                    },
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
                
                return response
            else:
                return jsonify({
                    'success': True,
                    'message': '档案更新成功',
                    'user': {
                        'id': current_user_id,
                        'email': updated_user.get('email', ''),
                        'role': updated_user.get('role', 'Fan'),
                        'nickname': updated_user.get('nickname', ''),
                        'bio': updated_user.get('bio', ''),
                        'avatar_url': updated_user.get('avatar_url', ''),
                        'preferences': updated_user.get('preferences', {})
                    }
                })
        else:
            return jsonify({'error': '获取更新后的用户信息失败'}), 500
        
    except jwt.InvalidTokenError:
        return jsonify({'error': '无效的token'}), 401
    except Exception as e:
        logger.error(f"更新档案失败: {str(e)}")
        return jsonify({'error': f'更新失败: {str(e)}'}), 500

@auth_bp.route('/user/stats', methods=['GET'])
def get_user_stats():
    """获取用户整体统计数据（管理员视角）"""
    try:
        # 验证JWT token
        token = request.headers.get('Authorization', '').replace('Bearer ', '')
        if not token:
            return jsonify({'error': '缺少认证token'}), 401
        
        payload = jwt.decode(token, JWT_SECRET, algorithms=['HS256'])
        current_user_id = payload['sub']
        current_user_role = payload['role']
        
        # 权限检查：只有Master和Firstmate可以查看整体统计
        if current_user_role not in ['Master', 'Firstmate']:
            return jsonify({'error': '无权限访问用户统计数据'}), 403
        
        # 从Supabase获取用户统计
        supabase_url = os.getenv('SUPABASE_URL')
        supabase_key = os.getenv('SUPABASE_SERVICE_KEY')
        
        headers = {
            'apikey': supabase_key,
            'Authorization': f'Bearer {supabase_key}',
            'Content-Type': 'application/json'
        }
        
        # 获取各角色用户数量
        stats = {
            'totalUsers': 0,
            'usersByRole': {
                'Fan': 0,
                'Member': 0,
                'Seller': 0,
                'Firstmate': 0,
                'Master': 0
            },
            'recentRegistrations': 0,
            'activeUsers': 0,
            'timestamp': datetime.utcnow().isoformat()
        }
        
        # 获取所有用户
        all_users_response = requests.get(
            f'{supabase_url}/rest/v1/profiles?select=id,role,created_at',
            headers=headers
        )
        
        if all_users_response.status_code == 200:
            all_users = all_users_response.json()
            stats['totalUsers'] = len(all_users)
            
            # 统计各角色用户数量
            for user in all_users:
                role = user.get('role', 'Fan')
                if role in stats['usersByRole']:
                    stats['usersByRole'][role] += 1
            
            # 统计最近7天注册的用户
            seven_days_ago = datetime.utcnow() - timedelta(days=7)
            recent_count = 0
            for user in all_users:
                created_at = user.get('created_at')
                if created_at:
                    try:
                        created_date = datetime.fromisoformat(created_at.replace('Z', '+00:00'))
                        if created_date >= seven_days_ago:
                            recent_count += 1
                    except:
                        pass
            stats['recentRegistrations'] = recent_count
        
        # 通过API获取活跃用户数量
        try:
            chat_api_url = os.getenv('CHAT_API_URL', 'http://chat-service:5003')
            active_users_response = requests.get(
                f'{chat_api_url}/api/chat/online-users',
                headers={'Authorization': f'Bearer {token}'},
                timeout=5
            )
            if active_users_response.status_code == 200:
                active_data = active_users_response.json()
                stats['activeUsers'] = active_data.get('count', 0)
            else:
                stats['activeUsers'] = 0
        except Exception as e:
            logger.warning(f"获取活跃用户数量失败: {str(e)}")
            stats['activeUsers'] = 0
        
        # 通过API获取业务统计
        try:
            # 算命订单统计
            fortune_api_url = os.getenv('FORTUNE_API_URL', 'http://216.144.233.104:5007')
            fortune_stats_response = requests.get(
                f'{fortune_api_url}/fortune/admin/stats',
                headers={'Authorization': f'Bearer {token}'},
                timeout=5
            )
            
            # 消息统计
            chat_api_url = os.getenv('CHAT_API_URL', 'http://chat-service:5003')
            message_stats_response = requests.get(
                f'{chat_api_url}/api/messages/stats',
                headers={'Authorization': f'Bearer {token}'},
                timeout=5
            )
            
            business_stats = {
                'totalFortuneOrders': 0,
                'completedOrders': 0,
                'totalMessages': 0,
                'recentMessages': 0
            }
            
            if fortune_stats_response.status_code == 200:
                fortune_data = fortune_stats_response.json()
                business_stats['totalFortuneOrders'] = fortune_data.get('total_orders', 0)
                business_stats['completedOrders'] = fortune_data.get('completed_orders', 0)
            
            if message_stats_response.status_code == 200:
                message_data = message_stats_response.json()
                business_stats['totalMessages'] = message_data.get('total_messages', 0)
                business_stats['recentMessages'] = message_data.get('recent_messages', 0)
            
            stats['businessStats'] = business_stats
            
        except Exception as e:
            logger.warning(f"获取业务统计失败: {str(e)}")
            stats['businessStats'] = {
                'totalFortuneOrders': 0,
                'completedOrders': 0,
                'totalMessages': 0,
                'recentMessages': 0
            }
        
        return jsonify(stats)
        
    except jwt.InvalidTokenError:
        return jsonify({'error': '无效的token'}), 401
    except Exception as e:
        logger.error(f"获取用户统计数据失败: {str(e)}")
        return jsonify({'error': '服务器内部错误'}), 500