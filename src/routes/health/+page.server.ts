export const load = async () => {
  try {
    // 简单的健康检查，显示环境变量状态
    return {
      status: 'healthy',
      timestamp: new Date().toISOString(),
      env_check: {
        VITE_SUPABASE_URL: import.meta.env.VITE_SUPABASE_URL ? '已配置' : '未配置',
        VITE_SUPABASE_ANON_KEY: import.meta.env.VITE_SUPABASE_ANON_KEY ? '已配置' : '未配置',
        VITE_APP_URL: import.meta.env.VITE_APP_URL || '未配置',
        NODE_ENV: import.meta.env.NODE_ENV || 'development'
      },
      build_info: {
        mode: import.meta.env.MODE || 'unknown',
        dev: import.meta.env.DEV || false,
        prod: import.meta.env.PROD || false
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