const express = require('express');
const router = express.Router();

// API Key管理接口（管理员专用）
router.get('/', async (req, res) => {
  res.json({ message: 'API Key management - coming soon' });
});

router.post('/', async (req, res) => {
  res.json({ message: 'Create API Key - coming soon' });
});

router.delete('/:keyId', async (req, res) => {
  res.json({ message: 'Delete API Key - coming soon' });
});

module.exports = router; 