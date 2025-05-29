export const load = async () => {
  try {
    // 获取所有环境变量
    const viteSupabaseUrl = import.meta.env.VITE_SUPABASE_URL;
    const viteSupabaseKey = import.meta.env.VITE_SUPABASE_ANON_KEY;
    const viteAppUrl = import.meta.env.VITE_APP_URL;
    const nodeEnv = import.meta.env.NODE_ENV || import.meta.env.MODE;
    
    // 后端API配置
    const ssoServiceUrl = import.meta.env.VITE_SSO_SERVICE_URL || 'http://107.172.87.113/api/sso';
    const authServiceUrl = import.meta.env.VITE_AUTH_SERVICE_URL || 'http://107.172.87.113/api/auth';
    const apiBaseUrl = import.meta.env.VITE_API_BASE_URL || 'http://107.172.87.113/api';
    
    // 构建信息
    const mode = import.meta.env.MODE || 'unknown';
    const isDev = import.meta.env.DEV || false;
    const isProd = import.meta.env.PROD || false;
    const isSSR = import.meta.env.SSR || false;
    
    return {
      status: 'healthy',
      timestamp: new Date().toISOString(),
      env_check: {
        // 前端环境变量
        VITE_SUPABASE_URL: viteSupabaseUrl ? 'configured' : 'not_configured',
        VITE_SUPABASE_ANON_KEY: viteSupabaseKey ? 'configured' : 'not_configured',
        VITE_APP_URL: viteAppUrl || 'not_configured',
        
        // 后端API配置
        SSO_SERVICE_URL: ssoServiceUrl,
        AUTH_SERVICE_URL: authServiceUrl,
        API_BASE_URL: apiBaseUrl,
        
        // 系统环境
        NODE_ENV: nodeEnv || 'not_configured'
      },
      build_info: {
        mode: mode,
        development: isDev,
        production: isProd,
        ssr: isSSR,
        timestamp: new Date().toISOString()
      },
      backend_status: {
        api_endpoint: 'http://107.172.87.113/api',
        health_check: 'http://107.172.87.113/api/health',
        services: {
          auth: 'http://107.172.87.113/api/auth/health',
          sso: 'http://107.172.87.113/api/sso/health',
          chat: 'http://107.172.87.113/api/chat/health',
          invite: 'http://107.172.87.113/api/invite/health',
          ecommerce: 'http://107.172.87.113/api/ecommerce/health',
          payment: 'http://107.172.87.113/api/payment/health',
          key: 'http://107.172.87.113/api/key/health'
        }
      },
      // 调试信息
      debug_info: {
        all_env_vars: {
          VITE_SUPABASE_URL: viteSupabaseUrl ? '✓ Set' : '✗ Missing',
          VITE_SUPABASE_ANON_KEY: viteSupabaseKey ? '✓ Set' : '✗ Missing',
          VITE_APP_URL: viteAppUrl ? '✓ Set' : '✗ Missing',
          NODE_ENV: nodeEnv ? '✓ Set' : '✗ Missing',
          MODE: import.meta.env.MODE ? '✓ Set' : '✗ Missing'
        }
      }
    };
  } catch (error) {
    return {
      status: 'error',
      error: String(error),
      timestamp: new Date().toISOString(),
      env_check: {
        SSO_SERVICE_URL: 'error_loading',
        NODE_ENV: 'error_loading'
      }
    };
  }
}; 