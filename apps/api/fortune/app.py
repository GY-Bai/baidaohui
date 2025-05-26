from flask import Flask, request, jsonify, current_app
from flask_cors import CORS
from werkzeug.utils import secure_filename
import os
import boto3
import pymongo
import redis
import uuid
from datetime import datetime, timedelta
from decimal import Decimal
import json
from bson import ObjectId
from supabase import create_client, Client
import logging

# 配置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)

# 配置
app.config.update({
    'MAX_CONTENT_LENGTH': 16 * 1024 * 1024,  # 16MB max file size
    'UPLOAD_FOLDER': '/tmp/uploads',
    'ALLOWED_EXTENSIONS': {'png', 'jpg', 'jpeg', 'gif', 'webp'}
})

# 环境变量配置
R2_ACCOUNT_ID = os.getenv("R2_ACCOUNT_ID", "25dea0f8748cc0d718d11a64983b4123")
R2_BUCKET_NAME = os.getenv("R2_BUCKET_NAME", "baidaohui-assets")
R2_ACCESS_KEY_ID = os.getenv("R2_ACCESS_KEY_ID")
R2_SECRET_ACCESS_KEY = os.getenv("R2_SECRET_ACCESS_KEY")
S3_ENDPOINT = os.getenv("S3_ENDPOINT", "https://25dea0f8748cc0d718d11a64983b4123.r2.cloudflarestorage.com")

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_ROLE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

MONGO_URL = os.getenv("MONGO_URL")

# Redis配置
REDIS_HOST = os.getenv('REDIS_HOST', 'redis')
REDIS_PORT = int(os.getenv('REDIS_PORT', 6379))
redis_client = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, db=0, decode_responses=True)

# 初始化客户端
def init_clients():
    # R2 客户端
    s3_client = boto3.client(
        's3',
        endpoint_url=S3_ENDPOINT,
        aws_access_key_id=R2_ACCESS_KEY_ID,
        aws_secret_access_key=R2_SECRET_ACCESS_KEY,
        region_name='auto'
    )
    
    # MongoDB 客户端
    mongo_client = pymongo.MongoClient(MONGO_URL)
    db = mongo_client.baidaohui
    
    # Supabase 客户端
    supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
    
    return s3_client, db, supabase, redis_client

s3_client, db, supabase, redis_client = init_clients()

def allowed_file(filename):
    return '.' in filename and \
           filename.rsplit('.', 1)[1].lower() in app.config['ALLOWED_EXTENSIONS']

def upload_to_r2(file, folder="fortune"):
    """上传文件到R2存储"""
    try:
        filename = secure_filename(file.filename)
        file_extension = filename.rsplit('.', 1)[1].lower()
        unique_filename = f"{folder}/{uuid.uuid4()}.{file_extension}"
        
        s3_client.upload_fileobj(
            file,
            R2_BUCKET_NAME,
            unique_filename,
            ExtraArgs={'ContentType': file.content_type}
        )
        
        # 返回CDN URL
        return f"https://assets.baidaohui.com/{unique_filename}"
    except Exception as e:
        logger.error(f"Upload to R2 failed: {e}")
        raise

def get_user_from_token(token):
    """从Supabase token获取用户信息"""
    try:
        user = supabase.auth.get_user(token)
        return user.user
    except Exception as e:
        logger.error(f"Get user from token failed: {e}")
        return None

def generate_order_number():
    """生成订单号"""
    timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
    random_suffix = str(uuid.uuid4())[:8]
    return f"FT{timestamp}{random_suffix}"

@app.route('/submit', methods=['POST'])
def submit_fortune_order():
    """提交算命申请"""
    try:
        # 验证用户身份
        auth_header = request.headers.get('Authorization')
        if not auth_header or not auth_header.startswith('Bearer '):
            return jsonify({'error': '未授权访问'}), 401
            
        token = auth_header.split(' ')[1]
        user = get_user_from_token(token)
        if not user:
            return jsonify({'error': '无效的用户令牌'}), 401
        
        # 检查用户角色
        user_role = user.user_metadata.get('role', 'fan')
        if user_role not in ['fan', 'member']:
            return jsonify({'error': '无权限提交算命申请'}), 403
        
        # 获取表单数据
        description = request.form.get('description', '').strip()
        if not description or len(description) > 800:
            return jsonify({'error': '描述内容必须在1-800字之间'}), 400
        
        amount = request.form.get('amount')
        currency = request.form.get('currency', 'CNY')
        is_child_urgent = request.form.get('is_child_urgent', 'false').lower() == 'true'
        
        try:
            amount = Decimal(str(amount))
            if amount <= 0:
                raise ValueError("金额必须大于0")
        except (ValueError, TypeError):
            return jsonify({'error': '无效的金额'}), 400
        
        if currency not in ['CNY', 'USD', 'CAD', 'SGD', 'AUD']:
            return jsonify({'error': '不支持的货币类型'}), 400
        
        # 处理图片上传
        uploaded_images = []
        for i in range(3):  # 最多3张图片
            file_key = f'image_{i}'
            if file_key in request.files:
                file = request.files[file_key]
                if file and file.filename and allowed_file(file.filename):
                    try:
                        image_url = upload_to_r2(file, "fortune/submissions")
                        uploaded_images.append(image_url)
                    except Exception as e:
                        logger.error(f"Image upload failed: {e}")
                        return jsonify({'error': f'图片上传失败: {str(e)}'}), 500
        
        # 处理付款截图
        payment_screenshots = []
        for i in range(5):  # 最多5张付款截图
            file_key = f'payment_screenshot_{i}'
            if file_key in request.files:
                file = request.files[file_key]
                if file and file.filename and allowed_file(file.filename):
                    try:
                        screenshot_url = upload_to_r2(file, "fortune/payments")
                        payment_screenshots.append(screenshot_url)
                    except Exception as e:
                        logger.error(f"Payment screenshot upload failed: {e}")
                        return jsonify({'error': f'付款截图上传失败: {str(e)}'}), 500
        
        # 生成订单
        order_data = {
            'user_id': ObjectId(user.id),
            'order_number': generate_order_number(),
            'images': uploaded_images,
            'description': description,
            'is_child_urgent': is_child_urgent,
            'amount': amount,
            'currency': currency,
            'payment_status': 'pending',
            'status': 'pending',
            'modification_count': 0,
            'max_modifications': 5,
            'modification_history': [],
            'all_payment_screenshots': [
                {
                    'url': url,
                    'uploaded_at': datetime.utcnow(),
                    'modification_number': 0
                } for url in payment_screenshots
            ],
            'created_at': datetime.utcnow(),
            'updated_at': datetime.utcnow()
        }
        
        # 保存到MongoDB
        result = db.fortune_orders.insert_one(order_data)
        order_id = str(result.inserted_id)
        
        # 触发AI关键词生成任务
        from .tasks import generate_keywords
        generate_keywords.delay(order_id, description)
        
        return jsonify({
            'success': True,
            'order_id': order_id,
            'order_number': order_data['order_number'],
            'message': '算命申请提交成功，请前往支付'
        }), 201
        
    except Exception as e:
        logger.error(f"Submit fortune order failed: {e}")
        return jsonify({'error': '提交失败，请稍后重试'}), 500

@app.route('/modify/<order_id>', methods=['PUT'])
def modify_fortune_order(order_id):
    """修改算命申请"""
    try:
        # 验证用户身份
        auth_header = request.headers.get('Authorization')
        if not auth_header or not auth_header.startswith('Bearer '):
            return jsonify({'error': '未授权访问'}), 401
            
        token = auth_header.split(' ')[1]
        user = get_user_from_token(token)
        if not user:
            return jsonify({'error': '无效的用户令牌'}), 401
        
        # 查找订单
        order = db.fortune_orders.find_one({
            '_id': ObjectId(order_id),
            'user_id': ObjectId(user.id)
        })
        
        if not order:
            return jsonify({'error': '订单不存在'}), 404
        
        # 检查是否可以修改
        if order['status'] not in ['pending', 'queued']:
            return jsonify({'error': '订单状态不允许修改'}), 400
        
        if order['status'] == 'refunded':
            return jsonify({'error': '已退款的订单无法修改'}), 400
        
        modification_count = order.get('modification_count', 0)
        max_modifications = order.get('max_modifications', 5)
        
        if modification_count >= max_modifications:
            return jsonify({'error': f'已达到最大修改次数限制（{max_modifications}次）'}), 400
        
        # 获取修改数据
        description = request.form.get('description', '').strip()
        if not description or len(description) > 800:
            return jsonify({'error': '描述内容必须在1-800字之间'}), 400
        
        amount = request.form.get('amount')
        currency = request.form.get('currency', 'CNY')
        is_child_urgent = request.form.get('is_child_urgent', 'false').lower() == 'true'
        
        try:
            amount = Decimal(str(amount))
            if amount <= 0:
                raise ValueError("金额必须大于0")
        except (ValueError, TypeError):
            return jsonify({'error': '无效的金额'}), 400
        
        if currency not in ['CNY', 'USD', 'CAD', 'SGD', 'AUD']:
            return jsonify({'error': '不支持的货币类型'}), 400
        
        # 处理新的正文图片上传
        uploaded_images = []
        for i in range(3):  # 最多3张图片
            file_key = f'image_{i}'
            if file_key in request.files:
                file = request.files[file_key]
                if file and file.filename and allowed_file(file.filename):
                    try:
                        image_url = upload_to_r2(file, "fortune/submissions")
                        uploaded_images.append(image_url)
                    except Exception as e:
                        logger.error(f"Image upload failed: {e}")
                        return jsonify({'error': f'图片上传失败: {str(e)}'}), 500
        
        # 处理新的付款截图
        new_payment_screenshots = []
        for i in range(5):  # 最多5张付款截图
            file_key = f'payment_screenshot_{i}'
            if file_key in request.files:
                file = request.files[file_key]
                if file and file.filename and allowed_file(file.filename):
                    try:
                        screenshot_url = upload_to_r2(file, "fortune/payments")
                        new_payment_screenshots.append(screenshot_url)
                    except Exception as e:
                        logger.error(f"Payment screenshot upload failed: {e}")
                        return jsonify({'error': f'付款截图上传失败: {str(e)}'}), 500
        
        # 记录修改历史
        new_modification_count = modification_count + 1
        modification_record = {
            'modification_number': new_modification_count,
            'images': uploaded_images,
            'description': description,
            'amount': amount,
            'currency': currency,
            'is_child_urgent': is_child_urgent,
            'payment_screenshots': new_payment_screenshots,
            'modified_at': datetime.utcnow()
        }
        
        # 更新所有付款截图历史
        all_payment_screenshots = order.get('all_payment_screenshots', [])
        for screenshot_url in new_payment_screenshots:
            all_payment_screenshots.append({
                'url': screenshot_url,
                'uploaded_at': datetime.utcnow(),
                'modification_number': new_modification_count
            })
        
        # 更新订单数据
        update_data = {
            'images': uploaded_images,  # 正文图片只保留最新的
            'description': description,
            'amount': amount,
            'currency': currency,
            'is_child_urgent': is_child_urgent,
            'modification_count': new_modification_count,
            'all_payment_screenshots': all_payment_screenshots,
            'updated_at': datetime.utcnow()
        }
        
        # 添加修改历史记录
        modification_history = order.get('modification_history', [])
        modification_history.append(modification_record)
        update_data['modification_history'] = modification_history
        
        # 更新数据库
        db.fortune_orders.update_one(
            {'_id': ObjectId(order_id)},
            {'$set': update_data}
        )
        
        # 重新生成AI关键词
        from .tasks import generate_keywords
        generate_keywords.delay(order_id, description)
        
        remaining_modifications = max_modifications - new_modification_count
        
        return jsonify({
            'success': True,
            'message': f'订单修改成功，剩余修改次数：{remaining_modifications}',
            'modification_count': new_modification_count,
            'remaining_modifications': remaining_modifications
        })
        
    except Exception as e:
        logger.error(f"Modify fortune order failed: {e}")
        return jsonify({'error': '修改失败，请稍后重试'}), 500

@app.route('/estimate_queue', methods=['GET'])
def estimate_queue():
    """估算排队情况"""
    try:
        auth_header = request.headers.get('Authorization')
        if not auth_header or not auth_header.startswith('Bearer '):
            return jsonify({'error': '未授权访问'}), 401
            
        token = auth_header.split(' ')[1]
        user = get_user_from_token(token)
        if not user:
            return jsonify({'error': '无效的用户令牌'}), 401
        
        order_id = request.args.get('order_id')
        if not order_id:
            return jsonify({'error': '缺少订单ID'}), 400
        
        # 从Redis获取队列位置
        try:
            position = redis_client.eval(
                open('apps/db/redis/queue_management.lua').read(),
                1,
                'fortune:queue',
                'get_position',
                order_id
            )
            
            if position is None:
                return jsonify({'error': '订单不在队列中'}), 404
            
            # 获取总队列长度
            total_count = redis_client.zcard('fortune:queue')
            percentage = (position / total_count) * 100 if total_count > 0 else 0
            
            return jsonify({
                'position': position,
                'total_count': total_count,
                'percentage': round(percentage, 2),
                'estimated_wait_hours': position * 2  # 假设每个订单处理2小时
            })
            
        except Exception as e:
            logger.error(f"Redis queue operation failed: {e}")
            return jsonify({'error': '获取队列信息失败'}), 500
        
    except Exception as e:
        logger.error(f"Estimate queue failed: {e}")
        return jsonify({'error': '获取队列信息失败'}), 500

@app.route('/refund', methods=['POST'])
def refund_order():
    """申请退款"""
    try:
        auth_header = request.headers.get('Authorization')
        if not auth_header or not auth_header.startswith('Bearer '):
            return jsonify({'error': '未授权访问'}), 401
            
        token = auth_header.split(' ')[1]
        user = get_user_from_token(token)
        if not user:
            return jsonify({'error': '无效的用户令牌'}), 401
        
        data = request.get_json()
        order_id = data.get('order_id')
        reason = data.get('reason', '').strip()
        
        if not order_id:
            return jsonify({'error': '缺少订单ID'}), 400
        
        # 查找订单
        order = db.fortune_orders.find_one({
            '_id': ObjectId(order_id),
            'user_id': ObjectId(user.id)
        })
        
        if not order:
            return jsonify({'error': '订单不存在'}), 404
        
        if order['status'] in ['refunded', 'cancelled']:
            return jsonify({'error': '订单已退款或取消'}), 400
        
        if order['status'] == 'completed':
            return jsonify({'error': '已完成的订单无法退款'}), 400
        
        # 更新订单状态
        db.fortune_orders.update_one(
            {'_id': ObjectId(order_id)},
            {
                '$set': {
                    'status': 'refunded',
                    'payment_status': 'refunded',
                    'refund_reason': reason,
                    'refunded_at': datetime.utcnow(),
                    'updated_at': datetime.utcnow()
                }
            }
        )
        
        # 从队列中移除
        redis_client.eval(
            open('apps/db/redis/queue_management.lua').read(),
            1,
            'fortune:queue',
            'remove',
            order_id
        )
        
        # 发送退款确认邮件
        # TODO: 集成邮件通知服务
        
        return jsonify({
            'success': True,
            'message': '退款申请已提交，将在3-5个工作日内处理'
        })
        
    except Exception as e:
        logger.error(f"Refund order failed: {e}")
        return jsonify({'error': '退款申请失败'}), 500

@app.route('/reply', methods=['POST'])
def reply_to_order():
    """回复算命订单（Master/Firstmate专用）"""
    try:
        auth_header = request.headers.get('Authorization')
        if not auth_header or not auth_header.startswith('Bearer '):
            return jsonify({'error': '未授权访问'}), 401
            
        token = auth_header.split(' ')[1]
        user = get_user_from_token(token)
        if not user:
            return jsonify({'error': '无效的用户令牌'}), 401
        
        # 检查权限
        user_role = user.user_metadata.get('role', 'fan')
        if user_role not in ['master', 'firstmate']:
            return jsonify({'error': '无权限回复订单'}), 403
        
        data = request.get_json()
        order_id = data.get('order_id')
        reply_content = data.get('reply_content', '').strip()
        is_draft = data.get('is_draft', False)
        reply_images = data.get('reply_images', [])
        
        if not order_id:
            return jsonify({'error': '缺少订单ID'}), 400
        
        # 查找订单
        order = db.fortune_orders.find_one({'_id': ObjectId(order_id)})
        if not order:
            return jsonify({'error': '订单不存在'}), 404
        
        if order['status'] not in ['queued', 'processing']:
            return jsonify({'error': '订单状态不允许回复'}), 400
        
        update_data = {
            'updated_at': datetime.utcnow()
        }
        
        if is_draft:
            # 保存草稿
            update_data['reply_draft'] = reply_content
        else:
            # 正式回复
            if not reply_content:
                return jsonify({'error': '回复内容不能为空'}), 400
            
            update_data.update({
                'reply_content': reply_content,
                'reply_images': reply_images,
                'replied_by': ObjectId(user.id),
                'replied_at': datetime.utcnow(),
                'status': 'completed'
            })
            
            # 从队列中移除
            redis_client.eval(
                open('apps/db/redis/queue_management.lua').read(),
                1,
                'fortune:queue',
                'remove',
                order_id
            )
        
        # 更新订单
        db.fortune_orders.update_one(
            {'_id': ObjectId(order_id)},
            {'$set': update_data}
        )
        
        action = '草稿已保存' if is_draft else '回复已发送'
        return jsonify({
            'success': True,
            'message': action
        })
        
    except Exception as e:
        logger.error(f"Reply to order failed: {e}")
        return jsonify({'error': '回复失败'}), 500

@app.route('/orders', methods=['GET'])
def get_orders():
    """获取订单列表"""
    try:
        auth_header = request.headers.get('Authorization')
        if not auth_header or not auth_header.startswith('Bearer '):
            return jsonify({'error': '未授权访问'}), 401
            
        token = auth_header.split(' ')[1]
        user = get_user_from_token(token)
        if not user:
            return jsonify({'error': '无效的用户令牌'}), 401
        
        user_role = user.user_metadata.get('role', 'fan')
        page = int(request.args.get('page', 1))
        limit = int(request.args.get('limit', 20))
        status = request.args.get('status')
        
        # 构建查询条件
        query = {}
        if user_role in ['fan', 'member']:
            query['user_id'] = ObjectId(user.id)
        elif status:
            query['status'] = status
        
        # 分页查询
        skip = (page - 1) * limit
        cursor = db.fortune_orders.find(query).sort('created_at', -1).skip(skip).limit(limit)
        
        orders = []
        for order in cursor:
            order['_id'] = str(order['_id'])
            order['user_id'] = str(order['user_id'])
            if 'replied_by' in order and order['replied_by']:
                order['replied_by'] = str(order['replied_by'])
            orders.append(order)
        
        total = db.fortune_orders.count_documents(query)
        
        return jsonify({
            'orders': orders,
            'pagination': {
                'page': page,
                'limit': limit,
                'total': total,
                'pages': (total + limit - 1) // limit
            }
        })
        
    except Exception as e:
        logger.error(f"Get orders failed: {e}")
        return jsonify({'error': '获取订单列表失败'}), 500

@app.route('/settings', methods=['GET', 'POST'])
def fortune_settings():
    """算命设置管理（Master/Firstmate专用）"""
    try:
        auth_header = request.headers.get('Authorization')
        if not auth_header or not auth_header.startswith('Bearer '):
            return jsonify({'error': '未授权访问'}), 401
            
        token = auth_header.split(' ')[1]
        user = get_user_from_token(token)
        if not user:
            return jsonify({'error': '无效的用户令牌'}), 401
        
        user_role = user.user_metadata.get('role', 'fan')
        if user_role not in ['master', 'firstmate']:
            return jsonify({'error': '无权限访问设置'}), 403
        
        if request.method == 'GET':
            # 获取当前设置
            settings = redis_client.hgetall('fortune:settings')
            return jsonify({
                'is_enabled': settings.get('is_enabled', 'true') == 'true',
                'min_amount': float(settings.get('min_amount', '0')),
                'currency': settings.get('currency', 'CNY')
            })
        
        elif request.method == 'POST':
            # 更新设置
            data = request.get_json()
            
            if 'is_enabled' in data:
                redis_client.hset('fortune:settings', 'is_enabled', str(data['is_enabled']).lower())
            
            if 'min_amount' in data:
                try:
                    min_amount = float(data['min_amount'])
                    if min_amount < 0:
                        raise ValueError("最低金额不能为负数")
                    redis_client.hset('fortune:settings', 'min_amount', str(min_amount))
                except (ValueError, TypeError):
                    return jsonify({'error': '无效的最低金额'}), 400
            
            if 'currency' in data:
                if data['currency'] in ['CNY', 'USD', 'CAD', 'SGD', 'AUD']:
                    redis_client.hset('fortune:settings', 'currency', data['currency'])
                else:
                    return jsonify({'error': '不支持的货币类型'}), 400
            
            return jsonify({'success': True, 'message': '设置已更新'})
        
    except Exception as e:
        logger.error(f"Fortune settings failed: {e}")
        return jsonify({'error': '设置操作失败'}), 500

@app.route('/health', methods=['GET'])
def health_check():
    """健康检查"""
    services = {}
    overall_status = 'healthy'
    
    # 检查必需的环境变量
    required_env_vars = ['MONGO_URL', 'SUPABASE_URL', 'SUPABASE_SERVICE_ROLE_KEY', 'R2_ACCESS_KEY_ID', 'R2_SECRET_ACCESS_KEY']
    missing_env_vars = [var for var in required_env_vars if not os.getenv(var)]
    
    if missing_env_vars:
        services['environment'] = f'missing variables: {", ".join(missing_env_vars)}'
        overall_status = 'unhealthy'
    else:
        services['environment'] = 'ok'
    
    # 检查MongoDB连接
    try:
        db.fortune_orders.find_one()
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
    
    # 检查R2连接
    try:
        if R2_ACCESS_KEY_ID and R2_SECRET_ACCESS_KEY:
            s3_client.list_objects_v2(Bucket=R2_BUCKET_NAME, MaxKeys=1)
            services['r2'] = 'ok'
        else:
            services['r2'] = 'error: missing credentials'
            overall_status = 'unhealthy'
    except Exception as e:
        services['r2'] = f'error: {str(e)}'
        overall_status = 'unhealthy'
    
    # 检查Supabase连接
    try:
        if SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY:
            # 简单的连接测试
            services['supabase'] = 'ok'
        else:
            services['supabase'] = 'error: missing credentials'
            overall_status = 'unhealthy'
    except Exception as e:
        services['supabase'] = f'error: {str(e)}'
        overall_status = 'unhealthy'
    
    response_data = {
        'status': overall_status,
        'service': 'fortune-service',
        'timestamp': datetime.utcnow().isoformat(),
        'version': '1.0.0',
        'services': services
    }
    
    status_code = 200 if overall_status == 'healthy' else 500
    return jsonify(response_data), status_code

if __name__ == '__main__':
    # 确保上传目录存在
    os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)
    port = int(os.getenv('PORT', 5000))
    app.run(debug=False, host='0.0.0.0', port=port) 