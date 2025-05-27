const express = require('express');
const axios = require('axios');
const router = express.Router();

const R2_ENDPOINT = process.env.R2_ENDPOINT;
const R2_BUCKET = process.env.R2_BUCKET;

// 获取产品列表
router.get('/products', async (req, res) => {
  try {
    const { db } = require('../app');
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const storeId = req.query.storeId;
    const category = req.query.category;
    const search = req.query.search;

    // 优先从R2获取静态JSON
    try {
      const r2Url = `${R2_ENDPOINT}/${R2_BUCKET}/products.json`;
      const response = await axios.get(r2Url, { timeout: 5000 });
      
      if (response.data && response.data.products) {
        let products = response.data.products;
        
        // 应用过滤条件
        if (storeId) {
          products = products.filter(p => p.storeId === storeId);
        }
        
        if (search) {
          const searchLower = search.toLowerCase();
          products = products.filter(p => 
            p.name.toLowerCase().includes(searchLower) ||
            p.description.toLowerCase().includes(searchLower)
          );
        }
        
        // 分页
        const total = products.length;
        const startIndex = (page - 1) * limit;
        const endIndex = startIndex + limit;
        const paginatedProducts = products.slice(startIndex, endIndex);
        
        return res.json({
          products: paginatedProducts,
          pagination: {
            page,
            limit,
            total,
            totalPages: Math.ceil(total / limit)
          },
          source: 'r2_cache',
          lastUpdated: response.data.lastUpdated
        });
      }
    } catch (r2Error) {
      console.warn('从R2获取产品失败，回退到MongoDB:', r2Error.message);
    }

    // 回退到MongoDB查询
    const database = db();
    if (!database) {
      return res.status(500).json({ error: '数据库连接未就绪' });
    }

    // 构建查询条件
    const query = {};
    if (storeId) {
      query.storeId = storeId;
    }
    
    if (search) {
      query.$or = [
        { name: { $regex: search, $options: 'i' } },
        { description: { $regex: search, $options: 'i' } }
      ];
    }

    // 分页查询
    const skip = (page - 1) * limit;
    const products = await database.collection('products')
      .find(query)
      .sort({ created: -1 })
      .skip(skip)
      .limit(limit)
      .toArray();

    const total = await database.collection('products').countDocuments(query);

    // 转换为前端格式
    const formattedProducts = products.map(product => ({
      id: product.id,
      name: product.name,
      description: product.description,
      images: product.images || [],
      price: {
        amount: product.default_price?.unit_amount || 0,
        currency: product.default_price?.currency || 'usd',
        formatted: formatPrice(product.default_price?.unit_amount || 0, product.default_price?.currency || 'usd')
      },
      storeId: product.storeId,
      createdAt: new Date(product.created * 1000).toISOString(),
      updatedAt: new Date(product.updated * 1000).toISOString(),
    }));

    res.json({
      products: formattedProducts,
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit)
      },
      source: 'mongodb'
    });

  } catch (error) {
    console.error('获取产品列表失败:', error);
    res.status(500).json({ error: '获取产品列表失败' });
  }
});

// 获取单个产品详情
router.get('/products/:productId', async (req, res) => {
  try {
    const { db } = require('../app');
    const { productId } = req.params;

    const database = db();
    if (!database) {
      return res.status(500).json({ error: '数据库连接未就绪' });
    }

    const product = await database.collection('products').findOne({ id: productId });

    if (!product) {
      return res.status(404).json({ error: '产品不存在' });
    }

    // 获取相关推荐（同店铺或相似产品）
    const relatedProducts = await database.collection('products')
      .find({
        $and: [
          { id: { $ne: productId } },
          {
            $or: [
              { storeId: product.storeId },
              { name: { $regex: product.name.split(' ')[0], $options: 'i' } }
            ]
          }
        ]
      })
      .limit(6)
      .toArray();

    const formattedProduct = {
      id: product.id,
      name: product.name,
      description: product.description,
      images: product.images || [],
      price: {
        amount: product.default_price?.unit_amount || 0,
        currency: product.default_price?.currency || 'usd',
        formatted: formatPrice(product.default_price?.unit_amount || 0, product.default_price?.currency || 'usd')
      },
      storeId: product.storeId,
      createdAt: new Date(product.created * 1000).toISOString(),
      updatedAt: new Date(product.updated * 1000).toISOString(),
      relatedProducts: relatedProducts.map(p => ({
        id: p.id,
        name: p.name,
        images: p.images?.slice(0, 1) || [],
        price: {
          amount: p.default_price?.unit_amount || 0,
          currency: p.default_price?.currency || 'usd',
          formatted: formatPrice(p.default_price?.unit_amount || 0, p.default_price?.currency || 'usd')
        },
        storeId: p.storeId
      }))
    };

    res.json({ product: formattedProduct });

  } catch (error) {
    console.error('获取产品详情失败:', error);
    res.status(500).json({ error: '获取产品详情失败' });
  }
});

// 获取商店列表
router.get('/stores', async (req, res) => {
  try {
    const { db } = require('../app');
    const database = db();
    
    if (!database) {
      return res.status(500).json({ error: '数据库连接未就绪' });
    }

    // 聚合查询获取每个商店的产品数量
    const stores = await database.collection('products').aggregate([
      {
        $group: {
          _id: '$storeId',
          productCount: { $sum: 1 },
          latestProduct: { $max: '$updated' }
        }
      },
      {
        $project: {
          storeId: '$_id',
          productCount: 1,
          latestUpdate: { $toDate: { $multiply: ['$latestProduct', 1000] } },
          _id: 0
        }
      },
      { $sort: { productCount: -1 } }
    ]).toArray();

    res.json({ stores });

  } catch (error) {
    console.error('获取商店列表失败:', error);
    res.status(500).json({ error: '获取商店列表失败' });
  }
});

// 价格格式化函数
function formatPrice(amount, currency) {
  try {
    const formatter = new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: currency.toUpperCase(),
    });
    return formatter.format(amount / 100); // Stripe金额以分为单位
  } catch (error) {
    return `${currency.toUpperCase()} ${(amount / 100).toFixed(2)}`;
  }
}

module.exports = router; 