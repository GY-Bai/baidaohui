from flask import Flask, request, jsonify
from flask_cors import CORS
import os
import jwt
import pymongo
import redis
import boto3
from datetime import datetime, timedelta
import uuid
import base64
import json
import requests
from werkzeug.utils import secure_filename
import logging
from PIL import Image
import io

app = Flask(__name__)
CORS(app, supports_credentials=True)

# 配置
MONGODB_URI = os.getenv('MONGODB_URI')
REDIS_URL = os.getenv('REDIS_URL', 'redis://localhost:6379')
JWT_SECRET = os.getenv('JWT_SECRET', 'your-secret-key')
R2_ENDPOINT = os.getenv('R2_ENDPOINT')
R2_ACCESS_KEY = os.getenv('R2_ACCESS_KEY')
R2_SECRET_KEY = os.getenv('R2_SECRET_KEY')
R2_BUCKET = os.getenv('R2_BUCKET')
EXCHANGE_API_KEY = os.getenv('EXCHANGE_API_KEY')  # 汇率API密钥

# 初始化数据库连接
mongo_client = pymongo.MongoClient(MONGODB_URI)
db = mongo_client.baidaohui
redis_client = redis.from_url(REDIS_URL)

# 初始化R2客户端
s3_client = boto3.client(
    's3',
    endpoint_url=R2_ENDPOINT,
    aws_access_key_id=R2_ACCESS_KEY,
    aws_secret_access_key=R2_SECRET_KEY,
    region_name='auto'
)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# 汇率缓存键
EXCHANGE_RATE_CACHE_KEY = "exchange_rates"
EXCHANGE_RATE_CACHE_TTL = 7 * 24 * 60 * 60  # 7天

def get_exchange_rates():
    """获取汇率，优先从缓存读取"""
    try:
        # 从Redis缓存获取
        cached_rates = redis_client.get(EXCHANGE_RATE_CACHE_KEY)
        if cached_rates:
            return json.loads(cached_rates)
        
        # 从API获取最新汇率
        response = requests.get(f"https://api.exchangerate-api.com/v4/latest/CAD")
        if response.status_code == 200:
            rates_data = response.json()
            rates = {
                'CAD': 1.0,
                'USD': 1 / rates_data['rates']['USD'],
                'CNY': 1 / rates_data['rates']['CNY'],
                'SGD': 1 / rates_data['rates']['SGD'],
                'AUD': 1 / rates_data['rates']['AUD']
            }
            
            # 缓存汇率
            redis_client.setex(EXCHANGE_RATE_CACHE_KEY, EXCHANGE_RATE_CACHE_TTL, json.dumps(rates))
            return rates
        else:
            # 使用默认汇率
            return {'CAD': 1.0, 'USD': 1.35, 'CNY': 0.18, 'SGD': 1.0, 'AUD': 0.9}
    except Exception as e:
        logger.error(f"获取汇率失败: {str(e)}")
        return {'CAD': 1.0, 'USD': 1.35, 'CNY': 0.18, 'SGD': 1.0, 'AUD': 0.9}

def convert_to_cad(amount, currency):
    """将金额转换为CAD"""
    rates = get_exchange_rates()
    return amount * rates.get(currency, 1.0)

def upload_image_to_r2(image_data, filename):
    """上传图片到R2并生成缩略图"""
    try:
        # 解码base64图片
        image_bytes = base64.b64decode(image_data)
        
        # 验证图片大小（5MB限制）
        if len(image_bytes) > 5 * 1024 * 1024:
            raise ValueError("图片大小超过5MB限制")
        
        # 生成文件名
        file_key = f"fortune/{datetime.now().strftime('%Y/%m/%d')}/{uuid.uuid4()}_{filename}"
        
        # 上传原图
        s3_client.put_object(
            Bucket=R2_BUCKET,
            Key=file_key,
            Body=image_bytes,
            ContentType='image/jpeg'
        )
        
        # 生成缩略图
        image = Image.open(io.BytesIO(image_bytes))
        image.thumbnail((300, 300), Image.Resampling.LANCZOS)
        
        thumbnail_buffer = io.BytesIO()
        image.save(thumbnail_buffer, format='JPEG', quality=85)
        thumbnail_bytes = thumbnail_buffer.getvalue()
        
        # 上传缩略图
        thumbnail_key = f"fortune/thumbnails/{datetime.now().strftime('%Y/%m/%d')}/{uuid.uuid4()}_{filename}"
        s3_client.put_object(
            Bucket=R2_BUCKET,
            Key=thumbnail_key,
            Body=thumbnail_bytes,
            ContentType='image/jpeg'
        )
        
        return {
            'original_url': f"{R2_ENDPOINT}/{R2_BUCKET}/{file_key}",
            'thumbnail_url': f"{R2_ENDPOINT}/{R2_BUCKET}/{thumbnail_key}",
            'filename': filename
        }
    except Exception as e:
        logger.error(f"上传图片失败: {str(e)}")
        raise

def verify_token():
    """验证JWT Token"""
    token = request.cookies.get('access_token')
    if not token:
        auth_header = request.headers.get('Authorization')
        if auth_header and auth_header.startswith('Bearer '):
            token = auth_header.split(' ')[1]
    
    if not token:
        return None
    
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=['HS256'])
        return payload
    except jwt.InvalidTokenError:
        return None

@app.route('/health')
def health():
    return jsonify({'status': 'healthy', 'service': 'fortune-service'})

@app.route('/fortune/apply', methods=['POST'])
def apply_fortune():
    """提交算命申请"""
    try:
        # 验证用户身份
        user_payload = verify_token()
        if not user_payload:
            return jsonify({'error': '未登录'}), 401
        
        user_id = user_payload['sub']
        data = request.get_json()
        
        # 验证必填字段
        required_fields = ['images', 'message', 'amount', 'currency']
        for field in required_fields:
            if field not in data:
                return jsonify({'error': f'缺少必填字段: {field}'}), 400
        
        images = data['images']
        message = data['message'].strip()
        amount = float(data['amount'])
        currency = data['currency']
        kids_emergency = data.get('kidsEmergency', False)
        
        # 验证数据
        if len(images) > 3:
            return jsonify({'error': '最多只能上传3张图片'}), 400
        
        if len(message) > 800:
            return jsonify({'error': '附言不能超过800字'}), 400
        
        if currency not in ['CNY', 'USD', 'CAD', 'SGD', 'AUD']:
            return jsonify({'error': '不支持的币种'}), 400
        
        if amount <= 0:
            return jsonify({'error': '金额必须大于0'}), 400
        
        # 上传图片
        uploaded_images = []
        for i, image_data in enumerate(images):
            try:
                filename = f"image_{i+1}.jpg"
                image_info = upload_image_to_r2(image_data, filename)
                uploaded_images.append(image_info)
            except Exception as e:
                return jsonify({'error': f'图片上传失败: {str(e)}'}), 400
        
        # 转换金额为CAD
        converted_amount_cad = convert_to_cad(amount, currency)
        
        # 创建申请记录
        application = {
            'user_id': user_id,
            'images': uploaded_images,
            'message': message,
            'amount': amount,
            'currency': currency,
            'converted_amount_cad': converted_amount_cad,
            'kids_emergency': kids_emergency,
            'status': 'Pending',
            'modifications': [],
            'remaining_modifications': 5,
            'created_at': datetime.utcnow(),
            'updated_at': datetime.utcnow(),
            'queue_index': None,
            'priority': 1 if kids_emergency else 0
        }
        
        result = db.fortune_applications.insert_one(application)
        order_id = str(result.inserted_id)
        
        # 触发队列更新（异步）
        update_queue_indexes.delay()
        
        logger.info(f"用户 {user_id} 提交算命申请: {order_id}")
        
        return jsonify({
            'success': True,
            'order_id': order_id,
            'status': 'Pending'
        })
        
    except Exception as e:
        logger.error(f"提交算命申请失败: {str(e)}")
        return jsonify({'error': '提交申请失败'}), 500

@app.route('/fortune/list')
def list_fortune_applications():
    """获取算命申请列表"""
    try:
        user_payload = verify_token()
        if not user_payload:
            return jsonify({'error': '未登录'}), 401
        
        user_id = user_payload['sub']
        user_role = user_payload['role']
        
        page = int(request.args.get('page', 1))
        limit = int(request.args.get('limit', 20))
        status_filter = request.args.get('status')
        
        # 构建查询条件
        query = {}
        if user_role in ['Fan', 'Member']:
            query['user_id'] = user_id
        
        if status_filter:
            query['status'] = status_filter
        
        # 排序：紧急度优先，然后按CAD金额降序
        sort_criteria = [('priority', -1), ('converted_amount_cad', -1), ('created_at', 1)]
        
        # 分页查询
        skip = (page - 1) * limit
        applications = db.fortune_applications.find(query).sort(sort_criteria).skip(skip).limit(limit)
        total = db.fortune_applications.count_documents(query)
        
        result_list = []
        for app in applications:
            result_list.append({
                'id': str(app['_id']),
                'user_id': app['user_id'],
                'message': app['message'],
                'amount': app['amount'],
                'currency': app['currency'],
                'converted_amount_cad': app['converted_amount_cad'],
                'kids_emergency': app['kids_emergency'],
                'status': app['status'],
                'remaining_modifications': app.get('remaining_modifications', 5),
                'queue_index': app.get('queue_index'),
                'priority': app['priority'],
                'created_at': app['created_at'].isoformat(),
                'updated_at': app['updated_at'].isoformat(),
                'images': app['images']
            })
        
        return jsonify({
            'applications': result_list,
            'total': total,
            'page': page,
            'limit': limit,
            'total_pages': (total + limit - 1) // limit
        })
        
    except Exception as e:
        logger.error(f"获取申请列表失败: {str(e)}")
        return jsonify({'error': '获取列表失败'}), 500

@app.route('/fortune/modify', methods=['POST'])
def modify_fortune_application():
    """修改算命申请"""
    try:
        user_payload = verify_token()
        if not user_payload:
            return jsonify({'error': '未登录'}), 401
        
        user_id = user_payload['sub']
        data = request.get_json()
        
        order_id = data.get('order_id')
        new_message = data.get('message', '').strip()
        new_images = data.get('images', [])
        
        if not order_id:
            return jsonify({'error': '缺少order_id'}), 400
        
        # 查找申请
        application = db.fortune_applications.find_one({
            '_id': pymongo.ObjectId(order_id),
            'user_id': user_id
        })
        
        if not application:
            return jsonify({'error': '申请不存在'}), 404
        
        # 检查状态和修改次数
        if application['status'] not in ['Pending', 'Queued-payed', 'Queued-upload']:
            return jsonify({'error': '当前状态不允许修改'}), 400
        
        if len(application.get('modifications', [])) >= 5:
            return jsonify({'error': '修改次数已用完'}), 400
        
        # 验证新数据
        if len(new_message) > 800:
            return jsonify({'error': '附言不能超过800字'}), 400
        
        if len(new_images) > 3:
            return jsonify({'error': '最多只能上传3张图片'}), 400
        
        # 上传新图片
        uploaded_images = []
        if new_images:
            for i, image_data in enumerate(new_images):
                try:
                    filename = f"modified_image_{i+1}.jpg"
                    image_info = upload_image_to_r2(image_data, filename)
                    uploaded_images.append(image_info)
                except Exception as e:
                    return jsonify({'error': f'图片上传失败: {str(e)}'}), 400
        
        # 记录修改历史
        modification = {
            'timestamp': datetime.utcnow(),
            'old_message': application['message'],
            'new_message': new_message,
            'old_images': application['images'],
            'new_images': uploaded_images if uploaded_images else application['images']
        }
        
        # 更新申请
        update_data = {
            '$push': {'modifications': modification},
            '$set': {
                'message': new_message,
                'updated_at': datetime.utcnow(),
                'remaining_modifications': 5 - len(application.get('modifications', [])) - 1
            }
        }
        
        if uploaded_images:
            update_data['$set']['images'] = uploaded_images
        
        db.fortune_applications.update_one(
            {'_id': pymongo.ObjectId(order_id)},
            update_data
        )
        
        logger.info(f"用户 {user_id} 修改申请: {order_id}")
        
        return jsonify({'success': True, 'message': '修改成功'})
        
    except Exception as e:
        logger.error(f"修改申请失败: {str(e)}")
        return jsonify({'error': '修改失败'}), 500

@app.route('/fortune/reply', methods=['POST'])
def reply_fortune_application():
    """Master/Firstmate回复算命申请"""
    try:
        user_payload = verify_token()
        if not user_payload:
            return jsonify({'error': '未登录'}), 401
        
        user_role = user_payload['role']
        if user_role not in ['Master', 'Firstmate']:
            return jsonify({'error': '无权限'}), 403
        
        user_id = user_payload['sub']
        data = request.get_json()
        
        order_id = data.get('order_id')
        reply_content = data.get('reply_content', '').strip()
        reply_images = data.get('reply_images', [])
        is_draft = data.get('draft', False)
        
        if not order_id or not reply_content:
            return jsonify({'error': '缺少必填字段'}), 400
        
        # 查找申请
        application = db.fortune_applications.find_one({'_id': pymongo.ObjectId(order_id)})
        if not application:
            return jsonify({'error': '申请不存在'}), 404
        
        if is_draft:
            # 保存草稿到Redis
            draft_key = f"draft:{order_id}:{user_id}"
            draft_data = {
                'content': reply_content,
                'images': reply_images,
                'updated_at': datetime.utcnow().isoformat()
            }
            redis_client.setex(draft_key, 24 * 60 * 60, json.dumps(draft_data))  # 24小时过期
            
            return jsonify({'success': True, 'message': '草稿已保存'})
        else:
            # 正式发布回复
            # 上传回复图片
            uploaded_reply_images = []
            if reply_images:
                for i, image_data in enumerate(reply_images):
                    try:
                        filename = f"reply_image_{i+1}.jpg"
                        image_info = upload_image_to_r2(image_data, filename)
                        uploaded_reply_images.append(image_info)
                    except Exception as e:
                        return jsonify({'error': f'图片上传失败: {str(e)}'}), 400
            
            # 更新申请状态
            reply_data = {
                'content': reply_content,
                'images': uploaded_reply_images,
                'replier_id': user_id,
                'replier_role': user_role,
                'replied_at': datetime.utcnow()
            }
            
            db.fortune_applications.update_one(
                {'_id': pymongo.ObjectId(order_id)},
                {
                    '$set': {
                        'status': 'Completed',
                        'reply': reply_data,
                        'updated_at': datetime.utcnow()
                    }
                }
            )
            
            # 删除草稿
            draft_key = f"draft:{order_id}:{user_id}"
            redis_client.delete(draft_key)
            
            # 触发邮件通知（这里可以发送到消息队列）
            # send_email_notification.delay(application['user_id'], 'fortune_reply', order_id)
            
            logger.info(f"{user_role} {user_id} 回复申请: {order_id}")
            
            return jsonify({'success': True, 'message': '回复已发布'})
        
    except Exception as e:
        logger.error(f"回复申请失败: {str(e)}")
        return jsonify({'error': '回复失败'}), 500

@app.route('/fortune/percentile')
def get_queue_percentile():
    """测试排队位置"""
    try:
        user_payload = verify_token()
        if not user_payload:
            return jsonify({'error': '未登录'}), 401
        
        user_id = user_payload['sub']
        amount = float(request.args.get('amount', 0))
        currency = request.args.get('currency', 'CAD')
        
        # 检查测试次数限制
        test_key = f"percentile_test:{user_id}"
        test_count = redis_client.get(test_key)
        if test_count and int(test_count) >= 15:
            return jsonify({'error': '测试次数已用完，请稍后再试'}), 429
        
        # 增加测试次数
        redis_client.incr(test_key)
        redis_client.expire(test_key, 3600)  # 1小时过期
        
        # 转换为CAD
        converted_amount = convert_to_cad(amount, currency)
        
        # 计算排队位置
        # 紧急订单数量
        emergency_count = db.fortune_applications.count_documents({
            'status': {'$in': ['Pending', 'Queued-payed', 'Queued-upload']},
            'kids_emergency': True
        })
        
        # 比当前金额高的非紧急订单数量
        higher_amount_count = db.fortune_applications.count_documents({
            'status': {'$in': ['Pending', 'Queued-payed', 'Queued-upload']},
            'kids_emergency': False,
            'converted_amount_cad': {'$gt': converted_amount}
        })
        
        # 总队列长度
        total_queue = db.fortune_applications.count_documents({
            'status': {'$in': ['Pending', 'Queued-payed', 'Queued-upload']}
        })
        
        # 计算位置（紧急订单 + 高金额订单 + 1）
        position = emergency_count + higher_amount_count + 1
        
        # 计算百分比
        if total_queue > 0:
            percentile = (position / (total_queue + 1)) * 100
        else:
            percentile = 0
        
        return jsonify({
            'percentile': round(percentile, 1),
            'position': position,
            'total_queue': total_queue + 1
        })
        
    except Exception as e:
        logger.error(f"计算排队位置失败: {str(e)}")
        return jsonify({'error': '计算失败'}), 500

@app.route('/fortune/update-status', methods=['POST'])
def update_payment_status():
    """更新支付状态（内部接口）"""
    try:
        data = request.get_json()
        order_id = data.get('order_id')
        status = data.get('status')
        
        if not order_id or not status:
            return jsonify({'error': '缺少必填字段'}), 400
        
        # 验证订单存在且状态为Pending
        application = db.fortune_applications.find_one({
            '_id': pymongo.ObjectId(order_id),
            'status': 'Pending'
        })
        
        if not application:
            return jsonify({'error': '订单不存在或状态不正确'}), 404
        
        # 更新状态
        db.fortune_applications.update_one(
            {'_id': pymongo.ObjectId(order_id)},
            {
                '$set': {
                    'status': status,
                    'updated_at': datetime.utcnow()
                }
            }
        )
        
        # 触发WebSocket通知（如果需要）
        # socketio.emit('status_update', {'order_id': order_id, 'status': status})
        
        logger.info(f"订单 {order_id} 状态更新为: {status}")
        
        return jsonify({'success': True})
        
    except Exception as e:
        logger.error(f"更新支付状态失败: {str(e)}")
        return jsonify({'error': '更新失败'}), 500

@app.route('/fortune/upload', methods=['POST'])
def upload_payment_proof():
    """上传支付凭证"""
    try:
        user_payload = verify_token()
        if not user_payload:
            return jsonify({'error': '未登录'}), 401
        
        user_id = user_payload['sub']
        data = request.get_json()
        
        order_id = data.get('order_id')
        screenshots = data.get('screenshots', [])
        
        if not order_id or not screenshots:
            return jsonify({'error': '缺少必填字段'}), 400
        
        if len(screenshots) > 3:
            return jsonify({'error': '最多只能上传3张截图'}), 400
        
        # 验证订单
        application = db.fortune_applications.find_one({
            '_id': pymongo.ObjectId(order_id),
            'user_id': user_id,
            'status': 'Pending'
        })
        
        if not application:
            return jsonify({'error': '订单不存在或状态不正确'}), 404
        
        # 上传截图
        uploaded_screenshots = []
        for i, screenshot_data in enumerate(screenshots):
            try:
                filename = f"payment_proof_{i+1}.jpg"
                image_info = upload_image_to_r2(screenshot_data, filename)
                uploaded_screenshots.append(image_info)
            except Exception as e:
                return jsonify({'error': f'截图上传失败: {str(e)}'}), 400
        
        # 更新订单状态
        db.fortune_applications.update_one(
            {'_id': pymongo.ObjectId(order_id)},
            {
                '$set': {
                    'status': 'Queued-upload',
                    'payment_screenshots': uploaded_screenshots,
                    'updated_at': datetime.utcnow()
                }
            }
        )
        
        logger.info(f"用户 {user_id} 上传支付凭证: {order_id}")
        
        return jsonify({'success': True, 'message': '凭证上传成功'})
        
    except Exception as e:
        logger.error(f"上传支付凭证失败: {str(e)}")
        return jsonify({'error': '上传失败'}), 500

# 定时任务：更新队列索引（这里使用简单的函数，实际应该用Celery等任务队列）
def update_queue_indexes():
    """更新队列索引（每2小时执行一次）"""
    try:
        # 按优先级和金额排序获取所有待处理申请
        applications = db.fortune_applications.find({
            'status': {'$in': ['Pending', 'Queued-payed', 'Queued-upload']}
        }).sort([('priority', -1), ('converted_amount_cad', -1), ('created_at', 1)])
        
        # 更新队列索引
        for index, app in enumerate(applications, 1):
            db.fortune_applications.update_one(
                {'_id': app['_id']},
                {'$set': {'queue_index': index}}
            )
        
        logger.info(f"队列索引更新完成，共 {index} 个申请")
        
    except Exception as e:
        logger.error(f"更新队列索引失败: {str(e)}")

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5003, debug=True) 