"""
用户账号同步处理模块
负责将OAuth登录的用户信息同步到本地数据库，实现多平台账号统一管理
"""

import logging
from datetime import datetime
from typing import Dict, Optional, Any
import pymongo
from pymongo import MongoClient
import os

logger = logging.getLogger(__name__)

class UserSyncService:
    def __init__(self):
        self.mongodb_uri = os.getenv('MONGODB_URI')
        self.client = MongoClient(self.mongodb_uri) if self.mongodb_uri else None
        self.db = self.client.baidaohui if self.client else None
        self.users_collection = self.db.users if self.db else None
        
    def sync_user_from_oauth(self, oauth_data: Dict[str, Any], provider: str = 'google') -> Dict[str, Any]:
        """
        从OAuth提供商同步用户信息到本地数据库
        
        Args:
            oauth_data: OAuth提供商返回的用户数据
            provider: OAuth提供商名称 (google, facebook, etc.)
            
        Returns:
            同步后的用户信息
        """
        try:
            user_id = oauth_data.get('id')
            email = oauth_data.get('email')
            
            if not user_id or not email:
                raise ValueError("缺少必要的用户信息")
            
            # 检查用户是否已存在
            existing_user = self.get_user_by_oauth_id(user_id, provider)
            
            if existing_user:
                # 更新现有用户信息
                updated_user = self.update_user_info(existing_user, oauth_data, provider)
                logger.info(f"更新用户信息: {email}")
                return updated_user
            else:
                # 检查是否有相同邮箱的用户（可能来自其他平台）
                existing_email_user = self.get_user_by_email(email)
                
                if existing_email_user:
                    # 关联新的OAuth账号到现有用户
                    linked_user = self.link_oauth_account(existing_email_user, oauth_data, provider)
                    logger.info(f"关联OAuth账号到现有用户: {email}")
                    return linked_user
                else:
                    # 创建新用户
                    new_user = self.create_new_user(oauth_data, provider)
                    logger.info(f"创建新用户: {email}")
                    return new_user
                    
        except Exception as e:
            logger.error(f"用户同步失败: {str(e)}")
            raise
    
    def get_user_by_oauth_id(self, oauth_id: str, provider: str) -> Optional[Dict]:
        """根据OAuth ID查找用户"""
        if not self.users_collection:
            return None
            
        return self.users_collection.find_one({
            f"oauth_accounts.{provider}.id": oauth_id
        })
    
    def get_user_by_email(self, email: str) -> Optional[Dict]:
        """根据邮箱查找用户"""
        if not self.users_collection:
            return None
            
        return self.users_collection.find_one({"email": email})
    
    def create_new_user(self, oauth_data: Dict[str, Any], provider: str) -> Dict[str, Any]:
        """创建新用户"""
        if not self.users_collection:
            raise Exception("数据库连接失败")
        
        user_id = oauth_data.get('id')
        email = oauth_data.get('email')
        name = oauth_data.get('name', '')
        avatar_url = oauth_data.get('avatar_url', '')
        
        # 生成本地用户ID
        local_user_id = f"user_{datetime.utcnow().strftime('%Y%m%d%H%M%S')}_{user_id[:8]}"
        
        new_user = {
            "_id": local_user_id,
            "email": email,
            "name": name,
            "nickname": name.split(' ')[0] if name else email.split('@')[0],
            "avatar_url": avatar_url,
            "role": "Fan",  # 默认角色
            "status": "active",
            "oauth_accounts": {
                provider: {
                    "id": user_id,
                    "email": email,
                    "name": name,
                    "avatar_url": avatar_url,
                    "linked_at": datetime.utcnow(),
                    "last_login": datetime.utcnow()
                }
            },
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow(),
            "last_login": datetime.utcnow(),
            "login_count": 1,
            "preferences": {
                "language": "zh-CN",
                "timezone": "Asia/Shanghai",
                "notifications": {
                    "email": True,
                    "push": True
                }
            },
            "metadata": {}
        }
        
        result = self.users_collection.insert_one(new_user)
        new_user["_id"] = str(result.inserted_id)
        
        return new_user
    
    def update_user_info(self, existing_user: Dict, oauth_data: Dict[str, Any], provider: str) -> Dict[str, Any]:
        """更新现有用户信息"""
        if not self.users_collection:
            raise Exception("数据库连接失败")
        
        user_id = oauth_data.get('id')
        email = oauth_data.get('email')
        name = oauth_data.get('name', '')
        avatar_url = oauth_data.get('avatar_url', '')
        
        # 更新OAuth账号信息
        update_data = {
            "$set": {
                f"oauth_accounts.{provider}.last_login": datetime.utcnow(),
                f"oauth_accounts.{provider}.name": name,
                f"oauth_accounts.{provider}.avatar_url": avatar_url,
                "last_login": datetime.utcnow(),
                "updated_at": datetime.utcnow()
            },
            "$inc": {
                "login_count": 1
            }
        }
        
        # 如果用户信息有更新，也同步更新
        if name and name != existing_user.get('name', ''):
            update_data["$set"]["name"] = name
        
        if avatar_url and avatar_url != existing_user.get('avatar_url', ''):
            update_data["$set"]["avatar_url"] = avatar_url
        
        self.users_collection.update_one(
            {"_id": existing_user["_id"]},
            update_data
        )
        
        # 返回更新后的用户信息
        return self.users_collection.find_one({"_id": existing_user["_id"]})
    
    def link_oauth_account(self, existing_user: Dict, oauth_data: Dict[str, Any], provider: str) -> Dict[str, Any]:
        """将新的OAuth账号关联到现有用户"""
        if not self.users_collection:
            raise Exception("数据库连接失败")
        
        user_id = oauth_data.get('id')
        email = oauth_data.get('email')
        name = oauth_data.get('name', '')
        avatar_url = oauth_data.get('avatar_url', '')
        
        # 添加新的OAuth账号
        update_data = {
            "$set": {
                f"oauth_accounts.{provider}": {
                    "id": user_id,
                    "email": email,
                    "name": name,
                    "avatar_url": avatar_url,
                    "linked_at": datetime.utcnow(),
                    "last_login": datetime.utcnow()
                },
                "last_login": datetime.utcnow(),
                "updated_at": datetime.utcnow()
            },
            "$inc": {
                "login_count": 1
            }
        }
        
        self.users_collection.update_one(
            {"_id": existing_user["_id"]},
            update_data
        )
        
        logger.info(f"成功关联 {provider} 账号到用户 {existing_user['email']}")
        
        # 返回更新后的用户信息
        return self.users_collection.find_one({"_id": existing_user["_id"]})
    
    def get_user_profile(self, user_id: str) -> Optional[Dict]:
        """获取用户完整档案"""
        if not self.users_collection:
            return None
            
        user = self.users_collection.find_one({"_id": user_id})
        if user:
            # 移除敏感信息
            user.pop('oauth_accounts', None)
            return user
        return None
    
    def update_user_role(self, user_id: str, new_role: str) -> bool:
        """更新用户角色"""
        if not self.users_collection:
            return False
        
        valid_roles = ['Fan', 'Member', 'Master', 'Firstmate', 'Seller']
        if new_role not in valid_roles:
            raise ValueError(f"无效的角色: {new_role}")
        
        result = self.users_collection.update_one(
            {"_id": user_id},
            {
                "$set": {
                    "role": new_role,
                    "updated_at": datetime.utcnow()
                }
            }
        )
        
        return result.modified_count > 0
    
    def get_user_statistics(self) -> Dict[str, Any]:
        """获取用户统计信息"""
        if not self.users_collection:
            return {}
        
        pipeline = [
            {
                "$group": {
                    "_id": "$role",
                    "count": {"$sum": 1}
                }
            }
        ]
        
        role_stats = list(self.users_collection.aggregate(pipeline))
        
        total_users = self.users_collection.count_documents({})
        active_users = self.users_collection.count_documents({"status": "active"})
        
        return {
            "total_users": total_users,
            "active_users": active_users,
            "role_distribution": {stat["_id"]: stat["count"] for stat in role_stats}
        }

# 全局用户同步服务实例
user_sync_service = UserSyncService() 