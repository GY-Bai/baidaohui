import Stripe from 'stripe';
import { MongoClient } from 'mongodb';
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
import cron from 'node-cron';
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
  storeId: string;
  created: number;
  updated: number;
}

async function getStripeAccounts(): Promise<StripeAccount[]> {
  try {
    const db = mongoClient.db('baidaohui');
    const accounts = await db.collection('stripe_accounts').find({
      status: 'active'
    }).toArray();
    
    return accounts.map(account => ({
      storeId: account.store_id,
      secretKey: account.secret_key,
      publishableKey: account.publishable_key
    }));
  } catch (error) {
    console.error('获取Stripe账户失败:', error);
    return [];
  }
}

async function syncProductsFromStripe(account: StripeAccount): Promise<Product[]> {
  try {
    const stripe = new Stripe(account.secretKey, {
      apiVersion: '2023-10-16',
    });

    console.log(`开始同步 ${account.storeId} 的产品...`);

    // 获取所有产品，包含价格信息
    const products = await stripe.products.list({
      active: true,
      expand: ['data.default_price'],
      limit: 100,
    });

    const syncedProducts: Product[] = [];

    for (const product of products.data) {
      if (!product.default_price) {
        console.warn(`产品 ${product.id} 没有默认价格，跳过`);
        continue;
      }

      const productData: Product = {
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
      };

      syncedProducts.push(productData);
    }

    console.log(`${account.storeId} 同步完成，共 ${syncedProducts.length} 个产品`);
    return syncedProducts;

  } catch (error) {
    console.error(`同步 ${account.storeId} 产品失败:`, error);
    return [];
  }
}

async function upsertProductsToMongoDB(products: Product[]): Promise<void> {
  try {
    const db = mongoClient.db('baidaohui');
    const collection = db.collection('products');

    for (const product of products) {
      await collection.updateOne(
        { id: product.id, storeId: product.storeId },
        {
          $set: {
            ...product,
            syncedAt: new Date(),
          }
        },
        { upsert: true }
      );
    }

    console.log(`MongoDB更新完成，共处理 ${products.length} 个产品`);
  } catch (error) {
    console.error('更新MongoDB失败:', error);
    throw error;
  }
}

async function generateProductsJSON(): Promise<void> {
  try {
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
      totalCount: productsForFrontend.length
    }, null, 2);

    // 上传到R2
    const uploadCommand = new PutObjectCommand({
      Bucket: config.R2_BUCKET,
      Key: 'products.json',
      Body: jsonData,
      ContentType: 'application/json',
      CacheControl: 'max-age=3600', // 1小时缓存
    });

    await s3Client.send(uploadCommand);
    console.log('products.json 上传到R2成功');

  } catch (error) {
    console.error('生成products.json失败:', error);
    throw error;
  }
}

function formatPrice(amount: number, currency: string): string {
  const formatter = new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: currency.toUpperCase(),
  });
  return formatter.format(amount / 100); // Stripe金额以分为单位
}

async function syncAllProducts(): Promise<void> {
  try {
    console.log('开始产品同步任务...');
    
    // 连接MongoDB
    await mongoClient.connect();
    
    // 获取所有Stripe账户
    const accounts = await getStripeAccounts();
    console.log(`找到 ${accounts.length} 个Stripe账户`);

    if (accounts.length === 0) {
      console.log('没有找到活跃的Stripe账户，跳过同步');
      return;
    }

    // 同步所有账户的产品
    const allProducts: Product[] = [];
    
    for (const account of accounts) {
      const products = await syncProductsFromStripe(account);
      allProducts.push(...products);
      
      // 避免API限制，每个账户之间暂停1秒
      await new Promise(resolve => setTimeout(resolve, 1000));
    }

    console.log(`总共同步了 ${allProducts.length} 个产品`);

    // 更新MongoDB
    if (allProducts.length > 0) {
      await upsertProductsToMongoDB(allProducts);
      
      // 生成并上传products.json
      await generateProductsJSON();
    }

    console.log('产品同步任务完成');

  } catch (error) {
    console.error('产品同步任务失败:', error);
  } finally {
    // 不关闭连接，保持长连接用于定时任务
  }
}

// 立即执行一次同步
syncAllProducts();

// 设置定时任务：每小时执行一次
cron.schedule('0 * * * *', () => {
  console.log('定时任务触发：开始产品同步');
  syncAllProducts();
}, {
  timezone: 'UTC'
});

// 健康检查端点
import express from 'express';
const app = express();

app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    service: 'ecommerce-poller',
    lastSync: new Date().toISOString()
  });
});

const PORT = process.env.PORT || 5004;
app.listen(PORT, () => {
  console.log(`电商轮询服务启动，端口: ${PORT}`);
});

// 优雅关闭
process.on('SIGTERM', async () => {
  console.log('收到SIGTERM信号，正在关闭服务...');
  await mongoClient.close();
  process.exit(0);
});

process.on('SIGINT', async () => {
  console.log('收到SIGINT信号，正在关闭服务...');
  await mongoClient.close();
  process.exit(0);
}); 