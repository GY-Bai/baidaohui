export const load = async () => {
  try {
    // 获取所有环境变量
    const viteSupabaseUrl = import.meta.env.VITE_SUPABASE_URL;
    const viteSupabaseKey = import.meta.env.VITE_SUPABASE_ANON_KEY;
    const viteAppUrl = import.meta.env.VITE_APP_URL;
    const nodeEnv = import.meta.env.NODE_ENV || import.meta.env.MODE;
    
    // 后端API配置（不显示IP）
    const ssoServiceUrl = import.meta.env.VITE_SSO_SERVICE_URL || 'http://107.172.87.113/api/sso';
    const authServiceUrl = import.meta.env.VITE_AUTH_SERVICE_URL || 'http://107.172.87.113/api/auth';
    const apiBaseUrl = import.meta.env.VITE_API_BASE_URL || 'http://107.172.87.113/api';
    
    // 构建信息
    const mode = import.meta.env.MODE || 'unknown';
    const isDev = import.meta.env.DEV || false;
    const isProd = import.meta.env.PROD || false;
    const isSSR = import.meta.env.SSR || false;
    
    const timestamp = new Date().toISOString();
    const cacheBuster = Date.now();
    
    // 测试服务健康状态的函数
    async function testService(url: string): Promise<{status: string, error?: string, response_time: number, http_status?: number, service_info?: any}> {
      const startTime = Date.now();
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 10000); // 10秒超时
      
      try {
        const response = await fetch(url, {
          method: 'GET',
          signal: controller.signal,
          headers: {
            'User-Agent': 'Health Check Bot',
            'Accept': 'application/json'
          }
        });
        
        clearTimeout(timeoutId);
        const responseTime = Date.now() - startTime;
        
        if (response.ok) {
          try {
            const data = await response.json();
            
            // 检查JSON响应中的status字段
            if (data && typeof data === 'object') {
              const serviceStatus = data.status;
              
              if (serviceStatus === 'healthy') {
                return { 
                  status: 'healthy', 
                  response_time: responseTime,
                  http_status: response.status,
                  service_info: data
                };
              } else if (serviceStatus) {
                // status字段存在但不是healthy
                return { 
                  status: 'error', 
                  error: `服务状态: ${serviceStatus}`, 
                  response_time: responseTime,
                  http_status: response.status,
                  service_info: data
                };
              } else {
                // 没有status字段
                return { 
                  status: 'error', 
                  error: '响应中缺少status字段', 
                  response_time: responseTime,
                  http_status: response.status,
                  service_info: data
                };
              }
            } else {
              return { 
                status: 'error', 
                error: '无效的JSON响应格式', 
                response_time: responseTime,
                http_status: response.status
              };
            }
          } catch (jsonError) {
            // JSON解析失败
            return { 
              status: 'error', 
              error: `JSON解析失败: ${jsonError instanceof Error ? jsonError.message : String(jsonError)}`, 
              response_time: responseTime,
              http_status: response.status
            };
          }
        } else {
          return { 
            status: 'error', 
            error: `HTTP ${response.status}`, 
            response_time: responseTime,
            http_status: response.status
          };
        }
      } catch (error: unknown) {
        clearTimeout(timeoutId);
        const responseTime = Date.now() - startTime;
        
        if (error instanceof Error && error.name === 'AbortError') {
          return { status: 'timeout', error: 'Request timeout', response_time: responseTime };
        }
        const errorMessage = error instanceof Error ? error.message : String(error);
        return { status: 'error', error: errorMessage, response_time: responseTime };
      }
    }

    // 圣何塞VPS服务测试（移除IP显示）
    const sanJoseServices = [
      { name: '认证服务（auth-service）', url: `${apiBaseUrl}/auth/health` },
      { name: '单点登录服务（sso-service）', url: `${apiBaseUrl}/sso/health` },
      { name: '聊天服务（chat-service）', url: `${apiBaseUrl}/chat/health` },
      { name: '电商服务（ecommerce-service）', url: `${apiBaseUrl}/ecommerce/health` },
      { name: '邀请服务（invite-service）', url: `${apiBaseUrl}/invite/health` },
      { name: '支付服务（payment-service）', url: `${apiBaseUrl}/payment/health` },
      { name: '密钥服务（key-service）', url: `${apiBaseUrl}/key/health` },
      { name: '静态API服务（static-api-service）', url: `${apiBaseUrl}/static/health` }
    ];

    // 水牛城VPS服务测试（移除IP显示）
    const buffaloServices = [
      { name: '算命服务（fortune-service）', url: 'http://216.144.233.104:5007/health' },
      { name: '邮件服务（email-service）', url: 'http://216.144.233.104:5008/health' },
      { name: 'R2同步服务（r2-sync-service）', url: 'http://216.144.233.104:5011/health' }
    ];

    // 并行测试所有服务
    const [sanJoseResults, buffaloResults] = await Promise.all([
      Promise.all(sanJoseServices.map(async service => ({
        name: service.name,
        result: await testService(service.url)
      }))),
      Promise.all(buffaloServices.map(async service => ({
        name: service.name,
        result: await testService(service.url)
      })))
    ]);

    // 组织服务状态数据
    const sanJoseVps: Record<string, any> = {};
    sanJoseResults.forEach(({name, result}) => {
      sanJoseVps[name] = result;
    });

    const buffaloVps: Record<string, any> = {};
    buffaloResults.forEach(({name, result}) => {
      buffaloVps[name] = result;
    });

    return {
      env_check: {
        supabase_url: viteSupabaseUrl || '未设置',
        supabase_key: viteSupabaseKey ? '已设置' : '未设置',
        app_url: viteAppUrl || '未设置',
        node_env: nodeEnv || '未设置',
        sso_service_url: ssoServiceUrl ? '已配置' : '未设置',
        auth_service_url: authServiceUrl ? '已配置' : '未设置',
        api_base_url: apiBaseUrl ? '已配置' : '未设置'
      },
      build_info: {
        version: '2.2.0',
        mode,
        is_dev: isDev,
        is_prod: isProd,
        is_ssr: isSSR,
        timestamp,
        cache_buster: cacheBuster
      },
      backend_status: {
        san_jose_vps: sanJoseVps,
        buffalo_vps: buffaloVps
      },
      debug_info: {
        user_agent: 'Health Check System',
        deployment_env: 'Cloudflare Pages',
        last_check: timestamp
      }
    };

  } catch (error) {
    console.error('Health check error:', error);
    return {
      error: '健康检查系统异常',
      message: error instanceof Error ? error.message : String(error),
      timestamp: new Date().toISOString()
    };
  }
}; 