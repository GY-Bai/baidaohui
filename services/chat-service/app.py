from flask import Flask, request, jsonify
from flask_socketio import SocketIO, emit, join_room, leave_room
from flask_cors import CORS
import os
import jwt
import redis
import pymongo
from datetime import datetime, timedelta
import logging
import requests
import json
from bson import ObjectId

app = Flask(__name__)
app.config['SECRET_KEY'] = os.getenv('SECRET_KEY', 'your-secret-key')
CORS(app, supports_credentials=True)

# 初始化SocketIO
socketio = SocketIO(app, cors_allowed_origins="*", async_mode='threading')

# 配置
MONGODB_URI = os.getenv('MONGODB_URI')
REDIS_URL = os.getenv('REDIS_URL', 'redis://localhost:6379')
JWT_SECRET = os.getenv('JWT_SECRET', 'your-secret-key')
AUTH_SERVICE_URL = os.getenv('AUTH_SERVICE_URL', 'http://auth-service:5001')
R2_ENDPOINT = os.getenv('R2_ENDPOINT')
R2_ACCESS_KEY = os.getenv('R2_ACCESS_KEY')
R2_SECRET_KEY = os.getenv('R2_SECRET_KEY')
R2_BUCKET = os.getenv('R2_BUCKET')

# 初始化数据库连接
mongo_client = pymongo.MongoClient(MONGODB_URI)
db = mongo_client.baidaohui
redis_client = redis.from_url(REDIS_URL)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

from websocket import register_websocket_handlers
register_websocket_handlers(socketio, db, redis_client, logger)

def verify_token(required_roles=None):
    """验证JWT Token装饰器"""
    def decorator(f):
        def wrapper(*args, **kwargs):
            token = request.cookies.get('access_token')
            if not token:
                return jsonify({'error': '未登录'}), 401
            
            try:
                payload = jwt.decode(token, JWT_SECRET, algorithms=['HS256'])
                user_id = payload['sub']
                user_role = payload['role']
                
                if required_roles and user_role not in required_roles:
                    return jsonify({'error': '权限不足'}), 403
                
                request.user_id = user_id
                request.user_role = user_role
                request.user_email = payload['email']
                
                return f(*args, **kwargs)
            except jwt.InvalidTokenError:
                return jsonify({'error': '无效的Token'}), 401
        
        wrapper.__name__ = f.__name__
        return wrapper
    return decorator

@app.route('/health')
def health():
    return jsonify({'status': 'healthy', 'service': 'chat-service'})

@app.route('/api/messages/history')
@verify_token()
def get_message_history():
    """获取聊天历史记录"""
    try:
        user_id = request.user_id
        user_role = request.user_role
        
        chat_id = request.args.get('chatId')
        limit = int(request.args.get('limit', 50))
        offset = int(request.args.get('offset', 0))
        
        if not chat_id:
            return jsonify({'error': '缺少chatId参数'}), 400
            
        # 检查用户是否有权限访问该聊天室
        if chat_id == 'general':
            # 群聊权限检查
            if user_role not in ['Member', 'Master', 'Firstmate']:
                return jsonify({'error': '无权限访问群聊'}), 403
        else:
            # 私聊权限检查
            if user_role == 'Member':
                # 检查私聊是否开启
                private_chat = db.private_chats.find_one({
                    'member_id': user_id,
                    'status': 'active',
                    'expires_at': {'$gt': datetime.utcnow()}
                })
                if not private_chat:
                    return jsonify({'error': '私聊未开启或已过期'}), 403
            elif user_role not in ['Master', 'Firstmate']:
                return jsonify({'error': '无权限访问私聊'}), 403
        
        # 查询消息历史
        messages = db.messages.find({
            'chat_id': chat_id,
            'deleted': {'$ne': True}  # 排除已删除的消息
        }).sort('timestamp', -1).skip(offset).limit(limit)
        
        message_list = []
        for msg in messages:
            message_list.append({
                'id': str(msg['_id']),
                'chat_id': msg['chat_id'],
                'sender_id': msg['sender_id'],
                'sender_name': msg.get('sender_name', ''),
                'content': msg['content'],
                'type': msg['type'],
                'timestamp': msg['timestamp'].isoformat(),
                'attachments': msg.get('attachments', []),
                'read_by': msg.get('read_by', []),
                'recalled': msg.get('recalled', False)
            })
        
        # 反转列表，使最新消息在最后
        message_list.reverse()
        
        return jsonify({
            'messages': message_list,
            'total': db.messages.count_documents({
                'chat_id': chat_id,
                'deleted': {'$ne': True}
            })
        })
        
    except Exception as e:
        logger.error(f"获取消息历史失败: {str(e)}")
        return jsonify({'error': '获取消息历史失败'}), 500

@app.route('/api/chat/mark-read', methods=['POST'])
@verify_token()
def mark_messages_read():
    """标记消息为已读"""
    try:
        user_id = request.user_id
        
        data = request.get_json()
        chat_id = data.get('chat_id')
        message_id = data.get('message_id')
        
        if not chat_id:
            return jsonify({'error': '缺少chat_id参数'}), 400
        
        # 更新消息的已读状态
        if message_id:
            # 标记特定消息为已读
            db.messages.update_one(
                {'_id': ObjectId(message_id)},
                {'$addToSet': {'read_by': user_id}}
            )
            
            # 更新Redis中的已读状态
            redis_client.set(f"read:{chat_id}:{user_id}", message_id)
        else:
            # 标记所有消息为已读
            latest_msg = db.messages.find_one(
                {'chat_id': chat_id, 'deleted': {'$ne': True}},
                sort=[('timestamp', -1)]
            )
            if latest_msg:
                # 更新所有未读消息
                db.messages.update_many(
                    {
                        'chat_id': chat_id,
                        'timestamp': {'$lte': latest_msg['timestamp']},
                        'sender_id': {'$ne': user_id}
                    },
                    {'$addToSet': {'read_by': user_id}}
                )
                
                redis_client.set(f"read:{chat_id}:{user_id}", str(latest_msg['_id']))
        
        # 清除未读计数
        redis_client.delete(f"unread:{chat_id}:{user_id}")
        
        # 发送已读回执事件
        socketio.emit('message_read', {
            'chat_id': chat_id,
            'user_id': user_id,
            'message_id': message_id,
            'timestamp': datetime.utcnow().isoformat()
        }, room=f"private_{chat_id}" if chat_id != 'general' else 'general')
        
        return jsonify({'success': True})
        
    except Exception as e:
        logger.error(f"标记已读失败: {str(e)}")
        return jsonify({'error': '标记已读失败'}), 500

@app.route('/api/messages/<message_id>/recall', methods=['POST'])
@verify_token()
def recall_message(message_id):
    """撤回消息"""
    try:
        user_id = request.user_id
        user_role = request.user_role
        
        # 查找消息
        message = db.messages.find_one({'_id': ObjectId(message_id)})
        if not message:
            return jsonify({'error': '消息不存在'}), 404
        
        # 检查权限：只能撤回自己的消息，或者Master/Firstmate可以撤回任何消息
        if message['sender_id'] != user_id and user_role not in ['Master', 'Firstmate']:
            return jsonify({'error': '无权限撤回此消息'}), 403
        
        # 检查时间限制：普通用户只能撤回2分钟内的消息
        if user_role not in ['Master', 'Firstmate']:
            time_diff = datetime.utcnow() - message['timestamp']
            if time_diff.total_seconds() > 120:  # 2分钟
                return jsonify({'error': '超过撤回时间限制'}), 400
        
        # 标记消息为已撤回
        db.messages.update_one(
            {'_id': ObjectId(message_id)},
            {
                '$set': {
                    'recalled': True,
                    'recalled_at': datetime.utcnow(),
                    'recalled_by': user_id,
                    'content': '[此消息已被撤回]'
                }
            }
        )
        
        # 广播撤回事件
        room_name = message['chat_id'] if message['chat_id'] == 'general' else f"private_{message['chat_id']}"
        socketio.emit('message_recalled', {
            'message_id': message_id,
            'chat_id': message['chat_id'],
            'recalled_by': user_id,
            'timestamp': datetime.utcnow().isoformat()
        }, room=room_name)
        
        return jsonify({'success': True})
        
    except Exception as e:
        logger.error(f"撤回消息失败: {str(e)}")
        return jsonify({'error': '撤回消息失败'}), 500

@app.route('/api/presence/online')
@verify_token(['Master', 'Firstmate'])
def get_online_users():
    """获取在线用户列表"""
    try:
        # 从Redis获取在线用户
        online_keys = redis_client.keys("online:*")
        online_users = []
        
        for key in online_keys:
            user_data = redis_client.get(key)
            if user_data:
                try:
                    user_info = json.loads(user_data)
                    online_users.append(user_info)
                except json.JSONDecodeError:
                    continue
        
        return jsonify({
            'online_users': online_users,
            'count': len(online_users)
        })
        
    except Exception as e:
        logger.error(f"获取在线用户失败: {str(e)}")
        return jsonify({'error': '获取在线用户失败'}), 500

@app.route('/api/presence/status', methods=['POST'])
@verify_token()
def update_presence_status():
    """更新用户在线状态"""
    try:
        user_id = request.user_id
        user_role = request.user_role
        user_email = request.user_email
        
        data = request.get_json()
        status = data.get('status', 'online')  # online, away, busy, offline
        
        if status == 'offline':
            redis_client.delete(f"online:{user_id}")
        else:
            redis_client.setex(f"online:{user_id}", 300, json.dumps({
                'user_id': user_id,
                'role': user_role,
                'email': user_email,
                'status': status,
                'last_seen': datetime.utcnow().isoformat()
            }))
        
        # 广播状态变更
        socketio.emit('presence_update', {
            'user_id': user_id,
            'status': status,
            'timestamp': datetime.utcnow().isoformat()
        })
        
        return jsonify({'success': True})
        
    except Exception as e:
        logger.error(f"更新在线状态失败: {str(e)}")
        return jsonify({'error': '更新状态失败'}), 500

@app.route('/api/private-chat/create', methods=['POST'])
@verify_token(['Master', 'Firstmate'])
def create_private_chat():
    """开启私聊"""
    try:
        data = request.get_json()
        member_id = data.get('member_id')
        duration_hours = data.get('duration_hours', 24)  # 默认24小时
        
        if not member_id:
            return jsonify({'error': '缺少member_id参数'}), 400
        
        # 检查用户是否存在且为Member
        user_info = requests.get(
            f"{AUTH_SERVICE_URL}/api/users/{member_id}",
            cookies=request.cookies
        )
        if user_info.status_code != 200:
            return jsonify({'error': '用户不存在'}), 404
        
        user_data = user_info.json()
        if user_data.get('role') != 'Member':
            return jsonify({'error': '只能为Member开启私聊'}), 400
        
        # 检查是否已有活跃的私聊
        existing_chat = db.private_chats.find_one({
            'member_id': member_id,
            'status': 'active',
            'expires_at': {'$gt': datetime.utcnow()}
        })
        
        if existing_chat:
            return jsonify({
                'error': '该用户已有活跃的私聊',
                'existing_chat_id': existing_chat['chat_id'],
                'expires_at': existing_chat['expires_at'].isoformat()
            }), 409
        
        # 创建新的私聊
        chat_id = f"private_{member_id}_{int(datetime.utcnow().timestamp())}"
        expires_at = datetime.utcnow() + timedelta(hours=duration_hours)
        
        private_chat = {
            'chat_id': chat_id,
            'member_id': member_id,
            'created_by': request.user_id,
            'created_at': datetime.utcnow(),
            'expires_at': expires_at,
            'duration_hours': duration_hours,
            'status': 'active'
        }
        
        db.private_chats.insert_one(private_chat)
        
        # 通知相关用户
        socketio.emit('private_chat_created', {
            'chat_id': chat_id,
            'member_id': member_id,
            'expires_at': expires_at.isoformat(),
            'created_by': request.user_id
        })
        
        return jsonify({
            'success': True,
            'chat_id': chat_id,
            'expires_at': expires_at.isoformat()
        })
        
    except Exception as e:
        logger.error(f"创建私聊失败: {str(e)}")
        return jsonify({'error': '创建私聊失败'}), 500

@app.route('/api/private-chat/<chat_id>/extend', methods=['POST'])
@verify_token(['Master', 'Firstmate'])
def extend_private_chat(chat_id):
    """延长私聊时间"""
    try:
        data = request.get_json()
        additional_hours = data.get('additional_hours', 24)
        
        private_chat = db.private_chats.find_one({
            'chat_id': chat_id,
            'status': 'active'
        })
        
        if not private_chat:
            return jsonify({'error': '私聊不存在或已过期'}), 404
        
        # 延长过期时间
        new_expires_at = private_chat['expires_at'] + timedelta(hours=additional_hours)
        
        db.private_chats.update_one(
            {'chat_id': chat_id},
            {
                '$set': {
                    'expires_at': new_expires_at,
                    'extended_by': request.user_id,
                    'extended_at': datetime.utcnow()
                }
            }
        )
        
        # 通知相关用户
        socketio.emit('private_chat_extended', {
            'chat_id': chat_id,
            'new_expires_at': new_expires_at.isoformat(),
            'extended_by': request.user_id
        })
        
        return jsonify({
            'success': True,
            'new_expires_at': new_expires_at.isoformat()
        })
        
    except Exception as e:
        logger.error(f"延长私聊失败: {str(e)}")
        return jsonify({'error': '延长私聊失败'}), 500

@app.route('/api/private-chat/<chat_id>/close', methods=['POST'])
@verify_token(['Master', 'Firstmate'])
def close_private_chat(chat_id):
    """关闭私聊"""
    try:
        private_chat = db.private_chats.find_one({
            'chat_id': chat_id,
            'status': 'active'
        })
        
        if not private_chat:
            return jsonify({'error': '私聊不存在或已关闭'}), 404
        
        # 更新状态为关闭
        db.private_chats.update_one(
            {'chat_id': chat_id},
            {
                '$set': {
                    'status': 'closed',
                    'closed_by': request.user_id,
                    'closed_at': datetime.utcnow()
                }
            }
        )
        
        # 通知相关用户
        socketio.emit('private_chat_closed', {
            'chat_id': chat_id,
            'closed_by': request.user_id,
            'timestamp': datetime.utcnow().isoformat()
        })
        
        return jsonify({'success': True})
        
    except Exception as e:
        logger.error(f"关闭私聊失败: {str(e)}")
        return jsonify({'error': '关闭私聊失败'}), 500

@app.route('/api/private-chat/list')
@verify_token(['Master', 'Firstmate'])
def list_private_chats():
    """获取私聊列表"""
    try:
        status = request.args.get('status', 'active')
        page = int(request.args.get('page', 1))
        limit = int(request.args.get('limit', 20))
        
        # 构建查询条件
        query = {'status': status}
        if status == 'active':
            query['expires_at'] = {'$gt': datetime.utcnow()}
        
        # 查询私聊列表
        chats = db.private_chats.find(query).sort('created_at', -1).skip((page-1)*limit).limit(limit)
        
        chat_list = []
        for chat in chats:
            chat_list.append({
                'chat_id': chat['chat_id'],
                'member_id': chat['member_id'],
                'created_by': chat['created_by'],
                'created_at': chat['created_at'].isoformat(),
                'expires_at': chat['expires_at'].isoformat(),
                'status': chat['status'],
                'duration_hours': chat.get('duration_hours', 0)
            })
        
        total = db.private_chats.count_documents(query)
        
        return jsonify({
            'chats': chat_list,
            'total': total,
            'page': page,
            'limit': limit
        })
        
    except Exception as e:
        logger.error(f"获取私聊列表失败: {str(e)}")
        return jsonify({'error': '获取私聊列表失败'}), 500

@app.route('/api/chat/cleanup', methods=['POST'])
@verify_token(['Master'])
def cleanup_expired_chats():
    """清理过期的私聊数据"""
    try:
        # 查找过期的私聊
        expired_chats = db.private_chats.find({
            'expires_at': {'$lt': datetime.utcnow()},
            'status': 'active'
        })
        
        cleanup_count = 0
        for chat in expired_chats:
            # 更新状态为过期
            db.private_chats.update_one(
                {'_id': chat['_id']},
                {
                    '$set': {
                        'status': 'expired',
                        'expired_at': datetime.utcnow()
                    }
                }
            )
            
            # 清理相关的Redis数据
            redis_client.delete(f"unread:{chat['chat_id']}:*")
            redis_client.delete(f"read:{chat['chat_id']}:*")
            
            # 通知用户私聊已过期
            socketio.emit('private_chat_expired', {
                'chat_id': chat['chat_id'],
                'timestamp': datetime.utcnow().isoformat()
            })
            
            cleanup_count += 1
        
        return jsonify({
            'success': True,
            'cleaned_up': cleanup_count
        })
        
    except Exception as e:
        logger.error(f"清理过期聊天失败: {str(e)}")
        return jsonify({'error': '清理失败'}), 500

if __name__ == '__main__':
    socketio.run(app, host='0.0.0.0', port=5002, debug=True)