#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Stripe 支付集成脚本
支持多币种配置（CNY、USD、CAD、SGD、AUD）
集成到电商模块和算命付款流程
"""

import os
import json
import logging
from typing import Dict, List, Optional, Any
from decimal import Decimal
import stripe
from datetime import datetime, timedelta

# 配置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# 支持的币种配置
SUPPORTED_CURRENCIES = {
    'CNY': {
        'name': '人民币',
        'symbol': '¥',
        'decimal_places': 2,
        'min_amount': 100,  # 最小金额（分）
        'stripe_multiplier': 100  # Stripe 金额倍数
    },
    'USD': {
        'name': '美元',
        'symbol': '$',
        'decimal_places': 2,
        'min_amount': 100,  # 最小金额（分）
        'stripe_multiplier': 100
    },
    'CAD': {
        'name': '加拿大元',
        'symbol': 'C$',
        'decimal_places': 2,
        'min_amount': 100,
        'stripe_multiplier': 100
    },
    'SGD': {
        'name': '新加坡元',
        'symbol': 'S$',
        'decimal_places': 2,
        'min_amount': 100,
        'stripe_multiplier': 100
    },
    'AUD': {
        'name': '澳大利亚元',
        'symbol': 'A$',
        'decimal_places': 2,
        'min_amount': 100,
        'stripe_multiplier': 100
    }
}

class StripePaymentManager:
    """Stripe 支付管理器"""
    
    def __init__(self):
        """初始化 Stripe 客户端"""
        self.clients = {}
        self.webhook_secrets = {}
        self.load_stripe_configs()
    
    def load_stripe_configs(self):
        """加载 Stripe 配置"""
        try:
            # 从环境变量或配置文件加载多个 Stripe 账户配置
            stripe_accounts = json.loads(os.getenv('STRIPE_ACCOUNTS', '[]'))
            
            for account in stripe_accounts:
                account_id = account.get('account_id')
                secret_key = account.get('secret_key')
                webhook_secret = account.get('webhook_secret')
                currencies = account.get('currencies', ['CAD'])
                
                if account_id and secret_key:
                    # 为每个账户创建 Stripe 客户端
                    client = stripe
                    client.api_key = secret_key
                    
                    for currency in currencies:
                        if currency in SUPPORTED_CURRENCIES:
                            self.clients[currency] = client
                            if webhook_secret:
                                self.webhook_secrets[currency] = webhook_secret
                    
                    logger.info(f"已加载 Stripe 账户: {account_id}, 支持币种: {currencies}")
            
            # 如果没有配置，使用默认配置
            if not self.clients:
                default_key = os.getenv('STRIPE_SECRET_KEY')
                default_webhook = os.getenv('STRIPE_WEBHOOK_SECRET')
                
                if default_key:
                    stripe.api_key = default_key
                    for currency in SUPPORTED_CURRENCIES:
                        self.clients[currency] = stripe
                        if default_webhook:
                            self.webhook_secrets[currency] = default_webhook
                    
                    logger.info("使用默认 Stripe 配置")
                else:
                    logger.error("未找到 Stripe 配置")
                    
        except Exception as e:
            logger.error(f"加载 Stripe 配置失败: {e}")
    
    def get_client(self, currency: str):
        """获取指定币种的 Stripe 客户端"""
        currency = currency.upper()
        if currency not in self.clients:
            raise ValueError(f"不支持的币种: {currency}")
        return self.clients[currency]
    
    def validate_amount(self, amount: float, currency: str) -> int:
        """验证并转换金额"""
        currency = currency.upper()
        if currency not in SUPPORTED_CURRENCIES:
            raise ValueError(f"不支持的币种: {currency}")
        
        config = SUPPORTED_CURRENCIES[currency]
        
        # 转换为最小单位（如分）
        stripe_amount = int(amount * config['stripe_multiplier'])
        
        if stripe_amount < config['min_amount']:
            min_display = config['min_amount'] / config['stripe_multiplier']
            raise ValueError(f"金额不能少于 {config['symbol']}{min_display}")
        
        return stripe_amount
    
    def create_checkout_session(self, order_data: Dict[str, Any]) -> Dict[str, Any]:
        """创建 Checkout Session"""
        try:
            currency = order_data['currency'].upper()
            amount = order_data['amount']
            order_id = order_data['order_id']
            description = order_data.get('description', '订单支付')
            success_url = order_data.get('success_url')
            cancel_url = order_data.get('cancel_url')
            customer_email = order_data.get('customer_email')
            
            # 验证金额
            stripe_amount = self.validate_amount(amount, currency)
            
            # 获取对应币种的客户端
            client = self.get_client(currency)
            
            # 创建 Checkout Session
            session_data = {
                'mode': 'payment',
                'payment_method_types': ['card'],
                'line_items': [{
                    'price_data': {
                        'currency': currency.lower(),
                        'product_data': {
                            'name': description,
                        },
                        'unit_amount': stripe_amount,
                    },
                    'quantity': 1,
                }],
                'metadata': {
                    'order_id': order_id,
                    'currency': currency,
                    'original_amount': str(amount)
                },
                'expires_at': int((datetime.now() + timedelta(hours=24)).timestamp()),
            }
            
            # 添加成功和取消 URL
            if success_url:
                session_data['success_url'] = success_url
            if cancel_url:
                session_data['cancel_url'] = cancel_url
            
            # 添加客户邮箱
            if customer_email:
                session_data['customer_email'] = customer_email
            
            session = client.checkout.Session.create(**session_data)
            
            logger.info(f"创建 Checkout Session 成功: {session.id}")
            
            return {
                'session_id': session.id,
                'url': session.url,
                'payment_intent': session.payment_intent,
                'expires_at': session.expires_at
            }
            
        except Exception as e:
            logger.error(f"创建 Checkout Session 失败: {e}")
            raise
    
    def create_payment_intent(self, order_data: Dict[str, Any]) -> Dict[str, Any]:
        """创建 Payment Intent（用于自定义支付流程）"""
        try:
            currency = order_data['currency'].upper()
            amount = order_data['amount']
            order_id = order_data['order_id']
            description = order_data.get('description', '订单支付')
            customer_email = order_data.get('customer_email')
            
            # 验证金额
            stripe_amount = self.validate_amount(amount, currency)
            
            # 获取对应币种的客户端
            client = self.get_client(currency)
            
            # 创建 Payment Intent
            intent_data = {
                'amount': stripe_amount,
                'currency': currency.lower(),
                'description': description,
                'metadata': {
                    'order_id': order_id,
                    'currency': currency,
                    'original_amount': str(amount)
                },
                'automatic_payment_methods': {
                    'enabled': True,
                },
            }
            
            # 添加客户邮箱
            if customer_email:
                intent_data['receipt_email'] = customer_email
            
            intent = client.PaymentIntent.create(**intent_data)
            
            logger.info(f"创建 Payment Intent 成功: {intent.id}")
            
            return {
                'payment_intent_id': intent.id,
                'client_secret': intent.client_secret,
                'status': intent.status
            }
            
        except Exception as e:
            logger.error(f"创建 Payment Intent 失败: {e}")
            raise
    
    def handle_webhook(self, payload: str, sig_header: str, currency: str = 'CAD') -> Dict[str, Any]:
        """处理 Webhook 事件"""
        try:
            currency = currency.upper()
            webhook_secret = self.webhook_secrets.get(currency)
            
            if not webhook_secret:
                raise ValueError(f"未配置 {currency} 的 Webhook Secret")
            
            # 验证 Webhook 签名
            event = stripe.Webhook.construct_event(
                payload, sig_header, webhook_secret
            )
            
            logger.info(f"收到 Webhook 事件: {event['type']}")
            
            # 处理不同类型的事件
            if event['type'] == 'checkout.session.completed':
                return self._handle_checkout_completed(event['data']['object'])
            elif event['type'] == 'payment_intent.succeeded':
                return self._handle_payment_succeeded(event['data']['object'])
            elif event['type'] == 'payment_intent.payment_failed':
                return self._handle_payment_failed(event['data']['object'])
            else:
                logger.info(f"未处理的事件类型: {event['type']}")
                return {'status': 'ignored', 'event_type': event['type']}
                
        except Exception as e:
            logger.error(f"处理 Webhook 失败: {e}")
            raise
    
    def _handle_checkout_completed(self, session: Dict[str, Any]) -> Dict[str, Any]:
        """处理 Checkout Session 完成事件"""
        try:
            order_id = session['metadata'].get('order_id')
            payment_intent = session.get('payment_intent')
            
            logger.info(f"订单支付成功: {order_id}")
            
            return {
                'status': 'success',
                'event_type': 'checkout.session.completed',
                'order_id': order_id,
                'payment_intent': payment_intent,
                'session_id': session['id'],
                'amount_total': session['amount_total'],
                'currency': session['currency']
            }
            
        except Exception as e:
            logger.error(f"处理 Checkout 完成事件失败: {e}")
            raise
    
    def _handle_payment_succeeded(self, payment_intent: Dict[str, Any]) -> Dict[str, Any]:
        """处理支付成功事件"""
        try:
            order_id = payment_intent['metadata'].get('order_id')
            
            logger.info(f"支付成功: {order_id}")
            
            return {
                'status': 'success',
                'event_type': 'payment_intent.succeeded',
                'order_id': order_id,
                'payment_intent_id': payment_intent['id'],
                'amount': payment_intent['amount'],
                'currency': payment_intent['currency']
            }
            
        except Exception as e:
            logger.error(f"处理支付成功事件失败: {e}")
            raise
    
    def _handle_payment_failed(self, payment_intent: Dict[str, Any]) -> Dict[str, Any]:
        """处理支付失败事件"""
        try:
            order_id = payment_intent['metadata'].get('order_id')
            
            logger.warning(f"支付失败: {order_id}")
            
            return {
                'status': 'failed',
                'event_type': 'payment_intent.payment_failed',
                'order_id': order_id,
                'payment_intent_id': payment_intent['id'],
                'last_payment_error': payment_intent.get('last_payment_error')
            }
            
        except Exception as e:
            logger.error(f"处理支付失败事件失败: {e}")
            raise
    
    def create_refund(self, payment_intent_id: str, amount: Optional[float] = None, 
                     reason: str = 'requested_by_customer') -> Dict[str, Any]:
        """创建退款"""
        try:
            refund_data = {
                'payment_intent': payment_intent_id,
                'reason': reason
            }
            
            if amount:
                # 如果指定了退款金额，需要转换为最小单位
                # 这里假设使用 CAD，实际应该从 payment_intent 获取币种
                refund_data['amount'] = int(amount * 100)
            
            refund = stripe.Refund.create(**refund_data)
            
            logger.info(f"创建退款成功: {refund.id}")
            
            return {
                'refund_id': refund.id,
                'status': refund.status,
                'amount': refund.amount,
                'currency': refund.currency
            }
            
        except Exception as e:
            logger.error(f"创建退款失败: {e}")
            raise
    
    def get_payment_status(self, payment_intent_id: str) -> Dict[str, Any]:
        """获取支付状态"""
        try:
            payment_intent = stripe.PaymentIntent.retrieve(payment_intent_id)
            
            return {
                'payment_intent_id': payment_intent.id,
                'status': payment_intent.status,
                'amount': payment_intent.amount,
                'currency': payment_intent.currency,
                'created': payment_intent.created,
                'metadata': payment_intent.metadata
            }
            
        except Exception as e:
            logger.error(f"获取支付状态失败: {e}")
            raise
    
    def format_amount(self, amount: int, currency: str) -> str:
        """格式化金额显示"""
        currency = currency.upper()
        if currency not in SUPPORTED_CURRENCIES:
            return f"{amount} {currency}"
        
        config = SUPPORTED_CURRENCIES[currency]
        display_amount = amount / config['stripe_multiplier']
        
        return f"{config['symbol']}{display_amount:.{config['decimal_places']}f}"

# 全局实例
stripe_manager = StripePaymentManager()

# 便捷函数
def create_session(order_data: Dict[str, Any]) -> Dict[str, Any]:
    """创建支付会话的便捷函数"""
    return stripe_manager.create_checkout_session(order_data)

def handle_webhook(payload: str, sig_header: str, currency: str = 'CAD') -> Dict[str, Any]:
    """处理 Webhook 的便捷函数"""
    return stripe_manager.handle_webhook(payload, sig_header, currency)

def create_refund(payment_intent_id: str, amount: Optional[float] = None, 
                 reason: str = 'requested_by_customer') -> Dict[str, Any]:
    """创建退款的便捷函数"""
    return stripe_manager.create_refund(payment_intent_id, amount, reason)

if __name__ == "__main__":
    # 测试代码
    test_order = {
        'order_id': 'test_order_123',
        'amount': 29.99,
        'currency': 'CAD',
        'description': '测试订单',
        'customer_email': 'test@example.com',
        'success_url': 'https://baidaohui.com/success',
        'cancel_url': 'https://baidaohui.com/cancel'
    }
    
    try:
        result = create_session(test_order)
        print(f"测试创建会话成功: {result}")
    except Exception as e:
        print(f"测试失败: {e}") 