const rateLimit = require('express-rate-limit');
const redis = require('redis');
const winston = require('winston');

const logger = winston.createLogger({
  level: 'info',
  format: winston.format.simple(),
  transports: [new winston.transports.Console()]
});

// Redis连接
let redisClient;
if (process.env.REDIS_URL) {
  redisClient = redis.createClient({ url: process.env.REDIS_URL });
  redisClient.on('error', (err) => logger.error('Redis Client Error:', err));
  redisClient.connect();
}

// 基于API Key的速率限制
const perKeyLimit = async (req, res, next) => {
  try {
    const apiKey = req.apiKey;
    const keyId = apiKey._id.toString();
    const now = Date.now();
    const windowMs = 60 * 1000; // 1分钟窗口
    const maxRequests = apiKey.rateLimit || parseInt(process.env.RATE_LIMIT_REQUESTS_PER_MINUTE) || 60;

    if (!redisClient) {
      // 如果没有Redis，跳过速率限制
      return next();
    }

    const windowStart = Math.floor(now / windowMs) * windowMs;
    const redisKey = `rate_limit:${keyId}:${windowStart}`;

    try {
      const current = await redisClient.get(redisKey);
      const currentCount = current ? parseInt(current) : 0;

      if (currentCount >= maxRequests) {
        return res.status(429).json({
          error: {
            message: `Rate limit exceeded. You can make ${maxRequests} requests per minute.`,
            type: 'requests_limit_exceeded',
            code: 'rate_limit_exceeded'
          }
        });
      }

      // 增加计数
      await redisClient.multi()
        .incr(redisKey)
        .expire(redisKey, Math.ceil(windowMs / 1000))
        .exec();

      // 设置响应头
      res.set({
        'X-RateLimit-Limit': maxRequests,
        'X-RateLimit-Remaining': Math.max(0, maxRequests - currentCount - 1),
        'X-RateLimit-Reset': Math.ceil((windowStart + windowMs) / 1000)
      });

      next();

    } catch (redisError) {
      logger.warn('Redis rate limit error:', redisError);
      // Redis错误时跳过速率限制
      next();
    }

  } catch (error) {
    logger.error('Rate limit middleware error:', error);
    next(); // 出错时继续处理请求
  }
};

// 基于IP的全局速率限制
const globalIpLimit = rateLimit({
  windowMs: 15 * 60 * 1000, // 15分钟
  max: 100, // 最多100次请求
  message: {
    error: {
      message: 'Too many requests from this IP, please try again later.',
      type: 'rate_limit_error',
      code: 'ip_rate_limit_exceeded'
    }
  },
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req) => {
    return req.ip || req.connection.remoteAddress;
  }
});

module.exports = {
  perKeyLimit,
  globalIpLimit
}; 