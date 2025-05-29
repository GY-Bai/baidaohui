import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ fetch }) => {
  try {
    // 简单的健康检查，不依赖后端服务
    return {
      status: 'healthy',
      timestamp: new Date().toISOString(),
      env_check: {
        SSO_SERVICE_URL: import.meta.env.SSO_SERVICE_URL || import.meta.env.VITE_SSO_SERVICE_URL || 'not_configured',
        NODE_ENV: import.meta.env.NODE_ENV || 'not_configured'
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