from flask import Flask, request, jsonify, make_response
from flask_cors import CORS
import jwt
import os
import requests
from datetime import datetime, timedelta
import logging

app = Flask(__name__)
CORS(app, supports_credentials=True)

# 配置
SUPABASE_URL = os.getenv('SUPABASE_URL')
SUPABASE_SERVICE_KEY = os.getenv('SUPABASE_SERVICE_KEY')
SUPABASE_JWT_SECRET = os.getenv('SUPABASE_JWT_SECRET')
JWT_SECRET = os.getenv('JWT_SECRET', 'your-jwt-secret-key')
FRONTEND_URL = os.getenv('FRONTEND_URL', 'https://baidaohui.com')

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

from routes import auth_bp
app.register_blueprint(auth_bp, url_prefix='/auth')

# JWT兼容性配置：支持两种JWT验证方式
def get_jwt_secrets():
    """获取所有可用的JWT密钥用于验证"""
    secrets = []
    if SUPABASE_JWT_SECRET:
        secrets.append(SUPABASE_JWT_SECRET)
    if JWT_SECRET:
        secrets.append(JWT_SECRET)
    return secrets

def verify_jwt_token(token):
    """验证JWT令牌，支持多种密钥"""
    for secret in get_jwt_secrets():
        try:
            payload = jwt.decode(token, secret, algorithms=['HS256'])
            return payload
        except jwt.InvalidTokenError:
            continue
    raise jwt.InvalidTokenError("无法验证JWT令牌")

SUPABASE_SERVICE_ROLE_KEY = os.getenv('SUPABASE_SERVICE_ROLE_KEY')

@app.route('/health')
def health():
    return jsonify({'status': 'healthy', 'service': 'auth-service'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001, debug=True) 