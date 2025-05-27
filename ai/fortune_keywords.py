#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
算命关键词生成脚本
使用 Free-QwQ-32B 模型，每日限额 8000 调用，间隔 5 分钟自动执行
"""

import os
import sys
import time
import json
import logging
import requests
import schedule
from datetime import datetime, timedelta
from typing import Dict, List, Optional
import redis
from pymongo import MongoClient

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/baidaohui/ai_keywords.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

# API 配置
KW_API_BASE = "https://api.suanli.cn/v1"
KW_API_KEY = "sk-W0rpStc95T7JVYVwDYc29IyirjtpPPby6SozFMQr17m8KWeo"
MODEL_NAME = "free:QwQ-32B"

# 限制配置
DAILY_LIMIT = 8000
INTERVAL_MINUTES = 5
REDIS_KEY_PREFIX = "ai_keywords"
REDIS_DAILY_COUNT_KEY = f"{REDIS_KEY_PREFIX}:daily_count"
REDIS_LAST_CALL_KEY = f"{REDIS_KEY_PREFIX}:last_call"

class FortuneKeywordsGenerator:
    def __init__(self):
        self.api_base = KW_API_BASE
        self.api_key = KW_API_KEY
        self.model = MODEL_NAME
        
        # 初始化 Redis 连接
        self.redis_client = redis.Redis.from_url(
            os.getenv('REDIS_URL', 'redis://localhost:6379'),
            decode_responses=True
        )
        
        # 初始化 MongoDB 连接
        self.mongo_client = MongoClient(os.getenv('MONGODB_URI'))
        self.db = self.mongo_client.baidaohui
        self.fortunes_collection = self.db.fortunes
        
        # 系统提示词
        self.system_prompt = "请用不超过40个字的关键词总结下边的文字。"
        
    def check_rate_limit(self) -> bool:
        """检查是否超过调用限制"""
        try:
            # 检查今日调用次数
            today = datetime.now().strftime('%Y-%m-%d')
            daily_key = f"{REDIS_DAILY_COUNT_KEY}:{today}"
            current_count = int(self.redis_client.get(daily_key) or 0)
            
            if current_count >= DAILY_LIMIT:
                logger.warning(f"今日调用次数已达上限: {current_count}/{DAILY_LIMIT}")
                return False
            
            # 检查调用间隔
            last_call = self.redis_client.get(REDIS_LAST_CALL_KEY)
            if last_call:
                last_call_time = datetime.fromisoformat(last_call)
                time_diff = datetime.now() - last_call_time
                if time_diff.total_seconds() < INTERVAL_MINUTES * 60:
                    remaining = INTERVAL_MINUTES * 60 - time_diff.total_seconds()
                    logger.info(f"调用间隔未满，还需等待 {remaining:.0f} 秒")
                    return False
            
            return True
            
        except Exception as e:
            logger.error(f"检查限制时出错: {e}")
            return False
    
    def update_rate_limit(self):
        """更新调用限制计数"""
        try:
            # 更新今日调用次数
            today = datetime.now().strftime('%Y-%m-%d')
            daily_key = f"{REDIS_DAILY_COUNT_KEY}:{today}"
            self.redis_client.incr(daily_key)
            self.redis_client.expire(daily_key, 86400)  # 24小时过期
            
            # 更新最后调用时间
            self.redis_client.set(REDIS_LAST_CALL_KEY, datetime.now().isoformat())
            
        except Exception as e:
            logger.error(f"更新限制计数时出错: {e}")
    
    def generate_keywords(self, content: str) -> Optional[str]:
        """调用 AI API 生成关键词"""
        if not self.check_rate_limit():
            return None
        
        try:
            headers = {
                'Authorization': f'Bearer {self.api_key}',
                'Content-Type': 'application/json'
            }
            
            data = {
                "model": self.model,
                "messages": [
                    {
                        "role": "system",
                        "content": self.system_prompt
                    },
                    {
                        "role": "user",
                        "content": content
                    }
                ],
                "max_tokens": 100,
                "temperature": 0.7
            }
            
            response = requests.post(
                f"{self.api_base}/chat/completions",
                headers=headers,
                json=data,
                timeout=30
            )
            
            if response.status_code == 200:
                result = response.json()
                keywords = result['choices'][0]['message']['content'].strip()
                
                # 更新调用计数
                self.update_rate_limit()
                
                logger.info(f"成功生成关键词: {keywords[:50]}...")
                return keywords
            else:
                logger.error(f"API 调用失败: {response.status_code} - {response.text}")
                return None
                
        except Exception as e:
            logger.error(f"生成关键词时出错: {e}")
            return None
    
    def get_pending_fortunes(self) -> List[Dict]:
        """获取待处理的算命申请"""
        try:
            # 查找没有关键词的申请
            query = {
                "status": {"$in": ["Pending", "Queued-payed", "Queued-upload"]},
                "keywords": {"$exists": False}
            }
            
            fortunes = list(self.fortunes_collection.find(query).limit(10))
            logger.info(f"找到 {len(fortunes)} 个待处理的算命申请")
            return fortunes
            
        except Exception as e:
            logger.error(f"获取待处理申请时出错: {e}")
            return []
    
    def update_fortune_keywords(self, fortune_id: str, keywords: str) -> bool:
        """更新算命申请的关键词"""
        try:
            result = self.fortunes_collection.update_one(
                {"_id": fortune_id},
                {
                    "$set": {
                        "keywords": keywords,
                        "keywordsGeneratedAt": datetime.now()
                    }
                }
            )
            
            if result.modified_count > 0:
                logger.info(f"成功更新关键词: {fortune_id}")
                return True
            else:
                logger.warning(f"未找到或未更新申请: {fortune_id}")
                return False
                
        except Exception as e:
            logger.error(f"更新关键词时出错: {e}")
            return False
    
    def process_fortunes(self):
        """处理算命申请，生成关键词"""
        logger.info("开始处理算命申请...")
        
        # 获取待处理的申请
        fortunes = self.get_pending_fortunes()
        
        if not fortunes:
            logger.info("没有待处理的申请")
            return
        
        processed_count = 0
        
        for fortune in fortunes:
            try:
                # 检查是否还能调用 API
                if not self.check_rate_limit():
                    logger.info("已达调用限制，停止处理")
                    break
                
                # 生成关键词
                content = fortune.get('message', '')
                if not content:
                    logger.warning(f"申请 {fortune['_id']} 没有内容")
                    continue
                
                keywords = self.generate_keywords(content)
                if keywords:
                    # 更新数据库
                    if self.update_fortune_keywords(fortune['_id'], keywords):
                        processed_count += 1
                    
                    # 等待间隔
                    time.sleep(2)
                else:
                    logger.warning(f"为申请 {fortune['_id']} 生成关键词失败")
                    
            except Exception as e:
                logger.error(f"处理申请 {fortune.get('_id')} 时出错: {e}")
                continue
        
        logger.info(f"处理完成，共处理 {processed_count} 个申请")
    
    def get_daily_stats(self) -> Dict:
        """获取今日统计信息"""
        try:
            today = datetime.now().strftime('%Y-%m-%d')
            daily_key = f"{REDIS_DAILY_COUNT_KEY}:{today}"
            current_count = int(self.redis_client.get(daily_key) or 0)
            
            return {
                "date": today,
                "calls_used": current_count,
                "calls_remaining": max(0, DAILY_LIMIT - current_count),
                "daily_limit": DAILY_LIMIT
            }
            
        except Exception as e:
            logger.error(f"获取统计信息时出错: {e}")
            return {}
    
    def run_once(self):
        """执行一次处理"""
        try:
            stats = self.get_daily_stats()
            logger.info(f"今日统计: {stats}")
            
            if stats.get('calls_remaining', 0) > 0:
                self.process_fortunes()
            else:
                logger.info("今日调用次数已用完")
                
        except Exception as e:
            logger.error(f"执行处理时出错: {e}")
    
    def start_scheduler(self):
        """启动定时任务"""
        logger.info(f"启动关键词生成服务，间隔 {INTERVAL_MINUTES} 分钟")
        
        # 立即执行一次
        self.run_once()
        
        # 设置定时任务
        schedule.every(INTERVAL_MINUTES).minutes.do(self.run_once)
        
        while True:
            try:
                schedule.run_pending()
                time.sleep(60)  # 每分钟检查一次
            except KeyboardInterrupt:
                logger.info("收到停止信号，正在退出...")
                break
            except Exception as e:
                logger.error(f"调度器出错: {e}")
                time.sleep(60)

def main():
    """主函数"""
    try:
        generator = FortuneKeywordsGenerator()
        
        # 检查命令行参数
        if len(sys.argv) > 1:
            if sys.argv[1] == "--once":
                # 执行一次
                generator.run_once()
            elif sys.argv[1] == "--stats":
                # 显示统计信息
                stats = generator.get_daily_stats()
                print(json.dumps(stats, indent=2, ensure_ascii=False))
            else:
                print("用法: python fortune_keywords.py [--once|--stats]")
                sys.exit(1)
        else:
            # 启动定时任务
            generator.start_scheduler()
            
    except Exception as e:
        logger.error(f"程序启动失败: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main() 