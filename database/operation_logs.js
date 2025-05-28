const mongoose = require('mongoose');

const operationLogSchema = new mongoose.Schema({
  userId: {
    type: String,
    required: true,
    ref: 'User',
    index: true
  },
  userRole: {
    type: String,
    required: true,
    enum: ['Fan', 'Member', 'Master', 'Firstmate', 'Seller'],
    index: true
  },
  operation: {
    type: String,
    required: true,
    enum: [
      // 认证相关
      'login',
      'logout',
      'role_upgrade',
      
      // 邀请链接相关
      'generate_invite',
      'use_invite',
      
      // 算命相关
      'create_fortune_request',
      'modify_fortune_request',
      'reply_fortune_request',
      'update_fortune_status',
      
      // 电商相关
      'add_product',
      'update_product',
      'delete_product',
      'create_order',
      'update_order_status',
      
      // 支付相关
      'create_payment_session',
      'payment_success',
      'payment_failed',
      'refund_payment',
      
      // 聊天相关
      'send_message',
      'create_chat_room',
      'join_chat_room',
      'leave_chat_room',
      
      // 密钥管理
      'add_stripe_key',
      'update_stripe_key',
      'delete_stripe_key',
      'test_stripe_key',
      
      // 邮件相关
      'send_email',
      'email_delivered',
      'email_failed',
      
      // 系统管理
      'system_backup',
      'system_restore',
      'cleanup_data',
      
      // 其他
      'custom'
    ],
    index: true
  },
  targetType: {
    type: String,
    enum: [
      'user',
      'invite',
      'fortune_request',
      'product',
      'order',
      'payment',
      'chat_room',
      'message',
      'stripe_key',
      'email',
      'system',
      'other'
    ],
    index: true
  },
  targetId: {
    type: String,
    index: true
  },
  details: {
    // 操作的详细信息
    description: String,
    oldValue: mongoose.Schema.Types.Mixed,
    newValue: mongoose.Schema.Types.Mixed,
    metadata: mongoose.Schema.Types.Mixed,
    tags: [String]
  },
  result: {
    type: String,
    enum: ['success', 'failed', 'pending'],
    default: 'success',
    index: true
  },
  errorMessage: {
    type: String,
    default: null
  },
  ipAddress: {
    type: String,
    index: true
  },
  userAgent: {
    type: String
  },
  sessionId: {
    type: String,
    index: true
  },
  requestId: {
    type: String,
    index: true
  },
  duration: {
    type: Number, // 操作耗时（毫秒）
    min: 0
  }
}, {
  timestamps: true
});

// 复合索引
operationLogSchema.index({ userId: 1, operation: 1, createdAt: -1 });
operationLogSchema.index({ userRole: 1, operation: 1, createdAt: -1 });
operationLogSchema.index({ targetType: 1, targetId: 1, createdAt: -1 });
operationLogSchema.index({ result: 1, createdAt: -1 });
operationLogSchema.index({ ipAddress: 1, createdAt: -1 });

// 虚拟字段：操作是否成功
operationLogSchema.virtual('isSuccess').get(function() {
  return this.result === 'success';
});

// 虚拟字段：操作是否失败
operationLogSchema.virtual('isFailed').get(function() {
  return this.result === 'failed';
});

// 静态方法：记录操作日志
operationLogSchema.statics.logOperation = function(logData) {
  const log = new this(logData);
  return log.save();
};

// 静态方法：获取用户操作历史
operationLogSchema.statics.getUserOperations = function(userId, limit = 50) {
  return this.find({ userId })
    .sort({ createdAt: -1 })
    .limit(limit);
};

// 静态方法：获取特定操作的日志
operationLogSchema.statics.getOperationLogs = function(operation, limit = 100) {
  return this.find({ operation })
    .sort({ createdAt: -1 })
    .limit(limit);
};

// 静态方法：获取失败的操作
operationLogSchema.statics.getFailedOperations = function(startDate, endDate) {
  const query = { result: 'failed' };
  if (startDate && endDate) {
    query.createdAt = { $gte: startDate, $lte: endDate };
  }
  return this.find(query).sort({ createdAt: -1 });
};

// 静态方法：获取操作统计
operationLogSchema.statics.getOperationStats = function(startDate, endDate) {
  const pipeline = [
    {
      $match: {
        createdAt: {
          $gte: startDate,
          $lte: endDate
        }
      }
    },
    {
      $group: {
        _id: {
          operation: '$operation',
          result: '$result',
          userRole: '$userRole'
        },
        count: { $sum: 1 },
        avgDuration: { $avg: '$duration' }
      }
    },
    {
      $group: {
        _id: '$_id.operation',
        stats: {
          $push: {
            result: '$_id.result',
            userRole: '$_id.userRole',
            count: '$count',
            avgDuration: '$avgDuration'
          }
        },
        totalCount: { $sum: '$count' }
      }
    },
    {
      $sort: { totalCount: -1 }
    }
  ];
  
  return this.aggregate(pipeline);
};

// 静态方法：获取用户活动统计
operationLogSchema.statics.getUserActivityStats = function(userId, days = 30) {
  const startDate = new Date();
  startDate.setDate(startDate.getDate() - days);
  
  const pipeline = [
    {
      $match: {
        userId,
        createdAt: { $gte: startDate }
      }
    },
    {
      $group: {
        _id: {
          $dateToString: {
            format: '%Y-%m-%d',
            date: '$createdAt'
          }
        },
        operations: { $sum: 1 },
        uniqueOperations: { $addToSet: '$operation' }
      }
    },
    {
      $project: {
        date: '$_id',
        operations: 1,
        uniqueOperationCount: { $size: '$uniqueOperations' }
      }
    },
    {
      $sort: { date: 1 }
    }
  ];
  
  return this.aggregate(pipeline);
};

// 静态方法：清理旧日志
operationLogSchema.statics.cleanupOldLogs = function(daysOld = 180) {
  const cutoffDate = new Date();
  cutoffDate.setDate(cutoffDate.getDate() - daysOld);
  
  return this.deleteMany({
    createdAt: { $lt: cutoffDate },
    result: { $in: ['success', 'failed'] }
  });
};

// 静态方法：获取安全相关的操作
operationLogSchema.statics.getSecurityLogs = function(limit = 100) {
  const securityOperations = [
    'login',
    'logout', 
    'role_upgrade',
    'add_stripe_key',
    'delete_stripe_key'
  ];
  
  return this.find({
    operation: { $in: securityOperations }
  })
  .sort({ createdAt: -1 })
  .limit(limit);
};

module.exports = mongoose.model('OperationLog', operationLogSchema); 