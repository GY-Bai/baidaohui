<script lang="ts">
  import { onMount } from 'svelte';
  import { signInWithGoogle, getSession, redirectToRoleDomain } from '$lib/auth';
  import type { UserRole } from '$lib/auth';

  let loading = false;
  let error = '';

  onMount(async () => {
    // 检查是否已经登录
    const session = await getSession();
    if (session) {
      redirectToRoleDomain(session.user.role);
    }
  });

  async function handleGoogleLogin() {
    try {
      loading = true;
      error = '';
      await signInWithGoogle();
    } catch (err) {
      error = '登录失败，请重试';
      console.error(err);
    } finally {
      loading = false;
    }
  }
</script>

<svelte:head>
  <title>百道会 - 登录</title>
</svelte:head>

<div class="min-h-screen flex items-center justify-center bg-gradient-to-br from-blue-50 to-indigo-100">
  <div class="max-w-md w-full space-y-8 p-8">
    <div class="text-center">
      <h1 class="text-4xl font-bold text-gray-900 mb-2">百道会</h1>
      <p class="text-gray-600">聊天 · 电商 · 算命</p>
    </div>

    <div class="bg-white rounded-lg shadow-lg p-8">
      <div class="text-center mb-6">
        <h2 class="text-2xl font-semibold text-gray-900 mb-2">欢迎回来</h2>
        <p class="text-gray-600">使用 Google 账号一键登录</p>
      </div>

      {#if error}
        <div class="mb-4 p-3 bg-red-100 border border-red-400 text-red-700 rounded">
          {error}
        </div>
      {/if}

      <button
        on:click={handleGoogleLogin}
        disabled={loading}
        class="w-full flex items-center justify-center px-4 py-3 border border-transparent text-base font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
      >
        {#if loading}
          <svg class="animate-spin -ml-1 mr-3 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
          </svg>
          登录中...
        {:else}
          <svg class="w-5 h-5 mr-2" viewBox="0 0 24 24">
            <path fill="currentColor" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/>
            <path fill="currentColor" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>
            <path fill="currentColor" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"/>
            <path fill="currentColor" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"/>
          </svg>
          使用 Google 登录
        {/if}
      </button>

      <div class="mt-6 text-center">
        <p class="text-sm text-gray-500">
          登录即表示您同意我们的
          <a href="/terms" class="text-blue-600 hover:text-blue-500">服务条款</a>
          和
          <a href="/privacy" class="text-blue-600 hover:text-blue-500">隐私政策</a>
        </p>
      </div>
    </div>

    <div class="text-center">
      <p class="text-sm text-gray-500">
        首次登录将自动创建账户
      </p>
    </div>
  </div>
</div> 