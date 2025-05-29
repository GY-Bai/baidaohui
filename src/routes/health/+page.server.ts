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
    const cacheBuster = Date.now();

    // 服务配置（将在客户端使用）
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

    const buffaloServices = [
      { name: '算命服务（fortune-service）', url: 'http://216.144.233.104:5007/health' },
      { name: '邮件服务（email-service）', url: 'http://216.144.233.104:5008/health' },
      { name: 'R2同步服务（r2-sync-service）', url: 'http://216.144.233.104:5011/health' }
    ];

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
        version: '2.3.0',
        mode,
        is_dev: isDev,
        is_prod: isProd,
        is_ssr: isSSR,
        timestamp,
        cache_buster: cacheBuster
      },
      service_config: {
        san_jose_services: sanJoseServices,
        buffalo_services: buffaloServices
      },
      debug_info: {
        user_agent: 'Health Check System',
        deployment_env: 'Cloudflare Pages',
        last_check: timestamp,
        testing_mode: 'Client-side (User Browser)',
        browser_request_note: '健康检查请求将从用户浏览器发出，绕过Cloudflare Worker限制'
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