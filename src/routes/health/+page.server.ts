export const load = async () => {
  try {
    // 获取所有环境变量
    const viteSupabaseUrl = import.meta.env.VITE_SUPABASE_URL;
    const viteSupabaseKey = import.meta.env.VITE_SUPABASE_ANON_KEY;
    const viteAppUrl = import.meta.env.VITE_APP_URL;
    const nodeEnv = import.meta.env.NODE_ENV || import.meta.env.MODE;
    
    // 统一API基础URL
    const apiBaseUrl = 'https://api.baidaohui.com';
    
    // 构建信息
    const mode = import.meta.env.MODE || 'unknown';
    const isDev = import.meta.env.DEV || false;
    const isProd = import.meta.env.PROD || false;
    const isSSR = import.meta.env.SSR || false;
    
    const timestamp = new Date().toISOString();
    const cacheBuster = Date.now();

    // 服务配置（将在客户端使用）
    const sanJoseServices = [
      { name: '认证服务（auth-service）', url: `${apiBaseUrl}/auth/health` },
      { name: '单点登录服务（sso-service）', url: `${apiBaseUrl}/sso/health` },
      { name: '聊天服务（chat-service）', url: `${apiBaseUrl}/chat/health` },
      { name: '电商服务（ecommerce-service）', url: `${apiBaseUrl}/ecommerce/health` },
      { name: '邀请服务（invite-service）', url: `${apiBaseUrl}/invite/health` },
      { name: '支付服务（payment-service）', url: `${apiBaseUrl}/payment/health` },
      { name: '密钥服务（key-service）', url: `${apiBaseUrl}/keys/health` },
      { name: '静态API服务（static-api-service）', url: `${apiBaseUrl}/static/health` }
    ];

    const buffaloServices = [
      { name: '算命服务（fortune-service）', url: `${apiBaseUrl}/fortune/health` },
      { name: '邮件服务（email-service）', url: `${apiBaseUrl}/email/health` },
      { name: 'R2同步服务（r2-sync-service）', url: `${apiBaseUrl}/r2-sync/health` }
    ];

    const aiServices = [
      { name: 'AI代理服务（ai-proxy-service）', url: `${apiBaseUrl}/v1/health` }
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
        version: '2.4.0',
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
        cors_note: '通过API网关统一CORS配置，解决跨域问题'
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