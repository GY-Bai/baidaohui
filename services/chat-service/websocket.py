from flask_socketio import emit, join_room, leave_room, disconnect
import jwt
import json
from datetime import datetime
import uuid
import boto3
from botocore.exceptions import ClientError
import base64
import os

def register_websocket_handlers(socketio, db, redis_client, logger):
    JWT_SECRET = os.getenv('JWT_SECRET', 'your-secret-key')
    R2_ENDPOINT = os.getenv('R2_ENDPOINT')
    R2_ACCESS_KEY = os.getenv('R2_ACCESS_KEY')
    R2_SECRET_KEY = os.getenv('R2_SECRET_KEY')
    R2_BUCKET = os.getenv('R2_BUCKET')
    
    # 初始化R2客户端
    s3_client = None
    if R2_ENDPOINT and R2_ACCESS_KEY and R2_SECRET_KEY:
        s3_client = boto3.client(
            's3',
            endpoint_url=R2_ENDPOINT,
            aws_access_key_id=R2_ACCESS_KEY,
            aws_secret_access_key=R2_SECRET_KEY,
            region_name='auto'
        )

    @socketio.on('connect')
    def handle_connect(auth):
        """处理WebSocket连接"""
        try:
            # 从认证数据中获取token
            token = None
            if auth and 'token' in auth:
                token = auth['token']
            
            if not token:
                logger.warning("WebSocket连接缺少token")
                disconnect()
                return False
            
            # 验证JWT
            payload = jwt.decode(token, JWT_SECRET, algorithms=['HS256'])
            user_id = payload['sub']
            user_role = payload['role']
            user_email = payload['email']
            
            # 存储用户信息到session
            socketio.session['user_id'] = user_id
            socketio.session['user_role'] = user_role
            socketio.session['user_email'] = user_email
            
            # 更新在线状态
            redis_client.setex(f"online:{user_id}", 300, json.dumps({
                'user_id': user_id,
                'role': user_role,
                'email': user_email,
                'connected_at': datetime.utcnow().isoformat()
            }))
            
            logger.info(f"用户 {user_email} ({user_role}) WebSocket连接成功")
            
            # 根据角色自动加入相应房间
            if user_role in ['Member', 'Master', 'Firstmate']:
                join_room('general')
                emit('joined_room', {'room': 'general'})
            
            # 如果是Member，检查是否有活跃的私聊
            if user_role == 'Member':
                private_chat = db.private_chats.find_one({
                    'member_id': user_id,
                    'status': 'active',
                    'expires_at': {'$gt': datetime.utcnow()}
                })
                if private_chat:
                    private_room = f"private_{private_chat['chat_id']}"
                    join_room(private_room)
                    emit('joined_room', {'room': private_room})
            
            # Master和Firstmate可以加入所有活跃的私聊房间
            elif user_role in ['Master', 'Firstmate']:
                active_private_chats = db.private_chats.find({
                    'status': 'active',
                    'expires_at': {'$gt': datetime.utcnow()}
                })
                for chat in active_private_chats:
                    private_room = f"private_{chat['chat_id']}"
                    join_room(private_room)
            
            emit('connection_success', {
                'user_id': user_id,
                'role': user_role,
                'timestamp': datetime.utcnow().isoformat()
            })
            
        except jwt.InvalidTokenError:
            logger.warning("WebSocket连接token无效")
            disconnect()
            return False
        except Exception as e:
            logger.error(f"WebSocket连接处理失败: {str(e)}")
            disconnect()
            return False

    @socketio.on('disconnect')
    def handle_disconnect():
        """处理WebSocket断开连接"""
        try:
            user_id = socketio.session.get('user_id')
            if user_id:
                # 移除在线状态
                redis_client.delete(f"online:{user_id}")
                logger.info(f"用户 {user_id} WebSocket断开连接")
        except Exception as e:
            logger.error(f"处理断开连接失败: {str(e)}")

    @socketio.on('send_message')
    def handle_send_message(data):
        """处理发送消息"""
        try:
            user_id = socketio.session.get('user_id')
            user_role = socketio.session.get('user_role')
            user_email = socketio.session.get('user_email')
            
            if not user_id:
                emit('error', {'message': '未认证的连接'})
                return
            
            chat_id = data.get('chat_id')
            content = data.get('content', '').strip()
            message_type = data.get('type', 'text')
            attachments = data.get('attachments', [])
            
            if not chat_id or not content:
                emit('error', {'message': '消息内容不能为空'})
                return
            
            # 权限检查
            if chat_id == 'general':
                if user_role not in ['Member', 'Master', 'Firstmate']:
                    emit('error', {'message': '无权限发送群聊消息'})
                    return
            else:
                # 私聊权限检查
                if user_role == 'Member':
                    private_chat = db.private_chats.find_one({
                        'member_id': user_id,
                        'chat_id': chat_id,
                        'status': 'active',
                        'expires_at': {'$gt': datetime.utcnow()}
                    })
                    if not private_chat:
                        emit('error', {'message': '私聊未开启或已过期'})
                        return
                elif user_role not in ['Master', 'Firstmate']:
                    emit('error', {'message': '无权限发送私聊消息'})
                    return
            
            # 处理附件上传
            processed_attachments = []
            if attachments and s3_client:
                for attachment in attachments:
                    try:
                        # 假设附件是base64编码的图片
                        file_data = base64.b64decode(attachment['data'])
                        file_name = f"chat/{chat_id}/{uuid.uuid4()}.{attachment.get('type', 'jpg')}"
                        
                        # 上传到R2
                        s3_client.put_object(
                            Bucket=R2_BUCKET,
                            Key=file_name,
                            Body=file_data,
                            ContentType=f"image/{attachment.get('type', 'jpeg')}"
                        )
                        
                        processed_attachments.append({
                            'url': f"{R2_ENDPOINT}/{R2_BUCKET}/{file_name}",
                            'type': attachment.get('type', 'image'),
                            'name': attachment.get('name', file_name)
                        })
                    except Exception as e:
                        logger.error(f"上传附件失败: {str(e)}")
            
            # 保存消息到数据库
            message_doc = {
                'chat_id': chat_id,
                'sender_id': user_id,
                'sender_name': user_email.split('@')[0],  # 使用邮箱前缀作为显示名
                'content': content,
                'type': message_type,
                'attachments': processed_attachments,
                'timestamp': datetime.utcnow()
            }
            
            result = db.messages.insert_one(message_doc)
            message_doc['_id'] = str(result.inserted_id)
            message_doc['timestamp'] = message_doc['timestamp'].isoformat()
            
            # 确定房间名称
            room_name = chat_id if chat_id == 'general' else f"private_{chat_id}"
            
            # 广播消息到房间
            socketio.emit('new_message', message_doc, room=room_name)
            
            # 更新未读计数
            if chat_id != 'general':
                # 为私聊更新未读计数
                private_chat = db.private_chats.find_one({'chat_id': chat_id})
                if private_chat:
                    # 为对方增加未读计数
                    if user_role == 'Member':
                        redis_client.incr(f"unread:{chat_id}:master")
                    else:
                        redis_client.incr(f"unread:{chat_id}:{private_chat['member_id']}")
            
            logger.info(f"用户 {user_email} 在 {chat_id} 发送消息")
            
        except Exception as e:
            logger.error(f"发送消息失败: {str(e)}")
            emit('error', {'message': '发送消息失败'})

    @socketio.on('join_private_chat')
    def handle_join_private_chat(data):
        """加入私聊房间"""
        try:
            user_id = socketio.session.get('user_id')
            user_role = socketio.session.get('user_role')
            
            if not user_id:
                emit('error', {'message': '未认证的连接'})
                return
            
            chat_id = data.get('chat_id')
            if not chat_id:
                emit('error', {'message': '缺少chat_id'})
                return
            
            # 权限检查
            if user_role == 'Member':
                private_chat = db.private_chats.find_one({
                    'member_id': user_id,
                    'chat_id': chat_id,
                    'status': 'active',
                    'expires_at': {'$gt': datetime.utcnow()}
                })
                if not private_chat:
                    emit('error', {'message': '私聊未开启或已过期'})
                    return
            elif user_role not in ['Master', 'Firstmate']:
                emit('error', {'message': '无权限加入私聊'})
                return
            
            room_name = f"private_{chat_id}"
            join_room(room_name)
            emit('joined_room', {'room': room_name})
            
            # 清除未读计数
            if user_role == 'Member':
                redis_client.delete(f"unread:{chat_id}:{user_id}")
            else:
                redis_client.delete(f"unread:{chat_id}:master")
            
        except Exception as e:
            logger.error(f"加入私聊房间失败: {str(e)}")
            emit('error', {'message': '加入私聊房间失败'})

    @socketio.on('leave_private_chat')
    def handle_leave_private_chat(data):
        """离开私聊房间"""
        try:
            chat_id = data.get('chat_id')
            if chat_id:
                room_name = f"private_{chat_id}"
                leave_room(room_name)
                emit('left_room', {'room': room_name})
        except Exception as e:
            logger.error(f"离开私聊房间失败: {str(e)}")

    @socketio.on('get_online_users')
    def handle_get_online_users():
        """获取在线用户列表"""
        try:
            user_role = socketio.session.get('user_role')
            
            if user_role not in ['Master', 'Firstmate']:
                emit('error', {'message': '无权限查看在线用户'})
                return
            
            # 从Redis获取在线用户
            online_keys = redis_client.keys("online:*")
            online_users = []
            
            for key in online_keys:
                user_data = redis_client.get(key)
                if user_data:
                    online_users.append(json.loads(user_data))
            
            emit('online_users', {'users': online_users})
            
        except Exception as e:
            logger.error(f"获取在线用户失败: {str(e)}")
            emit('error', {'message': '获取在线用户失败'}) 