<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { browser } from '$app/environment';
  import { getSession } from '$lib/auth';

  let loading = true;
  let showRoleSelection = false;

  onMount(async () => {
    // 检查用户认证状态
    try {
      const user = await getSession();
      if (user) {
        // 用户已认证，重定向到对应角色页面
        const rolePaths: Record<string, string> = {
          Fan: '/fan',
          Member: '/member',
          Master: '/master',
          Firstmate: '/firstmate',
          Seller: '/seller'
        };
        
        const targetPath = rolePaths[user.role];
        if (targetPath) {
          goto(targetPath);
        } else {
          // 未知角色，显示角色选择
          showRoleSelection = true;
        }
      } else {
        // 用户未认证，重定向到登录页
        goto('/login');
      }
    } catch (error) {
      console.error('检查认证状态失败:', error);
      goto('/login');
    } finally {
      loading = false;
    }
  });
</script>

<svelte:head>
  <title>百刀会 - 专业的知识分享平台</title>
  <meta name="description" content="百刀会是一个专业的知识分享平台，连接粉丝、会员、大师和卖家。" />
</svelte:head>

<div class="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 flex items-center justify-center">
  <div class="max-w-md w-full space-y-8 p-8">
    {#if loading}
      <div class="text-center">
        <div class="mb-4">
          <svg class="animate-spin h-12 w-12 text-blue-600 mx-auto" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
          </svg>
        </div>
        <p class="text-lg text-gray-600">正在检查认证状态...</p>
      </div>
    {:else if showRoleSelection}
      <div class="text-center">
        <h1 class="text-4xl font-bold text-gray-900 mb-4">
          选择您的角色
        </h1>
        <p class="text-lg text-gray-600 mb-8">
          请选择您要访问的角色页面
        </p>
        
        <div class="space-y-4">
          <a 
            href="/fan" 
            class="w-full flex justify-center py-3 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 transition-colors"
          >
            Fan
          </a>
          <a 
            href="/member" 
            class="w-full flex justify-center py-3 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-green-600 hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500 transition-colors"
          >
            Member
          </a>
          <a 
            href="/master" 
            class="w-full flex justify-center py-3 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-purple-600 hover:bg-purple-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-purple-500 transition-colors"
          >
            Master
          </a>
          <a 
            href="/firstmate" 
            class="w-full flex justify-center py-3 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-orange-600 hover:bg-orange-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-orange-500 transition-colors"
          >
            Firstmate
          </a>
          <a 
            href="/seller" 
            class="w-full flex justify-center py-3 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-red-600 hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500 transition-colors"
          >
            Seller
          </a>
        </div>
      </div>
    {:else}
      <div class="text-center">
        <h1 class="text-4xl font-bold text-gray-900 mb-4">
          欢迎来到百刀会
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
    {/if}
  </div>
</div>

<style>
  /* 确保页面在加载时有基本样式 */
  :global(body) {
    margin: 0;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  }
</style> 