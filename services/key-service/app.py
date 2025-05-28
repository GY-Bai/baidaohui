from flask import Flask, request, jsonify
from flask_cors import CORS
import os
import jwt
import hashlib
import secrets
from datetime import datetime, timedelta
from pymongo import MongoClient
from bson import ObjectId
import logging
import stripe
import requests
import time
from collections import defaultdict
from threading import Lock
import hvac  # HashiCorp Vault client
from cryptography.fernet import Fernet
import base64

# 配置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)

# 环境变量配置
MONGODB_URI = os.getenv('MONGODB_URI', 'mongodb://localhost:27017/baidaohui')
JWT_SECRET = os.getenv('JWT_SECRET', 'your-jwt-secret-key')
SUPABASE_JWT_SECRET = os.getenv('SUPABASE_JWT_SECRET')
VAULT_URL = os.getenv('VAULT_URL')  # HashiCorp Vault URL
VAULT_TOKEN = os.getenv('VAULT_TOKEN')  # Vault access token
VAULT_MOUNT_POINT = os.getenv('VAULT_MOUNT_POINT', 'secret')  # Vault mount point
VAULT_ENCRYPTION_KEY = os.getenv('VAULT_ENCRYPTION_KEY', 'your-vault-encryption-key')

# 速率限制配置
RATE_LIMIT_WINDOW = 900  # 15分钟窗口
RATE_LIMIT_MAX_REQUESTS = 100  # 每15分钟最多100次请求
RATE_LIMIT_SENSITIVE_MAX = 10  # 敏感操作每15分钟最多10次

# 速率限制存储
rate_limit_store = defaultdict(list)
rate_limit_lock = Lock()

# MongoDB 连接
try:
    client = MongoClient(MONGODB_URI)
    db = client.baidaohui
    api_keys = db.api_keys
    stores = db.stores
    logger.info("MongoDB 连接成功")
except Exception as e:
    logger.error(f"MongoDB 连接失败: {e}")
    raise

# Vault 客户端初始化
vault_client = None
if VAULT_URL and VAULT_TOKEN:
    try:
        vault_client = hvac.Client(url=VAULT_URL, token=VAULT_TOKEN)
        if vault_client.is_authenticated():
            logger.info("Vault 连接成功")
        else:
            logger.warning("Vault 认证失败")
            vault_client = None
    except Exception as e:
        logger.error(f"Vault 连接失败: {e}")
        vault_client = None

# 本地加密密钥（当Vault不可用时的备选方案）
local_cipher = None
if VAULT_ENCRYPTION_KEY:
    try:
        # 确保密钥是32字节的base64编码
        key_bytes = VAULT_ENCRYPTION_KEY.encode()[:32].ljust(32, b'0')
        encoded_key = base64.urlsafe_b64encode(key_bytes)
        local_cipher = Fernet(encoded_key)
        logger.info("本地加密初始化成功")
    except Exception as e:
        logger.error(f"本地加密初始化失败: {e}")

def check_rate_limit(user_id, is_sensitive=False):
    """检查API速率限制"""
    with rate_limit_lock:
        now = time.time()
        window_start = now - RATE_LIMIT_WINDOW
        
        # 清理过期的请求记录
        rate_limit_store[user_id] = [
            timestamp for timestamp in rate_limit_store[user_id] 
            if timestamp > window_start
        ]
        
        # 检查请求数量
        current_requests = len(rate_limit_store[user_id])
        max_requests = RATE_LIMIT_SENSITIVE_MAX if is_sensitive else RATE_LIMIT_MAX_REQUESTS
        
        if current_requests >= max_requests:
            return False, {
                'error': '请求频率过高，请稍后再试',
                'retry_after': int(RATE_LIMIT_WINDOW - (now - min(rate_limit_store[user_id]))),
                'limit': max_requests,
                'window': RATE_LIMIT_WINDOW
            }
        
        # 记录当前请求
        rate_limit_store[user_id].append(now)
        return True, None

def verify_jwt(token):
    """验证JWT令牌（支持Supabase和传统JWT）"""
    try:
        # 优先尝试Supabase JWT
        if SUPABASE_JWT_SECRET:
            try:
                payload = jwt.decode(token, SUPABASE_JWT_SECRET, algorithms=['HS256'])
                return {
                    'sub': payload['sub'],
                    'email': payload.get('email'),
                    'role': payload.get('user_metadata', {}).get('role', 'user')
                }
            except jwt.InvalidTokenError:
                pass
        
        # 回退到传统JWT
        payload = jwt.decode(token, JWT_SECRET, algorithms=['HS256'])
        return payload
    except jwt.ExpiredSignatureError:
        return None
    except jwt.InvalidTokenError:
        return None

def check_auth():
    """检查用户认证和权限"""
    auth_header = request.headers.get('Authorization')
    token = None
    
    if auth_header and auth_header.startswith('Bearer '):
        token = auth_header.split(' ')[1]
    else:
        # 尝试从Cookie获取
        token = request.cookies.get('access_token') or request.cookies.get('sb-access-token')
    
    if not token:
        return None, {'error': '缺少认证令牌'}, 401
    
    payload = verify_jwt(token)
    if not payload:
        return None, {'error': '无效的认证令牌'}, 401
    
    return payload, None, None

def store_secret_in_vault(key_id, secret_value):
    """在Vault中存储密钥"""
    if not vault_client:
        logger.warning("Vault不可用，使用本地加密存储")
        return encrypt_key_local(secret_value)
    
    try:
        secret_path = f"{VAULT_MOUNT_POINT}/data/api-keys/{key_id}"
        secret_data = {
            'data': {
                'secret_key': secret_value,
                'created_at': datetime.utcnow().isoformat(),
                'service': 'key-service'
            }
        }
        
        response = vault_client.secrets.kv.v2.create_or_update_secret(
            path=f"api-keys/{key_id}",
            secret=secret_data['data'],
            mount_point=VAULT_MOUNT_POINT
        )
        
        logger.info(f"密钥 {key_id} 已存储到Vault")
        return f"vault:{key_id}"
        
    except Exception as e:
        logger.error(f"Vault存储失败: {e}")
        # 回退到本地加密
        return encrypt_key_local(secret_value)

def retrieve_secret_from_vault(vault_reference):
    """从Vault中检索密钥"""
    if not vault_reference.startswith('vault:'):
        # 本地加密的密钥
        return decrypt_key_local(vault_reference)
    
    if not vault_client:
        logger.error("Vault不可用，无法检索密钥")
        return None
    
    try:
        key_id = vault_reference.replace('vault:', '')
        response = vault_client.secrets.kv.v2.read_secret_version(
            path=f"api-keys/{key_id}",
            mount_point=VAULT_MOUNT_POINT
        )
        
        return response['data']['data']['secret_key']
        
    except Exception as e:
        logger.error(f"Vault检索失败: {e}")
        return None

def encrypt_key_local(key_value):
    """本地加密密钥"""
    if not local_cipher:
        # 简单的哈希方式（不可逆）
        salt = secrets.token_hex(16)
        encrypted = hashlib.pbkdf2_hmac('sha256', key_value.encode(), salt.encode(), 100000)
        return f"hash:{salt}:{encrypted.hex()}"
    
    try:
        encrypted = local_cipher.encrypt(key_value.encode())
        return f"local:{encrypted.decode()}"
    except Exception as e:
        logger.error(f"本地加密失败: {e}")
        return None

def decrypt_key_local(encrypted_reference):
    """本地解密密钥"""
    if encrypted_reference.startswith('hash:'):
        # 哈希方式存储的密钥无法解密
        parts = encrypted_reference.split(':', 2)
        if len(parts) >= 3:
            return f"****{parts[2][-8:]}"
        return "****encrypted"
    
    if encrypted_reference.startswith('local:') and local_cipher:
        try:
            encrypted_data = encrypted_reference.replace('local:', '')
            decrypted = local_cipher.decrypt(encrypted_data.encode())
            return decrypted.decode()
        except Exception as e:
            logger.error(f"本地解密失败: {e}")
            return None
    
    return None

def encrypt_key(key_value):
    """简单的密钥加密（实际生产环境应使用更安全的加密方法）"""
    # 这里使用简单的哈希+盐值方式，实际应该使用 AES 等对称加密
    salt = secrets.token_hex(16)
    encrypted = hashlib.pbkdf2_hmac('sha256', key_value.encode(), salt.encode(), 100000)
    return f"{salt}:{encrypted.hex()}"

def decrypt_key(encrypted_key):
    """解密密钥（这里只是示例，实际应该可以解密回原值）"""
    # 注意：这个示例实现不能真正解密，只是为了演示结构
    # 实际生产环境应该使用可逆的加密算法
    try:
        salt, encrypted_hex = encrypted_key.split(':', 1)
        return f"****{encrypted_hex[-8:]}"  # 返回脱敏版本
    except:
        return "****encrypted"

def mask_secret_key(secret_key):
    """脱敏显示密钥"""
    if not secret_key:
        return ""
    
    if secret_key.startswith('sk_'):
        # Stripe 密钥格式
        if len(secret_key) > 10:
            return f"****{secret_key[-8:]}"
        else:
            return "****" + secret_key[-4:]
    else:
        # 其他格式密钥
        if len(secret_key) > 8:
            return f"****{secret_key[-4:]}"
        else:
            return "****"

def test_stripe_key(secret_key, publishable_key=None):
    """测试 Stripe 密钥有效性"""
    try:
        # 临时设置 Stripe API 密钥
        original_key = stripe.api_key
        stripe.api_key = secret_key
        
        # 尝试获取账户信息
        account = stripe.Account.retrieve()
        
        # 恢复原始密钥
        stripe.api_key = original_key
        
        return {
            'valid': True,
            'account_id': account.id,
            'country': account.country,
            'currency': account.default_currency,
            'business_type': account.business_type
        }
    except stripe.error.AuthenticationError:
        return {'valid': False, 'error': '密钥认证失败'}
    except stripe.error.PermissionError:
        return {'valid': False, 'error': '密钥权限不足'}
    except Exception as e:
        return {'valid': False, 'error': f'连接测试失败: {str(e)}'}
    finally:
        # 确保恢复原始密钥
        if 'original_key' in locals():
            stripe.api_key = original_key

@app.route('/health', methods=['GET'])
def health_check():
    """健康检查接口"""
    return jsonify({'status': 'healthy', 'service': 'key-service'})

@app.route('/keys', methods=['GET'])
def get_keys():
    """获取密钥列表"""
    try:
        # 验证用户权限
        payload, error_response, status_code = check_auth()
        if error_response:
            return jsonify(error_response), status_code
        
        user_role = payload.get('role')
        user_id = payload.get('sub')
        
        # 构建查询条件
        query = {}
        
        if user_role == 'Seller':
            # Seller 只能查看自己的密钥
            query['owner_id'] = user_id
        elif user_role in ['Master', 'Firstmate']:
            # Master 和 Firstmate 可以查看所有密钥
            store_id = request.args.get('store_id')
            if store_id:
                query['store_id'] = store_id
        else:
            return jsonify({'error': '权限不足'}), 403
        
        # 查询参数
        page = int(request.args.get('page', 1))
        limit = int(request.args.get('limit', 20))
        
        # 分页查询
        skip = (page - 1) * limit
        cursor = api_keys.find(query).sort('created_at', -1).skip(skip).limit(limit)
        
        keys_list = []
        for key_doc in cursor:
            key_data = {
                'id': str(key_doc['_id']),
                'store_id': key_doc.get('store_id'),
                'store_name': key_doc.get('store_name'),
                'key_type': key_doc.get('key_type', 'stripe'),
                'secret_key_masked': mask_secret_key(key_doc.get('secret_key_original', '')),
                'publishable_key': key_doc.get('publishable_key', ''),
                'is_active': key_doc.get('is_active', True),
                'last_tested': key_doc.get('last_tested'),
                'test_status': key_doc.get('test_status'),
                'created_at': key_doc['created_at'].isoformat(),
                'updated_at': key_doc.get('updated_at', key_doc['created_at']).isoformat()
            }
            
            # 只有 Master 和 Firstmate 可以看到所有者信息
            if user_role in ['Master', 'Firstmate']:
                key_data['owner_id'] = key_doc.get('owner_id')
                key_data['created_by_role'] = key_doc.get('created_by_role')
            
            keys_list.append(key_data)
        
        # 获取总数
        total = api_keys.count_documents(query)
        
        return jsonify({
            'success': True,
            'keys': keys_list,
            'pagination': {
                'page': page,
                'limit': limit,
                'total': total,
                'pages': (total + limit - 1) // limit
            }
        })
        
    except Exception as e:
        logger.error(f"获取密钥列表失败: {e}")
        return jsonify({'error': '服务器内部错误'}), 500

@app.route('/keys', methods=['POST'])
def create_key():
    """创建新密钥"""
    try:
        # 验证用户权限
        payload, error_response, status_code = check_auth()
        if error_response:
            return jsonify(error_response), status_code
        
        user_role = payload.get('role')
        user_id = payload.get('sub')
        
        # 检查速率限制（创建密钥是敏感操作）
        rate_ok, rate_error = check_rate_limit(user_id, is_sensitive=True)
        if not rate_ok:
            return jsonify(rate_error), 429
        
        # Seller、Master 和 Firstmate 都可以创建密钥
        if user_role not in ['Seller', 'Master', 'Firstmate', 'admin']:
            return jsonify({'error': '权限不足'}), 403
        
        data = request.get_json()
        if not data:
            return jsonify({'error': '请求数据不能为空'}), 400
        
        store_id = data.get('store_id')
        secret_key = data.get('secret_key')
        publishable_key = data.get('publishable_key', '')
        key_type = data.get('key_type', 'stripe')
        
        if not store_id or not secret_key:
            return jsonify({'error': '缺少必要参数: store_id 和 secret_key'}), 400
        
        # 验证商店存在且用户有权限
        store = stores.find_one({'_id': ObjectId(store_id)})
        if not store:
            return jsonify({'error': '商店不存在'}), 404
        
        # Seller 只能为自己的商店创建密钥
        if user_role == 'Seller' and store.get('owner_id') != user_id:
            return jsonify({'error': '只能为自己的商店创建密钥'}), 403
        
        # 检查是否已存在该商店的密钥
        existing_key = api_keys.find_one({'store_id': store_id, 'key_type': key_type})
        if existing_key:
            return jsonify({'error': f'该商店已存在 {key_type} 类型的密钥'}), 409
        
        # 测试密钥有效性
        if key_type == 'stripe':
            test_result = test_stripe_key(secret_key, publishable_key)
            if not test_result['valid']:
                return jsonify({
                    'error': f'密钥测试失败: {test_result["error"]}'
                }), 400
        
        # 创建密钥记录
        key_doc = {
            'store_id': store_id,
            'store_name': store.get('name', ''),
            'key_type': key_type,
            'publishable_key': publishable_key,
            'owner_id': store.get('owner_id'),
            'created_by': user_id,
            'created_by_role': user_role,
            'is_active': True,
            'created_at': datetime.utcnow(),
            'updated_at': datetime.utcnow(),
            'last_tested': datetime.utcnow(),
            'test_status': 'valid' if key_type == 'stripe' and test_result['valid'] else 'unknown'
        }
        
        # 插入记录获取ID
        result = api_keys.insert_one(key_doc)
        key_id = str(result.inserted_id)
        
        # 使用Vault存储密钥
        vault_reference = store_secret_in_vault(key_id, secret_key)
        if not vault_reference:
            # 如果存储失败，删除记录
            api_keys.delete_one({'_id': result.inserted_id})
            return jsonify({'error': '密钥存储失败'}), 500
        
        # 更新记录，添加Vault引用
        api_keys.update_one(
            {'_id': result.inserted_id},
            {
                '$set': {
                    'vault_reference': vault_reference,
                    'secret_key_original': secret_key  # 临时保存用于脱敏显示
                }
            }
        )
        
        logger.info(f"用户 {user_id} ({user_role}) 为商店 {store_id} 创建了 {key_type} 密钥")
        
        return jsonify({
            'success': True,
            'key_id': key_id,
            'message': '密钥创建成功',
            'test_result': test_result if key_type == 'stripe' else None
        })
        
    except Exception as e:
        logger.error(f"创建密钥失败: {e}")
        return jsonify({'error': '服务器内部错误'}), 500

@app.route('/keys/<key_id>', methods=['PUT'])
def update_key(key_id):
    """更新密钥"""
    try:
        # 验证用户权限
        payload, error_response, status_code = check_auth()
        if error_response:
            return jsonify(error_response), status_code
        
        user_role = payload.get('role')
        user_id = payload.get('sub')
        
        # 验证密钥ID
        try:
            object_id = ObjectId(key_id)
        except:
            return jsonify({'error': '无效的密钥ID'}), 400
        
        # 查找密钥记录
        key_record = api_keys.find_one({'_id': object_id})
        if not key_record:
            return jsonify({'error': '密钥不存在'}), 404
        
        # 权限检查
        if user_role == 'Seller' and key_record.get('owner_id') != user_id:
            return jsonify({'error': '权限不足，只能修改自己的密钥'}), 403
        elif user_role not in ['Seller', 'Master', 'Firstmate']:
            return jsonify({'error': '权限不足'}), 403
        
        data = request.get_json()
        if not data:
            return jsonify({'error': '请求数据不能为空'}), 400
        
        # 构建更新字段
        update_fields = {'updated_at': datetime.utcnow()}
        
        # 可更新的字段
        if 'secret_key' in data and data['secret_key'].strip():
            new_secret_key = data['secret_key'].strip()
            if not new_secret_key.startswith('sk_'):
                return jsonify({'error': '无效的 Stripe 密钥格式'}), 400
            update_fields['secret_key_original'] = new_secret_key
            update_fields['secret_key_encrypted'] = encrypt_key(new_secret_key)
            update_fields['test_status'] = 'pending'  # 重置测试状态
        
        if 'publishable_key' in data:
            update_fields['publishable_key'] = data['publishable_key'].strip()
        
        if 'store_name' in data:
            update_fields['store_name'] = data['store_name'].strip()
        
        if 'is_active' in data and user_role in ['Master', 'Firstmate']:
            update_fields['is_active'] = bool(data['is_active'])
        
        # 更新数据库
        result = api_keys.update_one(
            {'_id': object_id},
            {'$set': update_fields}
        )
        
        if result.modified_count == 0:
            return jsonify({'error': '没有字段被更新'}), 400
        
        logger.info(f"用户 {user_id} ({user_role}) 更新了密钥 {key_id}")
        
        return jsonify({
            'success': True,
            'message': '密钥更新成功'
        })
        
    except Exception as e:
        logger.error(f"更新密钥失败: {e}")
        return jsonify({'error': '服务器内部错误'}), 500

@app.route('/keys/<key_id>', methods=['DELETE'])
def delete_key(key_id):
    """删除密钥"""
    try:
        # 验证用户权限
        payload, error_response, status_code = check_auth()
        if error_response:
            return jsonify(error_response), status_code
        
        user_role = payload.get('role')
        user_id = payload.get('sub')
        
        # 验证密钥ID
        try:
            object_id = ObjectId(key_id)
        except:
            return jsonify({'error': '无效的密钥ID'}), 400
        
        # 查找密钥记录
        key_record = api_keys.find_one({'_id': object_id})
        if not key_record:
            return jsonify({'error': '密钥不存在'}), 404
        
        # 权限检查
        if user_role == 'Seller' and key_record.get('owner_id') != user_id:
            return jsonify({'error': '权限不足，只能删除自己的密钥'}), 403
        elif user_role not in ['Seller', 'Master', 'Firstmate']:
            return jsonify({'error': '权限不足'}), 403
        
        # 软删除（标记为非活跃）而不是物理删除
        result = api_keys.update_one(
            {'_id': object_id},
            {
                '$set': {
                    'is_active': False,
                    'deleted_at': datetime.utcnow(),
                    'deleted_by': user_id,
                    'updated_at': datetime.utcnow()
                }
            }
        )
        
        if result.modified_count == 0:
            return jsonify({'error': '删除失败'}), 500
        
        # 更新商店记录
        store_id = key_record.get('store_id')
        if store_id:
            stores.update_one(
                {'store_id': store_id},
                {
                    '$set': {
                        'has_api_key': False,
                        'updated_at': datetime.utcnow()
                    }
                }
            )
        
        logger.info(f"用户 {user_id} ({user_role}) 删除了密钥 {key_id}")
        
        return jsonify({
            'success': True,
            'message': '密钥删除成功'
        })
        
    except Exception as e:
        logger.error(f"删除密钥失败: {e}")
        return jsonify({'error': '服务器内部错误'}), 500

@app.route('/keys/<key_id>/test', methods=['POST'])
def test_key(key_id):
    """测试密钥连接"""
    try:
        # 验证用户权限
        payload, error_response, status_code = check_auth()
        if error_response:
            return jsonify(error_response), status_code
        
        user_role = payload.get('role')
        user_id = payload.get('sub')
        
        # 验证密钥ID
        try:
            object_id = ObjectId(key_id)
        except:
            return jsonify({'error': '无效的密钥ID'}), 400
        
        # 查找密钥记录
        key_record = api_keys.find_one({'_id': object_id, 'is_active': True})
        if not key_record:
            return jsonify({'error': '密钥不存在或已停用'}), 404
        
        # 权限检查
        if user_role == 'Seller' and key_record.get('owner_id') != user_id:
            return jsonify({'error': '权限不足'}), 403
        elif user_role not in ['Seller', 'Master', 'Firstmate']:
            return jsonify({'error': '权限不足'}), 403
        
        # 获取原始密钥
        secret_key = key_record.get('secret_key_original')
        publishable_key = key_record.get('publishable_key')
        
        if not secret_key:
            return jsonify({'error': '密钥数据不完整'}), 400
        
        # 测试连接
        test_result = test_stripe_key(secret_key, publishable_key)
        
        # 更新测试结果
        update_data = {
            'last_tested': datetime.utcnow(),
            'test_status': 'success' if test_result['valid'] else 'failed',
            'updated_at': datetime.utcnow()
        }
        
        if test_result['valid']:
            update_data['test_details'] = {
                'account_id': test_result.get('account_id'),
                'country': test_result.get('country'),
                'currency': test_result.get('currency'),
                'business_type': test_result.get('business_type')
            }
        else:
            update_data['test_error'] = test_result.get('error')
        
        api_keys.update_one(
            {'_id': object_id},
            {'$set': update_data}
        )
        
        logger.info(f"用户 {user_id} 测试了密钥 {key_id}，结果: {'成功' if test_result['valid'] else '失败'}")
        
        return jsonify({
            'success': True,
            'test_result': test_result,
            'tested_at': update_data['last_tested'].isoformat()
        })
        
    except Exception as e:
        logger.error(f"测试密钥失败: {e}")
        return jsonify({'error': '服务器内部错误'}), 500

@app.route('/keys/<key_id>/reveal', methods=['POST'])
def reveal_key(key_id):
    """临时显示完整密钥（仅限所有者）"""
    try:
        # 验证用户权限
        payload, error_response, status_code = check_auth()
        if error_response:
            return jsonify(error_response), status_code
        
        user_role = payload.get('role')
        user_id = payload.get('sub')
        
        # 检查速率限制（查看完整密钥是高度敏感操作）
        rate_ok, rate_error = check_rate_limit(user_id, is_sensitive=True)
        if not rate_ok:
            return jsonify(rate_error), 429
        
        # 验证密钥ID
        try:
            object_id = ObjectId(key_id)
        except:
            return jsonify({'error': '无效的密钥ID'}), 400
        
        # 查找密钥记录
        key_record = api_keys.find_one({'_id': object_id, 'is_active': True})
        if not key_record:
            return jsonify({'error': '密钥不存在或已停用'}), 404
        
        # 严格权限检查：只有密钥所有者或 Master 可以查看完整密钥
        if user_role == 'Seller' and key_record.get('owner_id') != user_id:
            return jsonify({'error': '权限不足，只能查看自己的密钥'}), 403
        elif user_role == 'Firstmate':
            return jsonify({'error': 'Firstmate 无权查看完整密钥'}), 403
        elif user_role not in ['Seller', 'Master', 'admin']:
            return jsonify({'error': '权限不足'}), 403
        
        # 从Vault或本地存储获取密钥
        vault_reference = key_record.get('vault_reference')
        secret_key = None
        
        if vault_reference:
            secret_key = retrieve_secret_from_vault(vault_reference)
        else:
            # 兼容旧数据
            secret_key = key_record.get('secret_key_original')
        
        if not secret_key:
            return jsonify({'error': '无法获取密钥数据'}), 500
        
        # 记录查看日志
        api_keys.update_one(
            {'_id': object_id},
            {
                '$push': {
                    'view_logs': {
                        'viewed_by': user_id,
                        'viewed_at': datetime.utcnow(),
                        'ip_address': request.remote_addr,
                        'user_agent': request.headers.get('User-Agent', '')
                    }
                },
                '$set': {'updated_at': datetime.utcnow()}
            }
        )
        
        logger.warning(f"用户 {user_id} ({user_role}) 查看了密钥 {key_id} 的完整内容")
        
        return jsonify({
            'success': True,
            'secret_key': secret_key,
            'publishable_key': key_record.get('publishable_key'),
            'warning': '密钥已显示，请妥善保管，避免泄露',
            'expires_in': 300  # 建议5分钟内使用
        })
        
    except Exception as e:
        logger.error(f"显示密钥失败: {e}")
        return jsonify({'error': '服务器内部错误'}), 500

@app.route('/stores', methods=['GET'])
def get_stores():
    """获取商店列表（仅 Master 和 Firstmate）"""
    try:
        # 验证用户权限
        payload, error_response, status_code = check_auth()
        if error_response:
            return jsonify(error_response), status_code
        
        user_role = payload.get('role')
        
        if user_role not in ['Master', 'Firstmate']:
            return jsonify({'error': '权限不足'}), 403
        
        # 查询参数
        page = int(request.args.get('page', 1))
        limit = int(request.args.get('limit', 20))
        
        # 聚合查询，关联密钥信息
        pipeline = [
            {
                '$lookup': {
                    'from': 'api_keys',
                    'localField': 'store_id',
                    'foreignField': 'store_id',
                    'as': 'keys'
                }
            },
            {
                '$addFields': {
                    'active_keys': {
                        '$filter': {
                            'input': '$keys',
                            'cond': {'$eq': ['$$this.is_active', True]}
                        }
                    }
                }
            },
            {
                '$addFields': {
                    'key_count': {'$size': '$active_keys'},
                    'has_valid_key': {'$gt': [{'$size': '$active_keys'}, 0]}
                }
            },
            {'$sort': {'created_at': -1}},
            {'$skip': (page - 1) * limit},
            {'$limit': limit}
        ]
        
        stores_cursor = stores.aggregate(pipeline)
        stores_list = []
        
        for store in stores_cursor:
            store_data = {
                'store_id': store['store_id'],
                'store_name': store['store_name'],
                'owner_id': store.get('owner_id'),
                'product_count': store.get('product_count', 0),
                'has_api_key': store.get('has_valid_key', False),
                'key_count': store.get('key_count', 0),
                'created_at': store['created_at'].isoformat(),
                'updated_at': store.get('updated_at', store['created_at']).isoformat()
            }
            stores_list.append(store_data)
        
        # 获取总数
        total = stores.count_documents({})
        
        return jsonify({
            'success': True,
            'stores': stores_list,
            'pagination': {
                'page': page,
                'limit': limit,
                'total': total,
                'pages': (total + limit - 1) // limit
            }
        })
        
    except Exception as e:
        logger.error(f"获取商店列表失败: {e}")
        return jsonify({'error': '服务器内部错误'}), 500

if __name__ == '__main__':
    port = int(os.getenv('PORT', 5008))
    app.run(host='0.0.0.0', port=port, debug=os.getenv('FLASK_ENV') == 'development') 