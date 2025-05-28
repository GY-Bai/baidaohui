const mongoose = require('mongoose');

const chatSchema = new mongoose.Schema({
  _id: {
    type: String,
    required: true,
    default: () => require('uuid').v4()
  },
  chatId: {
    type: String,
    required: true,
    index: true
  },
  sender: {
    type: String,
    required: true,
    ref: 'User'
  },
  receiver: {
    type: String,
    required: false,
    ref: 'User'
  },
  content: {
    type: String,
    required: true,
    maxlength: 2000
  },
  type: {
    type: String,
    required: true,
    enum: ['text', 'image'],
    default: 'text'
  },
  timestamp: {
    type: Date,
    default: Date.now,
    required: true
  },
  readAt: {
    type: Date,
    default: null
  },
  attachments: [{
    type: {
      type: String,
      enum: ['image', 'file', 'video'],
      required: true
    },
    url: {
      type: String,
      required: true
    },
    filename: String,
    size: Number,
    mimeType: String
  }],
  isRead: {
    type: Boolean,
    default: false
  },
  metadata: {
    type: mongoose.Schema.Types.Mixed,
    default: {}
  }
}, {
  timestamps: false,
  collection: 'chats'
});

// 索引
chatSchema.index({ chatId: 1, timestamp: -1 });
chatSchema.index({ sender: 1 });
chatSchema.index({ receiver: 1 });
chatSchema.index({ timestamp: -1 });
chatSchema.index({ isRead: 1 });

// 复合索引用于查询特定聊天室的消息
chatSchema.index({ chatId: 1, timestamp: 1 });

module.exports = mongoose.model('Chat', chatSchema); 