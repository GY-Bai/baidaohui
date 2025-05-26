"""
AI 关键词生成服务
使用FREE-QWQ模型生成算命申请关键词
包含重试机制和速率限制（5分钟节流）
"""

import requests
import time
import json
import logging
from datetime import datetime, timedelta
from typing import Optional, Dict, Any
import redis
from functools import wraps
import os

# 配置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# AI API 配置
KW_API_BASE = "https://api.suanli.cn/v1"
KW_API_KEY = "sk-W0rpStc95T7JVYVwDYc29IyirjtpPPby6SozFMQr17m8KWeo"
MODEL_NAME = "free:QwQ-32B"

# 速率限制配置
RATE_LIMIT_WINDOW = 300  # 5分钟
MAX_REQUESTS_PER_WINDOW = 10  # 每5分钟最多10次请求
DAILY_LIMIT = 8000  # 每日限制8000次

# Redis配置
REDIS_HOST = os.getenv('REDIS_HOST', 'redis')
REDIS_PORT = int(os.getenv('REDIS_PORT', 6379))
redis_client = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, db=0, decode_responses=True)

class AIServiceError(Exception):
    """AI服务异常"""
    pass

class RateLimitExceeded(AIServiceError):
    """速率限制超出异常"""
    pass

def rate_limit(func):
    """速率限制装饰器"""
    @wraps(func)
    def wrapper(*args, **kwargs):
        now = datetime.now()
        
        # 检查每日限制
        daily_key = f"ai:daily:{now.strftime('%Y-%m-%d')}"
        daily_count = redis_client.get(daily_key)
        if daily_count and int(daily_count) >= DAILY_LIMIT:
            raise RateLimitExceeded(f"Daily limit of {DAILY_LIMIT} requests exceeded")
        
        # 检查5分钟窗口限制
        window_key = f"ai:window:{now.strftime('%Y-%m-%d-%H-%M')[:-1]}0"  # 5分钟窗口
        window_count = redis_client.get(window_key)
        if window_count and int(window_count) >= MAX_REQUESTS_PER_WINDOW:
            raise RateLimitExceeded(f"Rate limit of {MAX_REQUESTS_PER_WINDOW} requests per 5 minutes exceeded")
        
        # 执行函数
        result = func(*args, **kwargs)
        
        # 更新计数器
        redis_client.incr(daily_key)
        redis_client.expire(daily_key, 86400)  # 24小时过期
        
        redis_client.incr(window_key)
        redis_client.expire(window_key, RATE_LIMIT_WINDOW)  # 5分钟过期
        
        return result
    
    return wrapper

def retry_on_failure(max_retries: int = 3, delay: float = 1.0, backoff: float = 2.0):
    """重试装饰器"""
    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            last_exception = None
            
            for attempt in range(max_retries + 1):
                try:
                    return func(*args, **kwargs)
                except (requests.RequestException, AIServiceError) as e:
                    last_exception = e
                    if attempt < max_retries:
                        wait_time = delay * (backoff ** attempt)
                        logger.warning(f"Attempt {attempt + 1} failed: {e}. Retrying in {wait_time:.2f}s...")
                        time.sleep(wait_time)
                    else:
                        logger.error(f"All {max_retries + 1} attempts failed. Last error: {e}")
            
            raise last_exception
        
        return wrapper
    return decorator

@rate_limit
@retry_on_failure(max_retries=3, delay=2.0, backoff=2.0)
def generate_keywords(description: str) -> str:
    """
    生成关键词
    
    Args:
        description: 用户描述文本
        
    Returns:
        生成的关键词字符串
        
    Raises:
        AIServiceError: AI服务调用失败
        RateLimitExceeded: 速率限制超出
    """
    try:
        # 构建prompt
        prompt = f"请用不超过40个字的关键词总结下边的文字。{description}"
        
        # 构建请求数据
        request_data = {
            "model": MODEL_NAME,
            "messages": [
                {
                    "role": "user",
                    "content": prompt
                }
            ],
            "max_tokens": 100,
            "temperature": 0.7,
            "top_p": 0.9
        }
        
        # 发送请求
        headers = {
            'Authorization': f'Bearer {KW_API_KEY}',
            'Content-Type': 'application/json'
        }
        
        logger.info(f"Sending AI request for description: {description[:50]}...")
        
        response = requests.post(
            f"{KW_API_BASE}/chat/completions",
            headers=headers,
            json=request_data,
            timeout=30
        )
        
        # 检查响应状态
        if response.status_code == 429:
            raise RateLimitExceeded("API rate limit exceeded")
        elif response.status_code != 200:
            raise AIServiceError(f"API request failed with status {response.status_code}: {response.text}")
        
        # 解析响应
        response_data = response.json()
        
        if 'choices' not in response_data or not response_data['choices']:
            raise AIServiceError("Invalid API response: no choices found")
        
        content = response_data['choices'][0].get('message', {}).get('content', '').strip()
        
        if not content:
            raise AIServiceError("Empty response from AI model")
        
        # 清理和验证关键词
        keywords = clean_keywords(content)
        
        logger.info(f"Generated keywords: {keywords}")
        
        return keywords
        
    except requests.Timeout:
        raise AIServiceError("Request timeout")
    except requests.RequestException as e:
        raise AIServiceError(f"Request failed: {e}")
    except json.JSONDecodeError as e:
        raise AIServiceError(f"Invalid JSON response: {e}")
    except Exception as e:
        raise AIServiceError(f"Unexpected error: {e}")

def clean_keywords(raw_keywords: str) -> str:
    """
    清理和验证关键词
    
    Args:
        raw_keywords: 原始关键词字符串
        
    Returns:
        清理后的关键词字符串
    """
    try:
        # 移除多余的空白字符
        keywords = raw_keywords.strip()
        
        # 移除可能的引号
        if keywords.startswith('"') and keywords.endswith('"'):
            keywords = keywords[1:-1]
        if keywords.startswith("'") and keywords.endswith("'"):
            keywords = keywords[1:-1]
        
        # 限制长度（最多40个字符）
        if len(keywords) > 40:
            keywords = keywords[:40]
            # 尝试在最后一个标点符号处截断
            for i in range(len(keywords) - 1, -1, -1):
                if keywords[i] in '，。、；':
                    keywords = keywords[:i + 1]
                    break
        
        # 移除开头和结尾的标点符号
        keywords = keywords.strip('，。、；：！？')
        
        return keywords
        
    except Exception as e:
        logger.error(f"Error cleaning keywords: {e}")
        return raw_keywords[:40]  # 返回截断的原始字符串

def get_rate_limit_status() -> Dict[str, Any]:
    """
    获取当前速率限制状态
    
    Returns:
        包含速率限制信息的字典
    """
    try:
        now = datetime.now()
        
        # 获取每日使用量
        daily_key = f"ai:daily:{now.strftime('%Y-%m-%d')}"
        daily_count = int(redis_client.get(daily_key) or 0)
        
        # 获取当前5分钟窗口使用量
        window_key = f"ai:window:{now.strftime('%Y-%m-%d-%H-%M')[:-1]}0"
        window_count = int(redis_client.get(window_key) or 0)
        
        # 计算剩余配额
        daily_remaining = max(0, DAILY_LIMIT - daily_count)
        window_remaining = max(0, MAX_REQUESTS_PER_WINDOW - window_count)
        
        return {
            'daily': {
                'used': daily_count,
                'limit': DAILY_LIMIT,
                'remaining': daily_remaining
            },
            'window': {
                'used': window_count,
                'limit': MAX_REQUESTS_PER_WINDOW,
                'remaining': window_remaining,
                'window_minutes': RATE_LIMIT_WINDOW // 60
            },
            'can_make_request': daily_remaining > 0 and window_remaining > 0
        }
        
    except Exception as e:
        logger.error(f"Error getting rate limit status: {e}")
        return {
            'error': str(e),
            'can_make_request': False
        }

def reset_rate_limits():
    """重置速率限制（仅用于测试或紧急情况）"""
    try:
        now = datetime.now()
        
        # 删除当日计数器
        daily_key = f"ai:daily:{now.strftime('%Y-%m-%d')}"
        redis_client.delete(daily_key)
        
        # 删除当前窗口计数器
        window_key = f"ai:window:{now.strftime('%Y-%m-%d-%H-%M')[:-1]}0"
        redis_client.delete(window_key)
        
        logger.info("Rate limits reset successfully")
        
    except Exception as e:
        logger.error(f"Error resetting rate limits: {e}")
        raise

def test_ai_service() -> Dict[str, Any]:
    """
    测试AI服务连接
    
    Returns:
        测试结果字典
    """
    try:
        test_description = "测试用户描述，用于验证AI服务是否正常工作。"
        
        start_time = time.time()
        keywords = generate_keywords(test_description)
        end_time = time.time()
        
        return {
            'success': True,
            'keywords': keywords,
            'response_time': round(end_time - start_time, 2),
            'rate_limit_status': get_rate_limit_status()
        }
        
    except Exception as e:
        return {
            'success': False,
            'error': str(e),
            'rate_limit_status': get_rate_limit_status()
        }

if __name__ == '__main__':
    # 测试脚本
    print("Testing AI keyword generation service...")
    
    # 测试服务
    result = test_ai_service()
    print(f"Test result: {json.dumps(result, indent=2, ensure_ascii=False)}")
    
    # 显示速率限制状态
    status = get_rate_limit_status()
    print(f"Rate limit status: {json.dumps(status, indent=2, ensure_ascii=False)}")
    
    # 测试实际关键词生成
    if result['success']:
        test_cases = [
            "我最近工作不顺利，感情也遇到了问题，想知道未来的运势如何。",
            "孩子今年要高考了，很担心他的成绩，希望大师指点一下。",
            "创业遇到困难，资金链紧张，不知道是否应该坚持下去。"
        ]
        
        for i, description in enumerate(test_cases, 1):
            try:
                print(f"\nTest case {i}:")
                print(f"Description: {description}")
                keywords = generate_keywords(description)
                print(f"Keywords: {keywords}")
            except Exception as e:
                print(f"Error: {e}")
                break 