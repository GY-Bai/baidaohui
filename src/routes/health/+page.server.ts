export const load = async () => {
  try {
    // 获取所有环境变量 - 兼容Cloudflare Pages和本地开发
    const viteSupabaseUrl = import.meta.env.VITE_SUPABASE_URL || process.env.VITE_SUPABASE_URL;
    const viteSupabaseKey = import.meta.env.VITE_SUPABASE_ANON_KEY || process.env.VITE_SUPABASE_ANON_KEY;
    const viteAppUrl = import.meta.env.VITE_APP_URL || process.env.VITE_APP_URL;
    const nodeEnv = import.meta.env.NODE_ENV || import.meta.env.MODE || process.env.NODE_ENV || 'development';
    
    // 统一API基础URL
    const apiBaseUrl = 'https://api.baidaohui.com';
    
    // 构建信息
    const mode = import.meta.env.MODE || process.env.NODE_ENV || 'development';
    const isDev = import.meta.env.DEV || mode === 'development';
    const isProd = import.meta.env.PROD || mode === 'production';
    const isSSR = import.meta.env.SSR || false;
    
    const timestamp = new Date().toISOString();
    const cacheBuster = Date.now();

    // 服务配置（将在客户端使用）- 修复路径匹配nginx配置和后端端口
    const sanJoseServices = [
      { name: '认证服务（auth-service）', url: `${apiBaseUrl}/auth/health` },
      { name: '单点登录服务（sso-service）', url: `${apiBaseUrl}/sso/health` },
      { name: '聊天服务（chat-service）', url: `${apiBaseUrl}/chat/health` },
      { name: '电商服务（ecommerce-api-service）', url: `${apiBaseUrl}/ecommerce/health` },
      { name: '邀请服务（invite-service）', url: `${apiBaseUrl}/invite/health` },
      { name: '支付服务（payment-service）', url: `${apiBaseUrl}/payment/health` },
      { name: '密钥服务（key-service）', url: `${apiBaseUrl}/keys/health` },
      { name: '静态API服务（static-api-service）', url: `${apiBaseUrl}/api/stats/health` }
    ];

    const buffaloServices = [
      { name: '算命服务（fortune-service）', url: `${apiBaseUrl}/fortune/health` },
      { name: '邮件服务（email-service）', url: `${apiBaseUrl}/email/health` },
      { name: 'R2同步服务（r2-sync-service）', url: `${apiBaseUrl}/sync/health` }
    ];

    const aiServices = [
      { name: 'AI代理服务（ai-proxy-service）', url: `${apiBaseUrl}/ai/health` }
    ];

    return {
      env_check: {
        supabase_url: viteSupabaseUrl || '未设置',
        supabase_key: viteSupabaseKey ? '已设置' : '未设置',
        app_url: viteAppUrl || '未设置',
        node_env: nodeEnv || '未设置',
        api_base_url: apiBaseUrl
      },
      build_info: {
        version: '2.4.1',
        mode,
        is_dev: isDev,
        is_prod: isProd,
        is_ssr: isSSR,
        timestamp,
        cache_buster: cacheBuster
      },
      service_config: {
        san_jose_services: sanJoseServices,
        buffalo_services: buffaloServices,
        ai_services: aiServices
      },
      debug_info: {
        user_agent: 'Health Check System',
        deployment_env: 'Cloudflare Pages',
        last_check: timestamp,
        testing_mode: 'Client-side via API Gateway',
        api_gateway: 'https://api.baidaohui.com',
        cors_note: '通过API网关统一CORS配置，解决跨域问题',
        dns_status: 'api.baidaohui.com → 107.172.87.113 (圣何塞VPS)',
        port_mapping: {
          'ecommerce-api-service': '5005:5004 (外部5005→内部5004)',
          'key-service': '5013:5009 (外部5013→内部5009)',
          'static-api-service': '5010:5010',
          'ai-proxy-service': '5012:5012'
        }
      }
    };

  } catch (error) {
    console.error('Health check load error:', error);
    return {
      error: '健康检查系统异常',
      message: error instanceof Error ? error.message : String(error),
      timestamp: new Date().toISOString(),
      env_check: {
        supabase_url: '加载失败',
        supabase_key: '加载失败',
        app_url: '加载失败',
        node_env: 'development',
        api_base_url: 'https://api.baidaohui.com'
      },
      build_info: {
        version: '2.4.1',
        mode: 'error',
        is_dev: true,
        is_prod: false,
        is_ssr: false,
        timestamp: new Date().toISOString(),
        cache_buster: Date.now()
      }
    };
  }
}; 