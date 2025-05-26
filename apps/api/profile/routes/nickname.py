from flask import Blueprint, request, jsonify
import re
import pymongo
from supabase import create_client, Client
import os
from functools import wraps

nickname_bp = Blueprint('nickname', __name__)

# 配置
MONGO_URL = os.getenv('MONGO_URL')
SUPABASE_URL = os.getenv('SUPABASE_URL')
SUPABASE_SERVICE_ROLE_KEY = os.getenv('SUPABASE_SERVICE_ROLE_KEY')

# 初始化数据库连接
mongo_client = pymongo.MongoClient(MONGO_URL)
db = mongo_client.baidaohui
users_collection = db.users

# 初始化 Supabase
supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

def verify_token(f):
    """验证JWT Token装饰器"""
    @wraps(f)
    def decorated(*args, **kwargs):
        token = request.headers.get('Authorization')
        if not token:
            return jsonify({'error': '缺少认证令牌'}), 401
        
        try:
            # 移除 "Bearer " 前缀
            if token.startswith('Bearer '):
                token = token[7:]
            
            # 验证 Supabase JWT
            user = supabase.auth.get_user(token)
            if not user:
                return jsonify({'error': '无效的认证令牌'}), 401
            
            request.current_user = user.user
            return f(*args, **kwargs)
        except Exception as e:
            return jsonify({'error': '认证失败'}), 401
    
    return decorated

def validate_nickname_format(nickname):
    """验证昵称格式"""
    if not nickname or not nickname.strip():
        return False, '昵称不能为空'
    
    nickname = nickname.strip()
    
    if len(nickname) > 20:
        return False, '昵称不能超过20个字符'
    
    if len(nickname) < 2:
        return False, '昵称至少需要2个字符'
    
    # 检查是否只包含中英文字母和emoji
    # 中文字符范围：\u4e00-\u9fa5
    # 英文字母：a-zA-Z
    # 常见emoji范围
    valid_pattern = re.compile(r'^[\u4e00-\u9fa5a-zA-Z\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F1E0}-\u{1F1FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{1F900}-\u{1F9FF}\u{1F018}-\u{1F270}]+$', re.UNICODE)
    
    if not valid_pattern.match(nickname):
        return False, '昵称只能包含中文、英文字母和emoji'
    
    # 检查是否包含敏感词
    sensitive_words = ['admin', 'root', 'master', 'system', '管理员', '系统', '客服']
    nickname_lower = nickname.lower()
    for word in sensitive_words:
        if word in nickname_lower:
            return False, '昵称包含敏感词汇'
    
    return True, None

def check_nickname_uniqueness(nickname, exclude_user_id=None):
    """检查昵称唯一性"""
    try:
        # 在MongoDB中检查昵称是否已被使用
        query = {'nickname': nickname}
        if exclude_user_id:
            query['user_id'] = {'$ne': exclude_user_id}
        
        existing_user = users_collection.find_one(query)
        if existing_user:
            return False
        
        # 也在Supabase中检查（双重保险）
        try:
            # 注意：这里需要根据实际的Supabase查询方式调整
            # 由于Supabase的限制，我们主要依赖MongoDB进行唯一性检查
            pass
        except Exception as e:
            # 如果Supabase查询失败，仍然依赖MongoDB的结果
            pass
        
        return True
        
    except Exception as e:
        # 如果检查失败，为了安全起见返回False
        return False

@nickname_bp.route('/validate_nickname', methods=['POST'])
@verify_token
def validate_nickname():
    """验证昵称可用性"""
    try:
        data = request.get_json()
        nickname = data.get('nickname', '').strip()
        
        # 格式验证
        is_valid, error_msg = validate_nickname_format(nickname)
        if not is_valid:
            return jsonify({
                'available': False,
                'error': error_msg
            }), 400
        
        # 唯一性检查
        user_id = request.current_user.id
        is_unique = check_nickname_uniqueness(nickname, exclude_user_id=user_id)
        
        if not is_unique:
            return jsonify({
                'available': False,
                'error': '该昵称已被使用'
            }), 400
        
        return jsonify({
            'available': True,
            'nickname': nickname
        })
        
    except Exception as e:
        return jsonify({
            'available': False,
            'error': '验证昵称时发生错误'
        }), 500

@nickname_bp.route('/update_nickname', methods=['PUT'])
@verify_token
def update_nickname():
    """更新用户昵称"""
    try:
        data = request.get_json()
        nickname = data.get('nickname', '').strip()
        user = request.current_user
        user_id = user.id
        
        # 格式验证
        is_valid, error_msg = validate_nickname_format(nickname)
        if not is_valid:
            return jsonify({
                'success': False,
                'error': error_msg
            }), 400
        
        # 唯一性检查
        is_unique = check_nickname_uniqueness(nickname, exclude_user_id=user_id)
        if not is_unique:
            return jsonify({
                'success': False,
                'error': '该昵称已被使用'
            }), 400
        
        # 更新Supabase用户元数据
        try:
            current_metadata = user.user_metadata or {}
            updated_metadata = current_metadata.copy()
            updated_metadata['nickname'] = nickname
            updated_metadata['nickname_updated_at'] = datetime.utcnow().isoformat()
            
            supabase.auth.admin.update_user_by_id(
                user_id,
                {
                    'user_metadata': updated_metadata
                }
            )
        except Exception as e:
            return jsonify({
                'success': False,
                'error': '更新用户信息失败'
            }), 500
        
        # 更新或创建MongoDB记录
        try:
            from datetime import datetime
            
            user_doc = {
                'user_id': user_id,
                'email': user.email,
                'nickname': nickname,
                'updated_at': datetime.utcnow()
            }
            
            # 使用upsert操作
            users_collection.update_one(
                {'user_id': user_id},
                {
                    '$set': user_doc,
                    '$setOnInsert': {'created_at': datetime.utcnow()}
                },
                upsert=True
            )
        except Exception as e:
            # MongoDB更新失败，但Supabase已更新，记录警告
            import logging
            logging.warning(f"MongoDB昵称更新失败: {str(e)}")
        
        return jsonify({
            'success': True,
            'nickname': nickname,
            'message': '昵称更新成功'
        })
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': '更新昵称失败'
        }), 500

@nickname_bp.route('/profile', methods=['GET'])
@verify_token
def get_profile():
    """获取用户资料"""
    try:
        user = request.current_user
        user_id = user.id
        
        # 从MongoDB获取用户信息
        user_doc = users_collection.find_one({'user_id': user_id})
        
        # 从Supabase获取元数据
        user_metadata = user.user_metadata or {}
        
        profile = {
            'id': user_id,
            'email': user.email,
            'nickname': user_metadata.get('nickname') or (user_doc.get('nickname') if user_doc else None),
            'role': user_metadata.get('role', 'fan'),
            'created_at': user.created_at,
            'updated_at': user_doc.get('updated_at') if user_doc else None
        }
        
        return jsonify({
            'success': True,
            'profile': profile
        })
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': '获取用户资料失败'
        }), 500

@nickname_bp.route('/check_nickname/<nickname>', methods=['GET'])
def check_nickname_availability(nickname):
    """公开接口：检查昵称可用性（不需要登录）"""
    try:
        # 格式验证
        is_valid, error_msg = validate_nickname_format(nickname)
        if not is_valid:
            return jsonify({
                'available': False,
                'error': error_msg
            })
        
        # 唯一性检查
        is_unique = check_nickname_uniqueness(nickname)
        
        return jsonify({
            'available': is_unique,
            'nickname': nickname,
            'error': None if is_unique else '该昵称已被使用'
        })
        
    except Exception as e:
        return jsonify({
            'available': False,
            'error': '检查昵称时发生错误'
        }), 500 