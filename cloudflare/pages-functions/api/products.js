// Cloudflare Pages Functions - 产品API
// 直接从R2获取产品数据，减轻VPS压力

export async function onRequestGet(context) {
  const { request, env } = context;
  const url = new URL(request.url);
  const productId = url.pathname.split('/').pop();
  
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
    
    // 从R2获取产品数据
    const r2Object = await env.R2_BUCKET.get('products.json');
    
    if (!r2Object) {
      return new Response(JSON.stringify({
        success: false,
        error: '产品数据不可用'
      }), {
        status: 404,
        headers: {
          'Content-Type': 'application/json',
          ...corsHeaders
        }
      });
    }
    
    const productsData = await r2Object.json();
    
    // 如果请求特定产品ID
    if (productId && productId !== 'products') {
      const product = productsData.products.find(p => 
        p.id === productId || 
        p.productId === productId || 
        p.stripeProductId === productId
      );
      
      if (!product) {
        return new Response(JSON.stringify({
          success: false,
          error: '产品不存在'
        }), {
          status: 404,
          headers: {
            'Content-Type': 'application/json',
            ...corsHeaders
          }
        });
      }
      
      return new Response(JSON.stringify({
        success: true,
        data: product,
        cached: true,
        source: 'cloudflare-pages'
      }), {
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': 'public, max-age=300',
          ...corsHeaders
        }
      });
    }
    
    // 返回所有产品
    const { page = 1, limit = 20, category, storeId } = Object.fromEntries(url.searchParams);
    let products = productsData.products;
    
    // 过滤
    if (category) {
      products = products.filter(p => p.category === category);
    }
    if (storeId) {
      products = products.filter(p => p.storeId === storeId);
    }
    
    // 分页
    const startIndex = (page - 1) * limit;
    const endIndex = startIndex + parseInt(limit);
    const paginatedProducts = products.slice(startIndex, endIndex);
    
    return new Response(JSON.stringify({
      success: true,
      data: paginatedProducts,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: products.length,
        totalPages: Math.ceil(products.length / limit)
      },
      cached: true,
      source: 'cloudflare-pages',
      lastUpdated: productsData.lastUpdated
    }), {
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': 'public, max-age=300',
        ...corsHeaders
      }
    });
    
  } catch (error) {
    console.error('获取产品数据失败:', error);
    
    return new Response(JSON.stringify({
      success: false,
      error: '服务暂时不可用'
    }), {
      status: 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      }
    });
  }
} 