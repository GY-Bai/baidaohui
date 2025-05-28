#!/usr/bin/env python3
"""
汇率更新定时任务
每小时自动更新汇率并存储到MongoDB
"""

import os
import sys
import time
import schedule
import requests
import json
import logging
from datetime import datetime, timedelta
from pymongo import MongoClient
from dotenv import load_dotenv

# 加载环境变量
load_dotenv()

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
MONGODB_URI = os.getenv('MONGODB_URI')
EXCHANGE_RATE_API_KEY = os.getenv('EXCHANGE_RATE_API_KEY')
UPDATE_INTERVAL = int(os.getenv('UPDATE_INTERVAL', 302400))  # 默认1小时更新一次

# 初始化MongoDB连接
try:
    mongo_client = MongoClient(MONGODB_URI)
    db = mongo_client.baidaohui
    exchange_rates_collection = db.exchange_rates
    logger.info("MongoDB连接成功")
except Exception as e:
    logger.error(f"MongoDB连接失败: {str(e)}")
    sys.exit(1)

def fetch_exchange_rates():
    """从API获取最新汇率"""
    try:
        # 使用免费的汇率API
        if EXCHANGE_RATE_API_KEY:
            # 如果有API密钥，使用付费API
            url = f"https://v6.exchangerate-api.com/v6/{EXCHANGE_RATE_API_KEY}/latest/CAD"
        else:
            # 使用免费API
            url = "https://api.exchangerate-api.com/v4/latest/CAD"
        
        response = requests.get(url, timeout=30)
        
        if response.status_code == 200:
            rates_data = response.json()
            
            # 提取需要的货币汇率
            rates = {}
            if 'rates' in rates_data:
                base_rates = rates_data['rates']
                # 转换为以CAD为基准的汇率
                rates = {
                    'CAD': 1.0,
                    'USD': 1 / base_rates.get('USD', 1.35) if base_rates.get('USD') else 1.35,
                    'CNY': 1 / base_rates.get('CNY', 5.5) if base_rates.get('CNY') else 0.18,
                    'SGD': 1 / base_rates.get('SGD', 1.0) if base_rates.get('SGD') else 1.0,
                    'AUD': 1 / base_rates.get('AUD', 1.1) if base_rates.get('AUD') else 0.9
                }
            else:
                # 使用默认汇率
                rates = get_default_rates()
            
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

def get_default_rates():
    """获取默认汇率"""
    return {
        'CAD': 1.0,
        'USD': 1.35,
        'CNY': 0.18,
        'SGD': 1.0,
        'AUD': 0.9
    }

def update_exchange_rates():
    """更新汇率到MongoDB"""
    try:
        logger.info("开始更新汇率...")
        
        # 获取最新汇率
        rates = fetch_exchange_rates()
        
        if not rates:
            logger.warning("获取汇率失败，使用默认汇率")
            rates = get_default_rates()
        
        # 创建汇率文档
        exchange_rate_doc = {
            'rates': rates,
            'last_updated': datetime.utcnow(),
            'next_update': datetime.utcnow() + timedelta(seconds=UPDATE_INTERVAL),
            'is_default': rates == get_default_rates(),
            'created_at': datetime.utcnow()
        }
        
        # 保存到MongoDB
        result = exchange_rates_collection.insert_one(exchange_rate_doc)
        
        # 删除旧的汇率数据（保留最近10条记录）
        old_records = list(exchange_rates_collection.find().sort('created_at', -1).skip(10))
        if old_records:
            old_ids = [record['_id'] for record in old_records]
            exchange_rates_collection.delete_many({'_id': {'$in': old_ids}})
            logger.info(f"删除了 {len(old_ids)} 条旧汇率记录")
        
        logger.info(f"汇率更新成功，文档ID: {result.inserted_id}")
        return True
            
    except Exception as e:
        logger.error(f"更新汇率失败: {str(e)}")
        return False

def check_mongodb_connection():
    """检查MongoDB连接"""
    try:
        mongo_client.admin.command('ping')
        logger.info("MongoDB连接正常")
        return True
    except Exception as e:
        logger.error(f"MongoDB连接失败: {str(e)}")
        return False

def get_latest_exchange_rates():
    """获取最新汇率"""
    try:
        latest_rates = exchange_rates_collection.find_one(
            sort=[('created_at', -1)]
        )
        if latest_rates:
            return latest_rates['rates']
        else:
            logger.warning("数据库中没有汇率数据")
            return None
    except Exception as e:
        logger.error(f"获取汇率数据失败: {str(e)}")
        return None

def main():
    """主函数"""
    logger.info("汇率更新服务启动")
    logger.info(f"更新间隔: {UPDATE_INTERVAL} 秒")
    
    # 检查MongoDB连接
    if not check_mongodb_connection():
        logger.error("MongoDB连接失败，退出程序")
        sys.exit(1)
    
    # 立即执行一次更新
    logger.info("执行初始汇率更新...")
    update_exchange_rates()
    
    # 设置定时任务：根据UPDATE_INTERVAL更新
    if UPDATE_INTERVAL >= 3600:  # 1小时或更长
        # 每小时更新
        schedule.every().hour.do(update_exchange_rates)
        logger.info("定时任务已设置：每小时更新汇率")
    elif UPDATE_INTERVAL >= 1800:  # 30分钟或更长
        # 每30分钟更新
        schedule.every(30).minutes.do(update_exchange_rates)
        logger.info("定时任务已设置：每30分钟更新汇率")
    else:
        # 每10分钟更新（最小间隔）
        schedule.every(10).minutes.do(update_exchange_rates)
        logger.info("定时任务已设置：每10分钟更新汇率")
    
    # 健康检查任务：每天检查一次数据库连接
    schedule.every().day.at("06:00").do(check_mongodb_connection)
    
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