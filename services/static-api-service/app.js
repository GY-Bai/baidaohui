const express = require('express');
const cors = require('cors');
const { MongoClient } = require('mongodb');
const NodeCache = require('node-cache');
const rateLimit = require('express-rate-limit');

const app = express();

// 中间件
app.use(cors({
  origin: process.env.CORS_ORIGINS?.split(',') || ['https://baidaohui.com'],
  credentials: true
}));
app.use(express.json());

// 配置
const MONGODB_URI = process.env.MONGODB_URI;
const R2_ENDPOINT = process.env.R2_ENDPOINT;
const R2_BUCKET = process.env.R2_BUCKET;
const CACHE_TTL = parseInt(process.env.CACHE_TTL) || 300; // 5分钟缓存

// 本地缓存
const cache = new NodeCache({ stdTTL: CACHE_TTL });

// 限流配置
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15分钟
  max: 1000, // 每个IP最多1000次请求
  message: { error: '请求过于频繁，请稍后再试' }
});

app.use(limiter);

// MongoDB连接
let db;
MongoClient.connect(MONGODB_URI)
  .then(client => {
    console.log('MongoDB连接成功');
    db = client.db('baidaohui');
  })
  .catch(error => {
    console.error('MongoDB连接失败:', error);
    process.exit(1);
  });

// 健康检查
app.get('/health', (req, res) => {
  res.json({ 
    status: 'healthy', 
    service: 'static-api-service',
    timestamp: new Date().toISOString(),
    cache_stats: cache.getStats()
  });
});

// 获取产品列表（高度缓存）
app.get('/api/products', async (req, res) => {
  try {
    const cacheKey = 'products_list';
    let products = cache.get(cacheKey);
    
    if (!products) {
      // 优先从R2获取静态JSON
      try {
        const r2Response = await fetch(`${R2_ENDPOINT}/${R2_BUCKET}/products.json`);
        if (r2Response.ok) {
          products = await r2Response.json();
          cache.set(cacheKey, products, CACHE_TTL);
          console.log('从R2获取产品数据');
        }
      } catch (r2Error) {
        console.log('R2获取失败，从MongoDB获取:', r2Error.message);
      }
      
      // 兜底从MongoDB获取
      if (!products) {
        products = await db.collection('products')
          .find({ isActive: true })
          .sort({ createdAt: -1 })
          .limit(100)
          .toArray();
        
        cache.set(cacheKey, products, CACHE_TTL);
        console.log('从MongoDB获取产品数据');
      }
    }
    
    res.set('Cache-Control', 'public, max-age=300'); // 5分钟浏览器缓存
    res.json({
      success: true,
      data: products,
      cached: true,
      source: 'static-api-service'
    });
    
  } catch (error) {
    console.error('获取产品列表失败:', error);
    res.status(500).json({
      success: false,
      error: '获取产品列表失败'
    });
  }
});

// 获取产品详情（缓存）
app.get('/api/products/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const cacheKey = `product_${id}`;
    let product = cache.get(cacheKey);
    
    if (!product) {
      product = await db.collection('products').findOne({ 
        $or: [
          { _id: new ObjectId(id) },
          { productId: id },
          { stripeProductId: id }
        ]
      });
      
      if (product) {
        cache.set(cacheKey, product, CACHE_TTL);
      }
    }
    
    if (!product) {
      return res.status(404).json({
        success: false,
        error: '产品不存在'
      });
    }
    
    res.set('Cache-Control', 'public, max-age=300');
    res.json({
      success: true,
      data: product,
      cached: true
    });
    
  } catch (error) {
    console.error('获取产品详情失败:', error);
    res.status(500).json({
      success: false,
      error: '获取产品详情失败'
    });
  }
});

// 获取算命申请统计（缓存）
app.get('/api/fortune/stats', async (req, res) => {
  try {
    const cacheKey = 'fortune_stats';
    let stats = cache.get(cacheKey);
    
    if (!stats) {
      const [totalCount, pendingCount, completedCount] = await Promise.all([
        db.collection('fortune_applications').countDocuments(),
        db.collection('fortune_applications').countDocuments({ status: { $in: ['Pending', 'Queued-payed', 'Queued-upload'] } }),
        db.collection('fortune_applications').countDocuments({ status: 'Completed' })
      ]);
      
      stats = {
        total: totalCount,
        pending: pendingCount,
        completed: completedCount,
        updated_at: new Date().toISOString()
      };
      
      cache.set(cacheKey, stats, 60); // 1分钟缓存
    }
    
    res.set('Cache-Control', 'public, max-age=60');
    res.json({
      success: true,
      data: stats,
      cached: true
    });
    
  } catch (error) {
    console.error('获取算命统计失败:', error);
    res.status(500).json({
      success: false,
      error: '获取统计数据失败'
    });
  }
});

// 获取汇率信息（高度缓存）
app.get('/api/exchange-rates', async (req, res) => {
  try {
    const cacheKey = 'exchange_rates';
    let rates = cache.get(cacheKey);
    
    if (!rates) {
      rates = await db.collection('exchange_rates').findOne(
        {},
        { sort: { updatedAt: -1 } }
      );
      
      if (rates) {
        cache.set(cacheKey, rates, 3600); // 1小时缓存
      }
    }
    
    if (!rates) {
      return res.status(404).json({
        success: false,
        error: '汇率数据不可用'
      });
    }
    
    res.set('Cache-Control', 'public, max-age=3600'); // 1小时浏览器缓存
    res.json({
      success: true,
      data: rates,
      cached: true
    });
    
  } catch (error) {
    console.error('获取汇率失败:', error);
    res.status(500).json({
      success: false,
      error: '获取汇率失败'
    });
  }
});

// 获取公开的邀请链接信息（缓存）
app.get('/api/invite/:token/info', async (req, res) => {
  try {
    const { token } = req.params;
    const cacheKey = `invite_info_${token}`;
    let inviteInfo = cache.get(cacheKey);
    
    if (!inviteInfo) {
      const invite = await db.collection('invite_links').findOne({ 
        token,
        isActive: true,
        expiresAt: { $gt: new Date() }
      });
      
      if (invite) {
        inviteInfo = {
          type: invite.type,
          expiresAt: invite.expiresAt,
          maxUse: invite.maxUse,
          usedCount: invite.usedCount,
          isValid: invite.usedCount < invite.maxUse
        };
        
        cache.set(cacheKey, inviteInfo, 300); // 5分钟缓存
      }
    }
    
    if (!inviteInfo) {
      return res.status(404).json({
        success: false,
        error: '邀请链接无效或已过期'
      });
    }
    
    res.set('Cache-Control', 'public, max-age=300');
    res.json({
      success: true,
      data: inviteInfo,
      cached: true
    });
    
  } catch (error) {
    console.error('获取邀请链接信息失败:', error);
    res.status(500).json({
      success: false,
      error: '获取邀请链接信息失败'
    });
  }
});

// 缓存管理接口
app.post('/api/cache/clear', (req, res) => {
  const { key } = req.body;
  
  if (key) {
    cache.del(key);
    res.json({ success: true, message: `缓存键 ${key} 已清除` });
  } else {
    cache.flushAll();
    res.json({ success: true, message: '所有缓存已清除' });
  }
});

app.get('/api/cache/stats', (req, res) => {
  res.json({
    success: true,
    data: cache.getStats()
  });
});

// 错误处理
app.use((error, req, res, next) => {
  console.error('服务错误:', error);
  res.status(500).json({
    success: false,
    error: '服务内部错误'
  });
});

const PORT = process.env.PORT || 5010;
app.listen(PORT, () => {
  console.log(`静态API服务启动，端口: ${PORT}`);
  console.log(`缓存TTL: ${CACHE_TTL}秒`);
  console.log(`MongoDB: ${MONGODB_URI ? '已连接' : '未配置'}`);
  console.log(`R2存储: ${R2_ENDPOINT ? '已配置' : '未配置'}`);
}); 