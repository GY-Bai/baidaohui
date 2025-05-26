from flask import Flask, jsonify
from flask_cors import CORS
from routes.nickname import nickname_bp
import os

app = Flask(__name__)
CORS(app)

# 注册蓝图
app.register_blueprint(nickname_bp, url_prefix='/api/profile')

@app.route('/health', methods=['GET'])
def health_check():
    """健康检查"""
    from datetime import datetime
    
    services = {}
    overall_status = 'healthy'
    
    # 检查环境变量配置
    try:
        mongo_url = os.getenv('MONGO_URL')
        supabase_url = os.getenv('SUPABASE_URL')
        if mongo_url and supabase_url:
            services['config'] = 'ok'
        else:
            services['config'] = 'missing_env_vars'
            overall_status = 'unhealthy'
    except Exception as e:
        services['config'] = f'error: {str(e)}'
        overall_status = 'unhealthy'
    
    response_data = {
        'status': overall_status,
        'service': 'profile-service',
        'timestamp': datetime.utcnow().isoformat(),
        'services': services
    }
    
    status_code = 200 if overall_status == 'healthy' else 500
    return jsonify(response_data), status_code

if __name__ == '__main__':
    port = int(os.getenv('PORT', 5002))
    app.run(debug=True, host='0.0.0.0', port=port) 