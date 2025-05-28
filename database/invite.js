const mongoose = require('mongoose');

const inviteSchema = new mongoose.Schema({
  token: {
    type: String,
    required: true,
    unique: true,
    index: true
  },
  type: {
    type: String,
    required: true,
    enum: ['member', 'seller']
  },
  createdBy: {
    type: String,
    required: true,
    ref: 'User'
  },
  expiresAt: {
    type: Date,
    required: true,
    index: true
  },
  maxUse: {
    type: Number,
    required: true,
    min: 1
  },
  usedCount: {
    type: Number,
    default: 0,
    min: 0
  },
  usedBy: [{
    userId: {
      type: String,
      ref: 'User'
    },
    usedAt: {
      type: Date,
      default: Date.now
    }
  }],
  isActive: {
    type: Boolean,
    default: true,
    index: true
  }
}, {
  timestamps: true
});

// 复合索引
inviteSchema.index({ type: 1, isActive: 1 });
inviteSchema.index({ createdBy: 1, createdAt: -1 });
inviteSchema.index({ expiresAt: 1, isActive: 1 });

// 虚拟字段：是否已过期
inviteSchema.virtual('isExpired').get(function() {
  return new Date() > this.expiresAt;
});

// 虚拟字段：是否可用
inviteSchema.virtual('isAvailable').get(function() {
  return this.isActive && !this.isExpired && this.usedCount < this.maxUse;
});

// 实例方法：使用邀请链接
inviteSchema.methods.use = function(userId) {
  if (!this.isAvailable) {
    throw new Error('邀请链接不可用');
  }
  
  this.usedBy.push({ userId });
  this.usedCount += 1;
  
  if (this.usedCount >= this.maxUse) {
    this.isActive = false;
  }
  
  return this.save();
};

// 静态方法：清理过期链接
inviteSchema.statics.cleanupExpired = function() {
  return this.updateMany(
    { expiresAt: { $lt: new Date() }, isActive: true },
    { isActive: false }
  );
};

module.exports = mongoose.model('Invite', inviteSchema); 