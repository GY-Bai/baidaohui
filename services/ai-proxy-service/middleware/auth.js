const jwt = require('jsonwebtoken');
const { MongoClient } = require('mongodb');
const redis = require('redis');
const winston = require('winston');

const logger = winston.createLogger({
  level: 'info',
  format: winston.format.simple(),
  transports: [new winston.transports.Console()]
});

// MongoDB连接
let db;
MongoClient.connect(process.env.MONGODB_URI)
  .then(client => {
    db = client.db();
    logger.info('Connected to MongoDB for auth middleware');
  })
  .catch(err => {
    logger.error('MongoDB connection error:', err);
  });

// Redis连接
let redisClient;
if (process.env.REDIS_URL) {
  redisClient = redis.createClient({ url: process.env.REDIS_URL });
  redisClient.on('error', (err) => logger.error('Redis Client Error:', err));
  redisClient.connect();
}

// API Key验证中间件
const validateApiKey = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        error: {
          message: 'You didn\'t provide an API key. You need to provide your API key in an Authorization header using Bearer auth (i.e. Authorization: Bearer YOUR_KEY).',
          type: 'invalid_request_error',
          param: null,
          code: 'missing_api_key'
        }
      });
    }

    const apiKey = authHeader.substring(7); // 移除 'Bearer ' 前缀
    
    // 从缓存中检查API Key
    let keyData = null;
    if (redisClient) {
      try {
        const cached = await redisClient.get(`api_key:${apiKey}`);
        if (cached) {
          keyData = JSON.parse(cached);
        }
      } catch (err) {
        logger.warn('Redis cache error:', err);
      }
    }

    // 如果缓存中没有，从数据库查询
    if (!keyData && db) {
      keyData = await db.collection('ai_api_keys').findOne({ 
        key: apiKey,
        isActive: true,
        $or: [
          { expiresAt: null },
          { expiresAt: { $gt: new Date() } }
        ]
      });

      // 缓存结果（5分钟）
      if (keyData && redisClient) {
        try {
          await redisClient.setEx(`api_key:${apiKey}`, 300, JSON.stringify(keyData));
        } catch (err) {
          logger.warn('Redis cache set error:', err);
        }
      }
    }

    if (!keyData) {
      return res.status(401).json({
        error: {
          message: 'Incorrect API key provided. You can find your API key at https://api.baidaohui.com.',
          type: 'invalid_request_error',
          param: null,
          code: 'invalid_api_key'
        }
      });
    }

    // 检查使用限额
    if (keyData.dailyLimit && keyData.dailyUsage >= keyData.dailyLimit) {
      return res.status(429).json({
        error: {
          message: 'You exceeded your daily quota. Please check your plan and billing details.',
          type: 'quota_exceeded',
          param: null,
          code: 'quota_exceeded'
        }
      });
    }

    // 将API Key信息添加到请求对象
    req.apiKey = keyData;
    req.userId = keyData.userId;
    
    next();
  } catch (error) {
    logger.error('API key validation error:', error);
    res.status(500).json({
      error: {
        message: 'Internal server error during authentication',
        type: 'api_error',
        code: 'internal_error'
      }
    });
  }
};

// 管理员权限验证中间件
const requireAdmin = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        error: {
          message: 'Authorization required',
          type: 'invalid_request_error',
          code: 'unauthorized'
        }
      });
    }

    const token = authHeader.substring(7);
    
    // 验证JWT令牌
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    
    // 检查是否是管理员角色
    if (!decoded.role || !['master', 'firstmate'].includes(decoded.role)) {
      return res.status(403).json({
        error: {
          message: 'Admin access required',
          type: 'permission_error',
          code: 'insufficient_permissions'
        }
      });
    }

    req.user = decoded;
    next();
  } catch (error) {
    if (error.name === 'JsonWebTokenError') {
      return res.status(401).json({
        error: {
          message: 'Invalid token',
          type: 'invalid_request_error',
          code: 'invalid_token'
        }
      });
    }
    
    logger.error('Admin auth error:', error);
    res.status(500).json({
      error: {
        message: 'Internal server error during authorization',
        type: 'api_error',
        code: 'internal_error'
      }
    });
  }
};

// 更新API Key使用统计
const updateKeyUsage = async (apiKey) => {
  if (!db) return;
  
  try {
    const today = new Date().toISOString().split('T')[0];
    
    await db.collection('ai_api_keys').updateOne(
      { key: apiKey },
      { 
        $inc: { 
          totalUsage: 1,
          dailyUsage: 1
        },
        $set: { 
          lastUsed: new Date(),
          lastUsedDate: today
        }
      }
    );

    // 记录详细使用日志
    await db.collection('ai_usage_logs').insertOne({
      apiKey: apiKey,
      timestamp: new Date(),
      endpoint: '/v1/chat/completions',
      tokensUsed: 0, // 将在响应中更新
      cost: 0 // 将在响应中更新
    });

    // 清除缓存
    if (redisClient) {
      try {
        await redisClient.del(`api_key:${apiKey}`);
      } catch (err) {
        logger.warn('Redis cache delete error:', err);
      }
    }
  } catch (error) {
    logger.error('Update key usage error:', error);
  }
};

module.exports = {
  validateApiKey,
  requireAdmin,
  updateKeyUsage
}; 