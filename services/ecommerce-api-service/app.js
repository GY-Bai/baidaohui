const express = require('express');
const cors = require('cors');
const { MongoClient } = require('mongodb');
const jwt = require('jsonwebtoken');
const axios = require('axios');
const rateLimit = require('express-rate-limit');
const NodeCache = require('node-cache');
require('dotenv').config();

const app = express();

// 初始化缓存 (TTL: 5分钟)
const cache = new NodeCache({ stdTTL: 300 });

// 中间件
app.use(cors({ 
  credentials: true,
  origin: process.env.ALLOWED_ORIGINS?.split(',') || ['http://localhost:3000']
}));
app.use(express.json({ limit: '10mb' }));

// 基础限流
const generalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15分钟
  max: 100, // 限制每个IP 100次请求
  message: { error: '请求过于频繁，请稍后再试' },
  standardHeaders: true,
  legacyHeaders: false,
});

// 严格限流（用于创建订单等敏感操作）
const strictLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15分钟
  max: 10, // 限制每个IP 10次请求
  message: { error: '操作过于频繁，请稍后再试' },
  standardHeaders: true,
  legacyHeaders: false,
});

app.use('/api', generalLimiter);

// 配置
const MONGODB_URI = process.env.MONGODB_URI;
const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key';
const R2_ENDPOINT = process.env.R2_ENDPOINT;
const R2_BUCKET = process.env.R2_BUCKET;
const AUTH_SERVICE_URL = process.env.AUTH_SERVICE_URL || 'http://auth-service:5001';
const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY;
const SUPABASE_JWT_SECRET = process.env.SUPABASE_JWT_SECRET;

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

// Supabase SSO 验证中间件
async function authenticateSupabase(req, res, next) {
  try {
    // 从 Cookie 或 Authorization Header 获取 token
    const token = req.cookies?.['sb-access-token'] || 
                  req.cookies?.access_token || 
                  req.headers.authorization?.split(' ')[1];

    if (!token) {
      return res.status(401).json({ error: '未登录' });
    }

    // 验证 Supabase JWT
    let payload;
    try {
      payload = jwt.verify(token, SUPABASE_JWT_SECRET);
    } catch (jwtError) {
      console.error('JWT验证失败:', jwtError.message);
      return res.status(401).json({ error: '无效的Token' });
    }

    // 检查 token 是否过期
    if (payload.exp && payload.exp < Date.now() / 1000) {
      return res.status(401).json({ error: 'Token已过期' });
    }

    // 验证用户是否存在于 Supabase
    try {
      const supabaseResponse = await axios.get(`${SUPABASE_URL}/auth/v1/user`, {
        headers: {
          'Authorization': `Bearer ${token}`,
          'apikey': SUPABASE_ANON_KEY
        },
        timeout: 5000
      });

      if (!supabaseResponse.data) {
        return res.status(401).json({ error: '用户验证失败' });
      }

      // 设置用户信息
      req.user = {
        sub: payload.sub,
        email: payload.email,
        role: payload.user_metadata?.role || 'user',
        userId: payload.sub,
        supabaseUser: supabaseResponse.data
      };

      next();
    } catch (supabaseError) {
      console.error('Supabase用户验证失败:', supabaseError.message);
      return res.status(401).json({ error: 'SSO验证失败' });
    }

  } catch (error) {
    console.error('身份验证失败:', error);
    return res.status(401).json({ error: '身份验证失败' });
  }
}

// 传统JWT验证中间件（向后兼容）
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

// 智能身份验证中间件（优先使用Supabase SSO）
async function smartAuthenticate(req, res, next) {
  // 优先尝试 Supabase SSO（从 Authorization header）
  const authHeader = req.headers.authorization;
  if (authHeader && authHeader.startsWith('Bearer ')) {
    return authenticateSupabase(req, res, next);
  }
  
  // 尝试从 Cookie 获取 Supabase token
  const supabaseToken = req.cookies?.['sb-access-token'] || req.cookies?.['access_token'];
  if (supabaseToken) {
    return authenticateSupabase(req, res, next);
  }
  
  // 最后回退到传统JWT（向后兼容）
  return authenticateUser(req, res, next);
}

// 管理员权限验证中间件
function requireAdmin(req, res, next) {
  if (!req.user) {
    return res.status(401).json({ error: '未登录' });
  }
  
  if (req.user.role !== 'Master' && req.user.role !== 'Firstmate' && req.user.role !== 'admin') {
    return res.status(403).json({ error: '需要管理员权限' });
  }
  
  next();
}

// 缓存中间件
function cacheMiddleware(duration = 300) {
  return (req, res, next) => {
    if (req.method !== 'GET') {
      return next();
    }

    const key = `cache:${req.originalUrl}`;
    const cached = cache.get(key);

    if (cached) {
      return res.json(cached);
    }

    // 重写 res.json 以缓存响应
    const originalJson = res.json;
    res.json = function(data) {
      cache.set(key, data, duration);
      return originalJson.call(this, data);
    };

    next();
  };
}

// 清除缓存的辅助函数
function clearCache(pattern) {
  const keys = cache.keys();
  keys.forEach(key => {
    if (key.includes(pattern)) {
      cache.del(key);
    }
  });
}

// 引入路由
const productsRouter = require('./routes/products');
const orderRouter = require('./routes/order');
const paymentRouter = require('./routes/payment');

// 应用路由
app.use('/api/products', cacheMiddleware(300), productsRouter);
app.use('/api/orders', strictLimiter, orderRouter);
app.use('/api/payment', strictLimiter, paymentRouter);

// 健康检查
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    service: 'ecommerce-api-service',
    timestamp: new Date().toISOString(),
    version: process.env.npm_package_version || '1.0.0',
    cache: {
      keys: cache.keys().length,
      stats: cache.getStats()
    }
  });
});

// 缓存管理接口（仅管理员）
app.post('/api/cache/clear', smartAuthenticate, requireAdmin, (req, res) => {
  const { pattern } = req.body;
  
  if (pattern) {
    clearCache(pattern);
  } else {
    cache.flushAll();
  }
  
  console.log(`缓存清理: ${pattern || 'all'} by ${req.user.email}`);
  res.json({ success: true, message: '缓存清理成功' });
});

// 错误处理中间件
app.use((error, req, res, next) => {
  console.error('服务器错误:', error);
  
  // 判断错误类型
  if (error.name === 'ValidationError') {
    return res.status(400).json({
      error: '数据验证失败',
      details: error.message
    });
  }
  
  if (error.name === 'MongoError' || error.name === 'MongoServerError') {
    return res.status(500).json({
      error: '数据库操作失败',
      message: process.env.NODE_ENV === 'development' ? error.message : '请稍后重试'
    });
  }
  
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
  console.log(`Supabase SSO: ${SUPABASE_URL ? '已启用' : '未配置'}`);
  console.log(`缓存策略: NodeCache (TTL: 5分钟)`);
  console.log(`限流策略: 一般请求 100/15分钟, 敏感操作 10/15分钟`);
});

// 优雅关闭
process.on('SIGTERM', () => {
  console.log('收到SIGTERM信号，正在关闭服务器...');
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('收到SIGINT信号，正在关闭服务器...');
  process.exit(0);
});

// 导出供路由使用
module.exports = { 
  db: () => db, 
  authenticateUser, 
  authenticateSupabase,
  smartAuthenticate,
  requireAdmin,
  cache,
  clearCache
};