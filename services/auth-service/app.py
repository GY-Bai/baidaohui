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
JWT_SECRET = os.getenv('JWT_SECRET', 'your-secret-key')
FRONTEND_URL = os.getenv('FRONTEND_URL', 'https://baidaohui.com')

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

from routes import auth_bp
app.register_blueprint(auth_bp, url_prefix='/auth')

@app.route('/health')
def health():
    return jsonify({'status': 'healthy', 'service': 'auth-service'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001, debug=True) 