const express = require('express');
const { ObjectId } = require('mongodb');
const axios = require('axios');
const router = express.Router();

// 获取静态支付链接
router.get('/links/:orderId', async (req, res) => {
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
    const order = await database.collection('orders').findOne({ 
      orderId: orderId,
      userId: req.user.sub || req.user.userId 
    });

    if (!order) {
      return res.status(404).json({ error: '订单不存在' });
    }

    // 检查订单是否过期
    if (order.expiresAt && new Date() > order.expiresAt) {
      return res.status(400).json({ error: '订单已过期' });
    }

    // 检查订单状态
    if (order.status !== 'pending') {
      return res.status(400).json({ error: '订单状态不允许支付' });
    }

    res.json({
      orderId: order.orderId,
      paymentLinks: order.paymentLinks,
      totalAmount: order.totalAmount,
      currency: order.currency,
      expiresAt: order.expiresAt,
      status: order.status
    });

  } catch (error) {
    console.error('获取支付链接失败:', error);
    res.status(500).json({ error: '获取支付链接失败' });
  }
});

// 更新支付状态（内部调用）
router.post('/update-status', async (req, res) => {
  try {
    const { orderId, status, paymentId, transactionId } = req.body;

    // 验证内部调用（可以通过特殊header或API key）
    const internalKey = req.headers['x-internal-key'];
    if (internalKey !== process.env.INTERNAL_API_KEY) {
      return res.status(403).json({ error: '无权限访问' });
    }

    const { db, clearCache } = require('../app');
    const database = db();
    
    if (!database) {
      return res.status(500).json({ error: '数据库连接未就绪' });
    }

    // 验证状态转换
    const validStatuses = ['pending', 'paid', 'failed', 'cancelled', 'refunded'];
    if (!validStatuses.includes(status)) {
      return res.status(400).json({ error: '无效的状态' });
    }

    // 更新订单状态
    const updateData = {
      status: status,
      updatedAt: new Date()
    };

    if (paymentId) {
      updateData.paymentId = paymentId;
    }

    if (transactionId) {
      updateData.transactionId = transactionId;
    }

    if (status === 'paid') {
      updateData.paidAt = new Date();
    }

    const result = await database.collection('orders').updateOne(
      { orderId: orderId },
      { $set: updateData }
    );

    if (result.matchedCount === 0) {
      return res.status(404).json({ error: '订单不存在' });
    }

    // 清除缓存
    clearCache('orders');

    console.log(`订单 ${orderId} 状态更新为: ${status}`);

    res.json({
      success: true,
      orderId: orderId,
      status: status,
      updatedAt: updateData.updatedAt
    });

  } catch (error) {
    console.error('更新支付状态失败:', error);
    res.status(500).json({ error: '更新支付状态失败' });
  }
});

// 取消订单
router.post('/cancel/:orderId', async (req, res) => {
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
    const order = await database.collection('orders').findOne({ 
      orderId: orderId,
      userId: req.user.sub || req.user.userId 
    });

    if (!order) {
      return res.status(404).json({ error: '订单不存在' });
    }

    // 检查订单状态
    if (order.status !== 'pending') {
      return res.status(400).json({ error: '只能取消待支付的订单' });
    }

    // 更新订单状态
    const result = await database.collection('orders').updateOne(
      { orderId: orderId },
      { 
        $set: { 
          status: 'cancelled',
          cancelReason: reason || '用户取消',
          cancelledAt: new Date(),
          updatedAt: new Date()
        }
      }
    );

    // 清除缓存
    clearCache('orders');

    console.log(`用户 ${req.user.email} 取消订单: ${orderId}`);

    res.json({
      success: true,
      orderId: orderId,
      status: 'cancelled',
      message: '订单已取消'
    });

  } catch (error) {
    console.error('取消订单失败:', error);
    res.status(500).json({ error: '取消订单失败' });
  }
});

// 申请退款
router.post('/refund/:orderId', async (req, res) => {
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
    const { reason, amount } = req.body;

    // 查找订单
    const order = await database.collection('orders').findOne({ 
      orderId: orderId,
      userId: req.user.sub || req.user.userId 
    });

    if (!order) {
      return res.status(404).json({ error: '订单不存在' });
    }

    // 检查订单状态
    if (order.status !== 'paid') {
      return res.status(400).json({ error: '只能对已支付的订单申请退款' });
    }

    // 检查退款金额
    const refundAmount = amount || order.totalAmount;
    if (refundAmount > order.totalAmount) {
      return res.status(400).json({ error: '退款金额不能超过订单金额' });
    }

    // 创建退款申请
    const refundRequest = {
      orderId: orderId,
      userId: req.user.sub || req.user.userId,
      amount: refundAmount,
      currency: order.currency,
      reason: reason || '用户申请退款',
      status: 'pending',
      createdAt: new Date()
    };

    await database.collection('refund_requests').insertOne(refundRequest);

    // 更新订单状态
    await database.collection('orders').updateOne(
      { orderId: orderId },
      { 
        $set: { 
          status: 'refund_requested',
          refundRequestedAt: new Date(),
          updatedAt: new Date()
        }
      }
    );

    // 清除缓存
    clearCache('orders');

    console.log(`用户 ${req.user.email} 申请退款: ${orderId}`);

    res.json({
      success: true,
      orderId: orderId,
      refundAmount: refundAmount,
      status: 'refund_requested',
      message: '退款申请已提交，请等待处理'
    });

  } catch (error) {
    console.error('申请退款失败:', error);
    res.status(500).json({ error: '申请退款失败' });
  }
});

// 管理员处理退款（仅管理员）
router.post('/process-refund/:refundId', async (req, res) => {
  try {
    const { smartAuthenticate, requireAdmin, db, clearCache } = require('../app');
    
    // 验证管理员身份
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
    const { action, adminNote } = req.body; // action: 'approve' | 'reject'

    if (!['approve', 'reject'].includes(action)) {
      return res.status(400).json({ error: '无效的操作' });
    }

    // 查找退款申请
    const refundRequest = await database.collection('refund_requests').findOne({ 
      _id: new ObjectId(refundId) 
    });

    if (!refundRequest) {
      return res.status(404).json({ error: '退款申请不存在' });
    }

    if (refundRequest.status !== 'pending') {
      return res.status(400).json({ error: '退款申请已处理' });
    }

    // 更新退款申请状态
    const updateData = {
      status: action === 'approve' ? 'approved' : 'rejected',
      adminId: req.user.sub || req.user.userId,
      adminNote: adminNote || '',
      processedAt: new Date()
    };

    await database.collection('refund_requests').updateOne(
      { _id: new ObjectId(refundId) },
      { $set: updateData }
    );

    // 更新订单状态
    const newOrderStatus = action === 'approve' ? 'refunded' : 'paid';
    await database.collection('orders').updateOne(
      { orderId: refundRequest.orderId },
      { 
        $set: { 
          status: newOrderStatus,
          updatedAt: new Date()
        }
      }
    );

    // 清除缓存
    clearCache('orders');

    console.log(`管理员 ${req.user.email} ${action} 退款申请: ${refundId}`);

    res.json({
      success: true,
      refundId: refundId,
      action: action,
      status: updateData.status,
      message: `退款申请已${action === 'approve' ? '批准' : '拒绝'}`
    });

  } catch (error) {
    console.error('处理退款失败:', error);
    res.status(500).json({ error: '处理退款失败' });
  }
});

module.exports = router; 