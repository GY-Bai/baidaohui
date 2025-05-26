"""
SSO Token 适配层
Supabase JWT → PrestaShop customer token 交换服务
"""

from flask import Flask, request, jsonify, current_app
from flask_cors import CORS
import jwt
import requests
import hashlib
import hmac
import time
import json
import logging
from datetime import datetime, timedelta
from supabase import create_client, Client
import redis
from typing import Optional, Dict, Any
import os

# 配置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)

# 配置
SUPABASE_URL = "https://pvjowkjksutkhpsomwvv.supabase.co"
SUPABASE_SERVICE_ROLE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB2am93a2prc3V0a2hwc29td3Z2Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0Nzg3NjEzMSwiZXhwIjoyMDYzNDUyMTMxfQ.d3wCJvfVVAA-YrMhkZNY85YzqfU1jyFwwtv_DrRbDfI"

# PrestaShop 配置
PRESTASHOP_BASE_URL = "https://buyer.shop.baidaohui.com"
PRESTASHOP_API_KEY = "YOUR_PRESTASHOP_API_KEY"  # 需要配置
PRESTASHOP_SECRET = "YOUR_PRESTASHOP_SECRET"    # 需要配置

# 初始化客户端
supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

# Redis配置 - 支持环境变量
REDIS_URL = os.getenv('REDIS_URL', 'redis://redis:6379/0')  # 使用Docker内部通信
REDIS_HOST = os.getenv('REDIS_HOST', 'redis')
REDIS_PORT = int(os.getenv('REDIS_PORT', '6379'))  # 使用标准Redis端口
redis_client = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, db=0, decode_responses=True)

class TokenExchangeError(Exception):
    """Token交换异常"""
    pass

def verify_supabase_token(token: str) -> Optional[Dict[str, Any]]:
    """验证Supabase JWT token"""
    try:
        # 使用Supabase客户端验证token
        user = supabase.auth.get_user(token)
        if user and user.user:
            return {
                'id': user.user.id,
                'email': user.user.email,
                'role': user.user.user_metadata.get('role', 'fan'),
                'metadata': user.user.user_metadata
            }
        return None
    except Exception as e:
        logger.error(f"Supabase token verification failed: {e}")
        return None

def get_or_create_prestashop_customer(user_data: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    """获取或创建PrestaShop客户"""
    try:
        email = user_data['email']
        
        # 首先尝试查找现有客户
        customer = find_prestashop_customer_by_email(email)
        
        if customer:
            logger.info(f"Found existing PrestaShop customer: {customer['id']}")
            return customer
        
        # 创建新客户
        customer_data = {
            'email': email,
            'firstname': user_data.get('metadata', {}).get('nickname', 'User'),
            'lastname': 'BaiDaoHui',
            'passwd': generate_random_password(),
            'active': 1,
            'newsletter': 0,
            'optin': 0
        }
        
        customer = create_prestashop_customer(customer_data)
        if customer:
            logger.info(f"Created new PrestaShop customer: {customer['id']}")
            return customer
        
        return None
        
    except Exception as e:
        logger.error(f"Get or create PrestaShop customer failed: {e}")
        return None

def find_prestashop_customer_by_email(email: str) -> Optional[Dict[str, Any]]:
    """通过邮箱查找PrestaShop客户"""
    try:
        url = f"{PRESTASHOP_BASE_URL}/api/customers"
        params = {
            'filter[email]': email,
            'display': 'full',
            'output_format': 'JSON'
        }
        headers = {
            'Authorization': f'Basic {PRESTASHOP_API_KEY}:'
        }
        
        response = requests.get(url, params=params, headers=headers)
        response.raise_for_status()
        
        data = response.json()
        customers = data.get('customers', [])
        
        if customers:
            return customers[0]
        
        return None
        
    except Exception as e:
        logger.error(f"Find PrestaShop customer failed: {e}")
        return None

def create_prestashop_customer(customer_data: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    """创建PrestaShop客户"""
    try:
        url = f"{PRESTASHOP_BASE_URL}/api/customers"
        headers = {
            'Authorization': f'Basic {PRESTASHOP_API_KEY}:',
            'Content-Type': 'application/json'
        }
        
        # PrestaShop API格式
        prestashop_data = {
            'customer': customer_data
        }
        
        response = requests.post(url, json=prestashop_data, headers=headers)
        response.raise_for_status()
        
        data = response.json()
        return data.get('customer')
        
    except Exception as e:
        logger.error(f"Create PrestaShop customer failed: {e}")
        return None

def generate_prestashop_token(customer_id: str, user_data: Dict[str, Any]) -> str:
    """生成PrestaShop认证token"""
    try:
        # 创建JWT payload
        payload = {
            'customer_id': customer_id,
            'email': user_data['email'],
            'role': user_data['role'],
            'iat': int(time.time()),
            'exp': int(time.time()) + 3600 * 24,  # 24小时过期
            'iss': 'baidaohui-sso'
        }
        
        # 使用PrestaShop secret签名
        token = jwt.encode(payload, PRESTASHOP_SECRET, algorithm='HS256')
        
        return token
        
    except Exception as e:
        logger.error(f"Generate PrestaShop token failed: {e}")
        raise TokenExchangeError(f"Token generation failed: {e}")

def generate_random_password() -> str:
    """生成随机密码"""
    import secrets
    import string
    
    alphabet = string.ascii_letters + string.digits
    password = ''.join(secrets.choice(alphabet) for _ in range(12))
    return password

def cache_token_mapping(supabase_user_id: str, prestashop_token: str, ttl: int = 3600):
    """缓存token映射关系"""
    try:
        cache_key = f"sso:token:{supabase_user_id}"
        redis_client.setex(cache_key, ttl, prestashop_token)
    except Exception as e:
        logger.error(f"Cache token mapping failed: {e}")

def get_cached_token(supabase_user_id: str) -> Optional[str]:
    """获取缓存的token"""
    try:
        cache_key = f"sso:token:{supabase_user_id}"
        return redis_client.get(cache_key)
    except Exception as e:
        logger.error(f"Get cached token failed: {e}")
        return None

@app.route('/exchange', methods=['POST'])
def exchange_token():
    """交换token接口"""
    try:
        # 获取Supabase token
        auth_header = request.headers.get('Authorization')
        if not auth_header or not auth_header.startswith('Bearer '):
            return jsonify({'error': '缺少Authorization header'}), 401
        
        supabase_token = auth_header.split(' ')[1]
        
        # 验证Supabase token
        user_data = verify_supabase_token(supabase_token)
        if not user_data:
            return jsonify({'error': '无效的Supabase token'}), 401
        
        # 检查缓存
        cached_token = get_cached_token(user_data['id'])
        if cached_token:
            # 验证缓存的token是否仍然有效
            try:
                jwt.decode(cached_token, PRESTASHOP_SECRET, algorithms=['HS256'])
                return jsonify({
                    'prestashop_token': cached_token,
                    'expires_in': 3600,
                    'cached': True
                })
            except jwt.ExpiredSignatureError:
                # Token已过期，继续生成新的
                pass
            except jwt.InvalidTokenError:
                # Token无效，继续生成新的
                pass
        
        # 获取或创建PrestaShop客户
        customer = get_or_create_prestashop_customer(user_data)
        if not customer:
            return jsonify({'error': '无法创建或获取PrestaShop客户'}), 500
        
        # 生成PrestaShop token
        prestashop_token = generate_prestashop_token(str(customer['id']), user_data)
        
        # 缓存token
        cache_token_mapping(user_data['id'], prestashop_token, 3600)
        
        return jsonify({
            'prestashop_token': prestashop_token,
            'customer_id': customer['id'],
            'expires_in': 3600,
            'cached': False
        })
        
    except TokenExchangeError as e:
        return jsonify({'error': str(e)}), 500
    except Exception as e:
        logger.error(f"Token exchange failed: {e}")
        return jsonify({'error': '内部服务器错误'}), 500

@app.route('/verify', methods=['POST'])
def verify_prestashop_token():
    """验证PrestaShop token"""
    try:
        data = request.get_json()
        token = data.get('token')
        
        if not token:
            return jsonify({'error': '缺少token参数'}), 400
        
        try:
            # 解码并验证token
            payload = jwt.decode(token, PRESTASHOP_SECRET, algorithms=['HS256'])
            
            return jsonify({
                'valid': True,
                'customer_id': payload.get('customer_id'),
                'email': payload.get('email'),
                'role': payload.get('role'),
                'expires_at': payload.get('exp')
            })
            
        except jwt.ExpiredSignatureError:
            return jsonify({'valid': False, 'error': 'Token已过期'}), 401
        except jwt.InvalidTokenError:
            return jsonify({'valid': False, 'error': '无效的token'}), 401
        
    except Exception as e:
        logger.error(f"Token verification failed: {e}")
        return jsonify({'error': '验证失败'}), 500

@app.route('/refresh', methods=['POST'])
def refresh_token():
    """刷新token"""
    try:
        # 获取当前的Supabase token
        auth_header = request.headers.get('Authorization')
        if not auth_header or not auth_header.startswith('Bearer '):
            return jsonify({'error': '缺少Authorization header'}), 401
        
        supabase_token = auth_header.split(' ')[1]
        
        # 验证Supabase token
        user_data = verify_supabase_token(supabase_token)
        if not user_data:
            return jsonify({'error': '无效的Supabase token'}), 401
        
        # 清除缓存的token
        cache_key = f"sso:token:{user_data['id']}"
        redis_client.delete(cache_key)
        
        # 重新生成token
        customer = get_or_create_prestashop_customer(user_data)
        if not customer:
            return jsonify({'error': '无法获取PrestaShop客户'}), 500
        
        prestashop_token = generate_prestashop_token(str(customer['id']), user_data)
        cache_token_mapping(user_data['id'], prestashop_token, 3600)
        
        return jsonify({
            'prestashop_token': prestashop_token,
            'customer_id': customer['id'],
            'expires_in': 3600
        })
        
    except Exception as e:
        logger.error(f"Token refresh failed: {e}")
        return jsonify({'error': '刷新失败'}), 500

@app.route('/logout', methods=['POST'])
def logout():
    """登出，清除token缓存"""
    try:
        auth_header = request.headers.get('Authorization')
        if not auth_header or not auth_header.startswith('Bearer '):
            return jsonify({'error': '缺少Authorization header'}), 401
        
        supabase_token = auth_header.split(' ')[1]
        user_data = verify_supabase_token(supabase_token)
        
        if user_data:
            # 清除缓存
            cache_key = f"sso:token:{user_data['id']}"
            redis_client.delete(cache_key)
        
        return jsonify({'success': True, 'message': '登出成功'})
        
    except Exception as e:
        logger.error(f"Logout failed: {e}")
        return jsonify({'error': '登出失败'}), 500

@app.route('/health', methods=['GET'])
def health_check():
    """健康检查"""
    try:
        # 检查Redis连接
        redis_client.ping()
        
        # 检查Supabase连接
        supabase.table('profiles').select('id').limit(1).execute()
        
        return jsonify({
            'status': 'healthy',
            'timestamp': datetime.utcnow().isoformat(),
            'services': {
                'redis': 'ok',
                'supabase': 'ok',
                'prestashop': 'ok'  # 可以添加PrestaShop连接检查
            }
        })
        
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        return jsonify({
            'status': 'unhealthy',
            'error': str(e)
        }), 500

if __name__ == '__main__':
    port = int(os.getenv('PORT', 5004))
    app.run(debug=True, host='0.0.0.0', port=port) 