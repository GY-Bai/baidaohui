const mongoose = require('mongoose');

const keySchema = new mongoose.Schema({
  userId: {
    type: String,
    required: true,
    index: true
  },
  userRole: {
    type: String,
    required: true,
    enum: ['master', 'seller'],
    index: true
  },
  keyType: {
    type: String,
    required: true,
    enum: ['stripe_secret', 'stripe_publishable']
  },
  keyValue: {
    type: String,
    required: true
  },
  keyHash: {
    type: String,
    required: true // 脱敏显示用
  },
  storeId: {
    type: String,
    required: function() {
      return this.userRole === 'seller';
    },
    index: true
  },
  isActive: {
    type: Boolean,
    default: true,
    index: true
  },
  isListed: {
    type: Boolean,
    default: true, // 是否在电商页面展示（仅对seller有效）
    index: true
  },
  lastUsed: {
    type: Date,
    default: null
  },
  createdAt: {
    type: Date,
    default: Date.now,
    index: true
  },
  updatedAt: {
    type: Date,
    default: Date.now
  },
  metadata: {
    // 额外的元数据
    environment: {
      type: String,
      enum: ['test', 'live'],
      default: 'test'
    },
    description: String,
    permissions: [String]
  }
}, {
  timestamps: true
});

// 复合索引
keySchema.index({ userId: 1, keyType: 1 });
keySchema.index({ userRole: 1, isActive: 1 });
keySchema.index({ storeId: 1, isActive: 1, isListed: 1 });

// 虚拟字段 - 脱敏显示
keySchema.virtual('maskedKey').get(function() {
  if (!this.keyValue) return '';
  
  if (this.keyValue.startsWith('sk_')) {
    return `****${this.keyValue.slice(-6)}`;
  } else if (this.keyValue.startsWith('pk_')) {
    return `****${this.keyValue.slice(-6)}`;
  }
  return '****';
});

// 实例方法 - 验证密钥格式
keySchema.methods.validateKeyFormat = function() {
  const key = this.keyValue;
  
  if (this.keyType === 'stripe_secret') {
    return key.startsWith('sk_test_') || key.startsWith('sk_live_');
  } else if (this.keyType === 'stripe_publishable') {
    return key.startsWith('pk_test_') || key.startsWith('pk_live_');
  }
  
  return false;
};

// 实例方法：更新最后使用时间
keySchema.methods.updateLastUsed = function() {
  this.lastUsed = new Date();
  return this.save();
};

// 实例方法：停用密钥
keySchema.methods.deactivate = function() {
  this.isActive = false;
  return this.save();
};

// 静态方法 - 获取用户的有效密钥
keySchema.statics.getActiveKeys = function(userId, userRole) {
  return this.find({
    userId,
    userRole,
    isActive: true
  }).select('-keyValue'); // 不返回实际密钥值
};

// 静态方法 - 获取seller的上架密钥
keySchema.statics.getListedSellerKeys = function() {
  return this.find({
    userRole: 'seller',
    isActive: true,
    isListed: true
  });
};

// 静态方法 - 获取master的算命收款密钥
keySchema.statics.getMasterPaymentKeys = function() {
  return this.find({
    userRole: 'master',
    isActive: true
  });
};

// 更新时间中间件
keySchema.pre('save', function(next) {
  this.updatedAt = new Date();
  
  // 生成脱敏hash
  if (this.isModified('keyValue')) {
    this.keyHash = this.maskedKey;
  }
  
  next();
});

// 删除时清理相关数据
keySchema.pre('remove', function(next) {
  // 这里可以添加清理逻辑，比如通知相关服务
  next();
});

module.exports = mongoose.model('Key', keySchema); 