const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({
  _id: {
    type: String,
    required: true,
    default: () => require('uuid').v4()
  },
  email: {
    type: String,
    required: true,
    unique: true,
    lowercase: true,
    trim: true
  },
  role: {
    type: String,
    required: true,
    enum: ['Fan', 'Member', 'Master', 'Firstmate', 'Seller'],
    default: 'Fan'
  },
  nickname: {
    type: String,
    required: true,
    unique: true,
    trim: true,
    maxlength: 50
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
  collection: 'users'
});

// 更新时自动设置updatedAt
userSchema.pre('save', function(next) {
  this.updatedAt = new Date();
  next();
});

// 索引
userSchema.index({ email: 1 });
userSchema.index({ role: 1 });
userSchema.index({ nickname: 1 });

module.exports = mongoose.model('User', userSchema); 