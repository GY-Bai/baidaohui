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
const STRIPE_SECRET_KEY = process.env.STRIPE_SECRET_KEY;
const STRIPE_WEBHOOK_SECRET = process.env.STRIPE_WEBHOOK_SECRET;
const FRONTEND_URL = process.env.FRONTEND_URL || 'https://baidaohui.com';
const FORTUNE_SERVICE_URL = process.env.FORTUNE_SERVICE_URL || 'http://fortune-service:5003';

// 初始化Stripe
const stripe = new Stripe(STRIPE_SECRET_KEY, {
  apiVersion: '2023-10-16',
});

// MongoDB连接
let db;
MongoClient.connect(MONGODB_URI)
  .then(client => {
    console.log('MongoDB连接成功');
    db = client.db('baidaohui');
  })
  .catch(error => {
    console.error('MongoDB连接失败:', error);
    process.exit(1);
  });

// Webhook需要原始body，所以要在其他中间件之前处理
app.use('/payment/webhook', express.raw({ type: 'application/json' }));

// 其他中间件
app.use(cors({ credentials: true }));
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
    const { orderId, amount, currency, description } = req.body;

    // 验证必填字段
    if (!orderId || !amount || !currency || !description) {
      return res.status(400).json({ error: '缺少必填字段' });
    }

    // 验证订单存在且状态为Pending
    const application = await db.collection('fortune_applications').findOne({
      _id: new ObjectId(orderId),
      status: 'Pending'
    });

    if (!application) {
      return res.status(404).json({ error: '订单不存在或状态不正确' });
    }

    // 创建Stripe Checkout Session（算命服务使用单一Stripe账号）
    const session = await stripe.checkout.sessions.create({
      mode: 'payment',
      payment_method_types: ['card'],
      line_items: [{
        price_data: {
          currency: currency.toLowerCase(),
          product_data: {
            name: description,
            description: `算命申请 - ${orderId}`,
          },
          unit_amount: Math.round(amount * 100), // 转换为分
        },
        quantity: 1,
      }],
      metadata: {
        orderId: orderId,
        userId: req.user.sub,
        serviceType: 'fortune'
      },
      success_url: `${FRONTEND_URL}/fortune/pay/success?orderId=${orderId}&session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: `${FRONTEND_URL}/fortune/pay/cancel?orderId=${orderId}`,
      expires_at: Math.floor(Date.now() / 1000) + (30 * 60), // 30分钟后过期
    });

    // 保存支付记录
    const paymentRecord = {
      sessionId: session.id,
      orderId: orderId,
      userId: req.user.sub,
      amountTotal: amount,
      currency: currency,
      status: 'pending',
      stripeUrl: session.url,
      createdAt: new Date(),
      expiresAt: new Date(Date.now() + 30 * 60 * 1000) // 30分钟后过期
    };

    await db.collection('payments').insertOne(paymentRecord);

    console.log(`用户 ${req.user.sub} 创建支付会话: ${session.id} for 订单: ${orderId}`);

    res.json({
      success: true,
      sessionId: session.id,
      url: session.url
    });

  } catch (error) {
    console.error('创建支付会话失败:', error);
    res.status(500).json({ error: '创建支付会话失败' });
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
app.post('/payment/webhook', webhookHandler(stripe, db, STRIPE_WEBHOOK_SECRET, FORTUNE_SERVICE_URL));

// 健康检查
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    service: 'payment-service',
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
}); 