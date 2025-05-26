from flask import Flask, request, jsonify
from flask_cors import CORS
import os
import secrets
import string
from datetime import datetime, timedelta
import pymongo
from supabase import create_client, Client
import jwt
from functools import wraps
import redis

app = Flask(__name__)
CORS(app)

# 配置
MONGO_URL = os.getenv('MONGO_URL', "mongodb+srv://rocketadmin:ThHXoppdkygmLFhz@baidaohui-cluster.umysdas.mongodb.net/?retryWrites=true&w=majority&appName=baidaohui-Cluster")
SUPABASE_URL = os.getenv('SUPABASE_URL', "https://pvjowkjksutkhpsomwvv.supabase.co")
SUPABASE_SERVICE_ROLE_KEY = os.getenv('SUPABASE_SERVICE_ROLE_KEY', "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB2am93a2prc3V0a2hwc29td3Z2Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0Nzg3NjEzMSwiZXhwIjoyMDYzNDUyMTMxfQ.d3wCJvfVVAA-YrMhkZNY85YzqfU1jyFwwtv_DrRbDfI")

# 初始化数据库连接
mongo_client = pymongo.MongoClient(MONGO_URL)
db = mongo_client.baidaohui
invite_links_collection = db.invite_links
users_collection = db.users

# 初始化 Supabase
supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

# Redis配置
REDIS_HOST = os.getenv('REDIS_HOST', 'redis')
REDIS_PORT = int(os.getenv('REDIS_PORT', 6379))
redis_client = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, db=0)

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

def verify_master_or_firstmate(f):
    """验证Master或Firstmate权限装饰器"""
    @wraps(f)
    def decorated(*args, **kwargs):
        user = request.current_user
        user_metadata = user.user_metadata or {}
        role = user_metadata.get('role', 'fan')
        
        if role not in ['master', 'firstmate']:
            return jsonify({'error': '权限不足'}), 403
        
        return f(*args, **kwargs)
    
    return decorated

def generate_invite_code():
    """生成邀请码"""
    # 生成8位随机字符串，包含大小写字母和数字
    characters = string.ascii_letters + string.digits
    return ''.join(secrets.choice(characters) for _ in range(8))

@app.route('/generate_invite_link', methods=['POST'])
@verify_token
@verify_master_or_firstmate
def generate_invite_link():
    """生成邀请链接"""
    try:
        data = request.get_json()
        
        # 验证参数
        valid_hours = data.get('valid_hours', 24)
        max_uses = data.get('max_uses', 10)
        
        if not (1 <= valid_hours <= 48):
            return jsonify({'error': '有效期必须在1-48小时之间'}), 400
        
        if not (1 <= max_uses <= 100):
            return jsonify({'error': '使用次数必须在1-100之间'}), 400
        
        # 生成邀请码
        invite_code = generate_invite_code()
        
        # 确保邀请码唯一
        while invite_links_collection.find_one({'code': invite_code}):
            invite_code = generate_invite_code()
        
        # 计算过期时间
        expires_at = datetime.utcnow() + timedelta(hours=valid_hours)
        
        # 创建邀请链接记录
        invite_link = {
            'code': invite_code,
            'created_by': request.current_user.id,
            'created_by_email': request.current_user.email,
            'valid_hours': valid_hours,
            'max_uses': max_uses,
            'used_count': 0,
            'created_at': datetime.utcnow(),
            'expires_at': expires_at,
            'is_active': True,
            'used_by': []  # 记录使用者信息
        }
        
        result = invite_links_collection.insert_one(invite_link)
        
        # 构建完整的邀请链接
        invite_url = f"https://baiduohui.com?invite={invite_code}"
        
        return jsonify({
            'success': True,
            'invite_code': invite_code,
            'invite_url': invite_url,
            'valid_hours': valid_hours,
            'max_uses': max_uses,
            'expires_at': expires_at.isoformat(),
            'id': str(result.inserted_id)
        })
        
    except Exception as e:
        app.logger.error(f"生成邀请链接失败: {str(e)}")
        return jsonify({'error': '生成邀请链接失败'}), 500

@app.route('/consume_invite/<invite_code>', methods=['POST'])
@verify_token
def consume_invite(invite_code):
    """消费邀请链接"""
    try:
        user = request.current_user
        user_id = user.id
        user_email = user.email
        
        # 查找邀请链接
        invite_link = invite_links_collection.find_one({
            'code': invite_code,
            'is_active': True
        })
        
        if not invite_link:
            return jsonify({'error': '邀请链接不存在或已失效'}), 404
        
        # 检查是否过期
        if datetime.utcnow() > invite_link['expires_at']:
            invite_links_collection.update_one(
                {'_id': invite_link['_id']},
                {'$set': {'is_active': False}}
            )
            return jsonify({'error': '邀请链接已过期'}), 400
        
        # 检查使用次数
        if invite_link['used_count'] >= invite_link['max_uses']:
            invite_links_collection.update_one(
                {'_id': invite_link['_id']},
                {'$set': {'is_active': False}}
            )
            return jsonify({'error': '邀请链接使用次数已达上限'}), 400
        
        # 检查用户是否已经使用过此邀请链接
        if any(usage['user_id'] == user_id for usage in invite_link['used_by']):
            return jsonify({'error': '您已经使用过此邀请链接'}), 400
        
        # 获取用户当前角色
        current_metadata = user.user_metadata or {}
        current_role = current_metadata.get('role', 'fan')
        
        # 只有Fan可以升级为Member
        if current_role != 'fan':
            return jsonify({'error': f'当前角色 {current_role} 无法使用邀请链接'}), 400
        
        # 更新用户角色为Member
        try:
            # 更新 Supabase 用户元数据
            updated_metadata = current_metadata.copy()
            updated_metadata['role'] = 'member'
            updated_metadata['upgraded_at'] = datetime.utcnow().isoformat()
            updated_metadata['upgraded_by_invite'] = invite_code
            
            supabase.auth.admin.update_user_by_id(
                user_id,
                {
                    'user_metadata': updated_metadata
                }
            )
            
            # 记录使用信息
            usage_info = {
                'user_id': user_id,
                'user_email': user_email,
                'used_at': datetime.utcnow(),
                'previous_role': current_role,
                'new_role': 'member'
            }
            
            # 更新邀请链接使用记录
            invite_links_collection.update_one(
                {'_id': invite_link['_id']},
                {
                    '$inc': {'used_count': 1},
                    '$push': {'used_by': usage_info}
                }
            )
            
            # 如果达到最大使用次数，设为不活跃
            if invite_link['used_count'] + 1 >= invite_link['max_uses']:
                invite_links_collection.update_one(
                    {'_id': invite_link['_id']},
                    {'$set': {'is_active': False}}
                )
            
            # 发送通知邮件 (添加到Redis队列)
            try:
                notification = {
                    'type': 'role_upgrade',
                    'to_email': user_email,
                    'template': 'inform1',
                    'data': {
                        'user_email': user_email,
                        'old_role': current_role,
                        'new_role': 'member',
                        'invite_code': invite_code
                    }
                }
                redis_client.lpush('notifications', str(notification))
            except Exception as e:
                app.logger.warning(f"发送通知邮件失败: {str(e)}")
            
            return jsonify({
                'success': True,
                'message': '角色升级成功',
                'old_role': current_role,
                'new_role': 'member',
                'invite_code': invite_code
            })
            
        except Exception as e:
            app.logger.error(f"更新用户角色失败: {str(e)}")
            return jsonify({'error': '角色升级失败'}), 500
        
    except Exception as e:
        app.logger.error(f"消费邀请链接失败: {str(e)}")
        return jsonify({'error': '处理邀请链接失败'}), 500

@app.route('/invite_links', methods=['GET'])
@verify_token
@verify_master_or_firstmate
def get_invite_links():
    """获取邀请链接列表"""
    try:
        user_id = request.current_user.id
        
        # 查询当前用户创建的邀请链接
        links = list(invite_links_collection.find(
            {'created_by': user_id},
            {'_id': 0}  # 排除MongoDB的_id字段
        ).sort('created_at', -1))
        
        # 转换日期格式
        for link in links:
            link['created_at'] = link['created_at'].isoformat()
            link['expires_at'] = link['expires_at'].isoformat()
            
            # 转换used_by中的日期
            for usage in link.get('used_by', []):
                usage['used_at'] = usage['used_at'].isoformat()
        
        return jsonify({
            'success': True,
            'invite_links': links
        })
        
    except Exception as e:
        app.logger.error(f"获取邀请链接失败: {str(e)}")
        return jsonify({'error': '获取邀请链接失败'}), 500

@app.route('/invite_links/<invite_code>', methods=['DELETE'])
@verify_token
@verify_master_or_firstmate
def deactivate_invite_link(invite_code):
    """停用邀请链接"""
    try:
        user_id = request.current_user.id
        
        # 只能停用自己创建的邀请链接
        result = invite_links_collection.update_one(
            {
                'code': invite_code,
                'created_by': user_id,
                'is_active': True
            },
            {
                '$set': {
                    'is_active': False,
                    'deactivated_at': datetime.utcnow()
                }
            }
        )
        
        if result.matched_count == 0:
            return jsonify({'error': '邀请链接不存在或无权限操作'}), 404
        
        return jsonify({
            'success': True,
            'message': '邀请链接已停用'
        })
        
    except Exception as e:
        app.logger.error(f"停用邀请链接失败: {str(e)}")
        return jsonify({'error': '停用邀请链接失败'}), 500

@app.route('/health', methods=['GET'])
def health_check():
    """健康检查"""
    services = {}
    overall_status = 'healthy'
    
    # 检查MongoDB连接
    try:
        db.invite_links.find_one()
        services['mongodb'] = 'ok'
    except Exception as e:
        services['mongodb'] = f'error: {str(e)}'
        overall_status = 'unhealthy'
    
    # 检查Redis连接
    try:
        redis_client.ping()
        services['redis'] = 'ok'
    except Exception as e:
        services['redis'] = f'error: {str(e)}'
        overall_status = 'unhealthy'
    
    # 检查Supabase连接
    try:
        supabase.table('profiles').select('id').limit(1).execute()
        services['supabase'] = 'ok'
    except Exception as e:
        services['supabase'] = f'error: {str(e)}'
        overall_status = 'unhealthy'
    
    response_data = {
        'status': overall_status,
        'service': 'auth-service',
        'timestamp': datetime.utcnow().isoformat(),
        'services': services
    }
    
    status_code = 200 if overall_status == 'healthy' else 500
    return jsonify(response_data), status_code

if __name__ == '__main__':
    port = int(os.getenv('PORT', 5001))
    app.run(debug=True, host='0.0.0.0', port=port) 