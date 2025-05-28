from flask import Flask, request, jsonify, make_response, redirect
from flask_cors import CORS
import jwt
import os
import requests
from datetime import datetime, timedelta
import logging
import redis
import json

app = Flask(__name__)
CORS(app, supports_credentials=True, origins=[
    'https://baidaohui.com',
    'https://fan.baidaohui.com',
    'https://member.baidaohui.com', 
    'https://master.baidaohui.com',
    'https://firstmate.baidaohui.com',
    'https://seller.baidaohui.com',
    'http://localhost:5173'  # 开发环境
])

# 配置
SUPABASE_URL = os.getenv('SUPABASE_URL')
SUPABASE_SERVICE_KEY = os.getenv('SUPABASE_SERVICE_KEY')
JWT_SECRET = os.getenv('JWT_SECRET', 'your-secret-key')
REDIS_URL = os.getenv('REDIS_URL', 'redis://localhost:6379')
DOMAIN = os.getenv('DOMAIN', 'baidaohui.com')

# Redis连接
redis_client = redis.from_url(REDIS_URL)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# 角色对应的子域名映射
ROLE_SUBDOMAINS = {
    'Fan': f'fan.{DOMAIN}',
    'Member': f'member.{DOMAIN}',
    'Master': f'master.{DOMAIN}',
    'Firstmate': f'firstmate.{DOMAIN}',
    'Seller': f'seller.{DOMAIN}'
}

from routes import sso_bp
app.register_blueprint(sso_bp, url_prefix='/sso')

@app.route('/health')
def health():
    return jsonify({'status': 'healthy', 'service': 'sso-service'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5002, debug=True) 