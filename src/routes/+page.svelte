<script>
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { browser } from '$app/environment';

  onMount(() => {
    // 在客户端重定向到登录页面
    if (browser) {
      goto('/login');
    }
  });
</script>

<svelte:head>
  <title>百道会 - 专业的知识分享平台</title>
  <meta name="description" content="百道会是一个专业的知识分享平台，连接粉丝、会员、大师和卖家。" />
</svelte:head>

<div class="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 flex items-center justify-center">
  <div class="max-w-md w-full space-y-8 p-8">
    <div class="text-center">
      <h1 class="text-4xl font-bold text-gray-900 mb-4">
        欢迎来到百道会
      </h1>
      <p class="text-lg text-gray-600 mb-8">
        专业的知识分享平台
      </p>
      
      <div class="space-y-4">
        <a 
          href="/login" 
          class="w-full flex justify-center py-3 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 transition-colors"
        >
          立即登录
        </a>
        
        <div class="text-sm text-gray-500">
          正在重定向到登录页面...
        </div>
      </div>
    </div>
  </div>
</div>

<style>
  /* 确保页面在加载时有基本样式 */
  :global(body) {
    margin: 0;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  }
</style> 