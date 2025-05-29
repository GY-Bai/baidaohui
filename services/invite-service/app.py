from flask import Flask, request, jsonify
from flask_cors import CORS
import os
import jwt
import secrets
import string
import requests
from datetime import datetime, timedelta
from pymongo import MongoClient
from bson import ObjectId
import logging
import hashlib
import hmac

# 配置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)

# 环境变量配置
MONGODB_URI = os.getenv('MONGODB_URI', 'mongodb://localhost:27017/baidaohui')
JWT_SECRET = os.getenv('JWT_SECRET', 'your-jwt-secret-key')
SUPABASE_JWT_SECRET = os.getenv('SUPABASE_JWT_SECRET')
SUPABASE_URL = os.getenv('SUPABASE_URL')
SUPABASE_SERVICE_KEY = os.getenv('SUPABASE_SERVICE_KEY')
FRONTEND_BASE_URL = os.getenv('FRONTEND_BASE_URL', 'https://baidaohui.com')
WEBHOOK_SECRET = os.getenv('WEBHOOK_SECRET')  # 用于验证webhook调用
AUDIT_WEBHOOK_URL = os.getenv('AUDIT_WEBHOOK_URL')  # 审计日志webhook

# JWT兼容性配置：支持两种JWT验证方式
def get_jwt_secrets():
    """获取所有可用的JWT密钥用于验证"""
    secrets = []
    if SUPABASE_JWT_SECRET:
        secrets.append(SUPABASE_JWT_SECRET)
    if JWT_SECRET:
        secrets.append(JWT_SECRET)
    return secrets

def verify_jwt_token(token):
    """验证JWT令牌，支持多种密钥"""
    for secret in get_jwt_secrets():
        try:
            payload = jwt.decode(token, secret, algorithms=['HS256'])
            return payload
        except jwt.InvalidTokenError:
            continue
    raise jwt.InvalidTokenError("无法验证JWT令牌")

# MongoDB 连接
try:
    client = MongoClient(MONGODB_URI)
    db = client.baidaohui
    invite_links = db.invite_links
    audit_logs = db.audit_logs
    logger.info("MongoDB 连接成功")
except Exception as e:
    logger.error(f"MongoDB 连接失败: {e}")
    raise

def verify_jwt(token):
    """验证JWT令牌（支持Supabase和传统JWT）"""
    try:
        # 优先尝试Supabase JWT
        if SUPABASE_JWT_SECRET:
            try:
                payload = jwt.decode(token, SUPABASE_JWT_SECRET, algorithms=['HS256'])
                return {
                    'sub': payload['sub'],
                    'email': payload.get('email'),
                    'role': payload.get('user_metadata', {}).get('role', 'user')
                }
            except jwt.InvalidTokenError:
                pass
        
        # 回退到传统JWT
        payload = jwt.decode(token, JWT_SECRET, algorithms=['HS256'])
        return payload
    except jwt.ExpiredSignatureError:
        return None
    except jwt.InvalidTokenError:
        return None

def generate_token(length=32):
    """生成随机令牌"""
    alphabet = string.ascii_letters + string.digits
    return ''.join(secrets.choice(alphabet) for _ in range(length))

def generate_nonce():
    """生成防重放随机数"""
    return secrets.token_hex(16)

def check_auth():
    """检查用户认证和权限"""
    auth_header = request.headers.get('Authorization')
    token = None
    
    if auth_header and auth_header.startswith('Bearer '):
        token = auth_header.split(' ')[1]
    else:
        # 尝试从Cookie获取
        token = request.cookies.get('access_token') or request.cookies.get('sb-access-token')
    
    if not token:
        return None, {'error': '缺少认证令牌'}, 401
    
    payload = verify_jwt(token)
    if not payload:
        return None, {'error': '无效的认证令牌'}, 401
    
    return payload, None, None

def log_audit_event(event_type, user_id, details, ip_address=None, user_agent=None):
    """记录审计日志"""
    try:
        audit_record = {
            'event_type': event_type,
            'user_id': user_id,
            'details': details,
            'ip_address': ip_address or request.remote_addr,
            'user_agent': user_agent or request.headers.get('User-Agent', ''),
            'timestamp': datetime.utcnow(),
            'service': 'invite-service'
        }
        
        # 保存到数据库
        audit_logs.insert_one(audit_record)
        
        # 发送到外部审计系统（如果配置了）
        if AUDIT_WEBHOOK_URL:
            try:
                requests.post(AUDIT_WEBHOOK_URL, json=audit_record, timeout=5)
            except Exception as e:
                logger.warning(f"发送审计日志到webhook失败: {e}")
        
        logger.info(f"审计日志: {event_type} by {user_id}")
        
    except Exception as e:
        logger.error(f"记录审计日志失败: {e}")

def update_user_role_in_supabase(user_id, new_role):
    """在Supabase中更新用户角色"""
    if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
        logger.warning("Supabase配置缺失，跳过角色更新")
        return False
    
    try:
        headers = {
            'Authorization': f'Bearer {SUPABASE_SERVICE_KEY}',
            'Content-Type': 'application/json',
            'apikey': SUPABASE_SERVICE_KEY
        }
        
        # 更新用户元数据
        update_data = {
            'user_metadata': {
                'role': new_role
            }
        }
        
        response = requests.put(
            f"{SUPABASE_URL}/auth/v1/admin/users/{user_id}",
            headers=headers,
            json=update_data,
            timeout=10
        )
        
        if response.status_code == 200:
            logger.info(f"Supabase用户 {user_id} 角色更新为 {new_role}")
            return True
        else:
            logger.error(f"Supabase角色更新失败: {response.status_code} - {response.text}")
            return False
            
    except Exception as e:
        logger.error(f"Supabase角色更新异常: {e}")
        return False

@app.route('/health', methods=['GET'])
def health_check():
    """健康检查接口"""
    return jsonify({
        'status': 'healthy', 
        'service': 'invite-service',
        'timestamp': datetime.utcnow().isoformat()
    })

@app.route('/invite/generate', methods=['POST'])
def generate_invite():
    """生成邀请链接"""
    try:
        # 验证用户权限
        payload, error_response, status_code = check_auth()
        if error_response:
            return jsonify(error_response), status_code
        
        user_role = payload.get('role')
        user_id = payload.get('sub')
        user_email = payload.get('email')
        
        # 只有 Master 和 Firstmate 可以生成邀请链接
        if user_role not in ['Master', 'Firstmate', 'admin']:
            return jsonify({'error': '权限不足，只有 Master 和 Firstmate 可以生成邀请链接'}), 403
        
        data = request.get_json()
        if not data:
            return jsonify({'error': '请求数据不能为空'}), 400
        
        invite_type = data.get('type')  # 'member' 或 'seller'
        
        if invite_type not in ['member', 'seller']:
            return jsonify({'error': '邀请类型必须是 member 或 seller'}), 400
        
        # 生成唯一令牌和防重放随机数
        token = generate_token()
        nonce = generate_nonce()
        
        # 根据类型设置不同的参数
        if invite_type == 'member':
            # Member 邀请链接参数
            valid_hours = data.get('validHours', 24)  # 默认24小时
            max_uses = data.get('maxUses', 1)  # 默认1次使用
            
            # 验证参数范围
            if not (1 <= valid_hours <= 48):
                return jsonify({'error': '有效期必须在1-48小时之间'}), 400
            
            if not (1 <= max_uses <= 100):
                return jsonify({'error': '使用次数必须在1-100次之间'}), 400
            
            expires_at = datetime.utcnow() + timedelta(hours=valid_hours)
            target_role = 'Member'
            target_domain = f"member.{FRONTEND_BASE_URL.replace('https://', '').replace('http://', '')}"
            
        else:  # seller
            # Seller 邀请链接参数（固定1次使用，永久有效）
            max_uses = 1
            expires_at = None  # 永久有效
            target_role = 'Seller'
            target_domain = f"seller.{FRONTEND_BASE_URL.replace('https://', '').replace('http://', '')}"
        
        # 创建邀请链接记录
        invite_record = {
            'token': token,
            'nonce': nonce,  # 防重放随机数
            'type': invite_type,
            'target_role': target_role,
            'target_domain': target_domain,
            'created_by': user_id,
            'created_by_email': user_email,
            'created_by_role': user_role,
            'max_uses': max_uses,
            'current_uses': 0,
            'expires_at': expires_at,
            'created_at': datetime.utcnow(),
            'is_active': True,
            'used_by': [],  # 记录使用者信息
            'deactivated_reason': None
        }
        
        # 保存到数据库
        result = invite_links.insert_one(invite_record)
        
        # 生成完整的邀请URL
        invite_url = f"{FRONTEND_BASE_URL}/invite?token={token}&nonce={nonce}"
        
        # 记录审计日志
        log_audit_event(
            'invite_generated',
            user_id,
            {
                'invite_type': invite_type,
                'target_role': target_role,
                'max_uses': max_uses,
                'expires_at': expires_at.isoformat() if expires_at else None,
                'token': token
            }
        )
        
        logger.info(f"用户 {user_id} ({user_role}) 生成了 {invite_type} 邀请链接: {token}")
        
        return jsonify({
            'success': True,
            'token': token,
            'nonce': nonce,
            'url': invite_url,
            'type': invite_type,
            'target_role': target_role,
            'target_domain': target_domain,
            'max_uses': max_uses,
            'expires_at': expires_at.isoformat() if expires_at else None,
            'created_at': invite_record['created_at'].isoformat()
        })
        
    except Exception as e:
        logger.error(f"生成邀请链接失败: {e}")
        return jsonify({'error': '服务器内部错误'}), 500

@app.route('/invite/validate', methods=['GET'])
def validate_invite():
    """验证邀请链接"""
    try:
        token = request.args.get('token')
        nonce = request.args.get('nonce')
        
        if not token:
            return jsonify({'error': '缺少邀请令牌'}), 400
        
        # 查找邀请链接记录
        query = {'token': token, 'is_active': True}
        if nonce:
            query['nonce'] = nonce
        
        invite_record = invite_links.find_one(query)
        
        if not invite_record:
            return jsonify({
                'valid': False,
                'error': '邀请链接不存在或已失效'
            }), 404
        
        # 检查是否过期
        if invite_record.get('expires_at') and invite_record['expires_at'] < datetime.utcnow():
            # 标记为失效
            invite_links.update_one(
                {'_id': invite_record['_id']},
                {'$set': {'is_active': False, 'deactivated_reason': 'expired'}}
            )
            return jsonify({
                'valid': False,
                'error': '邀请链接已过期'
            }), 410
        
        # 检查使用次数
        if invite_record['current_uses'] >= invite_record['max_uses']:
            # 标记为失效
            invite_links.update_one(
                {'_id': invite_record['_id']},
                {'$set': {'is_active': False, 'deactivated_reason': 'max_uses_reached'}}
            )
            return jsonify({
                'valid': False,
                'error': '邀请链接使用次数已达上限'
            }), 410
        
        # 计算剩余时间（如果有过期时间）
        remaining_time = None
        if invite_record.get('expires_at'):
            remaining_seconds = (invite_record['expires_at'] - datetime.utcnow()).total_seconds()
            if remaining_seconds > 0:
                remaining_time = {
                    'hours': int(remaining_seconds // 3600),
                    'minutes': int((remaining_seconds % 3600) // 60),
                    'seconds': int(remaining_seconds % 60)
                }
        
        return jsonify({
            'valid': True,
            'token': token,
            'nonce': invite_record.get('nonce'),
            'type': invite_record['type'],
            'target_role': invite_record['target_role'],
            'target_domain': invite_record['target_domain'],
            'remaining_uses': invite_record['max_uses'] - invite_record['current_uses'],
            'remaining_time': remaining_time,
            'created_at': invite_record['created_at'].isoformat()
        })
        
    except Exception as e:
        logger.error(f"验证邀请链接失败: {e}")
        return jsonify({'error': '服务器内部错误'}), 500

@app.route('/invite/use', methods=['POST'])
def use_invite():
    """使用邀请链接（升级用户角色）"""
    try:
        # 验证用户认证
        payload, error_response, status_code = check_auth()
        if error_response:
            return jsonify(error_response), status_code
        
        user_id = payload.get('sub')
        user_email = payload.get('email')
        current_role = payload.get('role', 'user')
        
        data = request.get_json()
        if not data:
            return jsonify({'error': '请求数据不能为空'}), 400
        
        token = data.get('token')
        nonce = data.get('nonce')
        
        if not token:
            return jsonify({'error': '缺少邀请令牌'}), 400
        
        # 验证邀请链接（包含防重放检查）
        query = {'token': token, 'is_active': True}
        if nonce:
            query['nonce'] = nonce
        
        invite_record = invite_links.find_one(query)
        
        if not invite_record:
            return jsonify({'error': '邀请链接不存在或已失效'}), 404
        
        # 检查是否过期
        if invite_record.get('expires_at') and invite_record['expires_at'] < datetime.utcnow():
            invite_links.update_one(
                {'_id': invite_record['_id']},
                {'$set': {'is_active': False, 'deactivated_reason': 'expired'}}
            )
            return jsonify({'error': '邀请链接已过期'}), 410
        
        # 检查使用次数
        if invite_record['current_uses'] >= invite_record['max_uses']:
            invite_links.update_one(
                {'_id': invite_record['_id']},
                {'$set': {'is_active': False, 'deactivated_reason': 'max_uses_reached'}}
            )
            return jsonify({'error': '邀请链接使用次数已达上限'}), 410
        
        # 检查用户是否已经使用过此链接（防重放）
        if user_id in [usage.get('user_id') for usage in invite_record.get('used_by', [])]:
            return jsonify({'error': '您已经使用过此邀请链接'}), 409
        
        # 检查角色升级逻辑
        target_role = invite_record['target_role']
        if current_role == target_role:
            return jsonify({'error': f'您已经是 {target_role} 角色'}), 409
        
        # 在Supabase中更新用户角色
        supabase_success = update_user_role_in_supabase(user_id, target_role)
        
        # 记录使用信息
        usage_info = {
            'user_id': user_id,
            'user_email': user_email,
            'previous_role': current_role,
            'new_role': target_role,
            'used_at': datetime.utcnow(),
            'ip_address': request.remote_addr,
            'user_agent': request.headers.get('User-Agent', ''),
            'supabase_updated': supabase_success
        }
        
        # 更新邀请链接使用记录
        invite_links.update_one(
            {'_id': invite_record['_id']},
            {
                '$inc': {'current_uses': 1},
                '$push': {'used_by': usage_info}
            }
        )
        
        # 如果达到最大使用次数，标记为失效
        if invite_record['current_uses'] + 1 >= invite_record['max_uses']:
            invite_links.update_one(
                {'_id': invite_record['_id']},
                {'$set': {'is_active': False, 'deactivated_reason': 'max_uses_reached'}}
            )
        
        # 记录审计日志
        log_audit_event(
            'invite_used',
            user_id,
            {
                'token': token,
                'previous_role': current_role,
                'new_role': target_role,
                'invite_type': invite_record['type'],
                'created_by': invite_record['created_by'],
                'supabase_updated': supabase_success
            }
        )
        
        logger.info(f"用户 {user_id} 使用邀请链接 {token} 从 {current_role} 升级到 {target_role}")
        
        return jsonify({
            'success': True,
            'message': f'角色升级成功，从 {current_role} 升级到 {target_role}',
            'new_role': target_role,
            'target_domain': invite_record['target_domain'],
            'redirect_url': f"https://{invite_record['target_domain']}",
            'supabase_updated': supabase_success
        })
        
    except Exception as e:
        logger.error(f"使用邀请链接失败: {e}")
        return jsonify({'error': '服务器内部错误'}), 500

@app.route('/invite/list', methods=['GET'])
def list_invites():
    """获取邀请链接列表（仅 Master 和 Firstmate）"""
    try:
        # 验证用户权限
        payload, error_response, status_code = check_auth()
        if error_response:
            return jsonify(error_response), status_code
        
        user_role = payload.get('role')
        user_id = payload.get('sub')
        
        if user_role not in ['Master', 'Firstmate', 'admin']:
            return jsonify({'error': '权限不足'}), 403
        
        # 查询参数
        page = int(request.args.get('page', 1))
        limit = min(int(request.args.get('limit', 20)), 100)  # 最大100条
        invite_type = request.args.get('type')  # 可选过滤类型
        status = request.args.get('status')  # active, expired, used_up
        created_by = request.args.get('created_by')  # 按创建者过滤
        
        # 构建查询条件
        query = {}
        if invite_type:
            query['type'] = invite_type
        
        if created_by:
            query['created_by'] = created_by
        
        if status == 'active':
            query['is_active'] = True
            query['$or'] = [
                {'expires_at': {'$gt': datetime.utcnow()}},
                {'expires_at': None}
            ]
            query['$expr'] = {'$lt': ['$current_uses', '$max_uses']}
        elif status == 'expired':
            query['$or'] = [
                {'expires_at': {'$lte': datetime.utcnow()}},
                {'is_active': False, 'deactivated_reason': 'expired'}
            ]
        elif status == 'used_up':
            query['$expr'] = {'$gte': ['$current_uses', '$max_uses']}
        elif status == 'deactivated':
            query['is_active'] = False
        
        # 分页查询
        skip = (page - 1) * limit
        cursor = invite_links.find(query).sort('created_at', -1).skip(skip).limit(limit)
        total = invite_links.count_documents(query)
        
        invites = []
        for invite in cursor:
            invite_data = {
                'id': str(invite['_id']),
                'token': invite['token'],
                'type': invite['type'],
                'target_role': invite['target_role'],
                'created_by': invite['created_by'],
                'created_by_email': invite.get('created_by_email'),
                'created_by_role': invite['created_by_role'],
                'max_uses': invite['max_uses'],
                'current_uses': invite['current_uses'],
                'remaining_uses': invite['max_uses'] - invite['current_uses'],
                'expires_at': invite['expires_at'].isoformat() if invite.get('expires_at') else None,
                'created_at': invite['created_at'].isoformat(),
                'is_active': invite['is_active'],
                'deactivated_reason': invite.get('deactivated_reason'),
                'url': f"{FRONTEND_BASE_URL}/invite?token={invite['token']}&nonce={invite.get('nonce', '')}"
            }
            
            # 计算状态
            if not invite['is_active']:
                invite_data['status'] = 'deactivated'
            elif invite.get('expires_at') and invite['expires_at'] < datetime.utcnow():
                invite_data['status'] = 'expired'
            elif invite['current_uses'] >= invite['max_uses']:
                invite_data['status'] = 'used_up'
            else:
                invite_data['status'] = 'active'
            
            # 计算剩余时间
            if invite.get('expires_at') and invite_data['status'] == 'active':
                remaining_seconds = (invite['expires_at'] - datetime.utcnow()).total_seconds()
                if remaining_seconds > 0:
                    invite_data['remaining_time'] = {
                        'hours': int(remaining_seconds // 3600),
                        'minutes': int((remaining_seconds % 3600) // 60)
                    }
            
            # 添加使用历史（仅显示最近5次）
            if invite.get('used_by'):
                invite_data['recent_usage'] = [
                    {
                        'user_id': usage['user_id'],
                        'user_email': usage.get('user_email'),
                        'used_at': usage['used_at'].isoformat(),
                        'previous_role': usage.get('previous_role'),
                        'new_role': usage.get('new_role')
                    }
                    for usage in invite['used_by'][-5:]  # 最近5次
                ]
            
            invites.append(invite_data)
        
        return jsonify({
            'invites': invites,
            'pagination': {
                'page': page,
                'limit': limit,
                'total': total,
                'total_pages': (total + limit - 1) // limit
            }
        })
        
    except Exception as e:
        logger.error(f"获取邀请链接列表失败: {e}")
        return jsonify({'error': '服务器内部错误'}), 500

@app.route('/invite/deactivate/<invite_id>', methods=['POST'])
def deactivate_invite(invite_id):
    """停用邀请链接"""
    try:
        # 验证用户权限
        payload, error_response, status_code = check_auth()
        if error_response:
            return jsonify(error_response), status_code
        
        user_role = payload.get('role')
        user_id = payload.get('sub')
        
        if user_role not in ['Master', 'Firstmate', 'admin']:
            return jsonify({'error': '权限不足'}), 403
        
        data = request.get_json() or {}
        reason = data.get('reason', 'manual_deactivation')
        
        # 查找并更新邀请链接
        result = invite_links.update_one(
            {'_id': ObjectId(invite_id), 'is_active': True},
            {
                '$set': {
                    'is_active': False,
                    'deactivated_reason': reason,
                    'deactivated_by': user_id,
                    'deactivated_at': datetime.utcnow()
                }
            }
        )
        
        if result.matched_count == 0:
            return jsonify({'error': '邀请链接不存在或已停用'}), 404
        
        # 记录审计日志
        log_audit_event(
            'invite_deactivated',
            user_id,
            {
                'invite_id': invite_id,
                'reason': reason
            }
        )
        
        logger.info(f"用户 {user_id} 停用了邀请链接 {invite_id}")
        
        return jsonify({
            'success': True,
            'message': '邀请链接已停用'
        })
        
    except Exception as e:
        logger.error(f"停用邀请链接失败: {e}")
        return jsonify({'error': '服务器内部错误'}), 500

@app.route('/invite/audit-logs', methods=['GET'])
def get_audit_logs():
    """获取审计日志（仅Master）"""
    try:
        # 验证用户权限
        payload, error_response, status_code = check_auth()
        if error_response:
            return jsonify(error_response), status_code
        
        user_role = payload.get('role')
        
        if user_role not in ['Master', 'admin']:
            return jsonify({'error': '权限不足，仅Master可查看审计日志'}), 403
        
        # 查询参数
        page = int(request.args.get('page', 1))
        limit = min(int(request.args.get('limit', 50)), 100)
        event_type = request.args.get('event_type')
        user_filter = request.args.get('user_id')
        start_date = request.args.get('start_date')
        end_date = request.args.get('end_date')
        
        # 构建查询条件
        query = {}
        if event_type:
            query['event_type'] = event_type
        if user_filter:
            query['user_id'] = user_filter
        
        # 日期范围过滤
        if start_date or end_date:
            date_query = {}
            if start_date:
                date_query['$gte'] = datetime.fromisoformat(start_date.replace('Z', '+00:00'))
            if end_date:
                date_query['$lte'] = datetime.fromisoformat(end_date.replace('Z', '+00:00'))
            query['timestamp'] = date_query
        
        # 分页查询
        skip = (page - 1) * limit
        cursor = audit_logs.find(query).sort('timestamp', -1).skip(skip).limit(limit)
        total = audit_logs.count_documents(query)
        
        logs = []
        for log in cursor:
            logs.append({
                'id': str(log['_id']),
                'event_type': log['event_type'],
                'user_id': log['user_id'],
                'details': log['details'],
                'ip_address': log['ip_address'],
                'user_agent': log['user_agent'],
                'timestamp': log['timestamp'].isoformat(),
                'service': log['service']
            })
        
        return jsonify({
            'logs': logs,
            'pagination': {
                'page': page,
                'limit': limit,
                'total': total,
                'total_pages': (total + limit - 1) // limit
            }
        })
        
    except Exception as e:
        logger.error(f"获取审计日志失败: {e}")
        return jsonify({'error': '服务器内部错误'}), 500

@app.route('/webhook/role-update', methods=['POST'])
def webhook_role_update():
    """接收角色更新webhook回调"""
    try:
        # 验证webhook签名
        if WEBHOOK_SECRET:
            signature = request.headers.get('X-Webhook-Signature')
            if not signature:
                return jsonify({'error': '缺少签名'}), 401
            
            body = request.get_data()
            expected_signature = hmac.new(
                WEBHOOK_SECRET.encode(),
                body,
                hashlib.sha256
            ).hexdigest()
            
            if not hmac.compare_digest(signature, expected_signature):
                return jsonify({'error': '签名验证失败'}), 401
        
        data = request.get_json()
        user_id = data.get('user_id')
        new_role = data.get('new_role')
        old_role = data.get('old_role')
        
        if not user_id or not new_role:
            return jsonify({'error': '缺少必要参数'}), 400
        
        # 记录审计日志
        log_audit_event(
            'role_updated_webhook',
            user_id,
            {
                'old_role': old_role,
                'new_role': new_role,
                'source': 'webhook'
            }
        )
        
        return jsonify({'success': True})
        
    except Exception as e:
        logger.error(f"处理角色更新webhook失败: {e}")
        return jsonify({'error': '服务器内部错误'}), 500

if __name__ == '__main__':
    PORT = int(os.getenv('PORT', 5006))  # 默认5006端口，支持环境变量覆盖
    app.run(host='0.0.0.0', port=PORT, debug=False)
    logger.info(f"邀请服务启动在端口 {PORT}") 