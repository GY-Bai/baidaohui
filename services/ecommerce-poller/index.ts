import Stripe from 'stripe';
import { MongoClient } from 'mongodb';
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
import cron from 'node-cron';
import axios from 'axios';
import { config } from './config';

// 初始化客户端
const mongoClient = new MongoClient(config.MONGODB_URI);
const s3Client = new S3Client({
  region: 'auto',
  endpoint: config.R2_ENDPOINT,
  credentials: {
    accessKeyId: config.R2_ACCESS_KEY,
    secretAccessKey: config.R2_SECRET_KEY,
  },
});

interface StripeAccount {
  storeId: string;
  secretKey: string;
  publishableKey: string;
}

interface Product {
  id: string;
  name: string;
  description: string;
  images: string[];
  default_price: {
    id: string;
    unit_amount: number;
    currency: string;
  };
  payment_link?: {
    id: string;
    url: string;
    active: boolean;
  };
  storeId: string;
  created: number;
  updated: number;
}

interface SyncResult {
  success: boolean;
  storeId: string;
  productCount: number;
  error?: string;
  products?: Product[];
}

interface SyncStats {
  totalStores: number;
  successfulStores: number;
  failedStores: number;
  totalProducts: number;
  startTime: Date;
  endTime?: Date;
  errors: string[];
}

// 重试配置
const RETRY_CONFIG = {
  maxRetries: 3,
  baseDelay: 1000, // 1秒
  maxDelay: 10000, // 10秒
};

// 日志级别
enum LogLevel {
  INFO = 'INFO',
  WARN = 'WARN',
  ERROR = 'ERROR',
  CRITICAL = 'CRITICAL'
}

// 日志记录函数
function log(level: LogLevel, message: string, data?: any) {
  const timestamp = new Date().toISOString();
  const logEntry = {
    timestamp,
    level,
    service: 'ecommerce-poller',
    message,
    data
  };
  
  console.log(JSON.stringify(logEntry));
  
  // 对于错误和关键日志，发送告警
  if (level === LogLevel.ERROR || level === LogLevel.CRITICAL) {
    sendAlert(level, message, data).catch(err => 
      console.error('发送告警失败:', err)
    );
  }
}

// 发送告警通知
async function sendAlert(level: LogLevel, message: string, data?: any) {
  try {
    const alertData = {
      service: 'ecommerce-poller',
      level,
      message,
      data,
      timestamp: new Date().toISOString(),
      environment: process.env.NODE_ENV || 'development'
    };

    // 发送到监控系统或通知服务
    if (process.env.ALERT_WEBHOOK_URL) {
      await axios.post(process.env.ALERT_WEBHOOK_URL, alertData, {
        timeout: 5000
      });
    }

    // 发送邮件通知（如果配置了）
    if (process.env.EMAIL_SERVICE_URL && level === LogLevel.CRITICAL) {
      await axios.post(`${process.env.EMAIL_SERVICE_URL}/alert`, {
        to: process.env.ADMIN_EMAIL,
        subject: `[CRITICAL] 电商轮询服务告警`,
        message: `${message}\n\n详细信息: ${JSON.stringify(data, null, 2)}`
      }, {
        timeout: 5000
      });
    }
  } catch (error) {
    console.error('发送告警失败:', error);
  }
}

// 重试函数
async function retryWithBackoff<T>(
  operation: () => Promise<T>,
  context: string,
  maxRetries: number = RETRY_CONFIG.maxRetries
): Promise<T> {
  let lastError: Error;
  
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      return await operation();
    } catch (error) {
      lastError = error as Error;
      
      if (attempt === maxRetries) {
        log(LogLevel.ERROR, `${context} 重试失败，已达最大重试次数`, {
          attempts: attempt,
          error: lastError.message
        });
        throw lastError;
      }
      
      const delay = Math.min(
        RETRY_CONFIG.baseDelay * Math.pow(2, attempt - 1),
        RETRY_CONFIG.maxDelay
      );
      
      log(LogLevel.WARN, `${context} 失败，${delay}ms后重试 (${attempt}/${maxRetries})`, {
        error: lastError.message
      });
      
      await new Promise(resolve => setTimeout(resolve, delay));
    }
  }
  
  throw lastError!;
}

async function getStripeAccounts(): Promise<StripeAccount[]> {
  return retryWithBackoff(async () => {
    const db = mongoClient.db('baidaohui');
    const accounts = await db.collection('stripe_accounts').find({
      status: 'active'
    }).toArray();
    
    return accounts.map(account => ({
      storeId: account.store_id,
      secretKey: account.secret_key,
      publishableKey: account.publishable_key
    }));
  }, '获取Stripe账户');
}

async function syncProductsFromStripe(account: StripeAccount): Promise<SyncResult> {
  try {
    const result = await retryWithBackoff(async () => {
      const stripe = new Stripe(account.secretKey, {
        apiVersion: '2023-10-16',
        timeout: 30000, // 30秒超时
      });

      log(LogLevel.INFO, `开始同步 ${account.storeId} 的产品和Payment Link`);

      // 获取所有产品，包含价格信息
      const products = await stripe.products.list({
        active: true,
        expand: ['data.default_price'],
        limit: 100,
      });

      // 获取所有Payment Link
      const paymentLinks = await stripe.paymentLinks.list({
        active: true,
        limit: 100,
      });

      // 创建Payment Link映射表（按产品ID）
      const paymentLinkMap = new Map<string, any>();
      for (const link of paymentLinks.data) {
        if (link.line_items && link.line_items.data.length > 0) {
          const lineItem = link.line_items.data[0];
          if (lineItem.price && lineItem.price.product) {
            const productId = typeof lineItem.price.product === 'string' 
              ? lineItem.price.product 
              : lineItem.price.product.id;
            paymentLinkMap.set(productId, {
              id: link.id,
              url: link.url,
              active: link.active
            });
          }
        }
      }

      const syncedProducts: Product[] = [];

      for (const product of products.data) {
        if (!product.default_price) {
          log(LogLevel.WARN, `产品 ${product.id} 没有默认价格，跳过`, {
            storeId: account.storeId,
            productId: product.id
          });
          continue;
        }

        // 获取对应的Payment Link
        const paymentLink = paymentLinkMap.get(product.id);

        const syncedProduct: Product = {
          id: product.id,
          name: product.name,
          description: product.description || '',
          images: product.images || [],
          default_price: {
            id: (product.default_price as any).id,
            unit_amount: (product.default_price as any).unit_amount,
            currency: (product.default_price as any).currency,
          },
          payment_link: paymentLink,
          storeId: account.storeId,
          created: product.created,
          updated: product.updated || product.created,
        };

        syncedProducts.push(syncedProduct);
      }

      log(LogLevel.INFO, `${account.storeId} 同步完成`, {
        productCount: syncedProducts.length,
        paymentLinkCount: paymentLinks.data.length
      });

      return {
        success: true,
        storeId: account.storeId,
        productCount: syncedProducts.length,
        products: syncedProducts
      };
    }, `同步 ${account.storeId} 产品`);

    // 将产品数据存储到MongoDB
    if (result.products && result.products.length > 0) {
      await upsertProductsToMongoDB(result.products);
    }

    return {
      success: result.success,
      storeId: result.storeId,
      productCount: result.productCount
    };

  } catch (error) {
    log(LogLevel.ERROR, `同步 ${account.storeId} 失败`, {
      error: (error as Error).message,
      stack: (error as Error).stack
    });

    return {
      success: false,
      storeId: account.storeId,
      productCount: 0,
      error: (error as Error).message
    };
  }
}

async function upsertProductsToMongoDB(products: Product[]): Promise<void> {
  await retryWithBackoff(async () => {
    const db = mongoClient.db('baidaohui');
    const collection = db.collection('products');

    // 使用批量操作提高性能
    const bulkOps = products.map(product => ({
      updateOne: {
        filter: { id: product.id, storeId: product.storeId },
        update: {
          $set: {
            ...product,
            syncedAt: new Date(),
          }
        },
        upsert: true
      }
    }));

    if (bulkOps.length > 0) {
      await collection.bulkWrite(bulkOps);
    }

    log(LogLevel.INFO, `MongoDB更新完成`, {
      productCount: products.length
    });
  }, 'MongoDB产品更新');
}

async function generateProductsJSON(): Promise<void> {
  await retryWithBackoff(async () => {
    const db = mongoClient.db('baidaohui');
    const products = await db.collection('products').find({}).toArray();

    // 转换为前端需要的格式
    const productsForFrontend = products.map(product => ({
      id: product.id,
      name: product.name,
      description: product.description,
      images: product.images,
      price: {
        amount: product.default_price.unit_amount,
        currency: product.default_price.currency,
        formatted: formatPrice(product.default_price.unit_amount, product.default_price.currency)
      },
      storeId: product.storeId,
      createdAt: new Date(product.created * 1000).toISOString(),
      updatedAt: new Date(product.updated * 1000).toISOString(),
    }));

    const jsonData = JSON.stringify({
      products: productsForFrontend,
      lastUpdated: new Date().toISOString(),
      totalCount: productsForFrontend.length,
      syncStats: {
        timestamp: new Date().toISOString(),
        storeCount: new Set(products.map(p => p.storeId)).size
      }
    }, null, 2);

    // 上传到R2
    const uploadCommand = new PutObjectCommand({
      Bucket: config.R2_BUCKET,
      Key: 'products.json',
      Body: jsonData,
      ContentType: 'application/json',
      CacheControl: 'max-age=3600', // 1小时缓存
      Metadata: {
        'last-sync': new Date().toISOString(),
        'product-count': productsForFrontend.length.toString()
      }
    });

    await s3Client.send(uploadCommand);
    
    log(LogLevel.INFO, 'products.json 上传到R2成功', {
      productCount: productsForFrontend.length,
      fileSize: Buffer.byteLength(jsonData, 'utf8')
    });
  }, 'R2文件上传');
}

function formatPrice(amount: number, currency: string): string {
  try {
    const formatter = new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: currency.toUpperCase(),
    });
    return formatter.format(amount / 100); // Stripe金额以分为单位
  } catch (error) {
    log(LogLevel.WARN, '价格格式化失败', { amount, currency, error });
    return `${currency.toUpperCase()} ${(amount / 100).toFixed(2)}`;
  }
}

async function syncAllProducts(): Promise<SyncStats> {
  const stats: SyncStats = {
    totalStores: 0,
    successfulStores: 0,
    failedStores: 0,
    totalProducts: 0,
    startTime: new Date(),
    errors: []
  };

  try {
    log(LogLevel.INFO, '开始产品同步任务');
    
    // 确保MongoDB连接
    if (!mongoClient.topology?.isConnected()) {
      await mongoClient.connect();
      log(LogLevel.INFO, 'MongoDB连接已建立');
    }
    
    // 获取所有Stripe账户
    const accounts = await getStripeAccounts();
    stats.totalStores = accounts.length;
    
    log(LogLevel.INFO, `找到 ${accounts.length} 个Stripe账户`);

    if (accounts.length === 0) {
      log(LogLevel.WARN, '没有找到活跃的Stripe账户，跳过同步');
      return stats;
    }

    // 同步所有账户的产品
    const allProducts: Product[] = [];
    const syncResults: SyncResult[] = [];
    
    for (const account of accounts) {
      const result = await syncProductsFromStripe(account);
      syncResults.push(result);
      
      if (result.success) {
        stats.successfulStores++;
        stats.totalProducts += result.productCount;
        
        // 获取实际产品数据用于后续处理
        const products = await retryWithBackoff(async () => {
          const stripe = new Stripe(account.secretKey, {
            apiVersion: '2023-10-16',
          });
          const stripeProducts = await stripe.products.list({
            active: true,
            expand: ['data.default_price'],
            limit: 100,
          });
          
          return stripeProducts.data
            .filter(p => p.default_price)
            .map(product => ({
              id: product.id,
              name: product.name,
              description: product.description || '',
              images: product.images || [],
              default_price: {
                id: (product.default_price as Stripe.Price).id,
                unit_amount: (product.default_price as Stripe.Price).unit_amount || 0,
                currency: (product.default_price as Stripe.Price).currency,
              },
              storeId: account.storeId,
              created: product.created,
              updated: product.updated || product.created,
            }));
        }, `获取 ${account.storeId} 产品详情`);
        
        allProducts.push(...products);
      } else {
        stats.failedStores++;
        if (result.error) {
          stats.errors.push(`${account.storeId}: ${result.error}`);
        }
      }
      
      // 避免API限制，每个账户之间暂停1秒
      await new Promise(resolve => setTimeout(resolve, 1000));
    }

    log(LogLevel.INFO, `同步结果统计`, {
      totalStores: stats.totalStores,
      successfulStores: stats.successfulStores,
      failedStores: stats.failedStores,
      totalProducts: stats.totalProducts
    });

    // 更新MongoDB和生成JSON文件
    if (allProducts.length > 0) {
      await upsertProductsToMongoDB(allProducts);
      await generateProductsJSON();
    }

    stats.endTime = new Date();
    
    // 记录同步统计到数据库
    await recordSyncStats(stats);

    log(LogLevel.INFO, '产品同步任务完成', {
      duration: stats.endTime.getTime() - stats.startTime.getTime(),
      ...stats
    });

    // 如果有失败的同步，发送告警
    if (stats.failedStores > 0) {
      log(LogLevel.ERROR, `有 ${stats.failedStores} 个商店同步失败`, {
        errors: stats.errors
      });
    }

    return stats;

  } catch (error) {
    stats.endTime = new Date();
    const errorMessage = error instanceof Error ? error.message : String(error);
    stats.errors.push(errorMessage);
    
    log(LogLevel.CRITICAL, '产品同步任务失败', {
      error: errorMessage,
      duration: stats.endTime.getTime() - stats.startTime.getTime()
    });
    
    throw error;
  }
}

// 记录同步统计信息
async function recordSyncStats(stats: SyncStats): Promise<void> {
  try {
    const db = mongoClient.db('baidaohui');
    await db.collection('sync_stats').insertOne({
      ...stats,
      service: 'ecommerce-poller',
      createdAt: new Date()
    });
  } catch (error) {
    log(LogLevel.WARN, '记录同步统计失败', { error });
  }
}

// 立即执行一次同步
syncAllProducts().catch(error => {
  log(LogLevel.CRITICAL, '初始同步失败', { error: error.message });
});

// 设置定时任务：每小时执行一次
cron.schedule('0 * * * *', () => {
  log(LogLevel.INFO, '定时任务触发：开始产品同步');
  syncAllProducts().catch(error => {
    log(LogLevel.CRITICAL, '定时同步失败', { error: error.message });
  });
}, {
  timezone: 'UTC'
});

// 健康检查端点
import express from 'express';
const app = express();

app.use(express.json());

app.get('/health', async (req, res) => {
  try {
    // 检查MongoDB连接
    const mongoHealthy = mongoClient.topology?.isConnected() || false;
    
    // 检查最近的同步状态
    let lastSyncStatus = 'unknown';
    try {
      const db = mongoClient.db('baidaohui');
      const lastSync = await db.collection('sync_stats')
        .findOne({}, { sort: { createdAt: -1 } });
      
      if (lastSync) {
        const timeSinceLastSync = Date.now() - lastSync.createdAt.getTime();
        lastSyncStatus = timeSinceLastSync < 2 * 60 * 60 * 1000 ? 'healthy' : 'stale'; // 2小时内为健康
      }
    } catch (error) {
      lastSyncStatus = 'error';
    }

    const health = {
      status: mongoHealthy && lastSyncStatus !== 'error' ? 'healthy' : 'unhealthy',
      service: 'ecommerce-poller',
      timestamp: new Date().toISOString(),
      checks: {
        mongodb: mongoHealthy ? 'connected' : 'disconnected',
        lastSync: lastSyncStatus
      }
    };

    res.status(health.status === 'healthy' ? 200 : 503).json(health);
  } catch (error) {
    res.status(503).json({
      status: 'unhealthy',
      service: 'ecommerce-poller',
      timestamp: new Date().toISOString(),
      error: error instanceof Error ? error.message : String(error)
    });
  }
});

// 手动触发同步接口（仅内部调用）
app.post('/sync', async (req, res) => {
  try {
    const internalKey = req.headers['x-internal-key'];
    if (internalKey !== process.env.INTERNAL_API_KEY) {
      return res.status(403).json({ error: '无权限访问' });
    }

    log(LogLevel.INFO, '手动触发同步任务');
    const stats = await syncAllProducts();
    
    res.json({
      success: true,
      message: '同步任务完成',
      stats
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: '同步任务失败',
      error: error instanceof Error ? error.message : String(error)
    });
  }
});

const PORT = process.env.PORT || 5004;
app.listen(PORT, () => {
  log(LogLevel.INFO, `电商轮询服务启动，端口: ${PORT}`);
});

// 优雅关闭
process.on('SIGTERM', async () => {
  log(LogLevel.INFO, '收到SIGTERM信号，正在关闭服务...');
  await mongoClient.close();
  process.exit(0);
});

process.on('SIGINT', async () => {
  log(LogLevel.INFO, '收到SIGINT信号，正在关闭服务...');
  await mongoClient.close();
  process.exit(0);
});

// 未捕获异常处理
process.on('uncaughtException', (error) => {
  log(LogLevel.CRITICAL, '未捕获异常', { error: error.message, stack: error.stack });
  process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
  log(LogLevel.CRITICAL, '未处理的Promise拒绝', { reason, promise });
  process.exit(1);
}); 