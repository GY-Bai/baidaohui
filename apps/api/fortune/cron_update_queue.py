#!/usr/bin/env python3
"""
算命队列定时更新脚本
每2小时运行一次，重新计算队列排序和位置
"""

import sys
import os
import pymongo
import redis
from datetime import datetime, timedelta
from decimal import Decimal
from bson import ObjectId
import logging

# 添加项目根目录到Python路径
sys.path.append(os.path.dirname(os.path.dirname(os.path.dirname(__file__))))

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/fortune_queue_update.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# 数据库配置
MONGO_URL = "mongodb+srv://rocketadmin:ThHXoppdkygmLFhz@baidaohui-cluster.umysdas.mongodb.net/?retryWrites=true&w=majority&appName=baidaohui-Cluster"

# Redis配置
REDIS_HOST = os.getenv('REDIS_HOST', 'redis')
REDIS_PORT = int(os.getenv('REDIS_PORT', 6379))

def init_clients():
    """初始化数据库客户端"""
    try:
        # MongoDB 客户端
        mongo_client = pymongo.MongoClient(MONGO_URL)
        db = mongo_client.baidaohui
        
        # Redis 客户端
        redis_client = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, db=0, decode_responses=True)
        
        return db, redis_client
    except Exception as e:
        logger.error(f"Failed to initialize clients: {e}")
        raise

def calculate_priority_score(order):
    """计算订单优先级分数"""
    try:
        base_score = float(order['amount'])
        
        # 小孩危急加权
        if order.get('is_child_urgent', False):
            base_score *= 2.0
        
        # 时间因子（越早提交分数越高）
        created_at = order['created_at']
        if isinstance(created_at, str):
            created_at = datetime.fromisoformat(created_at.replace('Z', '+00:00'))
        
        hours_since_creation = (datetime.utcnow() - created_at).total_seconds() / 3600
        time_factor = 1.0 + (hours_since_creation * 0.1)
        
        return base_score * time_factor
    except Exception as e:
        logger.error(f"Error calculating priority score for order {order.get('_id')}: {e}")
        return 0.0

def update_queue():
    """更新算命队列"""
    try:
        db, redis_client = init_clients()
        
        logger.info("Starting queue update process...")
        
        # 获取所有排队中和处理中的订单
        orders = list(db.fortune_orders.find({
            'status': {'$in': ['queued', 'processing']},
            'payment_status': 'paid'
        }))
        
        logger.info(f"Found {len(orders)} orders in queue")
        
        if not orders:
            logger.info("No orders to process")
            return
        
        # 清空现有队列
        redis_client.delete('fortune:queue')
        
        # 重新计算优先级并添加到队列
        queue_updates = {}
        for order in orders:
            order_id = str(order['_id'])
            priority_score = calculate_priority_score(order)
            queue_updates[order_id] = priority_score
            
            # 添加到Redis队列
            redis_client.zadd('fortune:queue', {order_id: -priority_score})
        
        logger.info(f"Updated queue with {len(queue_updates)} orders")
        
        # 更新MongoDB中的队列位置信息
        queue_members = redis_client.zrange('fortune:queue', 0, -1, withscores=True)
        
        for position, (order_id, score) in enumerate(queue_members, 1):
            total_count = len(queue_members)
            percentage = (position / total_count) * 100 if total_count > 0 else 0
            
            # 更新订单的队列信息
            db.fortune_orders.update_one(
                {'_id': ObjectId(order_id)},
                {
                    '$set': {
                        'queue_position': position,
                        'queue_percentage': round(percentage, 2),
                        'updated_at': datetime.utcnow()
                    }
                }
            )
        
        logger.info("Queue positions updated in MongoDB")
        
        # 检查是否有订单需要自动处理
        check_auto_processing(db, redis_client)
        
        logger.info("Queue update completed successfully")
        
    except Exception as e:
        logger.error(f"Queue update failed: {e}")
        raise

def check_auto_processing(db, redis_client):
    """检查是否有订单需要自动处理"""
    try:
        # 获取算命设置
        settings = redis_client.hgetall('fortune:settings')
        is_enabled = settings.get('is_enabled', 'true') == 'true'
        
        if not is_enabled:
            logger.info("Fortune telling is disabled, skipping auto processing")
            return
        
        # 获取队列中的第一个订单
        next_order_id = redis_client.zrange('fortune:queue', 0, 0)
        if not next_order_id:
            logger.info("No orders in queue for auto processing")
            return
        
        order_id = next_order_id[0]
        order = db.fortune_orders.find_one({'_id': ObjectId(order_id)})
        
        if not order:
            logger.warning(f"Order {order_id} not found in database")
            return
        
        # 检查是否已经在处理中
        if order['status'] == 'processing':
            logger.info(f"Order {order_id} is already being processed")
            return
        
        # 更新订单状态为处理中
        db.fortune_orders.update_one(
            {'_id': ObjectId(order_id)},
            {
                '$set': {
                    'status': 'processing',
                    'processing_started_at': datetime.utcnow(),
                    'updated_at': datetime.utcnow()
                }
            }
        )
        
        logger.info(f"Order {order_id} marked as processing")
        
    except Exception as e:
        logger.error(f"Auto processing check failed: {e}")

def cleanup_expired_orders():
    """清理过期的未支付订单"""
    try:
        db, redis_client = init_clients()
        
        # 查找24小时前创建但未支付的订单
        cutoff_time = datetime.utcnow() - timedelta(hours=24)
        
        expired_orders = db.fortune_orders.find({
            'payment_status': 'pending',
            'created_at': {'$lt': cutoff_time}
        })
        
        expired_count = 0
        for order in expired_orders:
            order_id = str(order['_id'])
            
            # 更新订单状态为已取消
            db.fortune_orders.update_one(
                {'_id': order['_id']},
                {
                    '$set': {
                        'status': 'cancelled',
                        'cancelled_reason': 'Payment timeout',
                        'cancelled_at': datetime.utcnow(),
                        'updated_at': datetime.utcnow()
                    }
                }
            )
            
            # 从队列中移除（如果存在）
            redis_client.zrem('fortune:queue', order_id)
            
            expired_count += 1
        
        if expired_count > 0:
            logger.info(f"Cleaned up {expired_count} expired orders")
        
    except Exception as e:
        logger.error(f"Cleanup expired orders failed: {e}")

def generate_queue_report():
    """生成队列报告"""
    try:
        db, redis_client = init_clients()
        
        # 统计各状态订单数量
        stats = {}
        for status in ['pending', 'queued', 'processing', 'completed', 'refunded', 'cancelled']:
            count = db.fortune_orders.count_documents({'status': status})
            stats[status] = count
        
        # 队列长度
        queue_length = redis_client.zcard('fortune:queue')
        
        # 平均等待时间（基于最近完成的订单）
        recent_completed = list(db.fortune_orders.find({
            'status': 'completed',
            'replied_at': {'$gte': datetime.utcnow() - timedelta(days=7)}
        }).sort('replied_at', -1).limit(10))
        
        avg_wait_hours = 0
        if recent_completed:
            total_wait = sum([
                (order['replied_at'] - order['created_at']).total_seconds() / 3600
                for order in recent_completed
                if 'replied_at' in order and 'created_at' in order
            ])
            avg_wait_hours = total_wait / len(recent_completed)
        
        report = {
            'timestamp': datetime.utcnow().isoformat(),
            'queue_length': queue_length,
            'order_stats': stats,
            'avg_wait_hours': round(avg_wait_hours, 2)
        }
        
        logger.info(f"Queue report: {report}")
        
        # 保存报告到Redis（保留7天）
        redis_client.setex(
            'fortune:queue:report',
            7 * 24 * 3600,  # 7天
            str(report)
        )
        
    except Exception as e:
        logger.error(f"Generate queue report failed: {e}")

def main():
    """主函数"""
    try:
        logger.info("=== Fortune Queue Update Started ===")
        
        # 更新队列
        update_queue()
        
        # 清理过期订单
        cleanup_expired_orders()
        
        # 生成报告
        generate_queue_report()
        
        logger.info("=== Fortune Queue Update Completed ===")
        
    except Exception as e:
        logger.error(f"Queue update process failed: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()