const axios = require('axios');
const { ObjectId } = require('mongodb');

module.exports = function createWebhookHandler(stripe, db, webhookSecret, fortuneServiceUrl) {
  return async (req, res) => {
    const sig = req.headers['stripe-signature'];
    let event;

    try {
      // 验证webhook签名
      event = stripe.webhooks.constructEvent(req.body, sig, webhookSecret);
    } catch (err) {
      console.error('Webhook签名验证失败:', err.message);
      return res.status(400).send(`Webhook Error: ${err.message}`);
    }

    console.log('收到Stripe Webhook事件:', event.type);

    try {
      // 处理不同类型的事件
      switch (event.type) {
        case 'checkout.session.completed':
          await handleCheckoutSessionCompleted(event.data.object, db, fortuneServiceUrl);
          break;
        
        case 'checkout.session.expired':
          await handleCheckoutSessionExpired(event.data.object, db);
          break;
        
        case 'payment_intent.succeeded':
          await handlePaymentIntentSucceeded(event.data.object, db);
          break;
        
        case 'payment_intent.payment_failed':
          await handlePaymentIntentFailed(event.data.object, db);
          break;
        
        default:
          console.log(`未处理的事件类型: ${event.type}`);
      }

      res.json({ received: true });

    } catch (error) {
      console.error('处理Webhook事件失败:', error);
      res.status(500).json({ error: '处理事件失败' });
    }
  };
};

// 处理支付成功事件
async function handleCheckoutSessionCompleted(session, db, fortuneServiceUrl) {
  try {
    console.log('处理支付成功事件:', session.id);

    const orderId = session.metadata.orderId;
    const userId = session.metadata.userId;

    if (!orderId) {
      console.error('Webhook事件缺少orderId元数据');
      return;
    }

    // 更新支付记录状态
    const updateResult = await db.collection('payments').updateOne(
      { sessionId: session.id },
      {
        $set: {
          status: 'paid',
          paidAt: new Date(),
          stripePaymentIntentId: session.payment_intent,
          amountReceived: session.amount_total,
          updatedAt: new Date()
        }
      }
    );

    if (updateResult.matchedCount === 0) {
      console.error('未找到对应的支付记录:', session.id);
      return;
    }

    console.log('支付记录更新成功:', session.id);

    // 调用算命服务更新订单状态
    try {
      const response = await axios.post(`${fortuneServiceUrl}/fortune/update-status`, {
        order_id: orderId,
        status: 'Queued-payed'
      }, {
        timeout: 10000,
        headers: {
          'Content-Type': 'application/json'
        }
      });

      console.log('算命服务状态更新成功:', orderId);
    } catch (fortuneError) {
      console.error('调用算命服务失败:', fortuneError.message);
      
      // 记录失败的状态更新，稍后重试
      await db.collection('failed_status_updates').insertOne({
        orderId: orderId,
        sessionId: session.id,
        targetStatus: 'Queued-payed',
        error: fortuneError.message,
        createdAt: new Date(),
        retryCount: 0
      });
    }

    // 记录支付成功日志
    await db.collection('payment_logs').insertOne({
      sessionId: session.id,
      orderId: orderId,
      userId: userId,
      event: 'payment_completed',
      amount: session.amount_total,
      currency: session.currency,
      timestamp: new Date()
    });

    console.log('支付完成处理成功:', orderId);

  } catch (error) {
    console.error('处理支付成功事件失败:', error);
    throw error;
  }
}

// 处理支付会话过期事件
async function handleCheckoutSessionExpired(session, db) {
  try {
    console.log('处理支付会话过期事件:', session.id);

    // 更新支付记录状态
    await db.collection('payments').updateOne(
      { sessionId: session.id },
      {
        $set: {
          status: 'expired',
          expiredAt: new Date(),
          updatedAt: new Date()
        }
      }
    );

    // 记录过期日志
    await db.collection('payment_logs').insertOne({
      sessionId: session.id,
      orderId: session.metadata.orderId,
      userId: session.metadata.userId,
      event: 'session_expired',
      timestamp: new Date()
    });

    console.log('支付会话过期处理完成:', session.id);

  } catch (error) {
    console.error('处理支付会话过期事件失败:', error);
    throw error;
  }
}

// 处理支付意图成功事件
async function handlePaymentIntentSucceeded(paymentIntent, db) {
  try {
    console.log('处理支付意图成功事件:', paymentIntent.id);

    // 查找对应的支付记录
    const payment = await db.collection('payments').findOne({
      stripePaymentIntentId: paymentIntent.id
    });

    if (payment) {
      // 更新支付记录的详细信息
      await db.collection('payments').updateOne(
        { _id: payment._id },
        {
          $set: {
            paymentMethod: paymentIntent.payment_method,
            receiptEmail: paymentIntent.receipt_email,
            paymentIntentStatus: paymentIntent.status,
            updatedAt: new Date()
          }
        }
      );

      console.log('支付意图成功处理完成:', paymentIntent.id);
    }

  } catch (error) {
    console.error('处理支付意图成功事件失败:', error);
    throw error;
  }
}

// 处理支付意图失败事件
async function handlePaymentIntentFailed(paymentIntent, db) {
  try {
    console.log('处理支付意图失败事件:', paymentIntent.id);

    // 查找对应的支付记录
    const payment = await db.collection('payments').findOne({
      stripePaymentIntentId: paymentIntent.id
    });

    if (payment) {
      // 更新支付记录状态
      await db.collection('payments').updateOne(
        { _id: payment._id },
        {
          $set: {
            status: 'failed',
            failureReason: paymentIntent.last_payment_error?.message || 'Unknown error',
            paymentIntentStatus: paymentIntent.status,
            updatedAt: new Date()
          }
        }
      );

      // 记录失败日志
      await db.collection('payment_logs').insertOne({
        sessionId: payment.sessionId,
        orderId: payment.orderId,
        userId: payment.userId,
        event: 'payment_failed',
        error: paymentIntent.last_payment_error?.message || 'Unknown error',
        timestamp: new Date()
      });

      console.log('支付意图失败处理完成:', paymentIntent.id);
    }

  } catch (error) {
    console.error('处理支付意图失败事件失败:', error);
    throw error;
  }
} 