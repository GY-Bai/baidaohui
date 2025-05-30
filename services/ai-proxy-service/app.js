const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const NodeCache = require('node-cache');
const redis = require('redis');
const winston = require('winston');
const dotenv = require('dotenv');

// 加载环境变量
dotenv.config();

// 导入模块
const authMiddleware = require('./middleware/auth');
const rateLimitMiddleware = require('./middleware/rateLimit');
const chatController = require('./controllers/chat');
const modelsController = require('./controllers/models');
const keysController = require('./controllers/keys');
const statsController = require('./controllers/stats');
const configManager = require('./config/config');

// 创建Express应用
const app = express();
const PORT = process.env.AI_PROXY_PORT || 5012;

// 配置日志
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  defaultMeta: { service: 'ai-proxy-service' },
  transports: [
    new winston.transports.File({ filename: '/var/log/ai-proxy-error.log', level: 'error' }),
    new winston.transports.File({ filename: '/var/log/ai-proxy-combined.log' }),
    new winston.transports.Console({
      format: winston.format.simple()
    })
  ]
});

// 全局错误处理
process.on('uncaughtException', (error) => {
  logger.error('Uncaught Exception:', error);
  process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
  logger.error('Unhandled Rejection at:', promise, 'reason:', reason);
});

// 中间件配置
app.use(helmet({
  contentSecurityPolicy: false,
  crossOriginEmbedderPolicy: false
}));

app.use(cors({
  origin: ['https://www.baidaohui.com', 'https://fan.baidaohui.com', 'https://member.baidaohui.com', 
           'https://master.baidaohui.com', 'https://firstmate.baidaohui.com', 'https://seller.baidaohui.com',
           'http://localhost:5173'],
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With', 'Accept']
}));

app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// 全局速率限制
const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15分钟
  max: 1000, // 最多1000次请求
  message: {
    error: 'Too many requests',
    message: 'Rate limit exceeded. Please try again later.',
    resetTime: new Date(Date.now() + 15 * 60 * 1000)
  },
  standardHeaders: true,
  legacyHeaders: false
});

app.use(globalLimiter);

// 请求日志中间件
app.use((req, res, next) => {
  const startTime = Date.now();
  
  res.on('finish', () => {
    const duration = Date.now() - startTime;
    logger.info('Request completed', {
      method: req.method,
      url: req.url,
      statusCode: res.statusCode,
      duration: `${duration}ms`,
      userAgent: req.get('User-Agent'),
      ip: req.ip
    });
  });
  
  next();
});

// 健康检查接口
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    service: 'ai-proxy-service',
    version: '1.0.0',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    memory: process.memoryUsage()
  });
});

app.get('/v1/health', (req, res) => {
  res.json({
    status: 'healthy',
    service: 'ai-proxy-service',
    version: '1.0.0',
    timestamp: new Date().toISOString()
  });
});

// API Key管理接口（仅管理员）
app.use('/admin/keys', authMiddleware.requireAdmin, keysController);

// 统计和监控接口（仅管理员）
app.use('/admin/stats', authMiddleware.requireAdmin, statsController);

// OpenAI兼容接口
app.use('/v1/models', authMiddleware.validateApiKey, modelsController);
app.use('/v1/chat/completions', 
  authMiddleware.validateApiKey, 
  rateLimitMiddleware.perKeyLimit,
  chatController.completions
);

// 流式聊天接口
app.use('/v1/chat/completions', 
  authMiddleware.validateApiKey, 
  rateLimitMiddleware.perKeyLimit,
  chatController.streamCompletions
);

// 错误处理中间件
app.use((error, req, res, next) => {
  logger.error('Request error:', {
    error: error.message,
    stack: error.stack,
    url: req.url,
    method: req.method,
    body: req.body,
    headers: req.headers
  });

  if (error.name === 'ValidationError') {
    return res.status(400).json({
      error: {
        message: 'Invalid request data',
        type: 'invalid_request_error',
        details: error.message
      }
    });
  }

  if (error.name === 'UnauthorizedError') {
    return res.status(401).json({
      error: {
        message: 'Invalid API key',
        type: 'invalid_request_error',
        code: 'invalid_api_key'
      }
    });
  }

  if (error.name === 'RateLimitError') {
    return res.status(429).json({
      error: {
        message: 'Rate limit exceeded',
        type: 'requests_limit_exceeded',
        code: 'rate_limit_exceeded'
      }
    });
  }

  // 通用服务器错误
  res.status(500).json({
    error: {
      message: 'Internal server error',
      type: 'api_error',
      code: 'internal_error'
    }
  });
});

// 404处理
app.use('*', (req, res) => {
  res.status(404).json({
    error: {
      message: 'Endpoint not found',
      type: 'invalid_request_error',
      code: 'endpoint_not_found'
    }
  });
});

// 启动服务器
const server = app.listen(PORT, '0.0.0.0', () => {
  logger.info(`AI Proxy Service listening on port ${PORT}`, {
    port: PORT,
    env: process.env.NODE_ENV || 'development',
    timestamp: new Date().toISOString()
  });
});

// 优雅关闭
process.on('SIGTERM', () => {
  logger.info('SIGTERM received, shutting down gracefully');
  server.close(() => {
    logger.info('Process terminated');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  logger.info('SIGINT received, shutting down gracefully');
  server.close(() => {
    logger.info('Process terminated');
    process.exit(0);
  });
});

module.exports = app; 