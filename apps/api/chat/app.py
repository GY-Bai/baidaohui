from flask import Flask, request, jsonify, Response
from flask_cors import CORS
import os
import json
import redis
import pymongo
from datetime import datetime, timedelta
from supabase import create_client, Client
from functools import wraps
import requests
import uuid
import logging

app = Flask(__name__)
CORS(app)

# 配置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# 配置
MONGO_URL = os.getenv('MONGO_URL')
SUPABASE_URL = os.getenv('SUPABASE_URL')
SUPABASE_SERVICE_ROLE_KEY = os.getenv('SUPABASE_SERVICE_ROLE_KEY')
REDIS_HOST = os.getenv('REDIS_HOST', 'redis')
REDIS_PORT = int(os.getenv('REDIS_PORT', 6379))
PROSODY_API_URL = os.getenv('PROSODY_API_URL', 'http://prosody:5280/api')

# 初始化数据库连接
mongo_client = pymongo.MongoClient(MONGO_URL)
db = mongo_client.baidaohui
messages_collection = db.messages
chat_rooms_collection = db.chat_rooms

# 初始化 Redis
redis_client = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, db=0)

# 初始化 Supabase
supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

# 聊天配置
MASTER_JID = "anchor@localhost"
GROUP_CHAT_JID = "general@conference.localhost"

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
            logger.error(f"Token验证失败: {str(e)}")
            return jsonify({'error': '认证失败'}), 401
    
    return decorated

def get_user_role(user):
    """获取用户角色"""
    user_metadata = user.user_metadata or {}
    return user_metadata.get('role', 'fan')

def get_user_jid(user):
    """生成用户JID"""
    user_id = user.id.replace('-', '')[:8]  # 使用用户ID的前8位
    return f"user_{user_id}@localhost"

def call_prosody_api(endpoint, method='GET', data=None):
    """调用Prosody API"""
    try:
        url = f"{PROSODY_API_URL}/{endpoint}"
        headers = {'Content-Type': 'application/json'}
        
        if method == 'POST':
            response = requests.post(url, json=data, headers=headers, timeout=10)
        else:
            response = requests.get(url, headers=headers, timeout=10)
        
        return response.json() if response.status_code == 200 else None
    except Exception as e:
        logger.error(f"Prosody API调用失败: {str(e)}")
        return None

def store_message(message_data):
    """存储消息到MongoDB"""
    try:
        message_doc = {
            'id': message_data.get('id', str(uuid.uuid4())),
            'from_jid': message_data['from'],
            'to_jid': message_data['to'],
            'body': message_data['body'],
            'message_type': message_data.get('type', 'chat'),
            'timestamp': datetime.utcnow(),
            'user_id': message_data.get('user_id'),
            'user_role': message_data.get('user_role'),
            'is_forwarded': message_data.get('is_forwarded', False),
            'original_to': message_data.get('original_to'),
            'metadata': message_data.get('metadata', {})
        }
        
        result = messages_collection.insert_one(message_doc)
        return str(result.inserted_id)
    except Exception as e:
        logger.error(f"存储消息失败: {str(e)}")
        return None

def cache_message(message_data, expire_seconds=3600):
    """缓存消息到Redis"""
    try:
        cache_key = f"message:{message_data['id']}"
        redis_client.setex(cache_key, expire_seconds, json.dumps(message_data, default=str))
    except Exception as e:
        logger.error(f"缓存消息失败: {str(e)}")

@app.route('/send_message', methods=['POST'])
@verify_token
def send_message():
    """发送消息"""
    try:
        data = request.get_json()
        user = request.current_user
        user_role = get_user_role(user)
        user_jid = get_user_jid(user)
        
        message_body = data.get('body', '').strip()
        message_type = data.get('type', 'chat')
        to_jid = data.get('to', MASTER_JID)
        
        if not message_body:
            return jsonify({'error': '消息内容不能为空'}), 400
        
        # 检查用户权限
        if user_role == 'fan':
            return jsonify({'error': 'Fan用户无法发送消息，请升级为Member'}), 403
        
        # 生成消息ID
        message_id = str(uuid.uuid4())
        
        # 构建消息数据
        message_data = {
            'id': message_id,
            'from': user_jid,
            'to': to_jid,
            'body': message_body,
            'type': message_type,
            'user_id': user.id,
            'user_role': user_role,
            'timestamp': datetime.utcnow().isoformat()
        }
        
        # 根据用户角色处理消息路由
        if user_role in ['fan', 'member']:
            # 粉丝/会员发送给主播的消息需要转发到群聊
            if to_jid == MASTER_JID:
                # 发送到群聊，供主播查看
                group_message_data = message_data.copy()
                group_message_data['to'] = GROUP_CHAT_JID
                group_message_data['is_forwarded'] = True
                group_message_data['original_to'] = MASTER_JID
                group_message_data['metadata'] = {
                    'sender_nickname': user.user_metadata.get('nickname', f'用户{user.id[:8]}'),
                    'sender_email': user.email,
                    'is_private_message': True
                }
                
                # 调用Prosody API发送到群聊
                prosody_result = call_prosody_api('send_message', 'POST', {
                    'from': user_jid,
                    'to': GROUP_CHAT_JID,
                    'body': f"[私信] {group_message_data['metadata']['sender_nickname']}: {message_body}",
                    'type': 'groupchat'
                })
                
                if prosody_result:
                    # 存储转发的消息
                    store_message(group_message_data)
                    cache_message(group_message_data)
        
        elif user_role in ['master', 'firstmate']:
            # 主播/助理可以直接发送消息
            prosody_result = call_prosody_api('send_message', 'POST', {
                'from': user_jid,
                'to': to_jid,
                'body': message_body,
                'type': message_type
            })
        
        # 存储原始消息
        message_doc_id = store_message(message_data)
        cache_message(message_data)
        
        # 更新已读状态缓存
        read_key = f"read:{user.id}:{to_jid}"
        redis_client.setex(read_key, 3600, datetime.utcnow().isoformat())
        
        return jsonify({
            'success': True,
            'message_id': message_id,
            'doc_id': message_doc_id,
            'timestamp': message_data['timestamp']
        })
        
    except Exception as e:
        logger.error(f"发送消息失败: {str(e)}")
        return jsonify({'error': '发送消息失败'}), 500

@app.route('/get_messages', methods=['GET'])
@verify_token
def get_messages():
    """获取消息列表"""
    try:
        user = request.current_user
        user_role = get_user_role(user)
        user_jid = get_user_jid(user)
        
        # 获取查询参数
        chat_jid = request.args.get('chat', MASTER_JID)
        limit = min(int(request.args.get('limit', 50)), 100)
        offset = int(request.args.get('offset', 0))
        since = request.args.get('since')  # ISO格式时间戳
        
        # 构建查询条件
        query = {}
        
        if user_role in ['fan', 'member']:
            # 粉丝/会员只能看到与主播的对话
            if chat_jid == MASTER_JID:
                query = {
                    '$or': [
                        {'from_jid': user_jid, 'to_jid': MASTER_JID},
                        {'from_jid': MASTER_JID, 'to_jid': user_jid},
                        # 也包括主播在群聊中的公开回复
                        {'from_jid': MASTER_JID, 'to_jid': GROUP_CHAT_JID, 'metadata.is_public_reply': True}
                    ]
                }
            else:
                return jsonify({'error': '权限不足'}), 403
                
        elif user_role in ['master', 'firstmate']:
            # 主播/助理可以查看群聊消息
            if chat_jid == GROUP_CHAT_JID:
                query = {'to_jid': GROUP_CHAT_JID}
                # Firstmate不能看到发给Master的私信
                if user_role == 'firstmate':
                    query['metadata.is_private_message'] = {'$ne': True}
            else:
                # 查看与特定用户的对话
                query = {
                    '$or': [
                        {'from_jid': user_jid, 'to_jid': chat_jid},
                        {'from_jid': chat_jid, 'to_jid': user_jid}
                    ]
                }
        
        # 添加时间过滤
        if since:
            try:
                since_date = datetime.fromisoformat(since.replace('Z', '+00:00'))
                query['timestamp'] = {'$gte': since_date}
            except ValueError:
                pass
        
        # 查询消息
        messages = list(messages_collection.find(
            query,
            {'_id': 0}  # 排除MongoDB的_id字段
        ).sort('timestamp', -1).skip(offset).limit(limit))
        
        # 转换时间格式并添加显示信息
        for msg in messages:
            msg['timestamp'] = msg['timestamp'].isoformat()
            
            # 添加发送者显示名称
            if msg.get('metadata', {}).get('sender_nickname'):
                msg['sender_name'] = msg['metadata']['sender_nickname']
            elif msg['from_jid'] == MASTER_JID:
                msg['sender_name'] = '主播'
            else:
                msg['sender_name'] = f"用户{msg['from_jid'].split('_')[1][:8]}"
        
        # 反转顺序，使最新消息在最后
        messages.reverse()
        
        # 更新已读状态
        if messages:
            read_key = f"read:{user.id}:{chat_jid}"
            redis_client.setex(read_key, 3600, datetime.utcnow().isoformat())
        
        return jsonify({
            'success': True,
            'messages': messages,
            'total': len(messages),
            'has_more': len(messages) == limit
        })
        
    except Exception as e:
        logger.error(f"获取消息失败: {str(e)}")
        return jsonify({'error': '获取消息失败'}), 500

@app.route('/get_chat_list', methods=['GET'])
@verify_token
def get_chat_list():
    """获取聊天列表"""
    try:
        user = request.current_user
        user_role = get_user_role(user)
        
        chat_list = []
        
        if user_role in ['fan', 'member']:
            # 粉丝/会员只显示主播聊天
            chat_list.append({
                'jid': MASTER_JID,
                'name': '主播',
                'type': 'private',
                'last_message': None,
                'unread_count': 0,
                'available': user_role == 'member'  # Fan不能发送消息
            })
            
        elif user_role in ['master', 'firstmate']:
            # 主播/助理显示群聊
            chat_list.append({
                'jid': GROUP_CHAT_JID,
                'name': '群聊',
                'type': 'group',
                'last_message': None,
                'unread_count': 0,
                'available': True
            })
        
        # 获取最后一条消息和未读数量
        for chat in chat_list:
            # 获取最后一条消息
            last_msg = messages_collection.find_one(
                {'to_jid': chat['jid']},
                sort=[('timestamp', -1)]
            )
            
            if last_msg:
                chat['last_message'] = {
                    'body': last_msg['body'][:50] + ('...' if len(last_msg['body']) > 50 else ''),
                    'timestamp': last_msg['timestamp'].isoformat(),
                    'from': last_msg.get('sender_name', '未知')
                }
            
            # 获取未读数量（简化实现）
            read_key = f"read:{user.id}:{chat['jid']}"
            last_read = redis_client.get(read_key)
            if last_read:
                last_read_time = datetime.fromisoformat(last_read.decode())
                unread_count = messages_collection.count_documents({
                    'to_jid': chat['jid'],
                    'timestamp': {'$gt': last_read_time}
                })
                chat['unread_count'] = unread_count
        
        return jsonify({
            'success': True,
            'chats': chat_list
        })
        
    except Exception as e:
        logger.error(f"获取聊天列表失败: {str(e)}")
        return jsonify({'error': '获取聊天列表失败'}), 500

@app.route('/mark_as_read', methods=['POST'])
@verify_token
def mark_as_read():
    """标记消息为已读"""
    try:
        data = request.get_json()
        user = request.current_user
        chat_jid = data.get('chat_jid')
        
        if not chat_jid:
            return jsonify({'error': '缺少聊天JID'}), 400
        
        # 更新已读状态
        read_key = f"read:{user.id}:{chat_jid}"
        redis_client.setex(read_key, 3600, datetime.utcnow().isoformat())
        
        return jsonify({
            'success': True,
            'message': '已标记为已读'
        })
        
    except Exception as e:
        logger.error(f"标记已读失败: {str(e)}")
        return jsonify({'error': '标记已读失败'}), 500

@app.route('/websocket')
def websocket():
    """WebSocket连接端点（简化实现，实际应使用Socket.IO）"""
    # 这里应该实现WebSocket连接逻辑
    # 由于Flask原生不支持WebSocket，建议使用Flask-SocketIO
    return jsonify({'error': 'WebSocket功能需要使用Socket.IO实现'}), 501

@app.route('/health', methods=['GET'])
def health_check():
    """健康检查"""
    services = {}
    overall_status = 'healthy'
    
    # 检查MongoDB连接
    try:
        db.messages.find_one()
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
    
    # 检查Prosody连接
    try:
        prosody_result = call_prosody_api('status')
        services['prosody'] = 'ok' if prosody_result else 'disconnected'
        if not prosody_result:
            overall_status = 'unhealthy'
    except Exception as e:
        services['prosody'] = f'error: {str(e)}'
        overall_status = 'unhealthy'
    
    response_data = {
        'status': overall_status,
        'service': 'chat-service',
        'timestamp': datetime.utcnow().isoformat(),
        'services': services
    }
    
    status_code = 200 if overall_status == 'healthy' else 500
    return jsonify(response_data), status_code

if __name__ == '__main__':
    port = int(os.getenv('PORT', 5003))
    app.run(debug=True, host='0.0.0.0', port=port) 