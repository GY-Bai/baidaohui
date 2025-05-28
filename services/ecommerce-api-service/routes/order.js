const express = require('express');
const { ObjectId } = require('mongodb');
const axios = require('axios');
const router = express.Router();

// 创建订单（带静态支付链接）
router.post('/', async (req, res) => {
  try {
    const { smartAuthenticate, db, clearCache } = require('../app');
    
    // 验证用户身份
    await new Promise((resolve, reject) => {
      smartAuthenticate(req, res, (err) => {
        if (err) reject(err);
        else resolve();
      });
    });

    const database = db();
    if (!database) {
      return res.status(500).json({ error: '数据库连接未就绪' });
    }

    const {
      productId,
      quantity = 1,
      customerInfo,
      shippingAddress,
      notes,
      paymentMethod = 'stripe' // stripe, paypal, manual
    } = req.body;

    // 验证必填字段
    if (!productId) {
      return res.status(400).json({ error: '缺少产品ID' });
    }

    if (!customerInfo || !customerInfo.email) {
      return res.status(400).json({ error: '缺少客户信息' });
    }

    if (quantity <= 0 || quantity > 100) {
      return res.status(400).json({ error: '商品数量必须在1-100之间' });
    }

    // 获取产品信息
    const product = await database.collection('products').findOne({ id: productId });
    if (!product) {
      return res.status(404).json({ error: '产品不存在' });
    }

    // 计算订单金额
    const unitPrice = product.default_price?.unit_amount || 0;
    const totalAmount = unitPrice * quantity;
    const currency = product.default_price?.currency || 'usd';

    // 生成静态支付链接
    const paymentLinks = await generatePaymentLinks(product, quantity, totalAmount, currency);

    // 创建订单
    const order = {
      orderId: generateOrderId(),
      userId: req.user.sub || req.user.userId,
      userEmail: req.user.email,
      product: {
        id: product.id,
        name: product.name,
        description: product.description,
        images: product.images || [],
        unitPrice: unitPrice,
        currency: currency
      },
      quantity: quantity,
      totalAmount: totalAmount,
      currency: currency,
      customerInfo: {
        name: customerInfo.name || req.user.email.split('@')[0],
        email: customerInfo.email,
        phone: customerInfo.phone || ''
      },
      shippingAddress: shippingAddress || {},
      notes: notes || '',
      paymentMethod: paymentMethod,
      paymentLinks: paymentLinks,
      status: 'pending',
      storeId: product.storeId,
      createdAt: new Date(),
      updatedAt: new Date(),
      expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000) // 24小时后过期
    };

    const result = await database.collection('orders').insertOne(order);
    order._id = result.insertedId;

    // 清除相关缓存
    clearCache('orders');

    console.log(`用户 ${req.user.email} 创建订单: ${order.orderId}`);

    res.status(201).json({
      success: true,
      order: {
        id: order._id,
        orderId: order.orderId,
        product: order.product,
        quantity: order.quantity,
        totalAmount: order.totalAmount,
        currency: order.currency,
        status: order.status,
        paymentLinks: order.paymentLinks,
        expiresAt: order.expiresAt,
        createdAt: order.createdAt
      }
    });

  } catch (error) {
    console.error('创建订单失败:', error);
    res.status(500).json({ error: '创建订单失败' });
  }
});

// 获取用户订单列表
router.get('/', async (req, res) => {
  try {
    const { smartAuthenticate, db } = require('../app');
    
    // 验证用户身份
    await new Promise((resolve, reject) => {
      smartAuthenticate(req, res, (err) => {
        if (err) reject(err);
        else resolve();
      });
    });

    const database = db();
    if (!database) {
      return res.status(500).json({ error: '数据库连接未就绪' });
    }

    const page = parseInt(req.query.page) || 1;
    const limit = Math.min(parseInt(req.query.limit) || 10, 50); // 最大限制50
    const status = req.query.status;
    const storeId = req.query.storeId;

    // 构建查询条件
    const query = { userId: req.user.sub || req.user.userId };
    
    if (status) {
      query.status = status;
    }
    
    if (storeId) {
      query.storeId = storeId;
    }

    // 管理员可以查看所有订单
    if (req.user.role === 'Master' || req.user.role === 'Firstmate' || req.user.role === 'admin') {
      if (req.query.allOrders === 'true') {
        delete query.userId;
      }
    }

    // 分页查询
    const skip = (page - 1) * limit;
    const orders = await database.collection('orders')
      .find(query)
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit)
      .toArray();

    const total = await database.collection('orders').countDocuments(query);

    // 格式化订单数据
    const formattedOrders = orders.map(order => ({
      id: order._id,
      orderId: order.orderId,
      product: order.product,
      quantity: order.quantity,
      totalAmount: order.totalAmount,
      currency: order.currency,
      status: order.status,
      storeId: order.storeId,
      customerInfo: order.customerInfo,
      paymentMethod: order.paymentMethod,
      isExpired: order.expiresAt && new Date() > order.expiresAt,
      createdAt: order.createdAt,
      updatedAt: order.updatedAt
    }));

    res.json({
      orders: formattedOrders,
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit)
      }
    });

  } catch (error) {
    console.error('获取订单列表失败:', error);
    res.status(500).json({ error: '获取订单列表失败' });
  }
});

// 获取单个订单详情
router.get('/:orderId', async (req, res) => {
  try {
    const { smartAuthenticate, db } = require('../app');
    
    // 验证用户身份
    await new Promise((resolve, reject) => {
      smartAuthenticate(req, res, (err) => {
        if (err) reject(err);
        else resolve();
      });
    });

    const database = db();
    if (!database) {
      return res.status(500).json({ error: '数据库连接未就绪' });
    }

    const { orderId } = req.params;

    // 查找订单
    let order;
    if (ObjectId.isValid(orderId)) {
      order = await database.collection('orders').findOne({ _id: new ObjectId(orderId) });
    } else {
      order = await database.collection('orders').findOne({ orderId: orderId });
    }

    if (!order) {
      return res.status(404).json({ error: '订单不存在' });
    }

    // 检查权限（用户只能查看自己的订单，管理员可以查看所有订单）
    const isAdmin = req.user.role === 'Master' || req.user.role === 'Firstmate' || req.user.role === 'admin';
    const isOwner = order.userId === (req.user.sub || req.user.userId);
    
    if (!isAdmin && !isOwner) {
      return res.status(403).json({ error: '无权限查看此订单' });
    }

    res.json({
      order: {
        id: order._id,
        orderId: order.orderId,
        userId: order.userId,
        userEmail: order.userEmail,
        product: order.product,
        quantity: order.quantity,
        totalAmount: order.totalAmount,
        currency: order.currency,
        customerInfo: order.customerInfo,
        shippingAddress: order.shippingAddress,
        notes: order.notes,
        status: order.status,
        storeId: order.storeId,
        paymentMethod: order.paymentMethod,
        paymentLinks: order.paymentLinks,
        adminNotes: order.adminNotes,
        isExpired: order.expiresAt && new Date() > order.expiresAt,
        expiresAt: order.expiresAt,
        createdAt: order.createdAt,
        updatedAt: order.updatedAt,
        cancelledAt: order.cancelledAt,
        refundedAt: order.refundedAt
      }
    });

  } catch (error) {
    console.error('获取订单详情失败:', error);
    res.status(500).json({ error: '获取订单详情失败' });
  }
});

// 更新订单状态（仅管理员可用）
router.patch('/:orderId/status', async (req, res) => {
  try {
    const { smartAuthenticate, requireAdmin, db, clearCache } = require('../app');
    
    // 验证用户身份和权限
    await new Promise((resolve, reject) => {
      smartAuthenticate(req, res, (err) => {
        if (err) reject(err);
        else resolve();
      });
    });

    await new Promise((resolve, reject) => {
      requireAdmin(req, res, (err) => {
        if (err) reject(err);
        else resolve();
      });
    });

    const database = db();
    if (!database) {
      return res.status(500).json({ error: '数据库连接未就绪' });
    }

    const { orderId } = req.params;
    const { status, notes, trackingNumber } = req.body;

    if (!status) {
      return res.status(400).json({ error: '缺少状态参数' });
    }

    // 验证状态值
    const validStatuses = ['pending', 'confirmed', 'processing', 'shipped', 'delivered', 'cancelled', 'refunded', 'expired'];
    if (!validStatuses.includes(status)) {
      return res.status(400).json({ error: '无效的状态值' });
    }

    // 查找订单
    let order;
    if (ObjectId.isValid(orderId)) {
      order = await database.collection('orders').findOne({ _id: new ObjectId(orderId) });
    } else {
      order = await database.collection('orders').findOne({ orderId: orderId });
    }

    if (!order) {
      return res.status(404).json({ error: '订单不存在' });
    }

    // 状态转换验证
    const currentStatus = order.status;
    if (!isValidStatusTransition(currentStatus, status)) {
      return res.status(400).json({ 
        error: `无法从 ${currentStatus} 状态变更为 ${status} 状态` 
      });
    }

    // 更新订单
    const updateData = {
      status: status,
      updatedAt: new Date(),
      updatedBy: req.user.sub || req.user.userId
    };

    if (notes) {
      updateData.adminNotes = notes;
    }

    if (trackingNumber && status === 'shipped') {
      updateData.trackingNumber = trackingNumber;
    }

    if (status === 'cancelled') {
      updateData.cancelledAt = new Date();
    }

    if (status === 'refunded') {
      updateData.refundedAt = new Date();
    }

    await database.collection('orders').updateOne(
      { _id: order._id },
      { $set: updateData }
    );

    // 清除相关缓存
    clearCache('orders');

    console.log(`${req.user.role} ${req.user.email} 更新订单 ${order.orderId} 状态: ${currentStatus} -> ${status}`);

    res.json({
      success: true,
      message: '订单状态更新成功',
      orderId: order.orderId,
      oldStatus: currentStatus,
      newStatus: status
    });

  } catch (error) {
    console.error('更新订单状态失败:', error);
    res.status(500).json({ error: '更新订单状态失败' });
  }
});

// 取消订单
router.post('/:orderId/cancel', async (req, res) => {
  try {
    const { smartAuthenticate, db, clearCache } = require('../app');
    
    // 验证用户身份
    await new Promise((resolve, reject) => {
      smartAuthenticate(req, res, (err) => {
        if (err) reject(err);
        else resolve();
      });
    });

    const database = db();
    if (!database) {
      return res.status(500).json({ error: '数据库连接未就绪' });
    }

    const { orderId } = req.params;
    const { reason } = req.body;

    // 查找订单
    let order;
    if (ObjectId.isValid(orderId)) {
      order = await database.collection('orders').findOne({ _id: new ObjectId(orderId) });
    } else {
      order = await database.collection('orders').findOne({ orderId: orderId });
    }

    if (!order) {
      return res.status(404).json({ error: '订单不存在' });
    }

    // 检查权限
    const isAdmin = req.user.role === 'Master' || req.user.role === 'Firstmate' || req.user.role === 'admin';
    const isOwner = order.userId === (req.user.sub || req.user.userId);
    
    if (!isAdmin && !isOwner) {
      return res.status(403).json({ error: '无权限取消此订单' });
    }

    // 检查订单状态是否可以取消
    if (!['pending', 'confirmed'].includes(order.status)) {
      return res.status(400).json({ error: '当前状态的订单无法取消' });
    }

    // 更新订单状态
    await database.collection('orders').updateOne(
      { _id: order._id },
      { 
        $set: {
          status: 'cancelled',
          cancelledAt: new Date(),
          cancelReason: reason || '用户取消',
          updatedAt: new Date(),
          updatedBy: req.user.sub || req.user.userId
        }
      }
    );

    // 清除相关缓存
    clearCache('orders');

    console.log(`订单 ${order.orderId} 被取消，操作者: ${req.user.email}`);

    res.json({
      success: true,
      message: '订单取消成功',
      orderId: order.orderId
    });

  } catch (error) {
    console.error('取消订单失败:', error);
    res.status(500).json({ error: '取消订单失败' });
  }
});

// 申请退款
router.post('/:orderId/refund', async (req, res) => {
  try {
    const { smartAuthenticate, db, clearCache } = require('../app');
    
    // 验证用户身份
    await new Promise((resolve, reject) => {
      smartAuthenticate(req, res, (err) => {
        if (err) reject(err);
        else resolve();
      });
    });

    const database = db();
    if (!database) {
      return res.status(500).json({ error: '数据库连接未就绪' });
    }

    const { orderId } = req.params;
    const { reason, refundAmount } = req.body;

    // 查找订单
    let order;
    if (ObjectId.isValid(orderId)) {
      order = await database.collection('orders').findOne({ _id: new ObjectId(orderId) });
    } else {
      order = await database.collection('orders').findOne({ orderId: orderId });
    }

    if (!order) {
      return res.status(404).json({ error: '订单不存在' });
    }

    // 检查权限
    const isAdmin = req.user.role === 'Master' || req.user.role === 'Firstmate' || req.user.role === 'admin';
    const isOwner = order.userId === (req.user.sub || req.user.userId);
    
    if (!isAdmin && !isOwner) {
      return res.status(403).json({ error: '无权限申请退款' });
    }

    // 检查订单状态是否可以退款
    if (!['delivered', 'shipped', 'confirmed'].includes(order.status)) {
      return res.status(400).json({ error: '当前状态的订单无法退款' });
    }

    // 验证退款金额
    const requestedRefund = refundAmount || order.totalAmount;
    if (requestedRefund > order.totalAmount) {
      return res.status(400).json({ error: '退款金额不能超过订单总额' });
    }

    // 创建退款记录
    const refundRequest = {
      orderId: order.orderId,
      orderObjectId: order._id,
      userId: order.userId,
      requestedBy: req.user.sub || req.user.userId,
      requestedAmount: requestedRefund,
      originalAmount: order.totalAmount,
      currency: order.currency,
      reason: reason || '用户申请退款',
      status: isAdmin ? 'approved' : 'pending', // 管理员直接批准
      requestedAt: new Date(),
      approvedAt: isAdmin ? new Date() : null,
      approvedBy: isAdmin ? (req.user.sub || req.user.userId) : null
    };

    await database.collection('refunds').insertOne(refundRequest);

    // 如果是管理员操作，直接更新订单状态
    if (isAdmin) {
      await database.collection('orders').updateOne(
        { _id: order._id },
        { 
          $set: {
            status: 'refunded',
            refundedAt: new Date(),
            refundAmount: requestedRefund,
            updatedAt: new Date(),
            updatedBy: req.user.sub || req.user.userId
          }
        }
      );
    }

    // 清除相关缓存
    clearCache('orders');

    console.log(`订单 ${order.orderId} 退款申请，操作者: ${req.user.email}, 金额: ${requestedRefund}`);

    res.json({
      success: true,
      message: isAdmin ? '退款处理成功' : '退款申请已提交',
      orderId: order.orderId,
      refundAmount: requestedRefund,
      status: refundRequest.status
    });

  } catch (error) {
    console.error('退款申请失败:', error);
    res.status(500).json({ error: '退款申请失败' });
  }
});

// 获取退款列表（管理员）
router.get('/refunds', async (req, res) => {
  try {
    const { smartAuthenticate, requireAdmin, db } = require('../app');
    
    // 验证用户身份和权限
    await new Promise((resolve, reject) => {
      smartAuthenticate(req, res, (err) => {
        if (err) reject(err);
        else resolve();
      });
    });

    await new Promise((resolve, reject) => {
      requireAdmin(req, res, (err) => {
        if (err) reject(err);
        else resolve();
      });
    });

    const database = db();
    if (!database) {
      return res.status(500).json({ error: '数据库连接未就绪' });
    }

    const page = parseInt(req.query.page) || 1;
    const limit = Math.min(parseInt(req.query.limit) || 10, 50);
    const status = req.query.status;

    // 构建查询条件
    const query = {};
    if (status) {
      query.status = status;
    }

    // 分页查询
    const skip = (page - 1) * limit;
    const refunds = await database.collection('refunds')
      .find(query)
      .sort({ requestedAt: -1 })
      .skip(skip)
      .limit(limit)
      .toArray();

    const total = await database.collection('refunds').countDocuments(query);

    res.json({
      refunds,
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit)
      }
    });

  } catch (error) {
    console.error('获取退款列表失败:', error);
    res.status(500).json({ error: '获取退款列表失败' });
  }
});

// 处理退款申请（管理员）
router.patch('/refunds/:refundId', async (req, res) => {
  try {
    const { smartAuthenticate, requireAdmin, db, clearCache } = require('../app');
    
    // 验证用户身份和权限
    await new Promise((resolve, reject) => {
      smartAuthenticate(req, res, (err) => {
        if (err) reject(err);
        else resolve();
      });
    });

    await new Promise((resolve, reject) => {
      requireAdmin(req, res, (err) => {
        if (err) reject(err);
        else resolve();
      });
    });

    const database = db();
    if (!database) {
      return res.status(500).json({ error: '数据库连接未就绪' });
    }

    const { refundId } = req.params;
    const { action, notes } = req.body; // action: 'approve' or 'reject'

    if (!['approve', 'reject'].includes(action)) {
      return res.status(400).json({ error: '无效的操作类型' });
    }

    // 查找退款申请
    const refund = await database.collection('refunds').findOne({ 
      _id: new ObjectId(refundId) 
    });

    if (!refund) {
      return res.status(404).json({ error: '退款申请不存在' });
    }

    if (refund.status !== 'pending') {
      return res.status(400).json({ error: '退款申请已处理' });
    }

    // 更新退款状态
    const updateData = {
      status: action === 'approve' ? 'approved' : 'rejected',
      processedAt: new Date(),
      processedBy: req.user.sub || req.user.userId,
      adminNotes: notes || ''
    };

    await database.collection('refunds').updateOne(
      { _id: new ObjectId(refundId) },
      { $set: updateData }
    );

    // 如果批准退款，更新订单状态
    if (action === 'approve') {
      await database.collection('orders').updateOne(
        { _id: refund.orderObjectId },
        { 
          $set: {
            status: 'refunded',
            refundedAt: new Date(),
            refundAmount: refund.requestedAmount,
            updatedAt: new Date(),
            updatedBy: req.user.sub || req.user.userId
          }
        }
      );
    }

    // 清除相关缓存
    clearCache('orders');

    console.log(`退款申请 ${refundId} 被${action === 'approve' ? '批准' : '拒绝'}，操作者: ${req.user.email}`);

    res.json({
      success: true,
      message: `退款申请${action === 'approve' ? '批准' : '拒绝'}成功`,
      refundId,
      action
    });

  } catch (error) {
    console.error('处理退款申请失败:', error);
    res.status(500).json({ error: '处理退款申请失败' });
  }
});

// 生成订单统计（管理员）
router.get('/stats', async (req, res) => {
  try {
    const { smartAuthenticate, requireAdmin, db } = require('../app');
    
    // 验证用户身份和权限
    await new Promise((resolve, reject) => {
      smartAuthenticate(req, res, (err) => {
        if (err) reject(err);
        else resolve();
      });
    });

    await new Promise((resolve, reject) => {
      requireAdmin(req, res, (err) => {
        if (err) reject(err);
        else resolve();
      });
    });

    const database = db();
    if (!database) {
      return res.status(500).json({ error: '数据库连接未就绪' });
    }

    const { period = '30d', storeId } = req.query;

    // 计算时间范围
    const endDate = new Date();
    const startDate = new Date();
    
    switch (period) {
      case '7d':
        startDate.setDate(endDate.getDate() - 7);
        break;
      case '30d':
        startDate.setDate(endDate.getDate() - 30);
        break;
      case '90d':
        startDate.setDate(endDate.getDate() - 90);
        break;
      default:
        startDate.setDate(endDate.getDate() - 30);
    }

    // 构建查询条件
    const matchCondition = {
      createdAt: { $gte: startDate, $lte: endDate }
    };

    if (storeId) {
      matchCondition.storeId = storeId;
    }

    // 聚合统计
    const stats = await database.collection('orders').aggregate([
      { $match: matchCondition },
      {
        $group: {
          _id: null,
          totalOrders: { $sum: 1 },
          totalRevenue: { $sum: '$totalAmount' },
          averageOrderValue: { $avg: '$totalAmount' },
          statusBreakdown: {
            $push: '$status'
          }
        }
      }
    ]).toArray();

    // 按状态统计
    const statusStats = await database.collection('orders').aggregate([
      { $match: matchCondition },
      {
        $group: {
          _id: '$status',
          count: { $sum: 1 },
          revenue: { $sum: '$totalAmount' }
        }
      }
    ]).toArray();

    // 按日期统计
    const dailyStats = await database.collection('orders').aggregate([
      { $match: matchCondition },
      {
        $group: {
          _id: {
            $dateToString: {
              format: '%Y-%m-%d',
              date: '$createdAt'
            }
          },
          orders: { $sum: 1 },
          revenue: { $sum: '$totalAmount' }
        }
      },
      { $sort: { '_id': 1 } }
    ]).toArray();

    const result = {
      period,
      dateRange: {
        start: startDate,
        end: endDate
      },
      summary: stats[0] || {
        totalOrders: 0,
        totalRevenue: 0,
        averageOrderValue: 0
      },
      statusBreakdown: statusStats,
      dailyTrend: dailyStats
    };

    res.json(result);

  } catch (error) {
    console.error('获取订单统计失败:', error);
    res.status(500).json({ error: '获取订单统计失败' });
  }
});

// 辅助函数：生成订单ID
function generateOrderId() {
  const timestamp = Date.now().toString(36);
  const randomStr = Math.random().toString(36).substring(2, 8);
  return `ORD-${timestamp}-${randomStr}`.toUpperCase();
}

// 辅助函数：生成静态支付链接
async function generatePaymentLinks(product, quantity, totalAmount, currency) {
  const baseUrl = process.env.FRONTEND_URL || 'https://your-app.com';
  const stripePublicKey = process.env.STRIPE_PUBLIC_KEY;
  
  const links = {};

  // Stripe Payment Link
  if (stripePublicKey) {
    const stripeParams = new URLSearchParams({
      'line_items[0][price_data][currency]': currency,
      'line_items[0][price_data][product_data][name]': product.name,
      'line_items[0][price_data][unit_amount]': product.default_price?.unit_amount || 0,
      'line_items[0][quantity]': quantity,
      'mode': 'payment',
      'success_url': `${baseUrl}/order/success?session_id={CHECKOUT_SESSION_ID}`,
      'cancel_url': `${baseUrl}/order/cancel`
    });

    links.stripe = `https://buy.stripe.com/test_your_link?${stripeParams.toString()}`;
  }

  // PayPal Payment Link
  const paypalParams = new URLSearchParams({
    'cmd': '_xclick',
    'business': process.env.PAYPAL_EMAIL || 'merchant@example.com',
    'item_name': product.name,
    'amount': (totalAmount / 100).toFixed(2),
    'currency_code': currency.toUpperCase(),
    'quantity': quantity,
    'return': `${baseUrl}/order/success`,
    'cancel_return': `${baseUrl}/order/cancel`
  });

  links.paypal = `https://www.sandbox.paypal.com/cgi-bin/webscr?${paypalParams.toString()}`;

  // 手动支付说明
  links.manual = {
    instructions: '请联系客服完成支付',
    contact: process.env.CUSTOMER_SERVICE_EMAIL || 'support@example.com',
    reference: `请在付款时备注订单号`
  };

  return links;
}

// 辅助函数：验证状态转换
function isValidStatusTransition(currentStatus, newStatus) {
  const validTransitions = {
    'pending': ['confirmed', 'cancelled', 'expired'],
    'confirmed': ['processing', 'cancelled'],
    'processing': ['shipped', 'cancelled'],
    'shipped': ['delivered'],
    'delivered': ['refunded'],
    'cancelled': [], // 取消状态不能转换
    'refunded': [], // 退款状态不能转换
    'expired': ['confirmed'] // 过期订单可以重新确认
  };

  return validTransitions[currentStatus]?.includes(newStatus) || false;
}

module.exports = router;