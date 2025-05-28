#!/usr/bin/env python3
"""
汇率更新定时任务
每周自动更新汇率并缓存到Redis
"""

import os
import sys
import time
import schedule
import requests
import redis
import json
import logging
from datetime import datetime

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/exchange_rate_updater.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

# 配置
REDIS_URL = os.getenv('REDIS_URL', 'redis://localhost:6379')
EXCHANGE_API_KEY = os.getenv('EXCHANGE_API_KEY')
EXCHANGE_RATE_CACHE_KEY = "exchange_rates"
EXCHANGE_RATE_CACHE_TTL = 7 * 24 * 60 * 60  # 7天

# 初始化Redis连接
redis_client = redis.from_url(REDIS_URL)

def fetch_exchange_rates():
    """从API获取最新汇率"""
    try:
        # 使用免费的汇率API
        response = requests.get(
            "https://api.exchangerate-api.com/v4/latest/CAD",
            timeout=30
        )
        
        if response.status_code == 200:
            rates_data = response.json()
            
            # 转换为以CAD为基准的汇率
            rates = {
                'CAD': 1.0,
                'USD': 1 / rates_data['rates']['USD'],
                'CNY': 1 / rates_data['rates']['CNY'],
                'SGD': 1 / rates_data['rates']['SGD'],
                'AUD': 1 / rates_data['rates']['AUD']
            }
            
            logger.info(f"成功获取汇率: {rates}")
            return rates
        else:
            logger.error(f"汇率API返回错误状态码: {response.status_code}")
            return None
            
    except requests.RequestException as e:
        logger.error(f"请求汇率API失败: {str(e)}")
        return None
    except Exception as e:
        logger.error(f"处理汇率数据失败: {str(e)}")
        return None

def update_exchange_rates():
    """更新汇率到Redis缓存"""
    try:
        logger.info("开始更新汇率...")
        
        # 获取最新汇率
        rates = fetch_exchange_rates()
        
        if rates:
            # 添加更新时间戳
            rates_with_timestamp = {
                'rates': rates,
                'last_updated': datetime.utcnow().isoformat(),
                'next_update': datetime.utcnow().replace(
                    hour=0, minute=0, second=0, microsecond=0
                ).isoformat()
            }
            
            # 保存到Redis
            redis_client.setex(
                EXCHANGE_RATE_CACHE_KEY,
                EXCHANGE_RATE_CACHE_TTL,
                json.dumps(rates_with_timestamp)
            )
            
            logger.info(f"汇率更新成功，已缓存到Redis: {rates}")
            
            # 发送通知到fortune-service（可选）
            try:
                fortune_service_url = os.getenv('FORTUNE_SERVICE_URL', 'http://fortune-service:5003')
                internal_api_key = os.getenv('INTERNAL_API_KEY', 'internal-secret-key')
                
                response = requests.post(
                    f"{fortune_service_url}/fortune/exchange-rates-updated",
                    json={'rates': rates, 'updated_at': datetime.utcnow().isoformat()},
                    headers={'X-Internal-Key': internal_api_key},
                    timeout=10
                )
                
                if response.status_code == 200:
                    logger.info("已通知fortune-service汇率更新")
                else:
                    logger.warning(f"通知fortune-service失败: {response.status_code}")
                    
            except Exception as e:
                logger.warning(f"通知fortune-service失败: {str(e)}")
            
            return True
        else:
            logger.error("获取汇率失败，使用默认汇率")
            
            # 使用默认汇率
            default_rates = {
                'rates': {
                    'CAD': 1.0,
                    'USD': 1.35,
                    'CNY': 0.18,
                    'SGD': 1.0,
                    'AUD': 0.9
                },
                'last_updated': datetime.utcnow().isoformat(),
                'is_default': True
            }
            
            redis_client.setex(
                EXCHANGE_RATE_CACHE_KEY,
                EXCHANGE_RATE_CACHE_TTL,
                json.dumps(default_rates)
            )
            
            logger.info("已设置默认汇率")
            return False
            
    except Exception as e:
        logger.error(f"更新汇率失败: {str(e)}")
        return False

def check_redis_connection():
    """检查Redis连接"""
    try:
        redis_client.ping()
        logger.info("Redis连接正常")
        return True
    except Exception as e:
        logger.error(f"Redis连接失败: {str(e)}")
        return False

def main():
    """主函数"""
    logger.info("汇率更新服务启动")
    
    # 检查Redis连接
    if not check_redis_connection():
        logger.error("Redis连接失败，退出程序")
        sys.exit(1)
    
    # 立即执行一次更新
    logger.info("执行初始汇率更新...")
    update_exchange_rates()
    
    # 设置定时任务：每周一凌晨2点更新
    schedule.every().monday.at("02:00").do(update_exchange_rates)
    
    # 设置备用任务：每天检查一次，如果缓存过期则更新
    def check_and_update():
        try:
            cached_data = redis_client.get(EXCHANGE_RATE_CACHE_KEY)
            if not cached_data:
                logger.info("汇率缓存已过期，执行更新...")
                update_exchange_rates()
        except Exception as e:
            logger.error(f"检查汇率缓存失败: {str(e)}")
    
    schedule.every().day.at("06:00").do(check_and_update)
    
    logger.info("定时任务已设置：")
    logger.info("- 每周一凌晨2点更新汇率")
    logger.info("- 每天早上6点检查缓存")
    
    # 运行定时任务
    while True:
        try:
            schedule.run_pending()
            time.sleep(60)  # 每分钟检查一次
        except KeyboardInterrupt:
            logger.info("收到中断信号，正在退出...")
            break
        except Exception as e:
            logger.error(f"定时任务执行失败: {str(e)}")
            time.sleep(300)  # 出错后等待5分钟再继续

if __name__ == "__main__":
    main() 