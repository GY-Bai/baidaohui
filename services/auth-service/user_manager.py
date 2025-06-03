"""
用户管理器模块
负责从Supabase同步用户数据到本地缓存，为其他服务提供用户信息查询
"""

import os
import sqlite3
import threading
import time
import logging
from datetime import datetime, timedelta
from typing import Dict, Any, Optional, List
from supabase_client import supabase_client
import json

logger = logging.getLogger(__name__)

class UserManager:
    def __init__(self, db_path='users_cache.db'):
        self.db_path = db_path
        self.sync_interval = int(os.getenv('USER_SYNC_INTERVAL', '300'))  # 5分钟同步一次
        self.lock = threading.Lock()
        self.last_sync = None
        self.init_database()
        self.start_sync_thread()
    
    def init_database(self):
        """初始化本地用户缓存数据库"""
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                # 用户表
                cursor.execute('''
                    CREATE TABLE IF NOT EXISTS users (
                        id TEXT PRIMARY KEY,
                        email TEXT UNIQUE NOT NULL,
                        role TEXT NOT NULL DEFAULT 'Fan',
                        nickname TEXT,
                        created_at TEXT,
                        updated_at TEXT,
                        last_sync TEXT,
                        is_active BOOLEAN DEFAULT 1
                    )
                ''')
                
                # 用户会话表（用于快速JWT验证）
                cursor.execute('''
                    CREATE TABLE IF NOT EXISTS user_sessions (
                        user_id TEXT,
                        jwt_hash TEXT,
                        expires_at TEXT,
                        created_at TEXT,
                        FOREIGN KEY (user_id) REFERENCES users (id)
                    )
                ''')
                
                # 同步日志表
                cursor.execute('''
                    CREATE TABLE IF NOT EXISTS sync_logs (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        sync_type TEXT,
                        users_count INTEGER,
                        success BOOLEAN,
                        error_message TEXT,
                        sync_time TEXT
                    )
                ''')
                
                # 创建索引
                cursor.execute('CREATE INDEX IF NOT EXISTS idx_users_email ON users (email)')
                cursor.execute('CREATE INDEX IF NOT EXISTS idx_users_role ON users (role)')
                cursor.execute('CREATE INDEX IF NOT EXISTS idx_sessions_user ON user_sessions (user_id)')
                cursor.execute('CREATE INDEX IF NOT EXISTS idx_sessions_expires ON user_sessions (expires_at)')
                
                conn.commit()
                logger.info("用户缓存数据库初始化完成")
                
        except Exception as e:
            logger.error(f"初始化数据库失败: {e}")
            raise
    
    def sync_users_from_supabase(self, force=False):
        """从Supabase同步用户数据"""
        if not force and self.last_sync and (datetime.now() - self.last_sync).seconds < self.sync_interval:
            return True
        
        with self.lock:
            try:
                logger.info("开始同步用户数据...")
                
                # 通过Supabase客户端获取所有用户
                result = supabase_client._call_rpc('admin_list_users', {
                    'role_filter': None,
                    'limit_count': 1000
                })
                
                if not isinstance(result, list):
                    logger.error(f"获取用户列表失败: {result}")
                    self.log_sync_result('full', 0, False, str(result))
                    return False
                
                users_data = result
                users_count = len(users_data)
                
                # 更新本地数据库
                with sqlite3.connect(self.db_path) as conn:
                    cursor = conn.cursor()
                    
                    # 清空现有数据（全量同步）
                    cursor.execute('DELETE FROM users')
                    
                    # 插入新数据
                    for user in users_data:
                        cursor.execute('''
                            INSERT INTO users (id, email, role, nickname, created_at, updated_at, last_sync, is_active)
                            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                        ''', (
                            user.get('id'),
                            user.get('email'),
                            user.get('role', 'Fan'),
                            user.get('nickname'),
                            user.get('created_at'),
                            user.get('updated_at'),
                            datetime.now().isoformat(),
                            1
                        ))
                    
                    conn.commit()
                
                self.last_sync = datetime.now()
                self.log_sync_result('full', users_count, True, None)
                logger.info(f"用户数据同步完成，共同步 {users_count} 个用户")
                return True
                
            except Exception as e:
                logger.error(f"同步用户数据失败: {e}")
                self.log_sync_result('full', 0, False, str(e))
                return False
    
    def get_user_by_id(self, user_id: str) -> Optional[Dict[str, Any]]:
        """通过用户ID获取用户信息"""
        try:
            with sqlite3.connect(self.db_path) as conn:
                conn.row_factory = sqlite3.Row
                cursor = conn.cursor()
                
                cursor.execute('''
                    SELECT * FROM users WHERE id = ? AND is_active = 1
                ''', (user_id,))
                
                row = cursor.fetchone()
                if row:
                    return dict(row)
                
                # 如果本地没有，尝试从Supabase获取并更新缓存
                return self.fetch_and_cache_user(user_id)
                
        except Exception as e:
            logger.error(f"获取用户信息失败: {e}")
            return None
    
    def get_user_by_email(self, email: str) -> Optional[Dict[str, Any]]:
        """通过邮箱获取用户信息"""
        try:
            with sqlite3.connect(self.db_path) as conn:
                conn.row_factory = sqlite3.Row
                cursor = conn.cursor()
                
                cursor.execute('''
                    SELECT * FROM users WHERE email = ? AND is_active = 1
                ''', (email,))
                
                row = cursor.fetchone()
                if row:
                    return dict(row)
                
                return None
                
        except Exception as e:
            logger.error(f"通过邮箱获取用户信息失败: {e}")
            return None
    
    def get_users_by_role(self, role: str, limit: int = 100) -> List[Dict[str, Any]]:
        """获取指定角色的用户列表"""
        try:
            with sqlite3.connect(self.db_path) as conn:
                conn.row_factory = sqlite3.Row
                cursor = conn.cursor()
                
                cursor.execute('''
                    SELECT * FROM users WHERE role = ? AND is_active = 1
                    ORDER BY created_at DESC LIMIT ?
                ''', (role, limit))
                
                rows = cursor.fetchall()
                return [dict(row) for row in rows]
                
        except Exception as e:
            logger.error(f"获取角色用户列表失败: {e}")
            return []
    
    def get_all_users(self, limit: int = 500) -> List[Dict[str, Any]]:
        """获取所有用户列表"""
        try:
            with sqlite3.connect(self.db_path) as conn:
                conn.row_factory = sqlite3.Row
                cursor = conn.cursor()
                
                cursor.execute('''
                    SELECT * FROM users WHERE is_active = 1
                    ORDER BY created_at DESC LIMIT ?
                ''', (limit,))
                
                rows = cursor.fetchall()
                return [dict(row) for row in rows]
                
        except Exception as e:
            logger.error(f"获取用户列表失败: {e}")
            return []
    
    def fetch_and_cache_user(self, user_id: str) -> Optional[Dict[str, Any]]:
        """从Supabase获取用户并缓存到本地"""
        try:
            # 通过Supabase客户端获取用户信息
            result = supabase_client.get_user_profile(user_id)
            
            if 'error' in result:
                return None
            
            user_data = result
            
            # 缓存到本地数据库
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                cursor.execute('''
                    INSERT OR REPLACE INTO users (id, email, role, nickname, created_at, updated_at, last_sync, is_active)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                ''', (
                    user_data.get('id'),
                    user_data.get('email'),
                    user_data.get('role', 'Fan'),
                    user_data.get('nickname'),
                    user_data.get('created_at'),
                    user_data.get('updated_at'),
                    datetime.now().isoformat(),
                    1
                ))
                
                conn.commit()
            
            return user_data
            
        except Exception as e:
            logger.error(f"获取并缓存用户失败: {e}")
            return None
    
    def invalidate_user_cache(self, user_id: str):
        """使用户缓存失效（角色更新后调用）"""
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                cursor.execute('DELETE FROM users WHERE id = ?', (user_id,))
                cursor.execute('DELETE FROM user_sessions WHERE user_id = ?', (user_id,))
                conn.commit()
                
            logger.info(f"用户 {user_id} 缓存已清除")
            
        except Exception as e:
            logger.error(f"清除用户缓存失败: {e}")
    
    def cache_user_session(self, user_id: str, jwt_hash: str, expires_at: datetime):
        """缓存用户会话信息"""
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                # 清理过期会话
                cursor.execute('''
                    DELETE FROM user_sessions WHERE expires_at < ?
                ''', (datetime.now().isoformat(),))
                
                # 添加新会话
                cursor.execute('''
                    INSERT INTO user_sessions (user_id, jwt_hash, expires_at, created_at)
                    VALUES (?, ?, ?, ?)
                ''', (user_id, jwt_hash, expires_at.isoformat(), datetime.now().isoformat()))
                
                conn.commit()
                
        except Exception as e:
            logger.error(f"缓存用户会话失败: {e}")
    
    def verify_user_session(self, user_id: str, jwt_hash: str) -> bool:
        """验证用户会话是否有效"""
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                cursor.execute('''
                    SELECT 1 FROM user_sessions 
                    WHERE user_id = ? AND jwt_hash = ? AND expires_at > ?
                ''', (user_id, jwt_hash, datetime.now().isoformat()))
                
                return cursor.fetchone() is not None
                
        except Exception as e:
            logger.error(f"验证用户会话失败: {e}")
            return False
    
    def log_sync_result(self, sync_type: str, users_count: int, success: bool, error_message: str = None):
        """记录同步结果"""
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                cursor.execute('''
                    INSERT INTO sync_logs (sync_type, users_count, success, error_message, sync_time)
                    VALUES (?, ?, ?, ?, ?)
                ''', (sync_type, users_count, success, error_message, datetime.now().isoformat()))
                
                conn.commit()
                
        except Exception as e:
            logger.error(f"记录同步日志失败: {e}")
    
    def get_sync_status(self) -> Dict[str, Any]:
        """获取同步状态"""
        try:
            with sqlite3.connect(self.db_path) as conn:
                conn.row_factory = sqlite3.Row
                cursor = conn.cursor()
                
                # 获取最近的同步记录
                cursor.execute('''
                    SELECT * FROM sync_logs ORDER BY sync_time DESC LIMIT 1
                ''', )
                
                last_sync_row = cursor.fetchone()
                
                # 获取用户统计
                cursor.execute('SELECT COUNT(*) as total FROM users WHERE is_active = 1')
                total_users = cursor.fetchone()[0]
                
                cursor.execute('''
                    SELECT role, COUNT(*) as count FROM users 
                    WHERE is_active = 1 GROUP BY role
                ''')
                role_stats = {row[0]: row[1] for row in cursor.fetchall()}
                
                return {
                    'last_sync': dict(last_sync_row) if last_sync_row else None,
                    'total_users': total_users,
                    'role_stats': role_stats,
                    'sync_interval': self.sync_interval,
                    'cache_db_path': self.db_path
                }
                
        except Exception as e:
            logger.error(f"获取同步状态失败: {e}")
            return {}
    
    def start_sync_thread(self):
        """启动后台同步线程"""
        def sync_worker():
            while True:
                try:
                    self.sync_users_from_supabase()
                    time.sleep(self.sync_interval)
                except Exception as e:
                    logger.error(f"后台同步异常: {e}")
                    time.sleep(60)  # 出错后等待1分钟再重试
        
        sync_thread = threading.Thread(target=sync_worker, daemon=True)
        sync_thread.start()
        logger.info(f"后台用户同步线程已启动，同步间隔: {self.sync_interval}秒")

# 全局用户管理器实例
user_manager = UserManager() 