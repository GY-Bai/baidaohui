<script>
  export let data;
</script>

<div class="min-h-screen bg-gray-50 flex items-center justify-center">
  <div class="max-w-2xl w-full bg-white rounded-lg shadow-md p-6">
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
              <span>VITE_APP_URL:</span>
              <span class="text-gray-600 {data.env_check.VITE_APP_URL !== '未配置' ? 'text-green-600' : 'text-red-600'}">
                {data.env_check.VITE_APP_URL}
              </span>
            </div>
            <div class="flex justify-between">
              <span>NODE_ENV:</span>
              <span class="text-gray-600">{data.env_check.NODE_ENV}</span>
            </div>
          </div>
        </div>
      {/if}

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