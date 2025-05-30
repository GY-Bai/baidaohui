const winston = require('winston');

const logger = winston.createLogger({
  level: 'info',
  format: winston.format.simple(),
  transports: [new winston.transports.Console()]
});

// 模型列表接口
const listModels = (req, res) => {
  try {
    // 返回支持的模型列表（虚拟化，实际使用的是配置的模型）
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
        id: 'claude-3-haiku',
        object: 'model',
        created: Math.floor(Date.now() / 1000),
        owned_by: 'anthropic'
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
};

module.exports = listModels; 