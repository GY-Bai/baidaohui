const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const winston = require('winston');
const dotenv = require('dotenv');
const axios = require('axios');

// 加载环境变量
dotenv.config();

// 创建Express应用
const app = express();
const PORT = process.env.AI_PROXY_PORT || 5012;

// 固定API Key配置
const FIXED_API_KEY = 'wzj5788@gmail.com';
const OPENROUTER_API_KEY = process.env.OPENROUTER_API_KEY;
const OPENROUTER_BASE_URL = process.env.OPENROUTER_BASE_URL || 'https://openrouter.ai/api/v1';
const DEFAULT_MODEL = process.env.DEFAULT_MODEL || 'deepseek/deepseek-r1-0528:free';

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

// 中间件配置 - 允许所有来源
app.use(helmet({
  contentSecurityPolicy: false,
  crossOriginEmbedderPolicy: false
}));

app.use(cors({
  origin: '*', // 允许所有来源
  credentials: false, // 不需要凭据
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With', 'Accept']
}));

app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// 全局速率限制 - 放宽限制
const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15分钟
  max: 10000, // 最多10000次请求
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

// 简化的API Key验证中间件
const validateApiKey = (req, res, next) => {
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
  
  // 检查是否是固定的API Key
  if (apiKey !== FIXED_API_KEY) {
    return res.status(401).json({
      error: {
        message: 'Incorrect API key provided. Please contact admin for the correct API key.',
        type: 'invalid_request_error',
        param: null,
        code: 'invalid_api_key'
      }
    });
  }

  // 将API Key信息添加到请求对象
  req.apiKey = apiKey;
  req.userId = 'fixed-user';
  
  next();
};

// 健康检查接口
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    service: 'ai-proxy-service',
    version: '1.0.0',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    config: {
      defaultModel: DEFAULT_MODEL,
      openrouterConnected: !!OPENROUTER_API_KEY
    }
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

// 模型列表接口
app.get('/v1/models', validateApiKey, (req, res) => {
  try {
    const models = [
      {
        id: 'gpt-4',
        object: 'model',
        created: Math.floor(Date.now() / 1000),
        owned_by: 'openai'
      },
      {
        id: 'gpt-4-turbo',
        object: 'model',
        created: Math.floor(Date.now() / 1000),
        owned_by: 'openai'
      },
      {
        id: 'gpt-3.5-turbo',
        object: 'model',
        created: Math.floor(Date.now() / 1000),
        owned_by: 'openai'
      },
      {
        id: 'claude-3-sonnet',
        object: 'model',
        created: Math.floor(Date.now() / 1000),
        owned_by: 'anthropic'
      },
      {
        id: 'deepseek-r1',
        object: 'model',
        created: Math.floor(Date.now() / 1000),
        owned_by: 'deepseek'
      }
    ];

    res.json({
      object: 'list',
      data: models
    });

    logger.info('Models list requested', {
      userId: req.userId,
      modelCount: models.length
    });

  } catch (error) {
    logger.error('Models list error:', error);
    res.status(500).json({
      error: {
        message: 'Internal server error',
        type: 'api_error',
        code: 'internal_error'
      }
    });
  }
});

// 聊天完成接口
app.post('/v1/chat/completions', validateApiKey, async (req, res) => {
  try {
    const { messages, model, stream = false, ...otherParams } = req.body;

    // 验证必需参数
    if (!messages || !Array.isArray(messages) || messages.length === 0) {
      return res.status(400).json({
        error: {
          message: 'Missing or invalid messages parameter',
          type: 'invalid_request_error',
          param: 'messages',
          code: 'missing_messages'
        }
      });
    }

    // 重写模型为默认模型
    const targetModel = DEFAULT_MODEL;
    
    // 构建OpenRouter请求
    const openRouterPayload = {
      model: targetModel,
      messages: messages,
      stream: stream,
      ...otherParams,
      transforms: ["middle-out"],
      route: "fallback"
    };

    // 记录请求日志
    logger.info('Chat completion request', {
      userId: req.userId,
      originalModel: model,
      targetModel: targetModel,
      messageCount: messages.length,
      stream: stream
    });

    if (stream) {
      return handleStreamResponse(req, res, openRouterPayload);
    } else {
      return handleNormalResponse(req, res, openRouterPayload);
    }

  } catch (error) {
    logger.error('Chat completion error:', error);
    res.status(500).json({
      error: {
        message: 'Internal server error',
        type: 'api_error',
        code: 'internal_error'
      }
    });
  }
});

// 处理非流式响应
const handleNormalResponse = async (req, res, openRouterPayload) => {
  try {
    const response = await axios.post(
      `${OPENROUTER_BASE_URL}/chat/completions`,
      openRouterPayload,
      {
        headers: {
          'Authorization': `Bearer ${OPENROUTER_API_KEY}`,
          'Content-Type': 'application/json',
          'HTTP-Referer': 'https://api.baidaohui.com',
          'X-Title': 'BaiDaoHui AI Proxy'
        },
        timeout: 120000
      }
    );

    // 返回OpenAI格式的响应
    res.json({
      id: response.data.id || `chatcmpl-${Date.now()}`,
      object: 'chat.completion',
      created: response.data.created || Math.floor(Date.now() / 1000),
      model: req.body.model || DEFAULT_MODEL,
      choices: response.data.choices,
      usage: response.data.usage,
      system_fingerprint: response.data.system_fingerprint
    });

  } catch (error) {
    handleOpenRouterError(error, res);
  }
};

// 处理流式响应
const handleStreamResponse = async (req, res, openRouterPayload) => {
  try {
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Headers', 'Cache-Control');

    const response = await axios.post(
      `${OPENROUTER_BASE_URL}/chat/completions`,
      { ...openRouterPayload, stream: true },
      {
        headers: {
          'Authorization': `Bearer ${OPENROUTER_API_KEY}`,
          'Content-Type': 'application/json',
          'HTTP-Referer': 'https://api.baidaohui.com',
          'X-Title': 'BaiDaoHui AI Proxy'
        },
        responseType: 'stream',
        timeout: 120000
      }
    );

    response.data.on('data', (chunk) => {
      const lines = chunk.toString().split('\n');
      
      for (const line of lines) {
        if (line.startsWith('data: ')) {
          const data = line.slice(6);
          
          if (data === '[DONE]') {
            res.write('data: [DONE]\n\n');
            continue;
          }

          try {
            const parsed = JSON.parse(data);
            
            // 重写模型名称
            if (parsed.model) {
              parsed.model = req.body.model || DEFAULT_MODEL;
            }

            res.write(`data: ${JSON.stringify(parsed)}\n\n`);
          } catch (parseError) {
            logger.warn('Parse error in stream:', parseError);
          }
        }
      }
    });

    response.data.on('end', () => {
      res.end();
    });

    response.data.on('error', (error) => {
      logger.error('Stream error:', error);
      res.write(`data: {"error": {"message": "Stream error", "type": "api_error"}}\n\n`);
      res.end();
    });

  } catch (error) {
    handleOpenRouterError(error, res);
  }
};

// 处理OpenRouter错误
const handleOpenRouterError = (error, res) => {
  logger.error('OpenRouter API error:', {
    message: error.message,
    status: error.response?.status,
    data: error.response?.data
  });

  if (error.response) {
    const status = error.response.status;
    const data = error.response.data;

    if (status === 400) {
      return res.status(400).json({
        error: {
          message: data.error?.message || 'Invalid request to AI service',
          type: 'invalid_request_error',
          code: 'bad_request'
        }
      });
    }

    if (status === 401) {
      return res.status(500).json({
        error: {
          message: 'AI service authentication failed',
          type: 'api_error',
          code: 'upstream_auth_error'
        }
      });
    }

    if (status === 429) {
      return res.status(429).json({
        error: {
          message: 'AI service rate limit exceeded',
          type: 'rate_limit_error',
          code: 'upstream_rate_limit'
        }
      });
    }

    if (status >= 500) {
      return res.status(502).json({
        error: {
          message: 'AI service temporarily unavailable',
          type: 'api_error',
          code: 'upstream_error'
        }
      });
    }
  }

  res.status(500).json({
    error: {
      message: 'Failed to connect to AI service',
      type: 'api_error',
      code: 'network_error'
    }
  });
};

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
    timestamp: new Date().toISOString(),
    apiKey: FIXED_API_KEY,
    defaultModel: DEFAULT_MODEL
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