<script lang="ts">
  import { onMount } from 'svelte';
  import { createEventDispatcher } from 'svelte';
  
  const dispatch = createEventDispatcher();
  
  let iframeElement: HTMLIFrameElement;
  let loading: boolean = true;
  let error: string | null = null;
  let tokenExpired: boolean = false;
  let retryCount: number = 0;
  const maxRetries: number = 3;
  
  // SSO Token 管理
  let ssoToken: string | null = null;
  let tokenExpiresAt: Date | null = null;
  
  onMount(async () => {
    await initializeSSO();
  });
  
  async function initializeSSO() {
    try {
      loading = true;
      error = null;
      
      // 获取或刷新 SSO Token
      await refreshSSOToken();
      
      // 设置 iframe 源
      if (ssoToken) {
        const shopUrl = `https://buyer.shop.baiduohui.com?sso_token=${ssoToken}`;
        if (iframeElement) {
          iframeElement.src = shopUrl;
        }
      }
      
    } catch (err) {
      console.error('SSO 初始化失败:', err);
      error = '无法连接到商店，请稍后重试';
      loading = false;
    }
  }
  
  async function refreshSSOToken() {
    try {
      const supabaseToken = localStorage.getItem('supabase_token');
      if (!supabaseToken) {
        throw new Error('用户未登录');
      }
      
      const response = await fetch('/api/sso/presta-token', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${supabaseToken}`
        }
      });
      
      if (!response.ok) {
        if (response.status === 401) {
          tokenExpired = true;
          throw new Error('登录已过期');
        }
        throw new Error('获取商店访问权限失败');
      }
      
      const data = await response.json();
      ssoToken = data.token;
      tokenExpiresAt = new Date(data.expires_at);
      
      // 设置自动刷新
      scheduleTokenRefresh();
      
    } catch (err) {
      console.error('刷新 SSO Token 失败:', err);
      throw err;
    }
  }
  
  function scheduleTokenRefresh() {
    if (!tokenExpiresAt) return;
    
    const now = new Date();
    const expiresIn = tokenExpiresAt.getTime() - now.getTime();
    const refreshIn = Math.max(expiresIn - 5 * 60 * 1000, 60 * 1000); // 提前5分钟刷新，最少1分钟后
    
    setTimeout(async () => {
      try {
        await refreshSSOToken();
        // 通知 iframe 更新 token
        if (iframeElement && iframeElement.contentWindow) {
          iframeElement.contentWindow.postMessage({
            type: 'SSO_TOKEN_REFRESH',
            token: ssoToken
          }, 'https://buyer.shop.baiduohui.com');
        }
      } catch (err) {
        console.error('自动刷新 Token 失败:', err);
        // 如果自动刷新失败，显示手动刷新提示
        tokenExpired = true;
      }
    }, refreshIn);
  }
  
  function handleIframeLoad() {
    loading = false;
    error = null;
    retryCount = 0;
    
    // 监听来自 iframe 的消息
    window.addEventListener('message', handleIframeMessage);
  }
  
  function handleIframeError() {
    loading = false;
    retryCount++;
    
    if (retryCount < maxRetries) {
      error = `连接失败，正在重试... (${retryCount}/${maxRetries})`;
      setTimeout(() => {
        initializeSSO();
      }, 2000);
    } else {
      error = '无法连接到商店，请检查网络连接或稍后重试';
    }
  }
  
  function handleIframeMessage(event: MessageEvent) {
    // 只接受来自商店域名的消息
    if (event.origin !== 'https://buyer.shop.baiduohui.com') {
      return;
    }
    
    const { type, data } = event.data;
    
    switch (type) {
      case 'SSO_TOKEN_EXPIRED':
        tokenExpired = true;
        break;
        
      case 'SHOP_NAVIGATION':
        // 商店内导航事件
        dispatch('navigation', data);
        break;
        
      case 'SHOP_PURCHASE':
        // 购买事件
        dispatch('purchase', data);
        break;
        
      case 'SHOP_ERROR':
        error = data.message || '商店发生错误';
        break;
        
      default:
        break;
    }
  }
  
  async function handleRefresh() {
    tokenExpired = false;
    await initializeSSO();
  }
  
  function handleRetry() {
    retryCount = 0;
    initializeSSO();
  }
  
  // 清理事件监听器
  function cleanup() {
    window.removeEventListener('message', handleIframeMessage);
  }
  
  // 组件销毁时清理
  import { onDestroy } from 'svelte';
  onDestroy(cleanup);
</script>

<div class="relative w-full h-full min-h-[600px] bg-white rounded-lg shadow-sm overflow-hidden">
  {#if loading}
    <!-- 加载状态 -->
    <div class="absolute inset-0 flex items-center justify-center bg-gray-50">
      <div class="text-center">
        <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600 mb-4"></div>
        <p class="text-gray-600">正在加载商店...</p>
      </div>
    </div>
  {:else if error}
    <!-- 错误状态 -->
    <div class="absolute inset-0 flex items-center justify-center bg-gray-50">
      <div class="text-center max-w-md mx-auto p-6">
        <svg class="mx-auto h-12 w-12 text-red-400 mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z" />
        </svg>
        <h3 class="text-lg font-medium text-gray-900 mb-2">无法加载商店</h3>
        <p class="text-sm text-gray-600 mb-4">{error}</p>
        <button
          on:click={handleRetry}
          class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700"
        >
          重试
        </button>
      </div>
    </div>
  {:else if tokenExpired}
    <!-- Token 过期提示 -->
    <div class="absolute inset-0 flex items-center justify-center bg-gray-50">
      <div class="text-center max-w-md mx-auto p-6">
        <svg class="mx-auto h-12 w-12 text-yellow-400 mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z" />
        </svg>
        <h3 class="text-lg font-medium text-gray-900 mb-2">登录已过期</h3>
        <p class="text-sm text-gray-600 mb-4">您的登录状态已过期，请刷新页面重新登录</p>
        <div class="space-x-3">
          <button
            on:click={handleRefresh}
            class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700"
          >
            刷新
          </button>
          <button
            on:click={() => window.location.reload()}
            class="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50"
          >
            重新加载页面
          </button>
        </div>
      </div>
    </div>
  {:else}
    <!-- 商店 iframe -->
    <iframe
      bind:this={iframeElement}
      title="百刀会商店"
      class="w-full h-full border-0"
      sandbox="allow-same-origin allow-scripts allow-forms allow-popups allow-popups-to-escape-sandbox"
      on:load={handleIframeLoad}
      on:error={handleIframeError}
    ></iframe>
  {/if}
  
  <!-- 调试信息 (仅开发环境) -->
  {#if process.env.NODE_ENV === 'development'}
    <div class="absolute top-2 right-2 bg-black bg-opacity-75 text-white text-xs p-2 rounded">
      <div>Token: {ssoToken ? '已获取' : '未获取'}</div>
      <div>过期时间: {tokenExpiresAt ? tokenExpiresAt.toLocaleTimeString() : '未知'}</div>
      <div>重试次数: {retryCount}</div>
    </div>
  {/if}
</div>

<style>
  /* 确保 iframe 完全填充容器 */
  iframe {
    width: 100%;
    height: 100%;
    min-height: 600px;
  }
  
  /* 响应式调整 */
  @media (max-width: 768px) {
    iframe {
      min-height: 500px;
    }
  }
</style> 