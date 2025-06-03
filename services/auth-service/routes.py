from flask_socketio import emit, join_room, leave_room, disconnect
import jwt
import json
from datetime import datetime, timedelta
import uuid
import boto3
from botocore.exceptions import ClientError
import base64
import os
from bson import ObjectId
from flask import Blueprint, request, jsonify, make_response, redirect
import requests
import logging

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
                'status': 'online',
                'connected_at': datetime.utcnow().isoformat(),
                'last_seen': datetime.utcnow().isoformat()
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
            
            # 广播用户上线事件
            socketio.emit('user_online', {
                'user_id': user_id,
                'email': user_email,
                'role': user_role,
                'timestamp': datetime.utcnow().isoformat()
            }, broadcast=True)
            
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
            user_email = socketio.session.get('user_email')
            user_role = socketio.session.get('user_role')
            
            if user_id:
                # 更新离线状态
                redis_client.setex(f"offline:{user_id}", 300, json.dumps({
                    'user_id': user_id,
                    'role': user_role,
                    'email': user_email,
                    'status': 'offline',
                    'last_seen': datetime.utcnow().isoformat()
                }))
                
                # 移除在线状态
                redis_client.delete(f"online:{user_id}")
                
                # 广播用户离线事件
                socketio.emit('user_offline', {
                    'user_id': user_id,
                    'timestamp': datetime.utcnow().isoformat()
                }, broadcast=True)
                
                logger.info(f"用户 {user_email} WebSocket断开连接")
        except Exception as e:
            logger.error(f"处理断开连接失败: {str(e)}")

    @socketio.on('heartbeat')
    def handle_heartbeat():
        """处理心跳包，更新在线状态"""
        try:
            user_id = socketio.session.get('user_id')
            if user_id:
                # 更新在线状态的过期时间
                online_data = redis_client.get(f"online:{user_id}")
                if online_data:
                    user_info = json.loads(online_data)
                    user_info['last_seen'] = datetime.utcnow().isoformat()
                    redis_client.setex(f"online:{user_id}", 300, json.dumps(user_info))
                
                emit('heartbeat_ack')
        except Exception as e:
            logger.error(f"处理心跳包失败: {str(e)}")

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
            reply_to = data.get('reply_to')  # 回复的消息ID
            
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
                'timestamp': datetime.utcnow(),
                'read_by': [user_id],  # 发送者自动标记为已读
                'recalled': False,
                'deleted': False
            }
            
            # 如果是回复消息，添加回复信息
            if reply_to:
                try:
                    reply_message = db.messages.find_one({'_id': ObjectId(reply_to)})
                    if reply_message:
                        message_doc['reply_to'] = {
                            'message_id': reply_to,
                            'sender_name': reply_message.get('sender_name', ''),
                            'content': reply_message.get('content', '')[:100] + ('...' if len(reply_message.get('content', '')) > 100 else '')
                        }
                except Exception as e:
                    logger.error(f"处理回复消息失败: {str(e)}")
            
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
            else:
                # 群聊中为所有其他在线用户增加未读计数
                online_keys = redis_client.keys("online:*")
                for key in online_keys:
                    other_user_id = key.decode().split(':')[1]
                    if other_user_id != user_id:
                        redis_client.incr(f"unread:{chat_id}:{other_user_id}")
            
            logger.info(f"用户 {user_email} 在 {chat_id} 发送消息")
            
        except Exception as e:
            logger.error(f"发送消息失败: {str(e)}")
            emit('error', {'message': '发送消息失败'})

    @socketio.on('message_read')
    def handle_message_read(data):
        """处理消息已读事件"""
        try:
            user_id = socketio.session.get('user_id')
            if not user_id:
                emit('error', {'message': '未认证的连接'})
                return
            
            chat_id = data.get('chat_id')
            message_id = data.get('message_id')
            
            if not chat_id or not message_id:
                emit('error', {'message': '缺少必要参数'})
                return
            
            # 更新消息的已读状态
            db.messages.update_one(
                {'_id': ObjectId(message_id)},
                {'$addToSet': {'read_by': user_id}}
            )
            
            # 广播已读回执
            room_name = chat_id if chat_id == 'general' else f"private_{chat_id}"
            socketio.emit('message_read_receipt', {
                'message_id': message_id,
                'chat_id': chat_id,
                'reader_id': user_id,
                'timestamp': datetime.utcnow().isoformat()
            }, room=room_name, include_self=False)
            
        except Exception as e:
            logger.error(f"处理消息已读失败: {str(e)}")
            emit('error', {'message': '处理已读状态失败'})

    @socketio.on('typing_start')
    def handle_typing_start(data):
        """处理开始输入事件"""
        try:
            user_id = socketio.session.get('user_id')
            user_email = socketio.session.get('user_email')
            
            if not user_id:
                return
            
            chat_id = data.get('chat_id')
            if not chat_id:
                return
            
            room_name = chat_id if chat_id == 'general' else f"private_{chat_id}"
            
            socketio.emit('user_typing', {
                'user_id': user_id,
                'user_name': user_email.split('@')[0],
                'chat_id': chat_id,
                'timestamp': datetime.utcnow().isoformat()
            }, room=room_name, include_self=False)
            
        except Exception as e:
            logger.error(f"处理输入状态失败: {str(e)}")

    @socketio.on('typing_stop')
    def handle_typing_stop(data):
        """处理停止输入事件"""
        try:
            user_id = socketio.session.get('user_id')
            
            if not user_id:
                return
            
            chat_id = data.get('chat_id')
            if not chat_id:
                return
            
            room_name = chat_id if chat_id == 'general' else f"private_{chat_id}"
            
            socketio.emit('user_stop_typing', {
                'user_id': user_id,
                'chat_id': chat_id,
                'timestamp': datetime.utcnow().isoformat()
            }, room=room_name, include_self=False)
            
        except Exception as e:
            logger.error(f"处理停止输入状态失败: {str(e)}")

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
            
            # 通知房间内其他用户有人加入
            socketio.emit('user_joined_chat', {
                'user_id': user_id,
                'chat_id': chat_id,
                'timestamp': datetime.utcnow().isoformat()
            }, room=room_name, include_self=False)
            
        except Exception as e:
            logger.error(f"加入私聊房间失败: {str(e)}")
            emit('error', {'message': '加入私聊房间失败'})

    @socketio.on('leave_private_chat')
    def handle_leave_private_chat(data):
        """离开私聊房间"""
        try:
            user_id = socketio.session.get('user_id')
            
            chat_id = data.get('chat_id')
            if chat_id:
                room_name = f"private_{chat_id}"
                leave_room(room_name)
                emit('left_room', {'room': room_name})
                
                # 通知房间内其他用户有人离开
                socketio.emit('user_left_chat', {
                    'user_id': user_id,
                    'chat_id': chat_id,
                    'timestamp': datetime.utcnow().isoformat()
                }, room=room_name)
                
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
                    try:
                        online_users.append(json.loads(user_data))
                    except json.JSONDecodeError:
                        continue
            
            emit('online_users', {
                'users': online_users,
                'count': len(online_users)
            })
            
        except Exception as e:
            logger.error(f"获取在线用户失败: {str(e)}")
            emit('error', {'message': '获取在线用户失败'})

    @socketio.on('update_status')
    def handle_update_status(data):
        """更新用户状态"""
        try:
            user_id = socketio.session.get('user_id')
            user_role = socketio.session.get('user_role')
            user_email = socketio.session.get('user_email')
            
            if not user_id:
                emit('error', {'message': '未认证的连接'})
                return
            
            status = data.get('status', 'online')  # online, away, busy, dnd
            status_message = data.get('status_message', '')
            
            # 更新Redis中的用户状态
            user_info = {
                'user_id': user_id,
                'role': user_role,
                'email': user_email,
                'status': status,
                'status_message': status_message,
                'last_seen': datetime.utcnow().isoformat()
            }
            
            redis_client.setex(f"online:{user_id}", 300, json.dumps(user_info))
            
            # 广播状态更新
            socketio.emit('user_status_update', {
                'user_id': user_id,
                'status': status,
                'status_message': status_message,
                'timestamp': datetime.utcnow().isoformat()
            }, broadcast=True)
            
            emit('status_updated', {'success': True})
            
        except Exception as e:
            logger.error(f"更新用户状态失败: {str(e)}")
            emit('error', {'message': '更新状态失败'})

    @socketio.on('get_unread_count')
    def handle_get_unread_count(data):
        """获取未读消息数量"""
        try:
            user_id = socketio.session.get('user_id')
            
            if not user_id:
                emit('error', {'message': '未认证的连接'})
                return
            
            chat_id = data.get('chat_id')
            if not chat_id:
                emit('error', {'message': '缺少chat_id'})
                return
            
            # 从Redis获取未读计数
            unread_count = redis_client.get(f"unread:{chat_id}:{user_id}")
            unread_count = int(unread_count) if unread_count else 0
            
            emit('unread_count', {
                'chat_id': chat_id,
                'count': unread_count
            })
            
        except Exception as e:
            logger.error(f"获取未读计数失败: {str(e)}")
            emit('error', {'message': '获取未读计数失败'})

auth_bp = Blueprint('auth', __name__)

# 配置
SUPABASE_URL = os.getenv('SUPABASE_URL')
SUPABASE_SERVICE_KEY = os.getenv('SUPABASE_SERVICE_KEY')
SUPABASE_JWT_SECRET = os.getenv('SUPABASE_JWT_SECRET')
JWT_SECRET = os.getenv('JWT_SECRET', 'your-secret-key')
FRONTEND_URL = os.getenv('FRONTEND_URL', 'https://baidaohui.com')
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
        
        # 从MongoDB获取算命订单统计
        try:
            fortune_count = db.fortune_applications.count_documents({})
            stats['totalFortuneOrders'] = fortune_count
            
            # 计算总收入（这里需要根据实际的支付记录计算）
            revenue_pipeline = [
                {'$match': {'status': 'Completed'}},
                {'$group': {'_id': None, 'total': {'$sum': '$convertedAmountCAD'}}}
            ]
            revenue_result = list(db.fortune_applications.aggregate(revenue_pipeline))
            if revenue_result:
                stats['totalRevenue'] = revenue_result[0]['total']
        except Exception as e:
            logger.warning(f"获取MongoDB统计数据失败: {str(e)}")
        
        # 设置最后登录时间为当前时间
        stats['lastLogin'] = datetime.utcnow().isoformat()
        
        return jsonify(stats)
        
    except jwt.InvalidTokenError:
        return jsonify({'error': '无效的token'}), 401
    except Exception as e:
        logger.error(f"获取Master统计数据失败: {str(e)}")
        return jsonify({'error': '服务器内部错误'}), 500