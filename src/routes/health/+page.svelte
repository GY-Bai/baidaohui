<script>
  export let data;
</script>

<div class="min-h-screen bg-gray-50 flex items-center justify-center">
  <div class="max-w-md w-full bg-white rounded-lg shadow-md p-6">
    <h1 class="text-2xl font-bold text-center mb-4">
      系统健康检查
    </h1>
    
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
      
      {#if data.env_check}
        <div class="border-t pt-3">
          <h3 class="font-medium mb-2">环境变量检查:</h3>
          <div class="space-y-1 text-sm">
            <div class="flex justify-between">
              <span>SSO_SERVICE_URL:</span>
              <span class="text-gray-600 break-all">{data.env_check.SSO_SERVICE_URL}</span>
            </div>
            <div class="flex justify-between">
              <span>NODE_ENV:</span>
              <span class="text-gray-600">{data.env_check.NODE_ENV}</span>
            </div>
          </div>
        </div>
      {/if}
      
      {#if data.error}
        <div class="border-t pt-3">
          <h3 class="font-medium text-red-600 mb-2">错误信息:</h3>
          <pre class="text-sm text-red-600 bg-red-50 p-2 rounded">{data.error}</pre>
        </div>
      {/if}
    </div>
    
    <div class="mt-6 text-center">
      <a href="/login" class="text-blue-600 hover:text-blue-800 underline">
        返回登录页
      </a>
    </div>
  </div>
</div> 