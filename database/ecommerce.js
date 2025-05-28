const mongoose = require('mongoose');

const priceSchema = new mongoose.Schema({
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
  originalAmount: Number,
  discountPercentage: {
    type: Number,
    min: 0,
    max: 100,
    default: 0
  }
}, { _id: false });

const ecommerceSchema = new mongoose.Schema({
  _id: {
    type: String,
    required: true,
    default: () => require('uuid').v4()
  },
  productId: {
    type: String,
    required: true,
    unique: true,
    index: true
  },
  name: {
    type: String,
    required: true,
    trim: true,
    maxlength: 200
  },
  description: {
    type: String,
    required: true,
    maxlength: 2000
  },
  imageUrls: [{
    type: String,
    required: true
  }],
  price: {
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
  paymentLinkUrl: {
    type: String,
    required: true
  },
  storeId: {
    type: String,
    required: true,
    index: true
  },
  stripeProductId: {
    type: String,
    required: true
  },
  stripePriceId: {
    type: String,
    required: true
  },
  category: {
    type: String,
    default: 'general'
  },
  tags: [String],
  isActive: {
    type: Boolean,
    default: true
  },
  metadata: {
    type: mongoose.Schema.Types.Mixed,
    default: {}
  },
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
  collection: 'products'
});

// 更新时自动设置updatedAt
ecommerceSchema.pre('save', function(next) {
  this.updatedAt = new Date();
  next();
});

// 索引
ecommerceSchema.index({ productId: 1 });
ecommerceSchema.index({ storeId: 1 });
ecommerceSchema.index({ name: 'text', description: 'text' });
ecommerceSchema.index({ category: 1 });
ecommerceSchema.index({ tags: 1 });
ecommerceSchema.index({ isActive: 1 });
ecommerceSchema.index({ createdAt: -1 });
ecommerceSchema.index({ 'price.amount': 1 });

// 虚拟字段
ecommerceSchema.virtual('hasDiscount').get(function() {
  return this.price && this.price.discountPercentage > 0;
});

ecommerceSchema.virtual('finalPrice').get(function() {
  if (!this.price) return 0;
  if (this.hasDiscount) {
    return this.price.amount * (1 - this.price.discountPercentage / 100);
  }
  return this.price.amount;
});

module.exports = mongoose.model('Product', ecommerceSchema); 