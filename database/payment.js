const mongoose = require('mongoose');

const paymentSchema = new mongoose.Schema({
  _id: {
    type: String,
    required: true,
    default: () => require('uuid').v4()
  },
  sessionId: {
    type: String,
    required: true,
    unique: true,
    index: true
  },
  orderId: {
    type: String,
    required: true,
    index: true
  },
  userId: {
    type: String,
    required: true,
    ref: 'User',
    index: true
  },
  amountTotal: {
    type: Number,
    required: true,
    min: 0
  },
  currency: {
    type: String,
    required: true,
    enum: ['CNY', 'USD', 'CAD', 'SGD', 'AUD'],
    default: 'CAD'
  },
  status: {
    type: String,
    required: true,
    enum: ['pending', 'paid', 'failed', 'cancelled', 'refunded'],
    default: 'pending'
  },
  paymentMethod: {
    type: String,
    enum: ['stripe', 'manual_upload'],
    default: 'stripe'
  },
  stripePaymentIntentId: String,
  stripeCustomerId: String,
  metadata: {
    type: mongoose.Schema.Types.Mixed,
    default: {}
  },
  webhookEvents: [{
    eventId: String,
    eventType: String,
    processedAt: {
      type: Date,
      default: Date.now
    }
  }],
  refundInfo: {
    refundId: String,
    refundAmount: Number,
    refundReason: String,
    refundedAt: Date
  },
  createdAt: {
    type: Date,
    default: Date.now,
    required: true
  },
  updatedAt: {
    type: Date,
    default: Date.now
  },
  paidAt: Date,
  failedAt: Date,
  cancelledAt: Date
}, {
  timestamps: true,
  collection: 'payments'
});

// 更新时自动设置updatedAt
paymentSchema.pre('save', function(next) {
  this.updatedAt = new Date();
  
  // 根据状态设置相应的时间戳
  if (this.isModified('status')) {
    const now = new Date();
    switch (this.status) {
      case 'paid':
        if (!this.paidAt) this.paidAt = now;
        break;
      case 'failed':
        if (!this.failedAt) this.failedAt = now;
        break;
      case 'cancelled':
        if (!this.cancelledAt) this.cancelledAt = now;
        break;
    }
  }
  
  next();
});

// 索引
paymentSchema.index({ sessionId: 1 });
paymentSchema.index({ orderId: 1 });
paymentSchema.index({ userId: 1, createdAt: -1 });
paymentSchema.index({ status: 1 });
paymentSchema.index({ createdAt: -1 });
paymentSchema.index({ stripePaymentIntentId: 1 });

// 虚拟字段
paymentSchema.virtual('isCompleted').get(function() {
  return this.status === 'paid';
});

paymentSchema.virtual('canRefund').get(function() {
  return this.status === 'paid' && !this.refundInfo;
});

module.exports = mongoose.model('Payment', paymentSchema); 