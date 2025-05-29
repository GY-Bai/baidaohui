import Stripe from 'stripe';
import { MongoClient, Db } from 'mongodb';
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
import cron from 'node-cron';
import express, { Request, Response } from 'express';

const app = express();

// 类型定义
interface SellerKey {
  _id: any;
  userId: string;
  storeId?: string;
  keyValue: string;
  keyType: string;
  userRole: string;
  isActive: boolean;
  isListed: boolean;
  lastUsed?: Date;
}

interface ProductData {
  productId: string;
  stripeProductId: string;
  stripePriceId: string;
  name: string;
  description: string;
  imageUrls: string[];
  price: number;
  currency: string;
  paymentLinkUrl: string;
  storeId: string;
  category: string;
  tags: string[];
  isActive: boolean;
  isListed: boolean;
  sellerUserId: string;
  createdAt: Date;
  updatedAt: Date;
}

interface SyncResult {
  success: boolean;
  count: number;
  sellers: number;
  failed?: number;
}

// 全局变量声明
declare global {
  var lastSyncTime: string | undefined;
}

// 中间件
app.use(express.json());

// 配置
const MONGODB_URI = process.env.MONGODB_URI!;
const R2_ENDPOINT = process.env.R2_ENDPOINT!;
const R2_ACCESS_KEY = process.env.R2_ACCESS_KEY!;
const R2_SECRET_KEY = process.env.R2_SECRET_KEY!;
const R2_BUCKET = process.env.R2_BUCKET!;
const EMAIL_SERVICE_URL = process.env.EMAIL_SERVICE_URL; // Mailjet邮件服务

// R2客户端
const r2Client = new S3Client({
  region: 'auto',
  endpoint: R2_ENDPOINT,
  credentials: {
    accessKeyId: R2_ACCESS_KEY,
    secretAccessKey: R2_SECRET_KEY,
  },
});

// MongoDB连接
let db: Db;

MongoClient.connect(MONGODB_URI)
  .then((client) => {
    console.log('MongoDB连接成功');
    db = client.db('baidaohui');
    startPollingTasks();
  })
  .catch((error: Error) => {
    console.error('MongoDB连接失败:', error);
    process.exit(1);
  });

// 健康检查
app.get('/health', (req: Request, res: Response) => {
  res.json({ 
    status: 'healthy', 
    service: 'ecommerce-poller',
    timestamp: new Date().toISOString(),
    last_sync: global.lastSyncTime || null
  });
});

// 获取所有有效的seller Stripe密钥
async function getActiveSellerKeys(): Promise<SellerKey[]> {
  try {
    const sellerKeys = await db.collection('keys').find({
      userRole: 'seller',
      keyType: 'stripe_secret',
      isActive: true,
      isListed: true // 只获取上架的seller
    }).toArray() as SellerKey[];
    
    console.log(`找到 ${sellerKeys.length} 个有效的seller Stripe密钥`);
    return sellerKeys;
  } catch (error) {
    console.error('获取seller密钥失败:', error);
    return [];
  }
}

// 同步单个seller的商品
async function syncSellerProducts(sellerKey: SellerKey): Promise<ProductData[]> {
  try {
    const stripe = new Stripe(sellerKey.keyValue);
    const storeId = sellerKey.storeId || sellerKey.userId;
    
    console.log(`开始同步 seller ${storeId} 的商品...`);
    
    // 获取商品列表
    const products = await stripe.products.list({
      active: true,
      expand: ['data.default_price'],
      limit: 100
    });
    
    // 获取Payment Links
    const paymentLinks = await stripe.paymentLinks.list({
      active: true,
      limit: 100
    });
    
    // 创建Payment Link映射
    const paymentLinkMap = new Map<string, string>();
    paymentLinks.data.forEach((link: any) => {
      if (link.line_items?.data?.[0]?.price?.product) {
        paymentLinkMap.set(link.line_items.data[0].price.product as string, link.url);
      }
    });
    
    const processedProducts: ProductData[] = [];
    
    for (const product of products.data) {
      try {
        const defaultPrice = product.default_price as Stripe.Price;
        const paymentLinkUrl = paymentLinkMap.get(product.id);
        
        if (!defaultPrice || !paymentLinkUrl) {
          console.warn(`商品 ${product.id} 缺少价格或Payment Link，跳过`);
          continue;
        }
        
        const productData: ProductData = {
          productId: product.id,
          stripeProductId: product.id,
          stripePriceId: defaultPrice.id,
          name: product.name,
          description: product.description || '',
          imageUrls: product.images || [],
          price: defaultPrice.unit_amount ? defaultPrice.unit_amount / 100 : 0,
          currency: defaultPrice.currency?.toUpperCase() || 'USD',
          paymentLinkUrl,
          storeId,
          category: product.metadata?.category || 'general',
          tags: product.metadata?.tags ? product.metadata.tags.split(',') : [],
          isActive: true,
          isListed: true, // 新增字段，表示是否在前端展示
          sellerUserId: sellerKey.userId,
          createdAt: new Date(),
          updatedAt: new Date()
        };
        
        // Upsert到MongoDB
        await db.collection('products').updateOne(
          { stripeProductId: product.id, storeId },
          { $set: productData },
          { upsert: true }
        );
        
        processedProducts.push(productData);
        
      } catch (productError) {
        console.error(`处理商品 ${product.id} 失败:`, productError);
      }
    }
    
    // 更新密钥最后使用时间
    await db.collection('keys').updateOne(
      { _id: sellerKey._id },
      { $set: { lastUsed: new Date() } }
    );
    
    console.log(`seller ${storeId} 同步完成，处理了 ${processedProducts.length} 个商品`);
    return processedProducts;
    
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : String(error);
    console.error(`同步 seller ${sellerKey.storeId || sellerKey.userId} 失败:`, errorMessage);
    
    // 发送错误通知邮件给对应的seller
    if (EMAIL_SERVICE_URL) {
      try {
        // 获取seller的邮箱信息
        const seller = await db.collection('users').findOne({ _id: sellerKey.userId });
        if (seller?.email) {
          await fetch(`${EMAIL_SERVICE_URL}/send-notification`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              email: seller.email,
              type: 'seller_sync_error',
              data: {
                storeId: sellerKey.storeId || sellerKey.userId,
                error: errorMessage,
                timestamp: new Date().toISOString()
              }
            })
          });
        }
      } catch (emailError) {
        console.error('发送错误通知邮件失败:', emailError);
      }
    }
    
    return [];
  }
}

// 处理下架的seller商品
async function handleUnlistedSellers(): Promise<void> {
  try {
    // 获取被下架的seller
    const unlistedSellers = await db.collection('keys').find({
      userRole: 'seller',
      keyType: 'stripe_secret',
      isActive: true,
      isListed: false
    }).toArray() as SellerKey[];
    
    for (const seller of unlistedSellers) {
      const storeId = seller.storeId || seller.userId;
      
      // 将该seller的所有商品设为不展示
      await db.collection('products').updateMany(
        { storeId, sellerUserId: seller.userId },
        { 
          $set: { 
            isListed: false,
            updatedAt: new Date()
          }
        }
      );
      
      console.log(`seller ${storeId} 的商品已设为不展示`);
    }
    
  } catch (error) {
    console.error('处理下架seller失败:', error);
  }
}

// 主同步函数
async function syncAllProducts(): Promise<SyncResult> {
  try {
    console.log('开始同步所有seller商品...');
    global.lastSyncTime = new Date().toISOString();
    
    // 处理下架的seller
    await handleUnlistedSellers();
    
    // 获取有效的seller密钥
    const sellerKeys = await getActiveSellerKeys();
    
    if (sellerKeys.length === 0) {
      console.log('没有找到有效的seller密钥');
      return { success: true, count: 0, sellers: 0 };
    }
    
    const allProducts: ProductData[] = [];
    let successCount = 0;
    
    // 并发同步所有seller（限制并发数）
    const concurrency = 3;
    for (let i = 0; i < sellerKeys.length; i += concurrency) {
      const batch = sellerKeys.slice(i, i + concurrency);
      const batchResults = await Promise.allSettled(
        batch.map(key => syncSellerProducts(key))
      );
      
      batchResults.forEach((result, index) => {
        if (result.status === 'fulfilled') {
          allProducts.push(...result.value);
          successCount++;
        } else {
          console.error(`Batch ${i + index} 同步失败:`, result.reason);
        }
      });
    }
    
    // 生成products.json并上传到R2
    const productsData = {
      products: allProducts,
      total: allProducts.length,
      sellers: successCount,
      lastUpdated: new Date().toISOString(),
      version: '1.0'
    };
    
    const command = new PutObjectCommand({
      Bucket: R2_BUCKET,
      Key: 'products.json',
      Body: JSON.stringify(productsData),
      ContentType: 'application/json',
      CacheControl: 'public, max-age=300',
    });
    
    await r2Client.send(command);
    
    console.log(`同步完成: ${allProducts.length} 个商品，${successCount} 个seller`);
    
    return {
      success: true,
      count: allProducts.length,
      sellers: successCount,
      failed: sellerKeys.length - successCount
    };
    
  } catch (error) {
    console.error('同步商品失败:', error);
    throw error;
  }
}

// 启动定时任务
function startPollingTasks(): void {
  console.log('启动电商轮询定时任务...');
  
  // 每小时同步一次
  cron.schedule('0 * * * *', async () => {
    try {
      await syncAllProducts();
    } catch (error) {
      console.error('定时同步失败:', error);
    }
  });
  
  // 立即执行一次
  setTimeout(async () => {
    try {
      await syncAllProducts();
      console.log('初始同步完成');
    } catch (error) {
      console.error('初始同步失败:', error);
    }
  }, 5000);
}

// 手动同步接口
app.post('/sync/products', async (req: Request, res: Response) => {
  try {
    const result = await syncAllProducts();
    res.json(result);
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : String(error);
    res.status(500).json({ 
      success: false, 
      error: errorMessage 
    });
  }
});

// 同步特定seller
app.post('/sync/seller/:storeId', async (req: Request, res: Response) => {
  try {
    const { storeId } = req.params;
    
    const sellerKey = await db.collection('keys').findOne({
      $or: [
        { storeId },
        { userId: storeId }
      ],
      userRole: 'seller',
      keyType: 'stripe_secret',
      isActive: true
    }) as SellerKey | null;
    
    if (!sellerKey) {
      return res.status(404).json({
        success: false,
        error: 'Seller密钥不存在或未激活'
      });
    }
    
    const products = await syncSellerProducts(sellerKey);
    
    res.json({
      success: true,
      count: products.length,
      storeId
    });
    
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : String(error);
    res.status(500).json({
      success: false,
      error: errorMessage
    });
  }
});

// 获取同步状态
app.get('/sync/status', (req: Request, res: Response) => {
  res.json({
    service: 'ecommerce-poller',
    lastSyncTime: global.lastSyncTime || null,
    status: 'running'
  });
});

// 错误处理
app.use((error: any, req: any, res: any, next: any) => {
  console.error('服务错误:', error);
  res.status(500).json({
    success: false,
    error: '服务内部错误'
  });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`电商轮询服务启动，端口: ${PORT}`);
  console.log(`R2存储桶: ${R2_BUCKET}`);
  console.log(`MongoDB: ${MONGODB_URI ? '已连接' : '未配置'}`);
});

// 优雅关闭
process.on('SIGTERM', async () => {
  console.log('收到SIGTERM信号，正在关闭服务...');
  if (db) {
    await db.client.close();
  }
  process.exit(0);
});

process.on('SIGINT', async () => {
  console.log('收到SIGINT信号，正在关闭服务...');
  if (db) {
    await db.client.close();
  }
  process.exit(0);
});

// 未捕获异常处理
process.on('uncaughtException', (error) => {
  console.error('未捕获异常', { error: error.message, stack: error.stack });
  process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('未处理的Promise拒绝', { reason, promise });
  process.exit(1);
}); 