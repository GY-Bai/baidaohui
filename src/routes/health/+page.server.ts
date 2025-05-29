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
    
    const timestamp = new Date().toISOString();
    
    return {
      status: 'healthy',
      timestamp: timestamp,
      version: '2.0.0', // 版本号强制更新
      cache_buster: Date.now(), // 缓存破坏器
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
        timestamp: timestamp,
        svelte_version: '5.x',
        vite_version: '5.4.8'
      },
      backend_status: {
        // 圣何塞VPS (主要API服务)
        san_jose_vps: {
          ip: '107.172.87.113',
          api_endpoint: 'http://107.172.87.113/api',
          health_check: 'http://107.172.87.113/api/health',
          services: {
            auth: 'http://107.172.87.113/api/auth/health',
            sso: 'http://107.172.87.113/api/sso/health',
            chat: 'http://107.172.87.113/api/chat/health',
            invite: 'http://107.172.87.113/api/invite/health',
            ecommerce: 'http://107.172.87.113/api/ecommerce/health',
            payment: 'http://107.172.87.113/api/payment/health',
            key: 'http://107.172.87.113/api/key/health',
            'static-api': 'http://107.172.87.113/api/static/health'
          }
        },
        
        // 水牛城VPS (特殊服务)
        buffalo_vps: {
          ip: '216.144.233.104',
          description: '水牛城VPS - 专门服务',
          services: {
            fortune: 'http://216.144.233.104:5007/health',
            email: 'http://216.144.233.104:5008/health',
            'r2-sync': 'http://216.144.233.104:5011/health'
          },
          containers: {
            'ecommerce-poller': '电商数据轮询服务',
            'exchange-rate-updater': '汇率更新服务'
          }
        }
      },
      // 调试信息
      debug_info: {
        page_version: '2.0.0',
        last_updated: timestamp,
        all_env_vars: {
          VITE_SUPABASE_URL: viteSupabaseUrl ? '✓ Set' : '✗ Missing',
          VITE_SUPABASE_ANON_KEY: viteSupabaseKey ? '✓ Set' : '✗ Missing',
          VITE_APP_URL: viteAppUrl ? '✓ Set' : '✗ Missing',
          NODE_ENV: nodeEnv ? '✓ Set' : '✗ Missing',
          MODE: import.meta.env.MODE ? '✓ Set' : '✗ Missing'
        },
        deployment_info: {
          cloudflare_pages: true,
          adapter: '@sveltejs/adapter-cloudflare',
          build_time: timestamp
        }
      }
    };
  } catch (error) {
    return {
      status: 'error',
      error: String(error),
      timestamp: new Date().toISOString(),
      version: '2.0.0',
      env_check: {
        SSO_SERVICE_URL: 'error_loading',
        NODE_ENV: 'error_loading'
      }
    };
  }
}; 