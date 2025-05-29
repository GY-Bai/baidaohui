<script lang="ts">
  import { onMount } from 'svelte';
  import { clientSideRouteGuard, signOut } from '$lib/auth';
  import Chat from '$components/fan/Chat.svelte';
  import Fortune from '$components/fan/Fortune.svelte';
  import Ecommerce from '$components/fan/Ecommerce.svelte';
  import Profile from '$components/fan/Profile.svelte';

  let loading = true;
  let authenticated = false;

  onMount(async () => {
    // 使用客户端路由守卫
    authenticated = await clientSideRouteGuard('Fan');
    loading = false;
  });

  async function handleSignOut() {
    await signOut();
  }

  let activeTab = 'chat';

  const tabs = [
    { id: 'chat', name: '私信', icon: '💬' },
    { id: 'fortune', name: '算命', icon: '🔮' },
    { id: 'ecommerce', name: '带货', icon: '🛍️' },
    { id: 'profile', name: '个人', icon: '👤' }
  ];

  function setActiveTab(tabId) {
    activeTab = tabId;
  }
</script>

<svelte:head>
  <title>粉丝专区 - 百刀会</title>
</svelte:head>

{#if loading}
  <div class="min-h-screen flex items-center justify-center">
    <div class="text-center">
      <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto mb-4"></div>
      <p class="text-gray-600">正在验证身份...</p>
    </div>
  </div>
{:else if authenticated}
  <div class="min-h-screen bg-gradient-to-br from-purple-50 to-pink-100">
    <nav class="bg-white shadow-sm border-b">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex justify-between h-16">
          <div class="flex items-center">
            <h1 class="text-xl font-semibold text-gray-900">百刀会 - 粉丝专区</h1>
          </div>
          <div class="flex items-center space-x-4">
            <button
              on:click={handleSignOut}
              class="bg-red-600 hover:bg-red-700 text-white px-4 py-2 rounded-md text-sm font-medium transition-colors"
            >
              退出登录
            </button>
          </div>
        </div>
      </div>
    </nav>

    <main class="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
      <div class="px-4 py-6 sm:px-0">
        <div class="border-4 border-dashed border-gray-200 rounded-lg p-8 text-center">
          <div class="mb-6">
            <h2 class="text-3xl font-bold text-gray-900 mb-2">🌟 欢迎来到粉丝专区！</h2>
            <p class="text-lg text-gray-600">这里是专属于粉丝的特殊空间</p>
          </div>
          
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 mt-8">
            <div class="bg-white p-6 rounded-lg shadow-md">
              <div class="text-purple-600 text-4xl mb-4">💬</div>
              <h3 class="text-xl font-semibold mb-2">教主悄悄话</h3>
              <p class="text-gray-600">获取教主的独家分享和内幕消息</p>
            </div>
            
            <div class="bg-white p-6 rounded-lg shadow-md">
              <div class="text-pink-600 text-4xl mb-4">🔮</div>
              <h3 class="text-xl font-semibold mb-2">算命申请</h3>
              <p class="text-gray-600">申请教主为您进行专业算命服务</p>
            </div>
            
            <div class="bg-white p-6 rounded-lg shadow-md">
              <div class="text-blue-600 text-4xl mb-4">🛍️</div>
              <h3 class="text-xl font-semibold mb-2">好物推荐</h3>
              <p class="text-gray-600">发现教主推荐的优质商品</p>
            </div>
          </div>
          
          <div class="mt-8 p-4 bg-purple-100 rounded-lg">
            <p class="text-purple-800">
              <strong>粉丝特权：</strong>享受基础内容访问权限，参与社区讨论，获取定期更新
            </p>
          </div>
        </div>
      </div>
    </main>
  </div>
{/if} 