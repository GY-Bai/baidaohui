// Cloudflare Pages Functions - 统计API
// 直接从R2获取统计数据，减轻VPS压力

export async function onRequest(context) {
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

    // 只允许GET请求
    if (request.method !== 'GET') {
      return new Response('Method not allowed', { 
        status: 405,
        headers: corsHeaders 
      });
    }

    // 从R2获取统计数据
    const object = await env.STORAGE.get('stats.json');
    
    if (!object) {
      return new Response(JSON.stringify({ error: '统计数据不存在' }), {
        status: 404,
        headers: {
          'Content-Type': 'application/json',
          ...corsHeaders
        }
      });
    }

    const stats = await object.json();
    
    return new Response(JSON.stringify(stats), {
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': 'public, max-age=60', // 1分钟缓存
        ...corsHeaders
      }
    });

  } catch (error) {
    console.error('统计API错误:', error);
    
    return new Response(JSON.stringify({ 
      error: '获取统计数据失败',
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