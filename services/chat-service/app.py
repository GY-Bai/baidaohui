from flask import Flask, request, jsonify
from flask_socketio import SocketIO, emit, join_room, leave_room
from flask_cors import CORS
import os
import jwt
import redis
import pymongo
from datetime import datetime
import logging
import requests

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

@app.route('/health')
def health():
    return jsonify({'status': 'healthy', 'service': 'chat-service'})

@app.route('/api/messages/history')
def get_message_history():
    """获取聊天历史记录"""
    try:
        # 验证用户身份
        token = request.cookies.get('access_token')
        if not token:
            return jsonify({'error': '未登录'}), 401
            
        payload = jwt.decode(token, JWT_SECRET, algorithms=['HS256'])
        user_id = payload['sub']
        user_role = payload['role']
        
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
            'chat_id': chat_id
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
                'attachments': msg.get('attachments', [])
            })
        
        # 反转列表，使最新消息在最后
        message_list.reverse()
        
        return jsonify({
            'messages': message_list,
            'total': db.messages.count_documents({'chat_id': chat_id})
        })
        
    except jwt.InvalidTokenError:
        return jsonify({'error': '无效的Token'}), 401
    except Exception as e:
        logger.error(f"获取消息历史失败: {str(e)}")
        return jsonify({'error': '获取消息历史失败'}), 500

@app.route('/api/chat/mark-read', methods=['POST'])
def mark_messages_read():
    """标记消息为已读"""
    try:
        token = request.cookies.get('access_token')
        if not token:
            return jsonify({'error': '未登录'}), 401
            
        payload = jwt.decode(token, JWT_SECRET, algorithms=['HS256'])
        user_id = payload['sub']
        
        data = request.get_json()
        chat_id = data.get('chat_id')
        message_id = data.get('message_id')
        
        if not chat_id:
            return jsonify({'error': '缺少chat_id参数'}), 400
            
        # 更新Redis中的已读状态
        read_key = f"read:{chat_id}:{user_id}"
        if message_id:
            redis_client.set(read_key, message_id)
        else:
            # 标记所有消息为已读
            latest_msg = db.messages.find_one(
                {'chat_id': chat_id},
                sort=[('timestamp', -1)]
            )
            if latest_msg:
                redis_client.set(read_key, str(latest_msg['_id']))
        
        return jsonify({'success': True})
        
    except jwt.InvalidTokenError:
        return jsonify({'error': '无效的Token'}), 401
    except Exception as e:
        logger.error(f"标记已读失败: {str(e)}")
        return jsonify({'error': '标记已读失败'}), 500

@app.route('/api/chat/cleanup', methods=['POST'])
def cleanup_expired_chats():
    """清理过期的私聊数据"""
    try:
        # 只有Master可以调用此接口
        token = request.cookies.get('access_token')
        if not token:
            return jsonify({'error': '未登录'}), 401
            
        payload = jwt.decode(token, JWT_SECRET, algorithms=['HS256'])
        if payload['role'] != 'Master':
            return jsonify({'error': '无权限'}), 403
        
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
                {'$set': {'status': 'expired'}}
            )
            
            # 可选：删除相关消息（或保留用于归档）
            # db.messages.delete_many({'chat_id': chat['chat_id']})
            
            cleanup_count += 1
        
        return jsonify({
            'success': True,
            'cleaned_up': cleanup_count
        })
        
    except jwt.InvalidTokenError:
        return jsonify({'error': '无效的Token'}), 401
    except Exception as e:
        logger.error(f"清理过期聊天失败: {str(e)}")
        return jsonify({'error': '清理失败'}), 500

if __name__ == '__main__':
    socketio.run(app, host='0.0.0.0', port=5002, debug=True) 