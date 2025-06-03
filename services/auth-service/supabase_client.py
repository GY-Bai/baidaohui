"""
Supabase客户端模块
用于auth-service安全地调用Supabase数据库函数
避免直接数据库操作导致的RLS策略绕过和数据冲突
"""

import os
import requests
import json
import logging
from typing import Dict, Any, Optional, List
from datetime import datetime

logger = logging.getLogger(__name__)

class SupabaseClient:
    def __init__(self):
        self.base_url = os.getenv('SUPABASE_URL')
        self.service_key = os.getenv('SUPABASE_SERVICE_KEY')
        self.anon_key = os.getenv('SUPABASE_ANON_KEY')
        
        if not self.base_url or not self.service_key:
            raise ValueError("Missing required Supabase configuration")
        
        self.headers = {
            'Content-Type': 'application/json',
            'apikey': self.service_key,
            'Authorization': f'Bearer {self.service_key}'
        }
    
    def _call_rpc(self, function_name: str, params: Dict[str, Any]) -> Dict[str, Any]:
        """调用Supabase RPC函数"""
        try:
            url = f"{self.base_url}/rest/v1/rpc/{function_name}"
            
            response = requests.post(
                url,
                headers=self.headers,
                json=params,
                timeout=30
            )
            
            if response.status_code == 200:
                return response.json()
            else:
                error_data = response.json() if response.content else {}
                logger.error(f"Supabase RPC调用失败: {function_name}, 状态码: {response.status_code}, 错误: {error_data}")
                return {
                    'success': False,
                    'error': 'supabase_rpc_failed',
                    'details': error_data,
                    'status_code': response.status_code
                }
                
        except requests.exceptions.Timeout:
            logger.error(f"Supabase RPC调用超时: {function_name}")
            return {'success': False, 'error': 'timeout'}
        except Exception as e:
            logger.error(f"Supabase RPC调用异常: {function_name}, 错误: {str(e)}")
            return {'success': False, 'error': 'exception', 'details': str(e)}
    
    def upgrade_user_role_by_invite(self, user_id: str, invite_token: str) -> Dict[str, Any]:
        """通过邀请链接升级用户角色"""
        return self._call_rpc('upgrade_role', {
            'invite_token': invite_token
        })
    
    def admin_change_user_role(self, target_user_id: str, new_role: str, reason: str = '系统自动调整') -> Dict[str, Any]:
        """管理员调整用户角色（使用service key权限）"""
        return self._call_rpc('admin_change_user_role', {
            'target_user_id': target_user_id,
            'new_role': new_role,
            'reason': reason
        })
    
    def admin_change_role_by_email(self, email: str, new_role: str, reason: str = '系统自动调整') -> Dict[str, Any]:
        """通过邮箱调整用户角色"""
        return self._call_rpc('admin_change_role_by_email', {
            'target_email': email,
            'new_role': new_role,
            'reason': reason
        })
    
    def get_user_profile(self, user_id: str) -> Dict[str, Any]:
        """获取用户档案信息"""
        return self._call_rpc('get_user_profile_safe', {
            'user_id': user_id
        })
    
    def force_user_relogin(self, user_id: str, reason: str = '角色已更新') -> Dict[str, Any]:
        """标记用户需要重新登录"""
        return self._call_rpc('admin_force_user_relogin', {
            'target_user_id': user_id,
            'reason': reason
        })
    
    def create_user_profile(self, user_id: str, email: str, role: str = 'Fan', nickname: str = None) -> Dict[str, Any]:
        """创建用户档案（用于新用户注册）"""
        try:
            url = f"{self.base_url}/rest/v1/profiles"
            
            profile_data = {
                'id': user_id,
                'email': email,
                'role': role,
                'nickname': nickname or email.split('@')[0],
                'created_at': datetime.utcnow().isoformat(),
                'updated_at': datetime.utcnow().isoformat()
            }
            
            response = requests.post(
                url,
                headers=self.headers,
                json=profile_data,
                timeout=30
            )
            
            if response.status_code in [200, 201]:
                return {'success': True, 'profile': profile_data}
            else:
                error_data = response.json() if response.content else {}
                logger.error(f"创建用户档案失败: {error_data}")
                return {'success': False, 'error': 'create_profile_failed', 'details': error_data}
                
        except Exception as e:
            logger.error(f"创建用户档案异常: {str(e)}")
            return {'success': False, 'error': 'exception', 'details': str(e)}
    
    def get_invite_link_info(self, invite_token: str) -> Dict[str, Any]:
        """获取邀请链接信息"""
        try:
            url = f"{self.base_url}/rest/v1/invite_links"
            params = {
                'token': f'eq.{invite_token}',
                'is_active': 'eq.true',
                'select': 'id,type,target_role,max_uses,used_count,expires_at'
            }
            
            response = requests.get(
                url,
                headers=self.headers,
                params=params,
                timeout=30
            )
            
            if response.status_code == 200:
                links = response.json()
                if links:
                    link = links[0]
                    # 检查邀请链接是否有效
                    if (link.get('expires_at') and 
                        datetime.fromisoformat(link['expires_at'].replace('Z', '+00:00')) < datetime.utcnow()):
                        return {'success': False, 'error': 'invite_link_expired'}
                    
                    if link.get('used_count', 0) >= link.get('max_uses', 1):
                        return {'success': False, 'error': 'invite_link_exhausted'}
                    
                    return {'success': True, 'invite_link': link}
                else:
                    return {'success': False, 'error': 'invite_link_not_found'}
            else:
                return {'success': False, 'error': 'query_failed'}
                
        except Exception as e:
            logger.error(f"查询邀请链接异常: {str(e)}")
            return {'success': False, 'error': 'exception', 'details': str(e)}
    
    def use_invite_link(self, invite_token: str, user_id: str) -> Dict[str, Any]:
        """使用邀请链接（增加使用次数）"""
        return self._call_rpc('use_invite_link', {
            'invite_token': invite_token,
            'user_id': user_id
        })

# 全局实例
supabase_client = SupabaseClient() 