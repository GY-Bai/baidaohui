<script>
  export let data;
  
  // 确保数据存在
  $: envCheck = data?.env_check || {};
  $: buildInfo = data?.build_info || {};
  $: backendStatus = data?.backend_status || {};
  $: debugInfo = data?.debug_info || {};
</script>

<div class="min-h-screen bg-gray-50 flex items-center justify-center p-4">
  <div class="max-w-6xl w-full bg-white rounded-lg shadow-md p-6">
    <h1 class="text-3xl font-bold text-center mb-8 text-gray-800">
      系统健康检查
    </h1>
    
    <!-- 状态概览 -->
    <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
      <div class="bg-white border border-gray-200 rounded-lg p-4">
        <h3 class="font-semibold text-gray-700 mb-2">系统状态</h3>
        <div class="flex items-center space-x-2">
          <span class="px-3 py-1 rounded-full text-sm font-medium {data?.status === 'healthy' ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'}">
            {data?.status || 'unknown'}
          </span>
        </div>
      </div>
      
      <div class="bg-white border border-gray-200 rounded-lg p-4">
        <h3 class="font-semibold text-gray-700 mb-2">检查时间</h3>
        <p class="text-sm text-gray-600">{data?.timestamp || 'N/A'}</p>
      </div>
      
      <div class="bg-white border border-gray-200 rounded-lg p-4">
        <h3 class="font-semibold text-gray-700 mb-2">运行模式</h3>
        <p class="text-sm text-gray-600">{buildInfo.mode || 'unknown'}</p>
      </div>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
      
      <!-- 环境变量检查 -->
      <div class="bg-gray-50 rounded-lg p-6">
        <h3 class="text-lg font-semibold text-gray-800 mb-4">🔧 环境变量检查</h3>
        <div class="space-y-3">
          {#each Object.entries(envCheck) as [key, value]}
            <div class="flex justify-between items-center py-2 border-b border-gray-200">
              <span class="font-medium text-gray-700">{key}:</span>
              <span class="text-sm px-2 py-1 rounded {
                value === 'configured' || value === '✓ Set' ? 'bg-green-100 text-green-700' :
                value === 'not_configured' || value === '✗ Missing' ? 'bg-red-100 text-red-700' :
                'bg-blue-100 text-blue-700'
              }">
                {value}
              </span>
            </div>
          {/each}
        </div>
      </div>

      <!-- 构建信息 -->
      <div class="bg-gray-50 rounded-lg p-6">
        <h3 class="text-lg font-semibold text-gray-800 mb-4">⚙️ 构建信息</h3>
        <div class="space-y-3">
          <div class="flex justify-between items-center py-2 border-b border-gray-200">
            <span class="font-medium text-gray-700">Mode:</span>
            <span class="text-sm text-gray-600">{buildInfo.mode || 'unknown'}</span>
          </div>
          <div class="flex justify-between items-center py-2 border-b border-gray-200">
            <span class="font-medium text-gray-700">Development:</span>
            <span class="text-sm text-gray-600">{buildInfo.development ? '是' : '否'}</span>
          </div>
          <div class="flex justify-between items-center py-2 border-b border-gray-200">
            <span class="font-medium text-gray-700">Production:</span>
            <span class="text-sm text-gray-600">{buildInfo.production ? '是' : '否'}</span>
          </div>
          <div class="flex justify-between items-center py-2 border-b border-gray-200">
            <span class="font-medium text-gray-700">SSR:</span>
            <span class="text-sm text-gray-600">{buildInfo.ssr ? '是' : '否'}</span>
          </div>
          {#if buildInfo.timestamp}
            <div class="flex justify-between items-center py-2">
              <span class="font-medium text-gray-700">Build Time:</span>
              <span class="text-xs text-gray-500">{buildInfo.timestamp}</span>
            </div>
          {/if}
        </div>
      </div>
    </div>

    <!-- 后端服务状态 -->
    {#if backendStatus.services}
      <div class="mt-8 bg-gray-50 rounded-lg p-6">
        <h3 class="text-lg font-semibold text-gray-800 mb-4">🔗 后端API服务状态</h3>
        
        <div class="mb-4 p-4 bg-white rounded border">
          <h4 class="font-medium text-gray-700 mb-2">API端点:</h4>
          <div class="space-y-2 text-sm">
            <div class="flex justify-between">
              <span>Health Check:</span>
              <a href="{backendStatus.health_check}" target="_blank" class="text-blue-600 hover:underline">
                {backendStatus.health_check}
              </a>
            </div>
            <div class="flex justify-between">
              <span>API Base:</span>
              <span class="text-gray-600">{backendStatus.api_endpoint}</span>
            </div>
          </div>
        </div>
        
        <div class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-4">
          {#each Object.entries(backendStatus.services) as [service, url]}
            <div class="bg-white rounded border p-3">
              <div class="flex justify-between items-center">
                <span class="font-medium text-gray-700 capitalize">{service}:</span>
                <a href="{url}" target="_blank" class="inline-flex items-center px-2 py-1 bg-blue-100 text-blue-700 text-xs rounded hover:bg-blue-200">
                  测试
                </a>
              </div>
            </div>
          {/each}
        </div>
      </div>
    {/if}

    <!-- 调试信息 -->
    {#if debugInfo.all_env_vars}
      <div class="mt-8 bg-yellow-50 rounded-lg p-6">
        <h3 class="text-lg font-semibold text-gray-800 mb-4">🐛 调试信息</h3>
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          {#each Object.entries(debugInfo.all_env_vars) as [key, value]}
            <div class="flex justify-between items-center py-2 px-3 bg-white rounded border">
              <span class="font-medium text-gray-700">{key}:</span>
              <span class="text-sm px-2 py-1 rounded {
                value.includes('✓') ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'
              }">
                {value}
              </span>
            </div>
          {/each}
        </div>
      </div>
    {/if}
      
    <!-- 错误信息 -->
    {#if data?.error}
      <div class="mt-8 bg-red-50 rounded-lg p-6">
        <h3 class="text-lg font-semibold text-red-800 mb-4">❌ 错误信息</h3>
        <pre class="text-sm text-red-700 bg-red-100 p-4 rounded whitespace-pre-wrap">{data.error}</pre>
      </div>
    {/if}
    
    <!-- 操作按钮 -->
    <div class="mt-8 flex flex-wrap justify-center gap-4">
      <a href="/login" class="inline-flex items-center px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors">
        返回登录页
      </a>
      <a href="{backendStatus?.health_check || 'http://107.172.87.113/api/health'}" target="_blank" class="inline-flex items-center px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors">
        后端健康检查
      </a>
      <button on:click={() => window.location.reload()} class="inline-flex items-center px-4 py-2 bg-gray-600 text-white rounded-lg hover:bg-gray-700 transition-colors">
        刷新检查
      </button>
    </div>
  </div>
</div> 