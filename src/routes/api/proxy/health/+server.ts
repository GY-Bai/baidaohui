import { json } from '@sveltejs/kit';
import type { RequestHandler } from '@sveltejs/kit';

export const GET: RequestHandler = async ({ url, fetch }) => {
  try {
    // 从查询参数获取目标服务URL
    const targetUrl = url.searchParams.get('url');
    
    if (!targetUrl) {
      return json(
        { 
          status: 'error', 
          message: 'Missing target URL parameter' 
        }, 
        { status: 400 }
      );
    }

    // 验证目标URL是否为允许的服务器
    const allowedHosts = [
      'api.baidaohui.com',
      '107.172.87.113',
      '216.144.233.104'
    ];

    const urlObj = new URL(targetUrl);
    const isAllowed = allowedHosts.some(host => 
      urlObj.hostname === host || 
      urlObj.hostname.endsWith(host)
    );

    if (!isAllowed) {
      return json(
        { 
          status: 'error', 
          message: 'Target URL not allowed' 
        }, 
        { status: 403 }
      );
    }

    // 发起代理请求
    const startTime = Date.now();
    
    try {
      const response = await fetch(targetUrl, {
        method: 'GET',
        headers: {
          'User-Agent': 'BaiDaoHui-Health-Check/1.0',
          'Accept': 'application/json, text/plain, */*',
          'Cache-Control': 'no-cache'
        }
      });

      const responseTime = Date.now() - startTime;
      const responseText = await response.text();

      // 尝试解析JSON响应
      let responseData;
      try {
        responseData = JSON.parse(responseText);
      } catch {
        responseData = { raw: responseText };
      }

      // 转换Headers为普通对象
      const responseHeaders: Record<string, string> = {};
      response.headers.forEach((value, key) => {
        responseHeaders[key] = value;
      });

      return json({
        status: response.ok ? 'healthy' : 'error',
        httpStatus: response.status,
        responseTime: responseTime,
        data: responseData,
        headers: responseHeaders
      });

    } catch (fetchError: any) {
      const responseTime = Date.now() - startTime;
      
      let errorType = 'unknown';
      let errorMessage = fetchError.message || 'Unknown error';

      if (fetchError.name === 'AbortError' || fetchError.message?.includes('timeout')) {
        errorType = 'timeout';
        errorMessage = 'Request timeout (5s)';
      } else if (fetchError.message?.includes('ECONNREFUSED')) {
        errorType = 'connection_refused';
        errorMessage = 'Connection refused';
      } else if (fetchError.message?.includes('ENOTFOUND')) {
        errorType = 'dns_error';
        errorMessage = 'DNS resolution failed';
      } else if (fetchError.message?.includes('CORS')) {
        errorType = 'cors_error';
        errorMessage = 'CORS policy blocked request';
      }

      return json({
        status: 'error',
        errorType: errorType,
        errorMessage: errorMessage,
        responseTime: responseTime,
        httpStatus: 0
      });
    }

  } catch (error: any) {
    return json(
      { 
        status: 'error', 
        message: 'Proxy server error: ' + error.message 
      }, 
      { status: 500 }
    );
  }
}; 