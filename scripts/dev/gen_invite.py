#!/usr/bin/env python3
"""
CLI 工具：快速生成邀请码（调试用）
用法：python gen_invite.py --hours 24 --max-uses 10 --creator master
"""

import argparse
import sys
import os
import secrets
import string
from datetime import datetime, timedelta
import pymongo
from bson import ObjectId

# 添加项目根目录到Python路径
sys.path.append(os.path.join(os.path.dirname(__file__), '..', '..'))

# MongoDB配置
MONGO_URL = os.getenv("MONGO_URL", "mongodb://localhost:27017/baidaohui")

def generate_invite_code(length=8):
    """生成随机邀请码"""
    characters = string.ascii_letters + string.digits
    return ''.join(secrets.choice(characters) for _ in range(length))

def create_invite_link(hours=24, max_uses=10, creator_role='master'):
    """创建邀请链接"""
    try:
        # 连接MongoDB
        client = pymongo.MongoClient(MONGO_URL)
        db = client.baidaohui
        
        # 生成邀请码
        invite_code = generate_invite_code()
        
        # 检查是否已存在
        while db.invite_links.find_one({'code': invite_code}):
            invite_code = generate_invite_code()
        
        # 计算过期时间
        expires_at = datetime.utcnow() + timedelta(hours=hours)
        
        # 创建邀请链接记录
        invite_data = {
            'code': invite_code,
            'created_by': f'debug_{creator_role}',
            'created_by_role': creator_role,
            'max_uses': max_uses,
            'used_count': 0,
            'expires_at': expires_at,
            'created_at': datetime.utcnow(),
            'is_active': True,
            'used_by': []
        }
        
        # 插入数据库
        result = db.invite_links.insert_one(invite_data)
        
        # 生成完整链接
        invite_url = f"https://baiduohui.com?invite={invite_code}"
        
        print(f"✅ 邀请链接创建成功！")
        print(f"📋 邀请码: {invite_code}")
        print(f"🔗 完整链接: {invite_url}")
        print(f"⏰ 有效期: {hours}小时 (到期时间: {expires_at.strftime('%Y-%m-%d %H:%M:%S')} UTC)")
        print(f"👥 最大使用次数: {max_uses}")
        print(f"👤 创建者角色: {creator_role}")
        print(f"🆔 数据库ID: {result.inserted_id}")
        
        return invite_code, invite_url
        
    except Exception as e:
        print(f"❌ 创建邀请链接失败: {e}")
        return None, None
    finally:
        if 'client' in locals():
            client.close()

def list_active_invites():
    """列出所有活跃的邀请链接"""
    try:
        client = pymongo.MongoClient(MONGO_URL)
        db = client.baidaohui
        
        # 查询活跃的邀请链接
        invites = db.invite_links.find({
            'is_active': True,
            'expires_at': {'$gt': datetime.utcnow()}
        }).sort('created_at', -1)
        
        print("📋 活跃的邀请链接:")
        print("-" * 80)
        
        for invite in invites:
            status = "有效"
            if invite['used_count'] >= invite['max_uses']:
                status = "已用完"
            elif invite['expires_at'] < datetime.utcnow():
                status = "已过期"
            
            remaining_uses = max(0, invite['max_uses'] - invite['used_count'])
            
            print(f"代码: {invite['code']}")
            print(f"链接: https://baiduohui.com?invite={invite['code']}")
            print(f"状态: {status}")
            print(f"剩余使用次数: {remaining_uses}/{invite['max_uses']}")
            print(f"创建者: {invite.get('created_by', 'unknown')} ({invite.get('created_by_role', 'unknown')})")
            print(f"创建时间: {invite['created_at'].strftime('%Y-%m-%d %H:%M:%S')} UTC")
            print(f"过期时间: {invite['expires_at'].strftime('%Y-%m-%d %H:%M:%S')} UTC")
            print("-" * 80)
        
    except Exception as e:
        print(f"❌ 查询邀请链接失败: {e}")
    finally:
        if 'client' in locals():
            client.close()

def deactivate_invite(invite_code):
    """停用邀请链接"""
    try:
        client = pymongo.MongoClient(MONGO_URL)
        db = client.baidaohui
        
        result = db.invite_links.update_one(
            {'code': invite_code},
            {'$set': {'is_active': False, 'updated_at': datetime.utcnow()}}
        )
        
        if result.matched_count > 0:
            print(f"✅ 邀请码 {invite_code} 已停用")
        else:
            print(f"❌ 未找到邀请码 {invite_code}")
            
    except Exception as e:
        print(f"❌ 停用邀请链接失败: {e}")
    finally:
        if 'client' in locals():
            client.close()

def cleanup_expired_invites():
    """清理过期的邀请链接"""
    try:
        client = pymongo.MongoClient(MONGO_URL)
        db = client.baidaohui
        
        # 停用过期的邀请链接
        result = db.invite_links.update_many(
            {
                'expires_at': {'$lt': datetime.utcnow()},
                'is_active': True
            },
            {'$set': {'is_active': False, 'updated_at': datetime.utcnow()}}
        )
        
        print(f"✅ 已清理 {result.modified_count} 个过期的邀请链接")
        
    except Exception as e:
        print(f"❌ 清理过期邀请链接失败: {e}")
    finally:
        if 'client' in locals():
            client.close()

def main():
    parser = argparse.ArgumentParser(description='百刀会邀请链接管理工具')
    subparsers = parser.add_subparsers(dest='command', help='可用命令')
    
    # 创建邀请链接
    create_parser = subparsers.add_parser('create', help='创建新的邀请链接')
    create_parser.add_argument('--hours', type=int, default=24, help='有效期（小时），默认24小时')
    create_parser.add_argument('--max-uses', type=int, default=10, help='最大使用次数，默认10次')
    create_parser.add_argument('--creator', choices=['master', 'firstmate'], default='master', help='创建者角色')
    
    # 列出邀请链接
    list_parser = subparsers.add_parser('list', help='列出所有活跃的邀请链接')
    
    # 停用邀请链接
    deactivate_parser = subparsers.add_parser('deactivate', help='停用指定的邀请链接')
    deactivate_parser.add_argument('code', help='要停用的邀请码')
    
    # 清理过期邀请链接
    cleanup_parser = subparsers.add_parser('cleanup', help='清理过期的邀请链接')
    
    args = parser.parse_args()
    
    if args.command == 'create':
        create_invite_link(args.hours, args.max_uses, args.creator)
    elif args.command == 'list':
        list_active_invites()
    elif args.command == 'deactivate':
        deactivate_invite(args.code)
    elif args.command == 'cleanup':
        cleanup_expired_invites()
    else:
        parser.print_help()

if __name__ == '__main__':
    main() 