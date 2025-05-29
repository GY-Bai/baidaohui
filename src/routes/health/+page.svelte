<script>
  export let data;
  
  // 确保数据存在
  $: envCheck = data?.env_check || {};
  $: buildInfo = data?.build_info || {};
  $: backendStatus = data?.backend_status || {};
  $: debugInfo = data?.debug_info || {};
  $: sanJoseVps = backendStatus?.san_jose_vps || {};
  $: buffaloVps = backendStatus?.buffalo_vps || {};
  
  // 获取服务状态图标和文本
  function getStatusDisplay(result) {
    if (!result) {
      return { icon: '🟡', text: '未知' };
    }
    
    const { status, error, http_status } = result;
    
    if (status === 'healthy') {
      return { 
        icon: '✅', 
        text: http_status ? `正常（HTTP ${http_status}）` : '正常'
      };
    } else if (status === 'timeout') {
      return { 
        icon: '🔴', 
        text: '异常（请求超时）'
      };
    } else if (status === 'error') {
      return { 
        icon: '🔴', 
        text: error ? `异常（${error}）` : '异常'
      };
    }
    
    return { icon: '🟡', text: '未知' };
  }
  
  // 强制刷新页面
  function forceRefresh() {
    window.location.reload();
  }
</script>

<!-- 版本信息用于强制刷新 -->
<svelte:head>
  <title>系统健康检查 v{buildInfo?.version || '2.1.0'}</title>
  <meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate">
  <meta http-equiv="Pragma" content="no-cache">
  <meta http-equiv="Expires" content="0">
  <meta name="cache-buster" content="{buildInfo?.cache_buster || Date.now()}">
</svelte:head>

<div class="min-h-screen bg-gray-50 py-8">
  <div class="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8">
    
    <!-- 页面标题 -->
    <div class="text-center mb-8">
      <h1 class="text-3xl font-bold text-gray-900 mb-2">
        系统健康检查面板
      </h1>
      <p class="text-gray-600">
        版本 {buildInfo?.version || '2.1.0'} • 
        最后更新: {buildInfo?.timestamp ? new Date(buildInfo.timestamp).toLocaleString('zh-CN') : '未知'}
      </p>
      <button 
        on:click={forceRefresh}
        class="mt-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors text-sm"
      >
        🔄 强制刷新
      </button>
    </div>

    {#if data?.error}
      <!-- 错误状态显示 -->
      <div class="bg-red-50 border-l-4 border-red-400 p-4 mb-6">
        <div class="flex">
          <div class="flex-shrink-0">
            <svg class="h-5 w-5 text-red-400" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"></path>
            </svg>
          </div>
          <div class="ml-3">
            <h3 class="text-sm font-medium text-red-800">系统检查异常</h3>
            <p class="mt-1 text-sm text-red-700">{data.error}: {data.message}</p>
          </div>
        </div>
      </div>
    {:else}
      
      <!-- 服务状态监控区 -->
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
        
        <!-- 圣何塞VPS服务状态 -->
        <div class="bg-white rounded-lg shadow-md p-6 border-l-4 border-blue-500">
          <h2 class="text-xl font-semibold text-gray-900 mb-4 flex items-center">
            <span class="w-3 h-3 bg-blue-500 rounded-full mr-3"></span>
            主要API服务
          </h2>
          
          <div class="space-y-2">
            {#each Object.entries(sanJoseVps) as [serviceName, result]}
              {@const status = getStatusDisplay(result)}
              <div class="flex items-center justify-between py-1">
                <span class="text-sm font-medium text-gray-700">{serviceName}</span>
                <span class="flex items-center text-sm">
                  <span class="mr-1">{status.icon}</span>
                  <span class={status.icon === '✅' ? 'text-green-600' : 'text-red-600'}>
                    {status.text}
                  </span>
                  {#if result?.response_time}
                    <span class="text-gray-500 ml-2 text-xs">
                      ({result.response_time}ms)
                    </span>
                  {/if}
                </span>
              </div>
            {/each}
          </div>
          
          {#if Object.keys(sanJoseVps).length === 0}
            <p class="text-gray-500 text-sm">无服务数据</p>
          {/if}
        </div>

        <!-- 水牛城VPS服务状态 -->
        <div class="bg-white rounded-lg shadow-md p-6 border-l-4 border-green-500">
          <h2 class="text-xl font-semibold text-gray-900 mb-4 flex items-center">
            <span class="w-3 h-3 bg-green-500 rounded-full mr-3"></span>
            专门服务
          </h2>
          
          <div class="space-y-2">
            {#each Object.entries(buffaloVps) as [serviceName, result]}
              {@const status = getStatusDisplay(result)}
              <div class="flex items-center justify-between py-1">
                <span class="text-sm font-medium text-gray-700">{serviceName}</span>
                <span class="flex items-center text-sm">
                  <span class="mr-1">{status.icon}</span>
                  <span class={status.icon === '✅' ? 'text-green-600' : 'text-red-600'}>
                    {status.text}
                  </span>
                  {#if result?.response_time}
                    <span class="text-gray-500 ml-2 text-xs">
                      ({result.response_time}ms)
                    </span>
                  {/if}
                </span>
              </div>
            {/each}
          </div>
          
          {#if Object.keys(buffaloVps).length === 0}
            <p class="text-gray-500 text-sm">无服务数据</p>
          {/if}
        </div>
      </div>

      <!-- 系统信息区 -->
      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        
        <!-- 环境变量检查 -->
        <div class="bg-white rounded-lg shadow-md p-6">
          <h3 class="text-lg font-semibold text-gray-900 mb-4">环境配置</h3>
          <div class="space-y-2">
            {#each Object.entries(envCheck) as [key, value]}
              <div class="flex justify-between items-center">
                <span class="text-sm text-gray-600">{key}:</span>
                <span class="text-sm font-medium {value === '已设置' || value === '已配置' ? 'text-green-600' : 'text-gray-500'}">
                  {value}
                </span>
              </div>
            {/each}
          </div>
        </div>

        <!-- 构建信息 -->
        <div class="bg-white rounded-lg shadow-md p-6">
          <h3 class="text-lg font-semibold text-gray-900 mb-4">构建信息</h3>
          <div class="space-y-2">
            <div class="flex justify-between">
              <span class="text-sm text-gray-600">版本:</span>
              <span class="text-sm font-medium text-green-600">{buildInfo?.version || '未知'}</span>
            </div>
            <div class="flex justify-between">
              <span class="text-sm text-gray-600">模式:</span>
              <span class="text-sm font-medium">{buildInfo?.mode || '未知'}</span>
            </div>
            <div class="flex justify-between">
              <span class="text-sm text-gray-600">生产环境:</span>
              <span class="text-sm font-medium">{buildInfo?.is_prod ? '是' : '否'}</span>
            </div>
            <div class="flex justify-between">
              <span class="text-sm text-gray-600">SSR:</span>
              <span class="text-sm font-medium">{buildInfo?.is_ssr ? '是' : '否'}</span>
            </div>
          </div>
        </div>

        <!-- 调试信息 -->
        <div class="bg-white rounded-lg shadow-md p-6">
          <h3 class="text-lg font-semibold text-gray-900 mb-4">系统信息</h3>
          <div class="space-y-2">
            <div class="flex justify-between">
              <span class="text-sm text-gray-600">用户代理:</span>
              <span class="text-sm font-medium">{debugInfo?.user_agent || '未知'}</span>
            </div>
            <div class="flex justify-between">
              <span class="text-sm text-gray-600">部署环境:</span>
              <span class="text-sm font-medium text-blue-600">{debugInfo?.deployment_env || '未知'}</span>
            </div>
            <div class="flex justify-between">
              <span class="text-sm text-gray-600">最后检查:</span>
              <span class="text-sm font-medium">
                {debugInfo?.last_check ? new Date(debugInfo.last_check).toLocaleTimeString('zh-CN') : '未知'}
              </span>
            </div>
          </div>
        </div>
      </div>
    {/if}
  </div>
</div> 