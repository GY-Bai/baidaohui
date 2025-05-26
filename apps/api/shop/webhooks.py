"""
PrestaShop 管理 Webhook 服务
处理商品变动、订单更新、卖家注册等事件
"""

from flask import Flask, request, jsonify, current_app
from flask_cors import CORS
import boto3
import pymongo
import redis
import requests
import hashlib
import hmac
import json
import logging
import os
from datetime import datetime
from bson import ObjectId
from typing import Dict, Any, Optional
import re
from urllib.parse import urlparse

# 配置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)

# 配置
R2_ACCOUNT_ID = os.getenv("R2_ACCOUNT_ID", "25dea0f8748cc0d718d11a64983b4123")
R2_BUCKET_NAME = os.getenv("R2_BUCKET_NAME", "baidaohui-assets")
R2_ACCESS_KEY_ID = os.getenv("R2_ACCESS_KEY_ID")
R2_SECRET_ACCESS_KEY = os.getenv("R2_SECRET_ACCESS_KEY")
S3_ENDPOINT = os.getenv("S3_ENDPOINT", "https://25dea0f8748cc0d718d11a64983b4123.r2.cloudflarestorage.com")

MONGO_URL = os.getenv("MONGO_URL")
REDIS_URL = os.getenv("REDIS_URL", "redis://redis:6379/0")

# PrestaShop 配置
PRESTASHOP_BASE_URL = "https://buyer.shop.baidaohui.com"
PRESTASHOP_API_KEY = os.getenv("PRESTASHOP_API_KEY", "YOUR_PRESTASHOP_API_KEY")
WEBHOOK_SECRET = os.getenv("WEBHOOK_SECRET", "YOUR_WEBHOOK_SECRET")

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
    
    # Redis 客户端
    redis_client = redis.from_url(REDIS_URL, decode_responses=True)
    
    return s3_client, db, redis_client

s3_client, db, redis_client = init_clients()

def verify_webhook_signature(payload: bytes, signature: str) -> bool:
    """验证webhook签名"""
    try:
        expected_signature = hmac.new(
            WEBHOOK_SECRET.encode('utf-8'),
            payload,
            hashlib.sha256
        ).hexdigest()
        
        return hmac.compare_digest(f"sha256={expected_signature}", signature)
    except Exception as e:
        logger.error(f"Webhook signature verification failed: {e}")
        return False

def upload_image_to_r2(image_url: str, folder: str = "shop") -> Optional[str]:
    """将图片从PrestaShop上传到R2"""
    try:
        # 下载图片
        response = requests.get(image_url, timeout=30)
        response.raise_for_status()
        
        # 解析文件名和扩展名
        parsed_url = urlparse(image_url)
        filename = parsed_url.path.split('/')[-1]
        if not filename or '.' not in filename:
            filename = f"image_{datetime.now().strftime('%Y%m%d_%H%M%S')}.jpg"
        
        # 生成R2路径
        r2_key = f"{folder}/{filename}"
        
        # 上传到R2
        s3_client.put_object(
            Bucket=R2_BUCKET_NAME,
            Key=r2_key,
            Body=response.content,
            ContentType=response.headers.get('content-type', 'image/jpeg')
        )
        
        # 返回CDN URL
        cdn_url = f"https://assets.baidaohui.com/{r2_key}"
        logger.info(f"Image uploaded to R2: {image_url} -> {cdn_url}")
        
        return cdn_url
        
    except Exception as e:
        logger.error(f"Failed to upload image to R2: {image_url}, error: {e}")
        return None

def replace_image_urls_in_product(product_data: Dict[str, Any]) -> Dict[str, Any]:
    """替换商品数据中的图片URL为R2链接"""
    try:
        updated_product = product_data.copy()
        
        # 处理主图片
        if 'image' in updated_product and updated_product['image']:
            r2_url = upload_image_to_r2(updated_product['image'], "shop/products")
            if r2_url:
                updated_product['image'] = r2_url
        
        # 处理图片列表
        if 'images' in updated_product and isinstance(updated_product['images'], list):
            updated_images = []
            for img_url in updated_product['images']:
                r2_url = upload_image_to_r2(img_url, "shop/products")
                updated_images.append(r2_url if r2_url else img_url)
            updated_product['images'] = updated_images
        
        # 处理描述中的图片
        if 'description' in updated_product:
            description = updated_product['description']
            # 查找描述中的图片URL
            img_pattern = r'<img[^>]+src=["\']([^"\']+)["\'][^>]*>'
            matches = re.findall(img_pattern, description)
            
            for img_url in matches:
                if img_url.startswith('http'):
                    r2_url = upload_image_to_r2(img_url, "shop/descriptions")
                    if r2_url:
                        description = description.replace(img_url, r2_url)
            
            updated_product['description'] = description
        
        return updated_product
        
    except Exception as e:
        logger.error(f"Failed to replace image URLs: {e}")
        return product_data

def log_shop_event(event_type: str, prestashop_id: int, event_data: Dict[str, Any], user_id: Optional[str] = None):
    """记录商店事件到MongoDB"""
    try:
        event_doc = {
            'event_type': event_type,
            'prestashop_id': prestashop_id,
            'event_data': event_data,
            'user_id': ObjectId(user_id) if user_id else None,
            'processed': False,
            'created_at': datetime.utcnow()
        }
        
        db.shop_events.insert_one(event_doc)
        logger.info(f"Shop event logged: {event_type} for ID {prestashop_id}")
        
    except Exception as e:
        logger.error(f"Failed to log shop event: {e}")

def send_notification(notification_type: str, recipient: str, data: Dict[str, Any]):
    """发送通知到Redis stream"""
    try:
        notification = {
            'type': notification_type,
            'recipient': recipient,
            'data': json.dumps(data),
            'timestamp': datetime.utcnow().isoformat()
        }
        
        redis_client.xadd('notifications', notification)
        logger.info(f"Notification sent: {notification_type} to {recipient}")
        
    except Exception as e:
        logger.error(f"Failed to send notification: {e}")

@app.route('/product/created', methods=['POST'])
def product_created():
    """商品创建webhook"""
    try:
        # 验证签名
        signature = request.headers.get('X-Webhook-Signature')
        if not signature or not verify_webhook_signature(request.data, signature):
            return jsonify({'error': 'Invalid signature'}), 401
        
        data = request.get_json()
        product_id = data.get('id')
        product_data = data.get('product', {})
        
        if not product_id:
            return jsonify({'error': 'Missing product ID'}), 400
        
        # 替换图片URL为R2链接
        updated_product = replace_image_urls_in_product(product_data)
        
        # 更新PrestaShop中的商品信息
        update_prestashop_product(product_id, updated_product)
        
        # 记录事件
        log_shop_event('product_created', product_id, {
            'original_data': product_data,
            'updated_data': updated_product
        })
        
        return jsonify({'success': True, 'message': 'Product created and images migrated'})
        
    except Exception as e:
        logger.error(f"Product created webhook failed: {e}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/product/updated', methods=['POST'])
def product_updated():
    """商品更新webhook"""
    try:
        signature = request.headers.get('X-Webhook-Signature')
        if not signature or not verify_webhook_signature(request.data, signature):
            return jsonify({'error': 'Invalid signature'}), 401
        
        data = request.get_json()
        product_id = data.get('id')
        product_data = data.get('product', {})
        
        if not product_id:
            return jsonify({'error': 'Missing product ID'}), 400
        
        # 替换图片URL为R2链接
        updated_product = replace_image_urls_in_product(product_data)
        
        # 更新PrestaShop中的商品信息
        update_prestashop_product(product_id, updated_product)
        
        # 记录事件
        log_shop_event('product_updated', product_id, {
            'original_data': product_data,
            'updated_data': updated_product
        })
        
        return jsonify({'success': True, 'message': 'Product updated and images migrated'})
        
    except Exception as e:
        logger.error(f"Product updated webhook failed: {e}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/product/deleted', methods=['POST'])
def product_deleted():
    """商品删除webhook"""
    try:
        signature = request.headers.get('X-Webhook-Signature')
        if not signature or not verify_webhook_signature(request.data, signature):
            return jsonify({'error': 'Invalid signature'}), 401
        
        data = request.get_json()
        product_id = data.get('id')
        
        if not product_id:
            return jsonify({'error': 'Missing product ID'}), 400
        
        # 记录事件
        log_shop_event('product_deleted', product_id, data)
        
        return jsonify({'success': True, 'message': 'Product deletion recorded'})
        
    except Exception as e:
        logger.error(f"Product deleted webhook failed: {e}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/order/created', methods=['POST'])
def order_created():
    """订单创建webhook"""
    try:
        signature = request.headers.get('X-Webhook-Signature')
        if not signature or not verify_webhook_signature(request.data, signature):
            return jsonify({'error': 'Invalid signature'}), 401
        
        data = request.get_json()
        order_id = data.get('id')
        order_data = data.get('order', {})
        customer_email = order_data.get('customer_email')
        
        if not order_id:
            return jsonify({'error': 'Missing order ID'}), 400
        
        # 记录事件
        log_shop_event('order_created', order_id, order_data)
        
        # 发送购物通知邮件
        if customer_email:
            send_notification('inform8', customer_email, {
                'shop_order_id': order_id,
                'status_text': '订单已创建',
                'product_name': order_data.get('product_name', '商品'),
                'amount': order_data.get('total_amount', '0'),
                'currency': order_data.get('currency', 'CNY')
            })
        
        return jsonify({'success': True, 'message': 'Order created notification sent'})
        
    except Exception as e:
        logger.error(f"Order created webhook failed: {e}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/order/updated', methods=['POST'])
def order_updated():
    """订单更新webhook"""
    try:
        signature = request.headers.get('X-Webhook-Signature')
        if not signature or not verify_webhook_signature(request.data, signature):
            return jsonify({'error': 'Invalid signature'}), 401
        
        data = request.get_json()
        order_id = data.get('id')
        order_data = data.get('order', {})
        customer_email = order_data.get('customer_email')
        
        if not order_id:
            return jsonify({'error': 'Missing order ID'}), 400
        
        # 记录事件
        log_shop_event('order_updated', order_id, order_data)
        
        # 发送状态更新通知
        if customer_email:
            status_map = {
                'pending': '待处理',
                'processing': '处理中',
                'shipped': '已发货',
                'delivered': '已送达',
                'cancelled': '已取消'
            }
            
            status_text = status_map.get(order_data.get('status', 'unknown'), '状态已更新')
            
            send_notification('inform8', customer_email, {
                'shop_order_id': order_id,
                'status_text': status_text,
                'product_name': order_data.get('product_name', '商品'),
                'amount': order_data.get('total_amount', '0'),
                'currency': order_data.get('currency', 'CNY')
            })
        
        return jsonify({'success': True, 'message': 'Order update notification sent'})
        
    except Exception as e:
        logger.error(f"Order updated webhook failed: {e}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/seller/registered', methods=['POST'])
def seller_registered():
    """卖家注册webhook"""
    try:
        signature = request.headers.get('X-Webhook-Signature')
        if not signature or not verify_webhook_signature(request.data, signature):
            return jsonify({'error': 'Invalid signature'}), 401
        
        data = request.get_json()
        seller_id = data.get('id')
        seller_data = data.get('seller', {})
        
        if not seller_id:
            return jsonify({'error': 'Missing seller ID'}), 400
        
        # 记录事件，等待Manager审批
        log_shop_event('seller_registered', seller_id, seller_data)
        
        # 通知管理员有新的卖家注册
        # 这里可以发送邮件或其他通知给管理员
        
        return jsonify({'success': True, 'message': 'Seller registration recorded, pending approval'})
        
    except Exception as e:
        logger.error(f"Seller registered webhook failed: {e}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/seller/approve', methods=['POST'])
def approve_seller():
    """Manager审批卖家"""
    try:
        data = request.get_json()
        seller_id = data.get('seller_id')
        approved = data.get('approved', False)
        manager_notes = data.get('notes', '')
        
        if not seller_id:
            return jsonify({'error': 'Missing seller ID'}), 400
        
        # 更新PrestaShop中的卖家状态
        success = update_prestashop_seller_status(seller_id, approved)
        
        if success:
            # 记录审批事件
            log_shop_event('seller_approved', seller_id, {
                'approved': approved,
                'manager_notes': manager_notes,
                'approved_at': datetime.utcnow().isoformat()
            })
            
            # 更新MongoDB中的事件状态
            db.shop_events.update_one(
                {
                    'event_type': 'seller_registered',
                    'prestashop_id': seller_id,
                    'processed': False
                },
                {
                    '$set': {
                        'processed': True,
                        'processed_at': datetime.utcnow(),
                        'approval_result': approved
                    }
                }
            )
            
            status_text = '审批通过' if approved else '审批拒绝'
            return jsonify({'success': True, 'message': f'Seller {status_text}'})
        else:
            return jsonify({'error': 'Failed to update seller status'}), 500
        
    except Exception as e:
        logger.error(f"Seller approval failed: {e}")
        return jsonify({'error': 'Internal server error'}), 500

def update_prestashop_product(product_id: int, product_data: Dict[str, Any]) -> bool:
    """更新PrestaShop商品信息"""
    try:
        url = f"{PRESTASHOP_BASE_URL}/api/products/{product_id}"
        headers = {
            'Authorization': f'Basic {PRESTASHOP_API_KEY}:',
            'Content-Type': 'application/json'
        }
        
        # PrestaShop API格式
        prestashop_data = {
            'product': product_data
        }
        
        response = requests.put(url, json=prestashop_data, headers=headers)
        response.raise_for_status()
        
        logger.info(f"PrestaShop product {product_id} updated successfully")
        return True
        
    except Exception as e:
        logger.error(f"Failed to update PrestaShop product {product_id}: {e}")
        return False

def update_prestashop_seller_status(seller_id: int, approved: bool) -> bool:
    """更新PrestaShop卖家状态"""
    try:
        url = f"{PRESTASHOP_BASE_URL}/api/employees/{seller_id}"
        headers = {
            'Authorization': f'Basic {PRESTASHOP_API_KEY}:',
            'Content-Type': 'application/json'
        }
        
        # 更新员工状态
        employee_data = {
            'active': 1 if approved else 0,
            'last_passwd_gen': datetime.utcnow().isoformat()
        }
        
        prestashop_data = {
            'employee': employee_data
        }
        
        response = requests.put(url, json=prestashop_data, headers=headers)
        response.raise_for_status()
        
        logger.info(f"PrestaShop seller {seller_id} status updated: {'approved' if approved else 'rejected'}")
        return True
        
    except Exception as e:
        logger.error(f"Failed to update PrestaShop seller {seller_id}: {e}")
        return False

@app.route('/events', methods=['GET'])
def get_shop_events():
    """获取商店事件列表（管理员用）"""
    try:
        page = int(request.args.get('page', 1))
        limit = int(request.args.get('limit', 20))
        event_type = request.args.get('type')
        processed = request.args.get('processed')
        
        # 构建查询条件
        query = {}
        if event_type:
            query['event_type'] = event_type
        if processed is not None:
            query['processed'] = processed.lower() == 'true'
        
        # 分页查询
        skip = (page - 1) * limit
        cursor = db.shop_events.find(query).sort('created_at', -1).skip(skip).limit(limit)
        
        events = []
        for event in cursor:
            event['_id'] = str(event['_id'])
            if 'user_id' in event and event['user_id']:
                event['user_id'] = str(event['user_id'])
            events.append(event)
        
        total = db.shop_events.count_documents(query)
        
        return jsonify({
            'events': events,
            'pagination': {
                'page': page,
                'limit': limit,
                'total': total,
                'pages': (total + limit - 1) // limit
            }
        })
        
    except Exception as e:
        logger.error(f"Get shop events failed: {e}")
        return jsonify({'error': 'Failed to get events'}), 500

@app.route('/health', methods=['GET'])
def health_check():
    """健康检查"""
    services = {}
    overall_status = 'healthy'
    
    # 检查MongoDB连接
    try:
        db.shop_events.find_one()
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
        s3_client.list_objects_v2(Bucket=R2_BUCKET_NAME, MaxKeys=1)
        services['r2'] = 'ok'
    except Exception as e:
        services['r2'] = f'error: {str(e)}'
        overall_status = 'unhealthy'
    
    response_data = {
        'status': overall_status,
        'timestamp': datetime.utcnow().isoformat(),
        'services': services
    }
    
    status_code = 200 if overall_status == 'healthy' else 500
    return jsonify(response_data), status_code 