const mongoose = require('mongoose');

const keySchema = new mongoose.Schema({
  userId: {
    type: String,
    required: true,
    ref: 'User',
    index: true
  },
  storeId: {
    type: String,
    required: true,
    index: true
  },
  keyType: {
    type: String,
    required: true,
    enum: ['stripe_secret', 'stripe_publishable']
  },
  keyHash: {
    type: String,
    required: true,
    // 脱敏显示，如 "****sk_test_123"
  },
  vaultPath: {
    type: String,
    required: true,
    // Vault中的存储路径
  },
  isActive: {
    type: Boolean,
    default: true,
    index: true
  },
  lastUsed: {
    type: Date,
    default: null
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
keySchema.index({ userId: 1, storeId: 1, keyType: 1 }, { unique: true });
keySchema.index({ storeId: 1, isActive: 1 });
keySchema.index({ keyType: 1, isActive: 1 });

// 虚拟字段：脱敏显示
keySchema.virtual('maskedKey').get(function() {
  return this.keyHash;
});

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

// 静态方法：获取用户的活跃密钥
keySchema.statics.getActiveKeys = function(userId, storeId = null) {
  const query = { userId, isActive: true };
  if (storeId) {
    query.storeId = storeId;
  }
  return this.find(query).sort({ createdAt: -1 });
};

// 静态方法：获取商店的密钥对
keySchema.statics.getStoreKeyPair = function(storeId) {
  return this.find({
    storeId,
    isActive: true
  }).sort({ keyType: 1 }); // secret 在前，publishable 在后
};

// 静态方法：清理非活跃密钥
keySchema.statics.cleanupInactive = function(daysOld = 30) {
  const cutoffDate = new Date();
  cutoffDate.setDate(cutoffDate.getDate() - daysOld);
  
  return this.deleteMany({
    isActive: false,
    updatedAt: { $lt: cutoffDate }
  });
};

module.exports = mongoose.model('Key', keySchema); 