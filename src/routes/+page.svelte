<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';

  // 客户端直接重定向，不做任何API调用
  onMount(() => {
    goto('/login');
  });
</script>

<svelte:head>
  <title>百刀会 - 专业的知识分享平台</title>
  <meta name="description" content="百刀会是一个专业的知识分享平台，连接粉丝、会员、大师和卖家。" />
</svelte:head>

<div class="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 flex items-center justify-center">
  <div class="max-w-md w-full space-y-8 p-8 text-center">
    <h1 class="text-4xl font-bold text-gray-900 mb-4">
      欢迎来到百刀会
    </h1>
    <p class="text-lg text-gray-600 mb-8">
      正在重定向到登录页面...
    </p>
    
    <div class="mb-4">
      <svg class="animate-spin h-8 w-8 text-blue-600 mx-auto" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
      </svg>
    </div>
    
    <a 
      href="/login" 
      class="inline-flex justify-center py-3 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 transition-colors"
    >
      点击这里立即登录
    </a>
  </div>
</div>

<style>
  /* 确保页面在加载时有基本样式 */
  :global(body) {
    margin: 0;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  }
</style> 