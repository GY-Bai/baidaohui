// Cloudflare Pages Functions - 汇率API
// 直接从R2获取汇率数据，减轻VPS压力

export async function onRequestGet(context) {
  const { request, env } = context;
  
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
    
    // 从R2获取统计数据（包含汇率）
    const r2Object = await env.R2_BUCKET.get('stats.json');
    
    if (!r2Object) {
      return new Response(JSON.stringify({
        success: false,
        error: '汇率数据不可用'
      }), {
        status: 404,
        headers: {
          'Content-Type': 'application/json',
          ...corsHeaders
        }
      });
    }
    
    const statsData = await r2Object.json();
    
    if (!statsData.exchangeRates) {
      return new Response(JSON.stringify({
        success: false,
        error: '汇率数据不可用'
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
      data: statsData.exchangeRates,
      cached: true,
      source: 'cloudflare-pages'
    }), {
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': 'public, max-age=3600', // 1小时缓存
        ...corsHeaders
      }
    });
    
  } catch (error) {
    console.error('获取汇率数据失败:', error);
    
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