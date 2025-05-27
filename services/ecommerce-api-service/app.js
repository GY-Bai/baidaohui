const express = require('express');
const cors = require('cors');
const { MongoClient } = require('mongodb');
const jwt = require('jsonwebtoken');
const axios = require('axios');
require('dotenv').config();

const app = express();

// 中间件
app.use(cors({ credentials: true }));
app.use(express.json());

// 配置
const MONGODB_URI = process.env.MONGODB_URI;
const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key';
const R2_ENDPOINT = process.env.R2_ENDPOINT;
const R2_BUCKET = process.env.R2_BUCKET;
const AUTH_SERVICE_URL = process.env.AUTH_SERVICE_URL || 'http://auth-service:5001';

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

// 验证用户身份的中间件
async function authenticateUser(req, res, next) {
  try {
    const token = req.cookies?.access_token || req.headers.authorization?.split(' ')[1];
    
    if (!token) {
      return res.status(401).json({ error: '未登录' });
    }

    // 验证JWT
    const payload = jwt.verify(token, JWT_SECRET);
    req.user = payload;
    next();
  } catch (error) {
    console.error('身份验证失败:', error);
    return res.status(401).json({ error: '无效的Token' });
  }
}

// 引入路由
const productsRouter = require('./routes/products');
const orderRouter = require('./routes/order');

app.use('/api', productsRouter);
app.use('/api', orderRouter);

// 健康检查
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    service: 'ecommerce-api-service',
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

const PORT = process.env.PORT || 5005;
app.listen(PORT, () => {
  console.log(`电商API服务启动，端口: ${PORT}`);
});

// 导出db和authenticateUser供路由使用
module.exports = { db: () => db, authenticateUser }; 