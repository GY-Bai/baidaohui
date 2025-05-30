const express = require('express');
const router = express.Router();

// 统计和监控接口（管理员专用）
router.get('/', async (req, res) => {
  res.json({ message: 'Usage statistics - coming soon' });
});

router.get('/usage', async (req, res) => {
  res.json({ message: 'Usage analytics - coming soon' });
});

module.exports = router; 