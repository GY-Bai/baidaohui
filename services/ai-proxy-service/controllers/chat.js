const axios = require('axios');
const winston = require('winston');
const configManager = require('../config/config');
const authMiddleware = require('../middleware/auth');

const logger = winston.createLogger({
  level: 'info',
  format: winston.format.simple(),
  transports: [new winston.transports.Console()]
});

// OpenRouter配置
const OPENROUTER_BASE_URL = process.env.OPENROUTER_BASE_URL || 'https://openrouter.ai/api/v1';
const OPENROUTER_API_KEY = process.env.OPENROUTER_API_KEY;
const DEFAULT_MODEL = process.env.DEFAULT_MODEL || 'anthropic/claude-3-sonnet';
const FALLBACK_MODELS = (process.env.FALLBACK_MODELS || 'openai/gpt-4,openai/gpt-3.5-turbo').split(',');

// 聊天完成接口
const completions = async (req, res) => {
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

    // 重写模型为管理员配置的模型
    const targetModel = getTargetModel(model);
    
    // 构建OpenRouter请求
    const openRouterPayload = {
      model: targetModel,
      messages: messages,
      stream: stream,
      ...otherParams,
      // 添加OpenRouter特定参数
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
};

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
        timeout: 120000 // 2分钟超时
      }
    );

    // 更新使用统计
    const usage = response.data.usage;
    if (usage) {
      await authMiddleware.updateKeyUsage(req.apiKey.key, {
        tokensUsed: usage.total_tokens,
        promptTokens: usage.prompt_tokens,
        completionTokens: usage.completion_tokens
      });
    }

    // 返回OpenAI格式的响应
    res.json({
      id: response.data.id || `chatcmpl-${Date.now()}`,
      object: 'chat.completion',
      created: response.data.created || Math.floor(Date.now() / 1000),
      model: req.body.model || DEFAULT_MODEL, // 返回用户请求的模型名
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
    // 设置SSE响应头
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

    let totalTokens = 0;

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

            // 计算tokens
            if (parsed.choices && parsed.choices[0] && parsed.choices[0].delta && parsed.choices[0].delta.content) {
              totalTokens += estimateTokens(parsed.choices[0].delta.content);
            }

            res.write(`data: ${JSON.stringify(parsed)}\n\n`);
          } catch (parseError) {
            logger.warn('Parse error in stream:', parseError);
          }
        }
      }
    });

    response.data.on('end', async () => {
      // 更新使用统计
      if (totalTokens > 0) {
        await authMiddleware.updateKeyUsage(req.apiKey.key, {
          tokensUsed: totalTokens,
          promptTokens: Math.floor(totalTokens * 0.3), // 估算
          completionTokens: Math.floor(totalTokens * 0.7)
        });
      }
      
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

// 获取目标模型
const getTargetModel = (requestedModel) => {
  // 总是使用管理员配置的默认模型
  return DEFAULT_MODEL;
};

// 处理OpenRouter错误
const handleOpenRouterError = (error, res) => {
  logger.error('OpenRouter API error:', {
    message: error.message,
    status: error.response?.status,
    data: error.response?.data
  });

  if (error.response) {
    // OpenRouter返回的错误
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

  // 网络错误或其他错误
  res.status(500).json({
    error: {
      message: 'Failed to connect to AI service',
      type: 'api_error',
      code: 'network_error'
    }
  });
};

// 估算token数量（简单实现）
const estimateTokens = (text) => {
  if (!text) return 0;
  // 粗略估算：1个token约等于4个字符
  return Math.ceil(text.length / 4);
};

module.exports = {
  completions
}; 