<script>
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { getSession, redirectToRoleDomain } from '$lib/auth';

  let loading = true;
  let error = '';

  onMount(async () => {
    try {
      // 等待认证完成
      await new Promise(resolve => setTimeout(resolve, 1000));
      
      const session = await getSession();
      if (session) {
        redirectToRoleDomain(session.user.role);
      } else {
        error = '登录失败，请重试';
        setTimeout(() => {
          goto('/login');
        }, 2000);
      }
    } catch (err) {
      error = '登录过程中出现错误';
      console.error(err);
      setTimeout(() => {
        goto('/login');
      }, 2000);
    } finally {
      loading = false;
    }
  });
</script>

<svelte:head>
  <title>登录中... - 百道会</title>
</svelte:head>

<div class="min-h-screen flex items-center justify-center bg-gradient-to-br from-blue-50 to-indigo-100">
  <div class="text-center">
    {#if loading}
      <div class="mb-4">
        <svg class="animate-spin h-12 w-12 text-blue-600 mx-auto" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
      </div>
      <h2 class="text-2xl font-semibold text-gray-900 mb-2">正在登录...</h2>
      <p class="text-gray-600">请稍候，正在验证您的身份</p>
    {:else if error}
      <div class="mb-4">
        <svg class="h-12 w-12 text-red-600 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z"></path>
        </svg>
      </div>
      <h2 class="text-2xl font-semibold text-red-900 mb-2">登录失败</h2>
      <p class="text-red-600 mb-4">{error}</p>
      <p class="text-gray-600">正在返回登录页面...</p>
    {/if}
  </div>
</div> 