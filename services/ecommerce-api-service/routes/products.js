const express = require('express');
const axios = require('axios');
const router = express.Router();
const { ObjectId } = require('mongodb');

const R2_ENDPOINT = process.env.R2_ENDPOINT;
const R2_BUCKET = process.env.R2_BUCKET;

// 获取商品列表
router.get('/', async (req, res) => {
  try {
    const { page = 1, limit = 20, storeId, category, search } = req.query;
    const skip = (parseInt(page) - 1) * parseInt(limit);

    // 构建查询条件
    const query = { active: true };
    
    if (storeId) {
      query.storeId = storeId;
    }
    
    if (category) {
      query.category = category;
    }
    
    if (search) {
      query.$or = [
        { name: { $regex: search, $options: 'i' } },
        { description: { $regex: search, $options: 'i' } }
      ];
    }

    // 优先从R2获取静态JSON
    let products = [];
    let total = 0;
    
    try {
      // 尝试从R2获取缓存的商品数据
      const r2Response = await axios.get(`${process.env.R2_ENDPOINT}/${process.env.R2_BUCKET}/products.json`, {
        timeout: 5000
      });
      
      if (r2Response.data && r2Response.data.products) {
        let allProducts = r2Response.data.products;
        
        // 应用过滤条件
        if (storeId) {
          allProducts = allProducts.filter(p => p.storeId === storeId);
        }
        
        if (category) {
          allProducts = allProducts.filter(p => p.category === category);
        }
        
        if (search) {
          const searchLower = search.toLowerCase();
          allProducts = allProducts.filter(p => 
            p.name.toLowerCase().includes(searchLower) || 
            (p.description && p.description.toLowerCase().includes(searchLower))
          );
        }
        
        total = allProducts.length;
        products = allProducts.slice(skip, skip + parseInt(limit));
        
        console.log(`从R2获取商品数据成功: ${products.length}/${total}`);
      }
    } catch (r2Error) {
      console.warn('从R2获取商品数据失败，回退到MongoDB:', r2Error.message);
      
      // 回退到MongoDB查询
      const db = req.app.locals.db;
      
      const [productsResult, totalResult] = await Promise.all([
        db.collection('products')
          .find(query)
          .sort({ created: -1 })
          .skip(skip)
          .limit(parseInt(limit))
          .toArray(),
        db.collection('products').countDocuments(query)
      ]);
      
      products = productsResult;
      total = totalResult;
      
      console.log(`从MongoDB获取商品数据: ${products.length}/${total}`);
    }

    // 格式化商品数据
    const formattedProducts = products.map(product => ({
      id: product.id,
      name: product.name,
      description: product.description,
      images: product.images || [],
      default_price: {
        id: product.default_price.id,
        unit_amount: product.default_price.unit_amount,
        currency: product.default_price.currency.toUpperCase()
      },
      payment_link: product.payment_link ? {
        id: product.payment_link.id,
        url: product.payment_link.url,
        active: product.payment_link.active
      } : null,
      storeId: product.storeId,
      category: product.category || 'general',
      created: product.created,
      updated: product.updated
    }));

    res.json({
      success: true,
      products: formattedProducts,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        totalPages: Math.ceil(total / parseInt(limit))
      },
      source: products.length > 0 ? (r2Error ? 'mongodb' : 'r2') : 'empty'
    });

  } catch (error) {
    console.error('获取商品列表失败:', error);
    res.status(500).json({
      success: false,
      error: '获取商品列表失败',
      message: process.env.NODE_ENV === 'development' ? error.message : '服务器内部错误'
    });
  }
});

// 获取单个商品详情
router.get('/:productId', async (req, res) => {
  try {
    const { productId } = req.params;
    const db = req.app.locals.db;

    // 从MongoDB查询商品详情
    const product = await db.collection('products').findOne({
      id: productId,
      active: true
    });

    if (!product) {
      return res.status(404).json({
        success: false,
        error: '商品不存在'
      });
    }

    // 获取相关推荐商品（同店铺或同类别）
    const relatedProducts = await db.collection('products')
      .find({
        $and: [
          { id: { $ne: productId } },
          { active: true },
          {
            $or: [
              { storeId: product.storeId },
              { category: product.category }
            ]
          }
        ]
      })
      .limit(6)
      .toArray();

    // 格式化商品数据
    const formattedProduct = {
      id: product.id,
      name: product.name,
      description: product.description,
      images: product.images || [],
      default_price: {
        id: product.default_price.id,
        unit_amount: product.default_price.unit_amount,
        currency: product.default_price.currency.toUpperCase()
      },
      payment_link: product.payment_link ? {
        id: product.payment_link.id,
        url: product.payment_link.url,
        active: product.payment_link.active
      } : null,
      storeId: product.storeId,
      category: product.category || 'general',
      created: product.created,
      updated: product.updated,
      related_products: relatedProducts.map(p => ({
        id: p.id,
        name: p.name,
        images: p.images || [],
        default_price: p.default_price,
        payment_link: p.payment_link
      }))
    };

    res.json({
      success: true,
      product: formattedProduct
    });

  } catch (error) {
    console.error('获取商品详情失败:', error);
    res.status(500).json({
      success: false,
      error: '获取商品详情失败',
      message: process.env.NODE_ENV === 'development' ? error.message : '服务器内部错误'
    });
  }
});

// 获取商店列表
router.get('/stores/list', async (req, res) => {
  try {
    const db = req.app.locals.db;

    // 聚合查询获取每个商店的商品统计
    const stores = await db.collection('products').aggregate([
      { $match: { active: true } },
      {
        $group: {
          _id: '$storeId',
          productCount: { $sum: 1 },
          totalValue: { $sum: '$default_price.unit_amount' },
          categories: { $addToSet: '$category' },
          lastUpdated: { $max: '$updated' }
        }
      },
      {
        $project: {
          storeId: '$_id',
          productCount: 1,
          totalValue: 1,
          categories: 1,
          lastUpdated: 1,
          _id: 0
        }
      },
      { $sort: { productCount: -1 } }
    ]).toArray();

    res.json({
      success: true,
      stores
    });

  } catch (error) {
    console.error('获取商店列表失败:', error);
    res.status(500).json({
      success: false,
      error: '获取商店列表失败'
    });
  }
});

// 搜索商品
router.get('/search/:keyword', async (req, res) => {
  try {
    const { keyword } = req.params;
    const { page = 1, limit = 20 } = req.query;
    const skip = (parseInt(page) - 1) * parseInt(limit);

    const db = req.app.locals.db;

    // 构建搜索查询
    const searchQuery = {
      active: true,
      $or: [
        { name: { $regex: keyword, $options: 'i' } },
        { description: { $regex: keyword, $options: 'i' } },
        { storeId: { $regex: keyword, $options: 'i' } }
      ]
    };

    const [products, total] = await Promise.all([
      db.collection('products')
        .find(searchQuery)
        .sort({ created: -1 })
        .skip(skip)
        .limit(parseInt(limit))
        .toArray(),
      db.collection('products').countDocuments(searchQuery)
    ]);

    const formattedProducts = products.map(product => ({
      id: product.id,
      name: product.name,
      description: product.description,
      images: product.images || [],
      default_price: product.default_price,
      payment_link: product.payment_link,
      storeId: product.storeId
    }));

    res.json({
      success: true,
      keyword,
      products: formattedProducts,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        totalPages: Math.ceil(total / parseInt(limit))
      }
    });

  } catch (error) {
    console.error('搜索商品失败:', error);
    res.status(500).json({
      success: false,
      error: '搜索失败'
    });
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