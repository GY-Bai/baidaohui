from flask import Flask, request, jsonify, make_response
from flask_socketio import SocketIO, emit, join_room, leave_room
from flask_cors import CORS
from pymongo import MongoClient
from bson import ObjectId
from datetime import datetime, timedelta
import json
import logging
import redis
from functools import wraps
import os
import urllib.parse
from websocket import register_websocket_handlers # 导入WebSocket处理函数

# 配置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
app.config['SECRET_KEY'] = 'your-secret-key'
CORS(app, origins=["http://localhost:3000"])

# 环境变量配置
JWT_SECRET = os.getenv('JWT_SECRET', 'your-secret-key')
SUPABASE_JWT_SECRET = os.getenv('SUPABASE_JWT_SECRET')

# 初始化SocketIO
socketio = SocketIO(app, cors_allowed_origins="*")

# 数据库连接
try:
    MONGODB_URI = os.getenv('MONGODB_URI', 'mongodb://localhost:27017/')
    client = MongoClient(MONGODB_URI)
    db = client.baidaohui_chat
    logger.info("MongoDB连接成功")
except Exception as e:
    logger.error(f"MongoDB连接失败: {e}")
    db = None

# Redis连接
try:
    REDIS_URL = os.getenv('REDIS_URL', 'redis://localhost:6379')
    if REDIS_URL.startswith('redis://'):
        # 解析Redis URL
        parsed = urllib.parse.urlparse(REDIS_URL)
        redis_host = parsed.hostname or 'localhost'
        redis_port = parsed.port or 6379
        redis_db = int(parsed.path.lstrip('/')) if parsed.path and parsed.path != '/' else 0
    else:
        redis_host = 'localhost'
        redis_port = 6379
        redis_db = 0
    
    redis_client = redis.Redis(host=redis_host, port=redis_port, db=redis_db, decode_responses=True)
    redis_client.ping()
    logger.info(f"Redis连接成功: {redis_host}:{redis_port}")
except Exception as e:
    logger.error(f"Redis连接失败: {e}")
    redis_client = None

# Token验证装饰器
def verify_token(allowed_roles=None):
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            # 这里应该实现JWT token验证逻辑
            # 暂时模拟验证通过
            return f(*args, **kwargs)
        return decorated_function
    return decorator

# 获取当前用户信息
def get_current_user():
    # 这里应该从JWT token中解析用户信息
    # 暂时返回模拟数据
    return {
        'id': 'master_user_id',
        'role': 'Master',
        'email': 'master@localhost',
        'nickname': '大师'
    }

# 健康检查
@app.route('/health')
def health():
    return jsonify({'status': 'healthy'})

# 注册WebSocket处理程序
register_websocket_handlers(socketio, db, redis_client, logger)

# 获取聊天成员列表
@app.route('/api/chat/members')
@verify_token(['Master', 'Firstmate'])
def get_chat_members():
    """获取聊天成员列表"""
    try:
        current_user = get_current_user()
        
        # 查询所有Member用户
        members = db.users.find({'role': 'Member'})
        
        member_list = []
        for member in members:
            # 获取私聊信息
            private_chat = db.private_chats.find_one({'member_id': str(member['_id'])})
            
            # 获取最新消息
            last_message = None
            unread_count = 0
            if private_chat and private_chat.get('enabled'):
                last_msg = db.messages.find_one(
                    {'chat_id': f'private_{member["_id"]}', 'deleted': {'$ne': True}},
                    sort=[('timestamp', -1)]
                )
                if last_msg:
                    last_message = {
                        'content': last_msg['content'],
                        'timestamp': last_msg['timestamp'],
                        'sender_id': last_msg['sender_id'],
                        'read_status': current_user['id'] in last_msg.get('read_by', [])
                    }
                
                # 计算未读消息数量
                unread_count = db.messages.count_documents({
                    'chat_id': f'private_{member["_id"]}',
                    'sender_id': {'$ne': current_user['id']},
                    'read_by': {'$ne': current_user['id']},
                    'deleted': {'$ne': True}
                })
            
            member_info = {
                'id': str(member['_id']),
                'email': member['email'],
                'nickname': member.get('nickname'),
                'privateChatEnabled': private_chat.get('enabled', False) if private_chat else False,
                'privateChatStartedAt': private_chat.get('started_at') if private_chat else None,
                'privateChatExpiresAt': private_chat.get('expires_at') if private_chat else None,
                'lastMessage': last_message,
                'unreadCount': unread_count
            }
            
            member_list.append(member_info)
        
        return jsonify(member_list)
        
    except Exception as e:
        logger.error(f"获取成员列表失败: {str(e)}")
        return jsonify({'error': '获取成员列表失败'}), 500

# 获取群聊信息
@app.route('/api/chat/group/general')
@verify_token(['Master', 'Firstmate'])
def get_group_chat_info():
    """获取群聊信息"""
    try:
        current_user = get_current_user()
        
        # 统计成员数量
        member_count = db.users.count_documents({'role': 'Member'})
        
        # 获取最新消息
        last_message = db.messages.find_one(
            {'chat_id': 'general', 'deleted': {'$ne': True}},
            sort=[('timestamp', -1)]
        )
        
        last_message_info = None
        if last_message:
            sender_info = db.users.find_one({'_id': last_message['sender_id']}) or {}
            last_message_info = {
                'content': last_message['content'],
                'timestamp': last_message['timestamp'],
                'sender_id': last_message['sender_id'],
                'sender_name': sender_info.get('nickname', sender_info.get('email', 'Unknown'))
            }
        
        # 计算未读消息数量
        unread_count = db.messages.count_documents({
            'chat_id': 'general',
            'sender_id': {'$ne': current_user['id']},
            'read_by': {'$ne': current_user['id']},
            'deleted': {'$ne': True}
        })
        
        group_info = {
            'id': 'general',
            'type': 'group',
            'name': '#general 群聊',
            'memberCount': member_count,
            'lastMessage': last_message_info,
            'unreadCount': unread_count,
            'isActive': True,
            'isPinned': True
        }
        
        return jsonify(group_info)
        
    except Exception as e:
        logger.error(f"获取群聊信息失败: {str(e)}")
        return jsonify({'error': '获取群聊信息失败'}), 500

# 获取聚合群聊消息
@app.route('/api/messages/aggregated')
@verify_token(['Master', 'Firstmate'])
def get_aggregated_messages():
    """获取聚合群聊消息（增强版，包含已读状态）"""
    try:
        current_user = get_current_user()
        limit = int(request.args.get('limit', 50))
        offset = int(request.args.get('offset', 0))
        
        # 获取群聊消息
        messages_cursor = db.messages.find({
            'chat_id': 'general',
            'deleted': {'$ne': True}
        }).sort('timestamp', -1).skip(offset).limit(limit)
        
        messages = []
        for msg in messages_cursor:
            # 检查消息是否被当前用户读过
            read_status = current_user['id'] in msg.get('read_by', [])
            
            # 获取发送者信息
            sender_info = db.users.find_one({'_id': msg['sender_id']}) or {}
            
            message_data = {
                'id': str(msg['_id']),
                'chat_id': msg['chat_id'],
                'sender_id': msg['sender_id'],
                'sender_role': sender_info.get('role', 'Member'),
                'sender_name': sender_info.get('nickname', sender_info.get('email', 'Unknown')),
                'sender_email': sender_info.get('email', ''),
                'content': msg['content'],
                'type': msg.get('type', 'text'),
                'timestamp': msg['timestamp'].isoformat(),
                'read_status': read_status,
                'attachments': msg.get('attachments', [])
            }
            messages.append(message_data)
        
        # 反转消息顺序（最新的在底部）
        messages.reverse()
        
        # 自动标记所有member消息为已读（仅对Master/Firstmate）
        if current_user['role'] in ['Master', 'Firstmate']:
            db.messages.update_many(
                {
                    'chat_id': 'general',
                    'sender_role': 'Member',
                    'read_by': {'$ne': current_user['id']},
                    'deleted': {'$ne': True}
                },
                {
                    '$addToSet': {'read_by': current_user['id']},
                    '$set': {'updated_at': datetime.utcnow()}
                }
            )
        
        return jsonify({
            'messages': messages,
            'total': db.messages.count_documents({'chat_id': 'general', 'deleted': {'$ne': True}})
        })
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# 获取私聊消息
@app.route('/api/messages/private/<member_id>')
@verify_token(['Master', 'Member'])
def get_private_messages(member_id):
    """获取私聊消息（增强版，包含已读状态）"""
    try:
        current_user = get_current_user()
        
        # 权限检查
        if current_user['role'] == 'Member' and current_user['id'] != member_id:
            return jsonify({'error': '权限不足'}), 403
        
        # 检查私聊权限
        private_chat = db.private_chats.find_one({'member_id': member_id})
        if not private_chat or not private_chat.get('enabled'):
            return jsonify({'error': '私聊未开启'}), 403
        
        # 检查是否过期
        if private_chat.get('expires_at') and private_chat['expires_at'] < datetime.utcnow():
            return jsonify({'error': '私聊已过期'}), 403
        
        chat_id = f'private_{member_id}'
        limit = int(request.args.get('limit', 50))
        offset = int(request.args.get('offset', 0))
        
        # 获取消息
        messages_cursor = db.messages.find({
            'chat_id': chat_id,
            'deleted': {'$ne': True}
        }).sort('timestamp', -1).skip(offset).limit(limit)
        
        messages = []
        for msg in messages_cursor:
            # 检查消息是否被当前用户读过
            read_status = current_user['id'] in msg.get('read_by', [])
            
            # 获取发送者信息
            sender_info = db.users.find_one({'_id': msg['sender_id']}) or {}
            
            message_data = {
                'id': str(msg['_id']),
                'chat_id': msg['chat_id'],
                'sender_id': msg['sender_id'],
                'sender_role': sender_info.get('role', 'Member'),
                'sender_name': sender_info.get('nickname', sender_info.get('email', 'Unknown')),
                'content': msg['content'],
                'type': msg.get('type', 'text'),
                'timestamp': msg['timestamp'].isoformat(),
                'read_status': read_status,
                'read_by_count': len(msg.get('read_by', [])),
                'attachments': msg.get('attachments', [])
            }
            messages.append(message_data)
        
        # 反转消息顺序（最新的在底部）
        messages.reverse()
        
        # 获取最新消息和未读数量
        latest_message = None
        if messages:
            latest_message = messages[-1]
        
        unread_count = db.messages.count_documents({
            'chat_id': chat_id,
            'sender_id': {'$ne': current_user['id']},
            'read_by': {'$ne': current_user['id']},
            'deleted': {'$ne': True}
        })
        
        return jsonify({
            'messages': messages,
            'lastMessage': latest_message,
            'unreadCount': unread_count,
            'expiresAt': private_chat.get('expires_at').isoformat() if private_chat.get('expires_at') else None,
            'total': db.messages.count_documents({'chat_id': chat_id, 'deleted': {'$ne': True}})
        })
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# 发送消息
@app.route('/api/messages/send', methods=['POST'])
@verify_token(['Master', 'Firstmate', 'Member'])
def send_message():
    """发送消息（增强版，包含已读状态管理）"""
    try:
        data = request.get_json()
        chat_id = data.get('chat_id')
        content = data.get('content')
        message_type = data.get('type', 'text')
        current_user = get_current_user()
        
        if not chat_id or not content:
            return jsonify({'error': '缺少必要参数'}), 400
        
        # 权限检查
        if chat_id.startswith('private_'):
            member_id = chat_id.replace('private_', '')
            
            # 检查私聊权限
            if current_user['role'] == 'Member':
                if current_user['id'] != member_id:
                    return jsonify({'error': '权限不足'}), 403
            
            private_chat = db.private_chats.find_one({'member_id': member_id})
            if not private_chat or not private_chat.get('enabled'):
                return jsonify({'error': '私聊未开启'}), 403
            
            # 检查是否过期
            if private_chat.get('expires_at') and private_chat['expires_at'] < datetime.utcnow():
                return jsonify({'error': '私聊已过期'}), 403
        
        # 获取发送者信息
        sender_info = db.users.find_one({'_id': current_user['id']}) or {}
        
        # 创建消息
        message = {
            'chat_id': chat_id,
            'sender_id': current_user['id'],
            'sender_role': sender_info.get('role', current_user['role']),
            'sender_name': sender_info.get('nickname', sender_info.get('email', '')),
            'content': content,
            'type': message_type,
            'timestamp': datetime.utcnow(),
            'read_by': [current_user['id']],  # 发送者自动标记为已读
            'attachments': data.get('attachments', []),
            'deleted': False,
            'created_at': datetime.utcnow(),
            'updated_at': datetime.utcnow()
        }
        
        # 保存消息
        result = db.messages.insert_one(message)
        message['_id'] = result.inserted_id
        
        # 更新Redis缓存
        if redis_client:
            redis_key = f'chat:{chat_id}:latest'
            redis_client.setex(redis_key, 3600, json.dumps({
                'content': content,
                'sender_id': current_user['id'],
                'timestamp': message['timestamp'].isoformat()
            }))
        
        return jsonify({
            'id': str(message['_id']),
            'chat_id': chat_id,
            'sender_id': current_user['id'],
            'sender_role': sender_info.get('role', current_user['role']),
            'sender_name': sender_info.get('nickname', ''),
            'content': content,
            'type': message_type,
            'timestamp': message['timestamp'].isoformat(),
            'read_status': True,
            'attachments': message.get('attachments', [])
        })
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# 更新私聊权限
@app.route('/api/chat/private/permission', methods=['POST'])
@verify_token(['Master'])
def update_private_chat_permission():
    """更新私聊权限"""
    try:
        data = request.get_json()
        member_id = data.get('memberId')
        enabled = data.get('enabled', False)
        expires_at = data.get('expiresAt')
        
        if not member_id:
            return jsonify({'error': '成员ID不能为空'}), 400
        
        # 检查成员是否存在
        member = db.users.find_one({'_id': member_id, 'role': 'Member'})
        if not member:
            return jsonify({'error': '成员不存在'}), 404
        
        if enabled:
            # 开启私聊
            private_chat_data = {
                'member_id': member_id,
                'enabled': True,
                'started_at': datetime.utcnow(),
                'expires_at': datetime.fromisoformat(expires_at.replace('Z', '+00:00')) if expires_at else None,
                'updated_at': datetime.utcnow()
            }
            
            db.private_chats.update_one(
                {'member_id': member_id},
                {'$set': private_chat_data},
                upsert=True
            )
            
            logger.info(f"为成员 {member_id} 开启私聊权限，到期时间: {expires_at}")
        else:
            # 关闭私聊
            db.private_chats.update_one(
                {'member_id': member_id},
                {'$set': {
                    'enabled': False,
                    'updated_at': datetime.utcnow()
                }}
            )
            
            logger.info(f"为成员 {member_id} 关闭私聊权限")
        
        return jsonify({'success': True})
        
    except Exception as e:
        logger.error(f"更新私聊权限失败: {str(e)}")
        return jsonify({'error': '更新权限失败'}), 500

# 标记群聊消息为已读
@app.route('/api/chat/mark-group-read', methods=['POST'])
@verify_token(['Master', 'Firstmate'])
def mark_group_messages_read():
    """标记群聊中的member消息为已读"""
    try:
        data = request.get_json()
        chat_id = data.get('chatId', 'general')
        current_user = get_current_user()
        
        # 更新群聊中所有member消息的已读状态
        result = db.messages.update_many(
            {
                'chat_id': chat_id,
                'sender_role': 'Member',
                'read_by': {'$ne': current_user['id']},
                'deleted': {'$ne': True}
            },
            {
                '$addToSet': {'read_by': current_user['id']},
                '$set': {'updated_at': datetime.utcnow()}
            }
        )
        
        return jsonify({
            'success': True,
            'marked_count': result.modified_count
        })
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# 标记私聊消息为已读
@app.route('/api/chat/mark-read', methods=['POST'])
@verify_token(['Master', 'Member'])
def mark_chat_as_read():
    """标记聊天消息为已读"""
    try:
        data = request.get_json()
        chat_id = data.get('chatId')
        member_id = data.get('memberId')
        current_user = get_current_user()
        
        if not chat_id:
            return jsonify({'error': '缺少chatId参数'}), 400
        
        # 更新消息已读状态
        result = db.messages.update_many(
            {
                'chat_id': chat_id,
                'sender_id': {'$ne': current_user['id']},
                'read_by': {'$ne': current_user['id']},
                'deleted': {'$ne': True}
            },
            {
                '$addToSet': {'read_by': current_user['id']},
                '$set': {'updated_at': datetime.utcnow()}
            }
        )
        
        return jsonify({
            'success': True,
            'marked_count': result.modified_count
        })
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# 删除私聊
@app.route('/api/chat/private/delete', methods=['POST'])
@verify_token(['Master'])
def delete_private_chat():
    """删除私聊（仅Master可用）"""
    try:
        data = request.get_json()
        member_id = data.get('memberId')
        
        if not member_id:
            return jsonify({'error': '缺少member_id参数'}), 400
        
        # 删除私聊权限记录
        db.private_chats.delete_one({'member_id': member_id})
        
        # 删除私聊消息
        chat_id = f'private_{member_id}'
        db.messages.update_many(
            {'chat_id': chat_id},
            {'$set': {'deleted': True, 'updated_at': datetime.utcnow()}}
        )
        
        # 清理Redis中的相关数据
        if redis_client:
            redis_client.delete(f'chat:{chat_id}:members')
            redis_client.delete(f'chat:{chat_id}:unread')
            redis_client.delete(f'chat:{chat_id}:latest')
        
        return jsonify({'success': True})
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# 清理过期私聊
@app.route('/api/chat/cleanup', methods=['POST'])
@verify_token(['Master'])
def cleanup_expired_chats():
    """清理过期的私聊"""
    try:
        data = request.get_json()
        member_id = data.get('memberId')
        
        if member_id:
            # 清理特定成员的过期私聊
            private_chat = db.private_chats.find_one({'member_id': member_id})
            if private_chat and private_chat.get('expires_at') and private_chat['expires_at'] <= datetime.utcnow():
                # 删除私聊权限记录
                db.private_chats.delete_one({'member_id': member_id})
                
                # 删除私聊消息
                chat_id = f'private_{member_id}'
                db.messages.update_many(
                    {'chat_id': chat_id},
                    {'$set': {'deleted': True, 'updated_at': datetime.utcnow()}}
                )
                
                # 清理Redis缓存
                if redis_client:
                    redis_client.delete(f'chat:{chat_id}:*')
                
                return jsonify({'success': True, 'cleaned': True})
            else:
                return jsonify({'success': True, 'cleaned': False})
        else:
            # 清理所有过期的私聊
            current_time = datetime.utcnow()
            expired_chats = db.private_chats.find({
                'enabled': True,
                'expires_at': {'$lt': current_time}
            })
            
            cleaned_count = 0
            for chat in expired_chats:
                member_id = chat['member_id']
                
                # 删除私聊权限记录
                db.private_chats.delete_one({'member_id': member_id})
                
                # 删除私聊消息
                chat_id = f'private_{member_id}'
                db.messages.update_many(
                    {'chat_id': chat_id},
                    {'$set': {'deleted': True, 'updated_at': current_time}}
                )
                
                cleaned_count += 1
                logger.info(f"清理过期私聊: {member_id}")
            
            return jsonify({
                'success': True,
                'cleaned_count': cleaned_count
            })
        
    except Exception as e:
        logger.error(f"清理过期聊天失败: {str(e)}")
        return jsonify({'error': '清理失败'}), 500

# 获取未读消息数量
@app.route('/api/chat/unread-count/<member_id>')
@verify_token(['Master', 'Member'])
def get_unread_count(member_id):
    """获取特定用户的未读消息数量"""
    try:
        current_user = get_current_user()
        
        # 检查权限
        if current_user['role'] == 'Member' and current_user['id'] != member_id:
            return jsonify({'error': '权限不足'}), 403
        
        chat_id = f'private_{member_id}'
        
        # 统计未读消息数量
        unread_count = db.messages.count_documents({
            'chat_id': chat_id,
            'sender_id': {'$ne': current_user['id']},  # 不是自己发送的消息
            'read_by': {'$ne': current_user['id']},     # 自己未读的消息
            'deleted': {'$ne': True}
        })
        
        return jsonify({
            'unread_count': unread_count,
            'member_id': member_id
        })
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# 下载聊天记录
@app.route('/api/chat/private/history/<member_id>/download')
@verify_token(['Master'])
def download_chat_history(member_id):
    """下载聊天记录"""
    try:
        # 获取所有私聊消息
        messages = db.messages.find({
            'chat_id': f'private_{member_id}',
            'deleted': {'$ne': True}
        }).sort('timestamp', 1)
        
        # 获取成员信息
        member = db.users.find_one({'_id': member_id})
        member_name = member.get('nickname', member.get('email', 'Unknown')) if member else 'Unknown'
        
        # 构建聊天记录
        chat_history = {
            'member_id': member_id,
            'member_name': member_name,
            'download_time': datetime.utcnow().isoformat(),
            'messages': []
        }
        
        for msg in messages:
            sender_info = db.users.find_one({'_id': msg['sender_id']}) or {}
            chat_history['messages'].append({
                'timestamp': msg['timestamp'].isoformat(),
                'sender_name': sender_info.get('nickname', sender_info.get('email', 'Unknown')),
                'sender_role': sender_info.get('role', 'Member'),
                'content': msg['content'],
                'type': msg.get('type', 'text')
            })
        
        # 返回JSON文件
        response = make_response(json.dumps(chat_history, ensure_ascii=False, indent=2))
        response.headers['Content-Type'] = 'application/json; charset=utf-8'
        response.headers['Content-Disposition'] = f'attachment; filename=chat-history-{member_id}-{datetime.now().strftime("%Y%m%d")}.json'
        
        return response
        
    except Exception as e:
        logger.error(f"下载聊天记录失败: {str(e)}")
        return jsonify({'error': '下载失败'}), 500

# WebSocket事件处理
@socketio.on('connect')
def handle_connect():
    logger.info('客户端连接')

@socketio.on('disconnect')
def handle_disconnect():
    logger.info('客户端断开连接')

@socketio.on('join_room')
def handle_join_room(data):
    room = data.get('room')
    if room:
        join_room(room)
        logger.info(f'用户加入房间: {room}')

@socketio.on('leave_room')
def handle_leave_room(data):
    room = data.get('room')
    if room:
        leave_room(room)
        logger.info(f'用户离开房间: {room}')

if __name__ == '__main__':
    PORT = int(os.getenv('PORT', 5003))  # 默认5003端口，支持环境变量覆盖
    socketio.run(app, host='0.0.0.0', port=PORT, debug=False)
    logger.info(f"聊天服务启动在端口 {PORT}") 