const express = require('express');
const cors = require('cors');
const { MongoClient, ObjectId } = require('mongodb');
const jwt = require('jsonwebtoken');
const axios = require('axios');
const Stripe = require('stripe');
require('dotenv').config();

const app = express();

// 配置
const MONGODB_URI = process.env.MONGODB_URI;
const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key';
const STRIPE_WEBHOOK_SECRET = process.env.STRIPE_WEBHOOK_SECRET;
const FRONTEND_URL = process.env.FRONTEND_URL || 'https://baidaohui.com';
const FORTUNE_SERVICE_URL = process.env.FORTUNE_SERVICE_URL || 'http://fortune-service:5003';
const EMAIL_SERVICE_URL = process.env.EMAIL_SERVICE_URL;

// MongoDB连接
let db;
let stripe = null; // 动态初始化

MongoClient.connect(MONGODB_URI)
  .then(client => {
    console.log('MongoDB连接成功');
    db = client.db('baidaohui');
    initializeStripe();
  })
  .catch(error => {
    console.error('MongoDB连接失败:', error);
    process.exit(1);
  });

// 初始化Stripe客户端
async function initializeStripe() {
  try {
    // 获取master的有效Stripe密钥
    const masterKey = await db.collection('keys').findOne({
      userRole: 'master',
      keyType: 'stripe_secret',
      isActive: true
    });
    
    if (masterKey && masterKey.keyValue) {
      stripe = new Stripe(masterKey.keyValue);
      console.log('Stripe客户端初始化成功');
    } else {
      console.warn('未找到master的Stripe密钥，支付功能将不可用');
    }
  } catch (error) {
    console.error('初始化Stripe失败:', error);
  }
}

// 重新初始化Stripe（当密钥更新时）
async function reinitializeStripe() {
  await initializeStripe();
}

// Webhook需要原始body，所以要在其他中间件之前处理
app.use('/payment/webhook', express.raw({ type: 'application/json' }));

// 其他中间件
app.use(cors({
  origin: process.env.CORS_ORIGINS?.split(',') || ['https://baidaohui.com'],
  credentials: true
}));
app.use(express.json());

// 验证用户身份的中间件
function authenticateUser(req, res, next) {
  try {
    const token = req.cookies?.access_token || req.headers.authorization?.split(' ')[1];
    
    if (!token) {
      return res.status(401).json({ error: '未登录' });
    }

    const payload = jwt.verify(token, JWT_SECRET);
    req.user = payload;
    next();
  } catch (error) {
    console.error('身份验证失败:', error);
    return res.status(401).json({ error: '无效的Token' });
  }
}

// 引入webhook处理
const webhookHandler = require('./webhook');

// 创建支付会话（仅用于算命服务）
app.post('/payment/session', authenticateUser, async (req, res) => {
  try {
    if (!stripe) {
      return res.status(503).json({
        success: false,
        error: 'Stripe未配置，请联系管理员'
      });
    }
    
    const { orderId, amount, currency, description } = req.body;
    
    if (!orderId || !amount || !currency) {
      return res.status(400).json({
        success: false,
        error: '缺少必要参数'
      });
    }
    
    // 验证订单存在且状态为Pending
    const order = await db.collection('fortune_applications').findOne({
      _id: orderId,
      status: 'Pending'
    });
    
    if (!order) {
      return res.status(404).json({
        success: false,
        error: '订单不存在或状态无效'
      });
    }
    
    // 创建Stripe Checkout Session
    const session = await stripe.checkout.sessions.create({
      mode: 'payment',
      payment_method_types: ['card'],
      line_items: [{
        price_data: {
          currency: currency.toLowerCase(),
          product_data: {
            name: description || '算命服务',
            description: `订单号: ${orderId}`
          },
          unit_amount: Math.round(amount * 100) // 转换为分
        },
        quantity: 1
      }],
      metadata: {
        orderId,
        service: 'fortune'
      },
      success_url: `${FRONTEND_URL}/fortune/pay/success?orderId=${orderId}`,
      cancel_url: `${FRONTEND_URL}/fortune/pay/cancel?orderId=${orderId}`
    });
    
    // 保存支付记录
    await db.collection('payments').insertOne({
      sessionId: session.id,
      orderId,
      userId: order.userId,
      amountTotal: amount,
      currency,
      status: 'pending',
      paymentMethod: 'stripe',
      metadata: {
        service: 'fortune',
        description
      },
      createdAt: new Date(),
      updatedAt: new Date()
    });
    
    res.json({
      success: true,
      url: session.url,
      sessionId: session.id
    });
    
  } catch (error) {
    console.error('创建支付会话失败:', error);
    res.status(500).json({
      success: false,
      error: '创建支付会话失败'
    });
  }
});

// 获取支付状态
app.get('/payment/status/:sessionId', authenticateUser, async (req, res) => {
  try {
    const { sessionId } = req.params;

    // 从数据库查询支付记录
    const payment = await db.collection('payments').findOne({ sessionId });

    if (!payment) {
      return res.status(404).json({ error: '支付记录不存在' });
    }

    // 检查权限
    if (payment.userId !== req.user.sub && req.user.role !== 'Master' && req.user.role !== 'Firstmate') {
      return res.status(403).json({ error: '无权限查看此支付记录' });
    }

    // 从Stripe获取最新状态
    const session = await stripe.checkout.sessions.retrieve(sessionId);

    res.json({
      sessionId: sessionId,
      orderId: payment.orderId,
      status: payment.status,
      stripeStatus: session.payment_status,
      amountTotal: payment.amountTotal,
      currency: payment.currency,
      createdAt: payment.createdAt,
      paidAt: payment.paidAt || null
    });

  } catch (error) {
    console.error('获取支付状态失败:', error);
    res.status(500).json({ error: '获取支付状态失败' });
  }
});

// 获取用户支付历史
app.get('/payment/history', authenticateUser, async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 10;
    const status = req.query.status;

    // 构建查询条件
    const query = { userId: req.user.sub };
    if (status) {
      query.status = status;
    }

    // 分页查询
    const skip = (page - 1) * limit;
    const payments = await db.collection('payments')
      .find(query)
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit)
      .toArray();

    const total = await db.collection('payments').countDocuments(query);

    res.json({
      payments: payments.map(p => ({
        sessionId: p.sessionId,
        orderId: p.orderId,
        amountTotal: p.amountTotal,
        currency: p.currency,
        status: p.status,
        createdAt: p.createdAt,
        paidAt: p.paidAt || null
      })),
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit)
      }
    });

  } catch (error) {
    console.error('获取支付历史失败:', error);
    res.status(500).json({ error: '获取支付历史失败' });
  }
});

// Webhook处理
app.post('/payment/webhook', express.raw({ type: 'application/json' }), async (req, res) => {
  try {
    if (!stripe) {
      console.error('Stripe未配置，无法处理webhook');
      return res.status(503).send('Stripe not configured');
    }
    
    const sig = req.headers['stripe-signature'];
    
    if (!sig) {
      console.error('Webhook签名未提供');
      return res.status(400).send('Webhook signature not provided');
    }
    
    let event;
    try {
      event = stripe.webhooks.constructEvent(req.body, sig, STRIPE_WEBHOOK_SECRET);
    } catch (err) {
      console.error('Webhook签名验证失败:', err.message);
      return res.status(400).send(`Webhook Error: ${err.message}`);
    }
    
    // 处理支付完成事件
    if (event.type === 'checkout.session.completed') {
      const session = event.data.object;
      const { orderId } = session.metadata;
      
      if (!orderId) {
        console.error('Webhook事件缺少orderId');
        return res.status(400).send('Missing orderId in metadata');
      }
      
      // 更新支付记录
      await db.collection('payments').updateOne(
        { sessionId: session.id },
        { 
          $set: { 
            status: 'paid',
            stripeCustomerId: session.customer,
            updatedAt: new Date()
          }
        }
      );
      
      // 通知算命服务更新订单状态
      try {
        const response = await fetch(`${FORTUNE_SERVICE_URL}/fortune/update-status`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({
            orderId,
            status: 'Queued-payed'
          })
        });
        
        if (!response.ok) {
          console.error('通知算命服务失败:', response.statusText);
        }
      } catch (error) {
        console.error('通知算命服务失败:', error);
      }
      
      // 发送邮件通知
      try {
        await fetch(`${EMAIL_SERVICE_URL}/email/send-payment-success`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({
            orderId,
            amount: session.amount_total / 100,
            currency: session.currency
          })
        });
      } catch (error) {
        console.error('发送邮件通知失败:', error);
      }
      
      console.log(`支付完成: 订单 ${orderId}, 会话 ${session.id}`);
    }
    
    res.json({ received: true });
    
  } catch (error) {
    console.error('Webhook处理失败:', error);
    res.status(500).send('Webhook processing failed');
  }
});

// 健康检查
app.get('/health', (req, res) => {
  res.json({ 
    status: 'healthy', 
    service: 'payment-service',
    stripe_configured: !!stripe,
    timestamp: new Date().toISOString()
  });
});

// 错误处理中间件
app.use((error, req, res, next) => {
  console.error('服务器错误:', error);
  res.status(500).json({
    error: '服务器内部错误',
    message: process.env.NODE_ENV === 'development' ? error.message : '请稍后重试'
  });
});

// 404处理
app.use('*', (req, res) => {
  res.status(404).json({ error: '接口不存在' });
});

const PORT = process.env.PORT || 5006;
app.listen(PORT, () => {
  console.log(`支付服务启动，端口: ${PORT}`);
  console.log(`前端URL: ${FRONTEND_URL}`);
  console.log(`算命服务: ${FORTUNE_SERVICE_URL}`);
  console.log(`邮件服务: ${EMAIL_SERVICE_URL}`);
}); 