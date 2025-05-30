import { json } from '@sveltejs/kit';
import type { RequestHandler } from '@sveltejs/kit';

export const GET: RequestHandler = async ({ url, fetch }) => {
  const serviceUrl = url.searchParams.get('url');
  
  if (!serviceUrl) {
    return json({
      status: 'error',
      errorMessage: 'Missing service URL parameter',
      responseTime: 0
    }, { status: 400 });
  }

  const startTime = Date.now();
  
  try {
    // 设置10秒超时
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 10000);
    
    const response = await fetch(serviceUrl, {
      method: 'GET',
      headers: {
        'User-Agent': 'BaiDaoHui-Health-Checker/1.0',
        'Accept': 'application/json',
        'Cache-Control': 'no-cache'
      },
      signal: controller.signal
    });
    
    clearTimeout(timeoutId);
    const responseTime = Date.now() - startTime;
    
    if (response.ok) {
      try {
        const data = await response.json();
        return json({
          status: 'healthy',
          responseTime,
          httpStatus: response.status,
          data: data
        });
      } catch (parseError) {
        // 如果不是JSON响应，但状态码是200，仍然认为服务正常
        return json({
          status: 'healthy',
          responseTime,
          httpStatus: response.status,
          data: { message: 'Service responded successfully but with non-JSON content' }
        });
      }
    } else {
      return json({
        status: 'error',
        responseTime,
        httpStatus: response.status,
        errorType: getErrorType(response.status),
        errorMessage: `HTTP ${response.status} ${response.statusText}`
      });
    }
    
  } catch (error: any) {
    const responseTime = Date.now() - startTime;
    
    if (error.name === 'AbortError') {
      return json({
        status: 'error',
        responseTime,
        errorType: 'timeout',
        errorMessage: 'Request timeout (10s)'
      });
    }
    
    if (error.code === 'ECONNREFUSED') {
      return json({
        status: 'error',
        responseTime,
        errorType: 'connection_refused',
        errorMessage: 'Connection refused - service may be down'
      });
    }
    
    if (error.code === 'ENOTFOUND' || error.code === 'EAI_AGAIN') {
      return json({
        status: 'error',
        responseTime,
        errorType: 'dns_error',
        errorMessage: 'DNS resolution failed'
      });
    }
    
    if (error.code === 'ECONNRESET') {
      return json({
        status: 'error',
        responseTime,
        errorType: 'connection_reset',
        errorMessage: 'Connection reset by peer'
      });
    }
    
    return json({
      status: 'error',
      responseTime,
      errorType: 'network_error',
      errorMessage: error.message || 'Unknown network error'
    });
  }
};

function getErrorType(status: number): string {
  if (status === 403) return 'forbidden';
  if (status === 404) return 'not_found';
  if (status === 429) return 'rate_limited';
  if (status >= 500) return 'server_error';
  if (status >= 400) return 'client_error';
  return 'unknown_error';
} 