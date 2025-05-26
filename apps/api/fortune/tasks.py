"""
Celery 任务定义
用于异步处理算命申请的AI关键词生成
"""

from celery import Celery
import pymongo
import redis
from datetime import datetime
from bson import ObjectId
import logging
from typing import Optional
import json

# 导入AI服务
try:
    from .services.ernie_kw import generate_keywords, AIServiceError, RateLimitExceeded
except ImportError:
    from services.ernie_kw import generate_keywords, AIServiceError, RateLimitExceeded

# 配置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# 数据库配置
MONGO_URL = "mongodb+srv://rocketadmin:ThHXoppdkygmLFhz@baidaohui-cluster.umysdas.mongodb.net/?retryWrites=true&w=majority&appName=baidaohui-Cluster"

# 初始化Celery
celery_app = Celery('fortune_tasks')

# Celery配置
celery_app.conf.update(
    broker_url='redis://redis:6379/1',  # 使用Redis作为消息代理
    result_backend='redis://redis:6379/2',  # 使用Redis存储结果
    task_serializer='json',
    accept_content=['json'],
    result_serializer='json',
    timezone='UTC',
    enable_utc=True,
    
    # 任务路由配置
    task_routes={
        'apps.api.fortune.tasks.generate_keywords': {'queue': 'ai_keywords'},
        'apps.api.fortune.tasks.retry_failed_keywords': {'queue': 'ai_retry'},
    },
    
    # 重试配置
    task_acks_late=True,
    worker_prefetch_multiplier=1,
    
    # 死信队列配置
    task_reject_on_worker_lost=True,
    task_ignore_result=False,
    
    # 任务过期时间
    task_soft_time_limit=300,  # 5分钟软限制
    task_time_limit=600,       # 10分钟硬限制
)

# 初始化数据库连接
def get_db_connection():
    """获取MongoDB连接"""
    try:
        mongo_client = pymongo.MongoClient(MONGO_URL)
        return mongo_client.baidaohui
    except Exception as e:
        logger.error(f"Failed to connect to MongoDB: {e}")
        raise

def get_redis_connection():
    """获取Redis连接"""
    try:
        return redis.Redis(host='redis', port=6379, db=0, decode_responses=True)
    except Exception as e:
        logger.error(f"Failed to connect to Redis: {e}")
        raise

@celery_app.task(bind=True, max_retries=3, default_retry_delay=300)
def generate_keywords_task(self, order_id: str, description: str) -> dict:
    """
    异步生成AI关键词任务
    
    Args:
        order_id: 订单ID
        description: 用户描述文本
        
    Returns:
        任务执行结果字典
    """
    try:
        logger.info(f"Starting keyword generation for order {order_id}")
        
        # 获取数据库连接
        db = get_db_connection()
        
        # 检查订单是否存在
        order = db.fortune_orders.find_one({'_id': ObjectId(order_id)})
        if not order:
            logger.error(f"Order {order_id} not found")
            return {
                'success': False,
                'error': 'Order not found',
                'order_id': order_id
            }
        
        # 检查是否已经生成过关键词
        if order.get('ai_keywords'):
            logger.info(f"Keywords already exist for order {order_id}")
            return {
                'success': True,
                'keywords': order['ai_keywords'],
                'order_id': order_id,
                'cached': True
            }
        
        # 调用AI服务生成关键词
        try:
            keywords = generate_keywords(description)
            
            # 更新订单记录
            db.fortune_orders.update_one(
                {'_id': ObjectId(order_id)},
                {
                    '$set': {
                        'ai_keywords': keywords,
                        'ai_generated_at': datetime.utcnow(),
                        'updated_at': datetime.utcnow()
                    }
                }
            )
            
            logger.info(f"Keywords generated successfully for order {order_id}: {keywords}")
            
            return {
                'success': True,
                'keywords': keywords,
                'order_id': order_id,
                'cached': False
            }
            
        except RateLimitExceeded as e:
            logger.warning(f"Rate limit exceeded for order {order_id}: {e}")
            
            # 速率限制时延迟重试
            raise self.retry(countdown=900, exc=e)  # 15分钟后重试
            
        except AIServiceError as e:
            logger.error(f"AI service error for order {order_id}: {e}")
            
            # AI服务错误时重试
            if self.request.retries < self.max_retries:
                # 指数退避重试
                countdown = 60 * (2 ** self.request.retries)
                raise self.retry(countdown=countdown, exc=e)
            else:
                # 达到最大重试次数，记录到死信队列
                add_to_dead_letter_queue(order_id, description, str(e))
                return {
                    'success': False,
                    'error': str(e),
                    'order_id': order_id,
                    'max_retries_reached': True
                }
        
    except Exception as e:
        logger.error(f"Unexpected error in keyword generation task for order {order_id}: {e}")
        
        # 其他异常也进行重试
        if self.request.retries < self.max_retries:
            countdown = 60 * (2 ** self.request.retries)
            raise self.retry(countdown=countdown, exc=e)
        else:
            add_to_dead_letter_queue(order_id, description, str(e))
            return {
                'success': False,
                'error': str(e),
                'order_id': order_id,
                'max_retries_reached': True
            }

@celery_app.task
def retry_failed_keywords_task() -> dict:
    """
    重试失败的关键词生成任务
    定期执行，处理死信队列中的任务
    
    Returns:
        处理结果统计
    """
    try:
        logger.info("Starting retry of failed keyword generation tasks")
        
        redis_client = get_redis_connection()
        
        # 获取死信队列中的任务
        failed_tasks = redis_client.lrange('ai:dead_letter_queue', 0, 9)  # 一次处理10个
        
        if not failed_tasks:
            logger.info("No failed tasks to retry")
            return {
                'success': True,
                'processed': 0,
                'retried': 0,
                'failed': 0
            }
        
        processed = 0
        retried = 0
        failed = 0
        
        for task_data in failed_tasks:
            try:
                task_info = json.loads(task_data)
                order_id = task_info['order_id']
                description = task_info['description']
                
                # 重新提交任务
                result = generate_keywords_task.delay(order_id, description)
                
                # 从死信队列中移除
                redis_client.lrem('ai:dead_letter_queue', 1, task_data)
                
                retried += 1
                logger.info(f"Retried keyword generation for order {order_id}")
                
            except Exception as e:
                logger.error(f"Failed to retry task {task_data}: {e}")
                failed += 1
            
            processed += 1
        
        logger.info(f"Retry completed: processed={processed}, retried={retried}, failed={failed}")
        
        return {
            'success': True,
            'processed': processed,
            'retried': retried,
            'failed': failed
        }
        
    except Exception as e:
        logger.error(f"Error in retry failed keywords task: {e}")
        return {
            'success': False,
            'error': str(e)
        }

@celery_app.task
def cleanup_old_tasks() -> dict:
    """
    清理过期的任务结果和死信队列
    
    Returns:
        清理结果统计
    """
    try:
        logger.info("Starting cleanup of old tasks")
        
        redis_client = get_redis_connection()
        
        # 清理超过7天的死信队列项目
        dead_letter_items = redis_client.lrange('ai:dead_letter_queue', 0, -1)
        cleaned_dead_letter = 0
        
        for item in dead_letter_items:
            try:
                task_info = json.loads(item)
                created_at = datetime.fromisoformat(task_info.get('created_at', ''))
                
                # 如果超过7天，则移除
                if (datetime.utcnow() - created_at).days > 7:
                    redis_client.lrem('ai:dead_letter_queue', 1, item)
                    cleaned_dead_letter += 1
                    
            except Exception as e:
                logger.error(f"Error processing dead letter item {item}: {e}")
                # 移除无效的项目
                redis_client.lrem('ai:dead_letter_queue', 1, item)
                cleaned_dead_letter += 1
        
        # 清理过期的速率限制键
        cleaned_rate_limit = 0
        for key in redis_client.scan_iter(match='ai:daily:*'):
            # 检查键是否过期（超过2天的日期键）
            try:
                date_str = key.split(':')[-1]
                key_date = datetime.strptime(date_str, '%Y-%m-%d')
                if (datetime.utcnow() - key_date).days > 2:
                    redis_client.delete(key)
                    cleaned_rate_limit += 1
            except Exception:
                # 删除格式不正确的键
                redis_client.delete(key)
                cleaned_rate_limit += 1
        
        logger.info(f"Cleanup completed: dead_letter={cleaned_dead_letter}, rate_limit={cleaned_rate_limit}")
        
        return {
            'success': True,
            'cleaned_dead_letter': cleaned_dead_letter,
            'cleaned_rate_limit': cleaned_rate_limit
        }
        
    except Exception as e:
        logger.error(f"Error in cleanup task: {e}")
        return {
            'success': False,
            'error': str(e)
        }

def add_to_dead_letter_queue(order_id: str, description: str, error: str):
    """
    将失败的任务添加到死信队列
    
    Args:
        order_id: 订单ID
        description: 描述文本
        error: 错误信息
    """
    try:
        redis_client = get_redis_connection()
        
        task_info = {
            'order_id': order_id,
            'description': description,
            'error': error,
            'created_at': datetime.utcnow().isoformat(),
            'retry_count': 0
        }
        
        redis_client.lpush('ai:dead_letter_queue', json.dumps(task_info))
        
        # 限制死信队列长度
        redis_client.ltrim('ai:dead_letter_queue', 0, 999)  # 保留最新的1000个
        
        logger.info(f"Added order {order_id} to dead letter queue")
        
    except Exception as e:
        logger.error(f"Failed to add to dead letter queue: {e}")

def get_task_statistics() -> dict:
    """
    获取任务统计信息
    
    Returns:
        统计信息字典
    """
    try:
        redis_client = get_redis_connection()
        db = get_db_connection()
        
        # 统计订单中的AI关键词生成情况
        total_orders = db.fortune_orders.count_documents({})
        orders_with_keywords = db.fortune_orders.count_documents({'ai_keywords': {'$exists': True, '$ne': None}})
        orders_without_keywords = total_orders - orders_with_keywords
        
        # 统计死信队列长度
        dead_letter_count = redis_client.llen('ai:dead_letter_queue')
        
        # 获取速率限制状态
        from .services.ernie_kw import get_rate_limit_status
        rate_limit_status = get_rate_limit_status()
        
        return {
            'orders': {
                'total': total_orders,
                'with_keywords': orders_with_keywords,
                'without_keywords': orders_without_keywords,
                'completion_rate': round((orders_with_keywords / total_orders * 100), 2) if total_orders > 0 else 0
            },
            'dead_letter_queue': {
                'count': dead_letter_count
            },
            'rate_limit': rate_limit_status
        }
        
    except Exception as e:
        logger.error(f"Error getting task statistics: {e}")
        return {
            'error': str(e)
        }

# 定期任务配置
from celery.schedules import crontab

celery_app.conf.beat_schedule = {
    # 每小时重试失败的任务
    'retry-failed-keywords': {
        'task': 'apps.api.fortune.tasks.retry_failed_keywords_task',
        'schedule': crontab(minute=0),  # 每小时的0分执行
    },
    
    # 每天凌晨清理过期任务
    'cleanup-old-tasks': {
        'task': 'apps.api.fortune.tasks.cleanup_old_tasks',
        'schedule': crontab(hour=2, minute=0),  # 每天凌晨2点执行
    },
}

# 为了向后兼容，保留原来的函数名
def generate_keywords(order_id: str, description: str):
    """
    生成关键词的便捷函数（异步）
    
    Args:
        order_id: 订单ID
        description: 描述文本
        
    Returns:
        Celery AsyncResult对象
    """
    return generate_keywords_task.delay(order_id, description)

if __name__ == '__main__':
    # 测试脚本
    print("Testing Celery tasks...")
    
    # 获取统计信息
    stats = get_task_statistics()
    print(f"Task statistics: {json.dumps(stats, indent=2, ensure_ascii=False)}")
    
    # 测试任务提交（需要Celery worker运行）
    # result = generate_keywords_task.delay("test_order_id", "测试描述文本")
    # print(f"Task submitted: {result.id}") 