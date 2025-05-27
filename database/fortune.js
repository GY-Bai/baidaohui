const mongoose = require('mongoose');

const modificationSchema = new mongoose.Schema({
  modifiedAt: {
    type: Date,
    default: Date.now
  },
  oldMessage: String,
  newMessage: String,
  oldImages: [String],
  newImages: [String],
  modifiedBy: {
    type: String,
    ref: 'User'
  }
}, { _id: false });

const fortuneSchema = new mongoose.Schema({
  _id: {
    type: String,
    required: true,
    default: () => require('uuid').v4()
  },
  userId: {
    type: String,
    required: true,
    ref: 'User',
    index: true
  },
  images: [{
    url: String,
    originalName: String,
    uploadedAt: {
      type: Date,
      default: Date.now
    }
  }],
  message: {
    type: String,
    required: true,
    maxlength: 800
  },
  amount: {
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
  convertedAmountCAD: {
    type: Number,
    default: 0
  },
  status: {
    type: String,
    required: true,
    enum: ['Pending', 'Queued-payed', 'Queued-upload', 'Completed', 'Refunded'],
    default: 'Pending'
  },
  kidsEmergency: {
    type: Boolean,
    default: false
  },
  priority: {
    type: Number,
    default: 0
  },
  queueIndex: {
    type: Number,
    default: 0
  },
  percentile: {
    type: Number,
    default: 0
  },
  remainingModifications: {
    type: Number,
    default: 5
  },
  modifications: [modificationSchema],
  reply: {
    content: String,
    images: [String],
    repliedBy: {
      type: String,
      ref: 'User'
    },
    repliedAt: Date,
    draft: {
      type: Boolean,
      default: false
    }
  },
  paymentScreenshots: [String],
  createdAt: {
    type: Date,
    default: Date.now
  },
  updatedAt: {
    type: Date,
    default: Date.now
  }
}, {
  timestamps: true,
  collection: 'fortunes'
});

// 更新时自动设置updatedAt和remainingModifications
fortuneSchema.pre('save', function(next) {
  this.updatedAt = new Date();
  this.remainingModifications = Math.max(0, 5 - this.modifications.length);
  next();
});

// 索引
fortuneSchema.index({ userId: 1, createdAt: -1 });
fortuneSchema.index({ status: 1 });
fortuneSchema.index({ kidsEmergency: -1, convertedAmountCAD: -1 });
fortuneSchema.index({ queueIndex: 1 });
fortuneSchema.index({ createdAt: -1 });

// 虚拟字段
fortuneSchema.virtual('canModify').get(function() {
  return ['Pending', 'Queued-payed', 'Queued-upload'].includes(this.status) && 
         this.remainingModifications > 0;
});

module.exports = mongoose.model('Fortune', fortuneSchema); 