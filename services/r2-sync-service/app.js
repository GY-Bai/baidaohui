const express = require('express');
const { MongoClient } = require('mongodb');
const { S3Client, PutObjectCommand, GetObjectCommand } = require('@aws-sdk/client-s3');
const cron = require('node-cron');
const compression = require('compression');

const app = express();

// 中间件
app.use(express.json());
app.use(compression());

// 配置
const MONGODB_URI = process.env.MONGODB_URI;
const R2_ENDPOINT = process.env.R2_ENDPOINT;
const R2_ACCESS_KEY = process.env.R2_ACCESS_KEY;
const R2_SECRET_KEY = process.env.R2_SECRET_KEY;
const R2_BUCKET = process.env.R2_BUCKET;
const SYNC_INTERVAL = process.env.SYNC_INTERVAL || '*/10 * * * *'; // 每10分钟

// R2客户端配置
const r2Client = new S3Client({
  region: 'auto',
  endpoint: R2_ENDPOINT,
  credentials: {
    accessKeyId: R2_ACCESS_KEY,
    secretAccessKey: R2_SECRET_KEY,
  },
});

// MongoDB连接
let db;
MongoClient.connect(MONGODB_URI)
  .then(client => {
    console.log('MongoDB连接成功');
    db = client.db('baidaohui');
    startSyncTasks();
  })
  .catch(error => {
    console.error('MongoDB连接失败:', error);
    process.exit(1);
  });

// 健康检查
app.get('/health', (req, res) => {
  res.json({ 
    status: 'healthy', 
    service: 'r2-sync-service',
    timestamp: new Date().toISOString(),
    last_sync: global.lastSyncTime || null
  });
});

// 同步产品数据到R2
async function syncProductsToR2() {
  try {
    console.log('开始同步产品数据到R2...');
    
    // 获取活跃产品
    const products = await db.collection('products')
      .find({ isActive: true })
      .sort({ createdAt: -1 })
      .limit(1000)
      .toArray();
    
    // 处理产品数据
    const processedProducts = products.map(product => ({
      id: product._id,
      productId: product.productId,
      name: product.name,
      description: product.description,
      imageUrls: product.imageUrls,
      price: product.price,
      currency: product.currency,
      paymentLinkUrl: product.paymentLinkUrl,
      storeId: product.storeId,
      category: product.category,
      tags: product.tags,
      updatedAt: product.updatedAt
    }));
    
    // 上传到R2
    const command = new PutObjectCommand({
      Bucket: R2_BUCKET,
      Key: 'products.json',
      Body: JSON.stringify({
        products: processedProducts,
        total: processedProducts.length,
        lastUpdated: new Date().toISOString(),
        version: '1.0'
      }),
      ContentType: 'application/json',
      CacheControl: 'public, max-age=300', // 5分钟缓存
    });
    
    await r2Client.send(command);
    console.log(`成功同步 ${processedProducts.length} 个产品到R2`);
    
    global.lastSyncTime = new Date().toISOString();
    return { success: true, count: processedProducts.length };
    
  } catch (error) {
    console.error('同步产品数据失败:', error);
    throw error;
  }
}

// 同步算命统计数据到R2
async function syncFortuneStatsToR2() {
  try {
    console.log('开始同步算命统计数据到R2...');
    
    const [totalCount, pendingCount, completedCount, todayCount] = await Promise.all([
      db.collection('fortune_applications').countDocuments(),
      db.collection('fortune_applications').countDocuments({ 
        status: { $in: ['Pending', 'Queued-payed', 'Queued-upload'] } 
      }),
      db.collection('fortune_applications').countDocuments({ status: 'Completed' }),
      db.collection('fortune_applications').countDocuments({
        createdAt: { $gte: new Date(new Date().setHours(0, 0, 0, 0)) }
      })
    ]);
    
    // 获取最近的汇率数据
    const exchangeRates = await db.collection('exchange_rates').findOne(
      {},
      { sort: { updatedAt: -1 } }
    );
    
    const stats = {
      fortune: {
        total: totalCount,
        pending: pendingCount,
        completed: completedCount,
        today: todayCount
      },
      exchangeRates: exchangeRates ? {
        rates: exchangeRates.rates,
        updatedAt: exchangeRates.updatedAt
      } : null,
      lastUpdated: new Date().toISOString()
    };
    
    const command = new PutObjectCommand({
      Bucket: R2_BUCKET,
      Key: 'stats.json',
      Body: JSON.stringify(stats),
      ContentType: 'application/json',
      CacheControl: 'public, max-age=60', // 1分钟缓存
    });
    
    await r2Client.send(command);
    console.log('成功同步统计数据到R2');
    
    return { success: true, stats };
    
  } catch (error) {
    console.error('同步统计数据失败:', error);
    throw error;
  }
}

// 同步邀请链接公开信息到R2
async function syncInviteInfoToR2() {
  try {
    console.log('开始同步邀请链接信息到R2...');
    
    const activeInvites = await db.collection('invite_links')
      .find({ 
        isActive: true,
        expiresAt: { $gt: new Date() }
      })
      .toArray();
    
    // 处理邀请链接数据（仅公开信息）
    const inviteInfo = {};
    activeInvites.forEach(invite => {
      inviteInfo[invite.token] = {
        type: invite.type,
        expiresAt: invite.expiresAt,
        maxUse: invite.maxUse,
        usedCount: invite.usedCount,
        isValid: invite.usedCount < invite.maxUse
      };
    });
    
    const command = new PutObjectCommand({
      Bucket: R2_BUCKET,
      Key: 'invites.json',
      Body: JSON.stringify({
        invites: inviteInfo,
        total: Object.keys(inviteInfo).length,
        lastUpdated: new Date().toISOString()
      }),
      ContentType: 'application/json',
      CacheControl: 'public, max-age=300', // 5分钟缓存
    });
    
    await r2Client.send(command);
    console.log(`成功同步 ${Object.keys(inviteInfo).length} 个邀请链接到R2`);
    
    return { success: true, count: Object.keys(inviteInfo).length };
    
  } catch (error) {
    console.error('同步邀请链接失败:', error);
    throw error;
  }
}

// 同步用户公开统计到R2
async function syncUserStatsToR2() {
  try {
    console.log('开始同步用户统计到R2...');
    
    // 从Supabase获取用户统计（这里需要调用auth-service）
    const userStats = {
      totalUsers: 0, // 需要从auth-service获取
      roleDistribution: {
        fan: 0,
        member: 0,
        master: 0,
        firstmate: 0,
        seller: 0
      },
      lastUpdated: new Date().toISOString()
    };
    
    const command = new PutObjectCommand({
      Bucket: R2_BUCKET,
      Key: 'user-stats.json',
      Body: JSON.stringify(userStats),
      ContentType: 'application/json',
      CacheControl: 'public, max-age=3600', // 1小时缓存
    });
    
    await r2Client.send(command);
    console.log('成功同步用户统计到R2');
    
    return { success: true, userStats };
    
  } catch (error) {
    console.error('同步用户统计失败:', error);
    throw error;
  }
}

// 启动定时同步任务
function startSyncTasks() {
  console.log(`启动定时同步任务，间隔: ${SYNC_INTERVAL}`);
  
  // 产品数据同步（每10分钟）
  cron.schedule(SYNC_INTERVAL, async () => {
    try {
      await syncProductsToR2();
    } catch (error) {
      console.error('定时同步产品数据失败:', error);
    }
  });
  
  // 统计数据同步（每分钟）
  cron.schedule('* * * * *', async () => {
    try {
      await syncFortuneStatsToR2();
    } catch (error) {
      console.error('定时同步统计数据失败:', error);
    }
  });
  
  // 邀请链接同步（每5分钟）
  cron.schedule('*/5 * * * *', async () => {
    try {
      await syncInviteInfoToR2();
    } catch (error) {
      console.error('定时同步邀请链接失败:', error);
    }
  });
  
  // 用户统计同步（每小时）
  cron.schedule('0 * * * *', async () => {
    try {
      await syncUserStatsToR2();
    } catch (error) {
      console.error('定时同步用户统计失败:', error);
    }
  });
  
  // 立即执行一次同步
  setTimeout(async () => {
    try {
      await Promise.all([
        syncProductsToR2(),
        syncFortuneStatsToR2(),
        syncInviteInfoToR2(),
        syncUserStatsToR2()
      ]);
      console.log('初始同步完成');
    } catch (error) {
      console.error('初始同步失败:', error);
    }
  }, 5000);
}

// 手动同步接口
app.post('/sync/products', async (req, res) => {
  try {
    const result = await syncProductsToR2();
    res.json(result);
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.post('/sync/stats', async (req, res) => {
  try {
    const result = await syncFortuneStatsToR2();
    res.json(result);
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.post('/sync/invites', async (req, res) => {
  try {
    const result = await syncInviteInfoToR2();
    res.json(result);
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.post('/sync/all', async (req, res) => {
  try {
    const results = await Promise.all([
      syncProductsToR2(),
      syncFortuneStatsToR2(),
      syncInviteInfoToR2(),
      syncUserStatsToR2()
    ]);
    
    res.json({
      success: true,
      results: {
        products: results[0],
        stats: results[1],
        invites: results[2],
        userStats: results[3]
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// 获取同步状态
app.get('/sync/status', (req, res) => {
  res.json({
    service: 'r2-sync-service',
    lastSyncTime: global.lastSyncTime || null,
    syncInterval: SYNC_INTERVAL,
    r2Bucket: R2_BUCKET,
    status: 'running'
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

const PORT = process.env.PORT || 5011;
app.listen(PORT, () => {
  console.log(`R2同步服务启动，端口: ${PORT}`);
  console.log(`同步间隔: ${SYNC_INTERVAL}`);
  console.log(`R2存储桶: ${R2_BUCKET}`);
  console.log(`MongoDB: ${MONGODB_URI ? '已连接' : '未配置'}`);
}); 