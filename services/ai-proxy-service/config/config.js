const dotenv = require('dotenv');

// 加载环境变量
dotenv.config();

const config = {
  // 服务配置
  port: process.env.AI_PROXY_PORT || 5012,
  env: process.env.NODE_ENV || 'development',
  
  // OpenRouter配置
  openRouter: {
    baseUrl: process.env.OPENROUTER_BASE_URL || 'https://openrouter.ai/api/v1',
    apiKey: process.env.OPENROUTER_API_KEY,
    defaultModel: process.env.DEFAULT_MODEL || 'anthropic/claude-3-sonnet',
    fallbackModels: (process.env.FALLBACK_MODELS || 'openai/gpt-4,openai/gpt-3.5-turbo').split(',')
  },
  
  // 数据库配置
  database: {
    mongoUri: process.env.MONGODB_URI,
    redisUrl: process.env.REDIS_URL
  },
  
  // 限制配置
  limits: {
    rateLimit: parseInt(process.env.RATE_LIMIT_REQUESTS_PER_MINUTE) || 60,
    maxTokens: parseInt(process.env.MAX_TOKENS_PER_REQUEST) || 4000,
    requestTimeout: parseInt(process.env.REQUEST_TIMEOUT_MS) || 120000
  },
  
  // 安全配置
  security: {
    jwtSecret: process.env.JWT_SECRET,
    allowedOrigins: [
      'https://www.baidaohui.com',
      'https://fan.baidaohui.com',
      'https://member.baidaohui.com',
      'https://master.baidaohui.com',
      'https://firstmate.baidaohui.com',
      'https://seller.baidaohui.com',
      'http://localhost:5173'
    ]
  },
  
  // 日志配置
  logging: {
    level: process.env.LOG_LEVEL || 'info',
    errorLogPath: '/var/log/ai-proxy-error.log',
    combinedLogPath: '/var/log/ai-proxy-combined.log'
  }
};

// 验证必需的环境变量
const requiredEnvVars = [
  'OPENROUTER_API_KEY',
  'MONGODB_URI',
  'JWT_SECRET'
];

const missingVars = requiredEnvVars.filter(varName => !process.env[varName]);

if (missingVars.length > 0) {
  console.error('Missing required environment variables:', missingVars);
  process.exit(1);
}

module.exports = config; 