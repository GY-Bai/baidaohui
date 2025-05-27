const express = require('express');
const { ObjectId } = require('mongodb');
const router = express.Router();

// 创建订单
router.post('/order', async (req, res) => {
  try {
    const { authenticateUser, db } = require('../app');
    
    // 验证用户身份
    await new Promise((resolve, reject) => {
      authenticateUser(req, res, (err) => {
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
      notes
    } = req.body;

    // 验证必填字段
    if (!productId) {
      return res.status(400).json({ error: '缺少产品ID' });
    }

    if (!customerInfo || !customerInfo.email) {
      return res.status(400).json({ error: '缺少客户信息' });
    }

    // 获取产品信息
    const product = await database.collection('products').findOne({ id: productId });
    if (!product) {
      return res.status(404).json({ error: '产品不存在' });
    }

    // 计算订单金额
    const unitPrice = product.default_price?.unit_amount || 0;
    const totalAmount = unitPrice * quantity;

    // 创建订单
    const order = {
      orderId: generateOrderId(),
      userId: req.user.sub,
      userEmail: req.user.email,
      product: {
        id: product.id,
        name: product.name,
        description: product.description,
        images: product.images || [],
        unitPrice: unitPrice,
        currency: product.default_price?.currency || 'usd'
      },
      quantity: quantity,
      totalAmount: totalAmount,
      currency: product.default_price?.currency || 'usd',
      customerInfo: {
        name: customerInfo.name || req.user.email.split('@')[0],
        email: customerInfo.email,
        phone: customerInfo.phone || ''
      },
      shippingAddress: shippingAddress || {},
      notes: notes || '',
      status: 'pending',
      storeId: product.storeId,
      createdAt: new Date(),
      updatedAt: new Date()
    };

    const result = await database.collection('orders').insertOne(order);
    order._id = result.insertedId;

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
        createdAt: order.createdAt
      }
    });

  } catch (error) {
    console.error('创建订单失败:', error);
    res.status(500).json({ error: '创建订单失败' });
  }
});

// 获取用户订单列表
router.get('/orders', async (req, res) => {
  try {
    const { authenticateUser, db } = require('../app');
    
    // 验证用户身份
    await new Promise((resolve, reject) => {
      authenticateUser(req, res, (err) => {
        if (err) reject(err);
        else resolve();
      });
    });

    const database = db();
    if (!database) {
      return res.status(500).json({ error: '数据库连接未就绪' });
    }

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
router.get('/orders/:orderId', async (req, res) => {
  try {
    const { authenticateUser, db } = require('../app');
    
    // 验证用户身份
    await new Promise((resolve, reject) => {
      authenticateUser(req, res, (err) => {
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

    // 检查权限（用户只能查看自己的订单，Master/Firstmate可以查看所有订单）
    if (req.user.role !== 'Master' && req.user.role !== 'Firstmate' && order.userId !== req.user.sub) {
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
        createdAt: order.createdAt,
        updatedAt: order.updatedAt
      }
    });

  } catch (error) {
    console.error('获取订单详情失败:', error);
    res.status(500).json({ error: '获取订单详情失败' });
  }
});

// 更新订单状态（仅Master/Firstmate可用）
router.patch('/orders/:orderId/status', async (req, res) => {
  try {
    const { authenticateUser, db } = require('../app');
    
    // 验证用户身份
    await new Promise((resolve, reject) => {
      authenticateUser(req, res, (err) => {
        if (err) reject(err);
        else resolve();
      });
    });

    // 检查权限
    if (req.user.role !== 'Master' && req.user.role !== 'Firstmate') {
      return res.status(403).json({ error: '无权限更新订单状态' });
    }

    const database = db();
    if (!database) {
      return res.status(500).json({ error: '数据库连接未就绪' });
    }

    const { orderId } = req.params;
    const { status, notes } = req.body;

    if (!status) {
      return res.status(400).json({ error: '缺少状态参数' });
    }

    // 验证状态值
    const validStatuses = ['pending', 'confirmed', 'processing', 'shipped', 'delivered', 'cancelled', 'refunded'];
    if (!validStatuses.includes(status)) {
      return res.status(400).json({ error: '无效的状态值' });
    }

    // 查找并更新订单
    let order;
    if (ObjectId.isValid(orderId)) {
      order = await database.collection('orders').findOne({ _id: new ObjectId(orderId) });
    } else {
      order = await database.collection('orders').findOne({ orderId: orderId });
    }

    if (!order) {
      return res.status(404).json({ error: '订单不存在' });
    }

    // 更新订单
    const updateData = {
      status: status,
      updatedAt: new Date(),
      updatedBy: req.user.sub
    };

    if (notes) {
      updateData.adminNotes = notes;
    }

    await database.collection('orders').updateOne(
      { _id: order._id },
      { $set: updateData }
    );

    console.log(`${req.user.role} ${req.user.email} 更新订单 ${order.orderId} 状态为: ${status}`);

    res.json({
      success: true,
      message: '订单状态更新成功',
      orderId: order.orderId,
      newStatus: status
    });

  } catch (error) {
    console.error('更新订单状态失败:', error);
    res.status(500).json({ error: '更新订单状态失败' });
  }
});

// 生成订单ID
function generateOrderId() {
  const timestamp = Date.now().toString(36);
  const randomStr = Math.random().toString(36).substring(2, 8);
  return `ORD-${timestamp}-${randomStr}`.toUpperCase();
}

module.exports = router; 