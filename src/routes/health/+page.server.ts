export const load = async () => {
  try {
    // 系统健康检查，显示前端和后端环境变量状态
    return {
      status: 'healthy',
      timestamp: new Date().toISOString(),
      env_check: {
        // 前端环境变量
        VITE_SUPABASE_URL: import.meta.env.VITE_SUPABASE_URL ? '已配置' : '未配置',
        VITE_SUPABASE_ANON_KEY: import.meta.env.VITE_SUPABASE_ANON_KEY ? '已配置' : '未配置',
        VITE_APP_URL: import.meta.env.VITE_APP_URL || '未配置',
        
        // 后端API配置 (通过环境变量)
        SSO_SERVICE_URL: import.meta.env.VITE_SSO_SERVICE_URL || 'http://107.172.87.113/api/sso',
        AUTH_SERVICE_URL: import.meta.env.VITE_AUTH_SERVICE_URL || 'http://107.172.87.113/api/auth',
        API_BASE_URL: import.meta.env.VITE_API_BASE_URL || 'http://107.172.87.113/api',
        
        // 系统环境
        NODE_ENV: import.meta.env.NODE_ENV || import.meta.env.MODE || 'development'
      },
      build_info: {
        mode: import.meta.env.MODE || 'unknown',
        dev: import.meta.env.DEV || false,
        prod: import.meta.env.PROD || false,
        ssr: import.meta.env.SSR || false
      },
      backend_status: {
        api_endpoint: 'http://107.172.87.113/api',
        health_check: 'http://107.172.87.113/api/health',
        services: {
          auth: 'http://107.172.87.113/api/auth',
          sso: 'http://107.172.87.113/api/sso',
          chat: 'http://107.172.87.113/api/chat',
          invite: 'http://107.172.87.113/api/invite',
          ecommerce: 'http://107.172.87.113/api/ecommerce',
          payment: 'http://107.172.87.113/api/payment'
        }
      }
    };
  } catch (error) {
    return {
      status: 'error',
      error: String(error),
      timestamp: new Date().toISOString()
    };
  }
}; 