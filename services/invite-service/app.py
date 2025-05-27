from flask import Flask, request, jsonify
from flask_cors import CORS
import os
import jwt
import secrets
import string
from datetime import datetime, timedelta
from pymongo import MongoClient
from bson import ObjectId
import logging

# 配置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)

# 环境变量配置
MONGODB_URI = os.getenv('MONGODB_URI', 'mongodb://localhost:27017/baidaohui')
JWT_SECRET = os.getenv('JWT_SECRET', 'your-jwt-secret-key')
FRONTEND_BASE_URL = os.getenv('FRONTEND_BASE_URL', 'https://baidaohui.com')

# MongoDB 连接
try:
    client = MongoClient(MONGODB_URI)
    db = client.baidaohui
    invite_links = db.invite_links
    logger.info("MongoDB 连接成功")
except Exception as e:
    logger.error(f"MongoDB 连接失败: {e}")
    raise

def verify_jwt(token):
    """验证JWT令牌"""
    try:
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

def check_auth():
    """检查用户认证和权限"""
    auth_header = request.headers.get('Authorization')
    if not auth_header or not auth_header.startswith('Bearer '):
        return None, {'error': '缺少认证令牌'}, 401
    
    token = auth_header.split(' ')[1]
    payload = verify_jwt(token)
    if not payload:
        return None, {'error': '无效的认证令牌'}, 401
    
    return payload, None, None

@app.route('/health', methods=['GET'])
def health_check():
    """健康检查接口"""
    return jsonify({'status': 'healthy', 'service': 'invite-service'})

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
        
        # 只有 Master 和 Firstmate 可以生成邀请链接
        if user_role not in ['Master', 'Firstmate']:
            return jsonify({'error': '权限不足，只有 Master 和 Firstmate 可以生成邀请链接'}), 403
        
        data = request.get_json()
        if not data:
            return jsonify({'error': '请求数据不能为空'}), 400
        
        invite_type = data.get('type')  # 'member' 或 'seller'
        
        if invite_type not in ['member', 'seller']:
            return jsonify({'error': '邀请类型必须是 member 或 seller'}), 400
        
        # 生成唯一令牌
        token = generate_token()
        
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
            'type': invite_type,
            'target_role': target_role,
            'target_domain': target_domain,
            'created_by': user_id,
            'created_by_role': user_role,
            'max_uses': max_uses,
            'current_uses': 0,
            'expires_at': expires_at,
            'created_at': datetime.utcnow(),
            'is_active': True,
            'used_by': []  # 记录使用者信息
        }
        
        # 保存到数据库
        result = invite_links.insert_one(invite_record)
        
        # 生成完整的邀请URL
        invite_url = f"{FRONTEND_BASE_URL}/invite?token={token}"
        
        logger.info(f"用户 {user_id} ({user_role}) 生成了 {invite_type} 邀请链接: {token}")
        
        return jsonify({
            'success': True,
            'token': token,
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
        if not token:
            return jsonify({'error': '缺少邀请令牌'}), 400
        
        # 查找邀请链接记录
        invite_record = invite_links.find_one({'token': token, 'is_active': True})
        
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
        current_role = payload.get('role')
        
        data = request.get_json()
        if not data:
            return jsonify({'error': '请求数据不能为空'}), 400
        
        token = data.get('token')
        if not token:
            return jsonify({'error': '缺少邀请令牌'}), 400
        
        # 验证邀请链接
        invite_record = invite_links.find_one({'token': token, 'is_active': True})
        
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
        
        # 检查用户是否已经使用过此链接
        if user_id in [usage.get('user_id') for usage in invite_record.get('used_by', [])]:
            return jsonify({'error': '您已经使用过此邀请链接'}), 409
        
        # 检查角色升级逻辑
        target_role = invite_record['target_role']
        if current_role == target_role:
            return jsonify({'error': f'您已经是 {target_role} 角色'}), 409
        
        # 记录使用信息
        usage_info = {
            'user_id': user_id,
            'previous_role': current_role,
            'used_at': datetime.utcnow(),
            'ip_address': request.remote_addr,
            'user_agent': request.headers.get('User-Agent', '')
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
        
        logger.info(f"用户 {user_id} 使用邀请链接 {token} 从 {current_role} 升级到 {target_role}")
        
        return jsonify({
            'success': True,
            'message': f'角色升级成功，从 {current_role} 升级到 {target_role}',
            'new_role': target_role,
            'target_domain': invite_record['target_domain'],
            'redirect_url': f"https://{invite_record['target_domain']}"
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
        
        if user_role not in ['Master', 'Firstmate']:
            return jsonify({'error': '权限不足'}), 403
        
        # 查询参数
        page = int(request.args.get('page', 1))
        limit = int(request.args.get('limit', 20))
        invite_type = request.args.get('type')  # 可选过滤类型
        status = request.args.get('status')  # active, expired, used_up
        
        # 构建查询条件
        query = {}
        if invite_type:
            query['type'] = invite_type
        
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
        
        # 分页查询
        skip = (page - 1) * limit
        cursor = invite_links.find(query).sort('created_at', -1).skip(skip).limit(limit)
        
        invites = []
        for invite in cursor:
            invite_data = {
                'id': str(invite['_id']),
                'token': invite['token'],
                'type': invite['type'],
                'target_role': invite['target_role'],
                'created_by': invite['created_by'],
                'created_by_role': invite['created_by_role'],
                'max_uses': invite['max_uses'],
                'current_uses': invite['current_uses'],
                'remaining_uses': invite['max_uses'] - invite['current_uses'],
                'expires_at': invite['expires_at'].isoformat() if invite.get('expires_at') else None,
                'created_at': invite['created_at'].isoformat(),
                'is_active': invite['is_active'],
                'url': f"{FRONTEND_BASE_URL}/invite?token={invite['token']}"
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
            
            invites.append(invite_data)
        
        # 获取总数
        total = invite_links.count_documents(query)
        
        return jsonify({
            'success': True,
            'invites': invites,
            'pagination': {
                'page': page,
                'limit': limit,
                'total': total,
                'pages': (total + limit - 1) // limit
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
        
        if user_role not in ['Master', 'Firstmate']:
            return jsonify({'error': '权限不足'}), 403
        
        # 验证邀请链接ID
        try:
            object_id = ObjectId(invite_id)
        except:
            return jsonify({'error': '无效的邀请链接ID'}), 400
        
        # 查找并更新邀请链接
        result = invite_links.update_one(
            {'_id': object_id, 'is_active': True},
            {
                '$set': {
                    'is_active': False,
                    'deactivated_reason': 'manual',
                    'deactivated_by': user_id,
                    'deactivated_at': datetime.utcnow()
                }
            }
        )
        
        if result.matched_count == 0:
            return jsonify({'error': '邀请链接不存在或已停用'}), 404
        
        logger.info(f"用户 {user_id} ({user_role}) 停用了邀请链接 {invite_id}")
        
        return jsonify({
            'success': True,
            'message': '邀请链接已停用'
        })
        
    except Exception as e:
        logger.error(f"停用邀请链接失败: {e}")
        return jsonify({'error': '服务器内部错误'}), 500

if __name__ == '__main__':
    port = int(os.getenv('PORT', 5007))
    app.run(host='0.0.0.0', port=port, debug=os.getenv('FLASK_ENV') == 'development') 