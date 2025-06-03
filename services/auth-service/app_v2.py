"""
Auth Service V2 主应用
重新设计的auth-service，专注于JWT验证、用户信息缓存和Supabase代理
"""

from flask import Flask, jsonify
from flask_cors import CORS
import os
import logging
from datetime import datetime

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# CORS配置
CORS(app, origins=[
    "http://localhost:3000",
    "https://baidaohui.com",
    "https://*.baidaohui.com"
], supports_credentials=True)

# 环境变量配置
app.config.update({
    'SECRET_KEY': os.getenv('JWT_SECRET', 'your-secret-key'),
    'SUPABASE_URL': os.getenv('SUPABASE_URL'),
    'SUPABASE_SERVICE_KEY': os.getenv('SUPABASE_SERVICE_KEY'),
    'SUPABASE_JWT_SECRET': os.getenv('SUPABASE_JWT_SECRET'),
    'DOMAIN': os.getenv('DOMAIN', 'baidaohui.com'),
    'USER_SYNC_INTERVAL': int(os.getenv('USER_SYNC_INTERVAL', '300'))
})

# 验证必要的环境变量
required_env_vars = ['SUPABASE_URL', 'SUPABASE_SERVICE_KEY']
missing_vars = [var for var in required_env_vars if not os.getenv(var)]
if missing_vars:
    logger.error(f"缺少必要的环境变量: {missing_vars}")
    raise ValueError(f"缺少必要的环境变量: {missing_vars}")

# 导入并注册蓝图
try:
    from auth_routes_v2 import auth_bp
    app.register_blueprint(auth_bp, url_prefix='/auth')
    logger.info("Auth V2 路由注册成功")
    
    # 兼容旧接口的路由
    from routes_updated import auth_bp as auth_legacy_bp
    app.register_blueprint(auth_legacy_bp, url_prefix='/auth/legacy')
    logger.info("Auth Legacy 路由注册成功（兼容性）")
    
except ImportError as e:
    logger.error(f"导入路由失败: {e}")
    raise

# 根路径重定向到健康检查
@app.route('/')
def root():
    return jsonify({
        'service': 'auth-service-v2',
        'version': '2.0.0',
        'status': 'running',
        'timestamp': datetime.now().isoformat(),
        'endpoints': {
            'health': '/auth/health',
            'validate': '/auth/validate',
            'verify_role': '/auth/verify-role',
            'user_info': '/auth/user/<user_id>',
            'users_by_role': '/auth/users/by-role/<role>',
            'supabase_proxy': '/auth/supabase/rpc/<function_name>',
            'cache_status': '/auth/cache/status',
            'legacy_endpoints': '/auth/legacy/*'
        },
        'architecture': {
            'description': 'JWT验证 + 用户缓存 + Supabase代理',
            'data_source': 'Supabase (主) + SQLite缓存 (辅)',
            'responsibilities': [
                'JWT Token验证',
                '用户信息查询（从缓存）',
                'Supabase RPC代理',
                '用户缓存管理'
            ]
        }
    })

# 全局错误处理
@app.errorhandler(404)
def not_found(error):
    return jsonify({
        'error': 'endpoint_not_found',
        'message': '请求的端点不存在',
        'available_endpoints': [
            '/auth/health',
            '/auth/validate', 
            '/auth/verify-role',
            '/auth/user/<user_id>',
            '/auth/users/by-role/<role>',
            '/auth/supabase/rpc/<function_name>'
        ]
    }), 404

@app.errorhandler(500)
def internal_error(error):
    logger.error(f"内部服务器错误: {error}")
    return jsonify({
        'error': 'internal_server_error',
        'message': '服务器内部错误'
    }), 500

@app.errorhandler(Exception)
def handle_exception(e):
    logger.error(f"未处理的异常: {e}")
    return jsonify({
        'error': 'unhandled_exception',
        'message': '服务器异常'
    }), 500

# 启动前检查
def startup_checks():
    """启动前检查"""
    try:
        # 检查Supabase连接
        from supabase_client import supabase_client
        test_result = supabase_client._call_rpc('admin_list_users', {'limit_count': 1})
        if 'error' in test_result:
            logger.warning(f"Supabase连接测试警告: {test_result}")
        else:
            logger.info("Supabase连接测试成功")
        
        # 检查用户管理器
        from user_manager import user_manager
        cache_status = user_manager.get_sync_status()
        logger.info(f"用户缓存状态: {cache_status}")
        
        # 强制执行一次同步
        logger.info("执行启动时用户数据同步...")
        sync_success = user_manager.sync_users_from_supabase(force=True)
        if sync_success:
            logger.info("启动时用户数据同步成功")
        else:
            logger.warning("启动时用户数据同步失败")
        
        return True
        
    except Exception as e:
        logger.error(f"启动检查失败: {e}")
        return False

if __name__ == '__main__':
    # 执行启动检查
    if startup_checks():
        logger.info("Auth Service V2 启动检查通过")
    else:
        logger.warning("Auth Service V2 启动检查有警告，但继续启动")
    
    # 获取配置
    host = os.getenv('HOST', '0.0.0.0')
    port = int(os.getenv('PORT', 5001))
    debug = os.getenv('DEBUG', 'False').lower() == 'true'
    
    logger.info(f"Auth Service V2 启动中...")
    logger.info(f"监听地址: {host}:{port}")
    logger.info(f"调试模式: {debug}")
    logger.info(f"CORS域名: {app.config['DOMAIN']}")
    logger.info(f"用户同步间隔: {app.config['USER_SYNC_INTERVAL']}秒")
    
    app.run(
        host=host,
        port=port,
        debug=debug,
        threaded=True
    ) 