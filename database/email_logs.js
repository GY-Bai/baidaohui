const mongoose = require('mongoose');

const emailLogSchema = new mongoose.Schema({
  userId: {
    type: String,
    required: true,
    ref: 'User',
    index: true
  },
  emailType: {
    type: String,
    required: true,
    enum: [
      'fortune_reply',
      'fortune_payment_success', 
      'role_upgrade',
      'welcome',
      'order_notification',
      'refund_confirmation',
      'custom'
    ],
    index: true
  },
  toEmail: {
    type: String,
    required: true,
    index: true
  },
  fromEmail: {
    type: String,
    default: 'noreply@baidaohui.com'
  },
  subject: {
    type: String,
    required: true
  },
  content: {
    html: String,
    text: String
  },
  status: {
    type: String,
    required: true,
    enum: ['pending', 'sent', 'failed', 'bounced'],
    default: 'pending',
    index: true
  },
  errorMessage: {
    type: String,
    default: null
  },
  sentAt: {
    type: Date,
    default: null
  },
  deliveredAt: {
    type: Date,
    default: null
  },
  openedAt: {
    type: Date,
    default: null
  },
  clickedAt: {
    type: Date,
    default: null
  },
  metadata: {
    // 邮件相关的元数据
    orderId: String,
    templateVersion: String,
    campaignId: String,
    tags: [String],
    priority: {
      type: String,
      enum: ['low', 'normal', 'high'],
      default: 'normal'
    }
  },
  retryCount: {
    type: Number,
    default: 0,
    min: 0
  },
  maxRetries: {
    type: Number,
    default: 3,
    min: 0
  }
}, {
  timestamps: true
});

// 复合索引
emailLogSchema.index({ userId: 1, emailType: 1, createdAt: -1 });
emailLogSchema.index({ status: 1, createdAt: -1 });
emailLogSchema.index({ toEmail: 1, createdAt: -1 });
emailLogSchema.index({ 'metadata.orderId': 1 });

// 虚拟字段：是否可重试
emailLogSchema.virtual('canRetry').get(function() {
  return this.status === 'failed' && this.retryCount < this.maxRetries;
});

// 虚拟字段：是否已送达
emailLogSchema.virtual('isDelivered').get(function() {
  return this.status === 'sent' && this.deliveredAt !== null;
});

// 实例方法：标记为已发送
emailLogSchema.methods.markAsSent = function() {
  this.status = 'sent';
  this.sentAt = new Date();
  return this.save();
};

// 实例方法：标记为失败
emailLogSchema.methods.markAsFailed = function(errorMessage) {
  this.status = 'failed';
  this.errorMessage = errorMessage;
  this.retryCount += 1;
  return this.save();
};

// 实例方法：标记为已送达
emailLogSchema.methods.markAsDelivered = function() {
  this.deliveredAt = new Date();
  return this.save();
};

// 实例方法：标记为已打开
emailLogSchema.methods.markAsOpened = function() {
  this.openedAt = new Date();
  return this.save();
};

// 实例方法：标记为已点击
emailLogSchema.methods.markAsClicked = function() {
  this.clickedAt = new Date();
  return this.save();
};

// 静态方法：获取用户邮件历史
emailLogSchema.statics.getUserEmailHistory = function(userId, limit = 50) {
  return this.find({ userId })
    .sort({ createdAt: -1 })
    .limit(limit);
};

// 静态方法：获取失败的邮件（用于重试）
emailLogSchema.statics.getFailedEmails = function() {
  return this.find({
    status: 'failed',
    retryCount: { $lt: this.maxRetries }
  }).sort({ createdAt: 1 });
};

// 静态方法：获取邮件统计
emailLogSchema.statics.getEmailStats = function(startDate, endDate) {
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
          status: '$status',
          emailType: '$emailType'
        },
        count: { $sum: 1 }
      }
    },
    {
      $group: {
        _id: '$_id.emailType',
        stats: {
          $push: {
            status: '$_id.status',
            count: '$count'
          }
        },
        total: { $sum: '$count' }
      }
    }
  ];
  
  return this.aggregate(pipeline);
};

// 静态方法：清理旧日志
emailLogSchema.statics.cleanupOldLogs = function(daysOld = 90) {
  const cutoffDate = new Date();
  cutoffDate.setDate(cutoffDate.getDate() - daysOld);
  
  return this.deleteMany({
    createdAt: { $lt: cutoffDate },
    status: { $in: ['sent', 'failed'] }
  });
};

module.exports = mongoose.model('EmailLog', emailLogSchema); 