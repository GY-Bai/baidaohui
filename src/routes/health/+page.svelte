<script>
  export let data;
</script>

<div class="min-h-screen bg-gray-50 flex items-center justify-center p-4">
  <div class="max-w-4xl w-full bg-white rounded-lg shadow-md p-6">
    <h1 class="text-2xl font-bold text-center mb-6">
      系统健康检查
    </h1>
    
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
      <!-- 基本状态 -->
      <div class="space-y-3">
        <div class="flex justify-between">
          <span class="font-medium">状态:</span>
          <span class="px-2 py-1 rounded text-sm {data.status === 'healthy' ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'}">
            {data.status}
          </span>
        </div>
        
        <div class="flex justify-between">
          <span class="font-medium">时间:</span>
          <span class="text-sm text-gray-600">{data.timestamp}</span>
        </div>
        
        {#if data.build_info}
          <div class="border-t pt-3">
            <h3 class="font-medium mb-2">构建信息:</h3>
            <div class="space-y-1 text-sm">
              <div class="flex justify-between">
                <span>Mode:</span>
                <span class="text-gray-600">{data.build_info.mode}</span>
              </div>
              <div class="flex justify-between">
                <span>Development:</span>
                <span class="text-gray-600">{data.build_info.dev ? '是' : '否'}</span>
              </div>
              <div class="flex justify-between">
                <span>Production:</span>
                <span class="text-gray-600">{data.build_info.prod ? '是' : '否'}</span>
              </div>
            </div>
          </div>
        {/if}
      </div>

      <!-- 环境变量检查 -->
      {#if data.env_check}
        <div class="space-y-3">
          <h3 class="font-medium">环境变量检查:</h3>
          <div class="space-y-1 text-sm">
            <div class="flex justify-between">
              <span>VITE_SUPABASE_URL:</span>
              <span class="text-gray-600 {data.env_check.VITE_SUPABASE_URL === '已配置' ? 'text-green-600' : 'text-red-600'}">
                {data.env_check.VITE_SUPABASE_URL}
              </span>
            </div>
            <div class="flex justify-between">
              <span>VITE_SUPABASE_ANON_KEY:</span>
              <span class="text-gray-600 {data.env_check.VITE_SUPABASE_ANON_KEY === '已配置' ? 'text-green-600' : 'text-red-600'}">
                {data.env_check.VITE_SUPABASE_ANON_KEY}
              </span>
            </div>
            <div class="flex justify-between">
              <span>SSO_SERVICE_URL:</span>
              <span class="text-green-600 text-xs">{data.env_check.SSO_SERVICE_URL}</span>
            </div>
            <div class="flex justify-between">
              <span>AUTH_SERVICE_URL:</span>
              <span class="text-green-600 text-xs">{data.env_check.AUTH_SERVICE_URL}</span>
            </div>
            <div class="flex justify-between">
              <span>NODE_ENV:</span>
              <span class="text-gray-600">{data.env_check.NODE_ENV}</span>
            </div>
          </div>
        </div>
      {/if}
    </div>

    <!-- 后端服务状态 -->
    {#if data.backend_status}
      <div class="border-t mt-6 pt-6">
        <h3 class="font-medium mb-4">后端API服务状态:</h3>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <h4 class="text-sm font-medium text-gray-700 mb-2">API端点:</h4>
            <div class="space-y-1 text-xs">
              <div class="flex justify-between">
                <span>Health Check:</span>
                <a href="{data.backend_status.health_check}" target="_blank" class="text-blue-600 hover:underline">
                  {data.backend_status.health_check}
                </a>
              </div>
              <div class="flex justify-between">
                <span>API Base:</span>
                <span class="text-gray-600">{data.backend_status.api_endpoint}</span>
              </div>
            </div>
          </div>
          
          <div>
            <h4 class="text-sm font-medium text-gray-700 mb-2">微服务:</h4>
            <div class="space-y-1 text-xs">
              {#each Object.entries(data.backend_status.services) as [service, url]}
                <div class="flex justify-between">
                  <span class="capitalize">{service}:</span>
                  <a href="{url}/health" target="_blank" class="text-blue-600 hover:underline">
                    测试
                  </a>
                </div>
              {/each}
            </div>
          </div>
        </div>
      </div>
    {/if}
      
    {#if data.error}
      <div class="border-t pt-3 mt-6">
        <h3 class="font-medium text-red-600 mb-2">错误信息:</h3>
        <pre class="text-sm text-red-600 bg-red-50 p-2 rounded">{data.error}</pre>
      </div>
    {/if}
    
    <div class="mt-6 text-center space-x-4">
      <a href="/login" class="text-blue-600 hover:text-blue-800 underline">
        返回登录页
      </a>
      <a href="{data.backend_status?.health_check || 'http://107.172.87.113/api/health'}" target="_blank" class="text-green-600 hover:text-green-800 underline">
        后端健康检查
      </a>
    </div>
  </div>
</div> 