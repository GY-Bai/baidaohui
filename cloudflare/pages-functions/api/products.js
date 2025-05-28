// Cloudflare Pages Functions - 产品API
// 直接从R2获取产品数据，减轻VPS压力

export async function onRequest(context) {
  const { request, env } = context;
  const url = new URL(request.url);
  
  try {
    // 设置CORS头
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
    };

    // 处理OPTIONS请求
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    // 只允许GET请求
    if (request.method !== 'GET') {
      return new Response('Method not allowed', { 
        status: 405,
        headers: corsHeaders 
      });
    }

    // 从R2获取产品数据
    const object = await env.STORAGE.get('products.json');
    
    if (!object) {
      return new Response(JSON.stringify({ error: '产品数据不存在' }), {
        status: 404,
        headers: {
          'Content-Type': 'application/json',
          ...corsHeaders
        }
      });
    }

    const products = await object.json();
    
    // 解析查询参数
    const page = parseInt(url.searchParams.get('page') || '1');
    const limit = parseInt(url.searchParams.get('limit') || '20');
    const category = url.searchParams.get('category');
    const storeId = url.searchParams.get('storeId');
    
    // 过滤产品
    let filteredProducts = products;
    
    if (category) {
      filteredProducts = filteredProducts.filter(p => p.category === category);
    }
    
    if (storeId) {
      filteredProducts = filteredProducts.filter(p => p.storeId === storeId);
    }
    
    // 分页
    const startIndex = (page - 1) * limit;
    const endIndex = startIndex + limit;
    const paginatedProducts = filteredProducts.slice(startIndex, endIndex);
    
    const response = {
      products: paginatedProducts,
      pagination: {
        page,
        limit,
        total: filteredProducts.length,
        totalPages: Math.ceil(filteredProducts.length / limit)
      },
      lastUpdated: new Date().toISOString()
    };

    return new Response(JSON.stringify(response), {
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': 'public, max-age=300', // 5分钟缓存
        ...corsHeaders
      }
    });

  } catch (error) {
    console.error('产品API错误:', error);
    
    return new Response(JSON.stringify({ 
      error: '获取产品数据失败',
      message: error.message 
    }), {
      status: 500,
      headers: {
        'Content-Type': 'application/json',
        ...corsHeaders
      }
    });
  }
} 