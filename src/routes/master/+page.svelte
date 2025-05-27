<script lang="ts">
  import { onMount } from 'svelte';
  import { validateRoleAndRedirect, signOut, getSession } from '$lib/auth';
  import InviteLink from '$components/master/InviteLink.svelte';
  import FortuneManagement from '$components/master/FortuneManagement.svelte';
  import EcommerceManagement from '$components/master/EcommerceManagement.svelte';
  import ChatManagement from '$components/master/ChatManagement.svelte';
  import type { UserSession } from '$lib/auth';

  let activeTab = 'invite';
  let loading = true;
  let user: UserSession | null = null;
  let onlineStatus = true;

  onMount(async () => {
    const isValid = await validateRoleAndRedirect('Master');
    if (isValid) {
      user = await getSession();
      loading = false;
    }
  });

  const tabs = [
    { id: 'invite', name: '邀请链接', icon: '🔗' },
    { id: 'fortune', name: '算命管理', icon: '🔮' },
    { id: 'ecommerce', name: '电商管理', icon: '🛍️' },
    { id: 'chat', name: '聊天管理', icon: '💬' }
  ];

  function setActiveTab(tabId: string) {
    activeTab = tabId;
  }

  async function handleSignOut() {
    if (confirm('确定要退出登录吗？')) {
      try {
        await signOut();
      } catch (error) {
        console.error('退出登录失败:', error);
        alert('退出登录失败，请重试');
      }
    }
  }

  function toggleOnlineStatus() {
    onlineStatus = !onlineStatus;
    // 这里应该调用API更新在线状态
  }
</script>

<svelte:head>
  <title>百道会 - Master 后台</title>
</svelte:head>

{#if loading}
  <div class="min-h-screen flex items-center justify-center">
    <div class="text-center">
      <svg class="animate-spin h-8 w-8 text-blue-600 mx-auto mb-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 714 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
      </svg>
      <p class="text-gray-600">加载中...</p>
    </div>
  </div>
{:else}
  <div class="min-h-screen bg-gray-50">
    <!-- 顶部导航栏 -->
    <nav class="bg-white shadow-sm border-b">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex justify-between h-16">
          <div class="flex items-center">
            <h1 class="text-xl font-semibold text-gray-900">百道会 - 后台管理</h1>
            <span class="ml-2 px-2 py-1 text-xs bg-purple-100 text-purple-800 rounded-full">Master</span>
          </div>
          
          <!-- 用户信息和状态 -->
          <div class="flex items-center space-x-4">
            <!-- 在线状态切换 -->
            <div class="flex items-center space-x-2">
              <span class="text-sm text-gray-600">在线状态:</span>
              <button
                on:click={toggleOnlineStatus}
                class="relative inline-flex h-6 w-11 items-center rounded-full transition-colors {onlineStatus ? 'bg-green-600' : 'bg-gray-200'}"
              >
                <span class="inline-block h-4 w-4 transform rounded-full bg-white transition-transform {onlineStatus ? 'translate-x-6' : 'translate-x-1'}"></span>
              </button>
              <span class="text-sm {onlineStatus ? 'text-green-600' : 'text-gray-500'}">
                {onlineStatus ? '在线' : '离线'}
              </span>
            </div>

            <!-- 用户头像和菜单 -->
            {#if user}
              <div class="relative group">
                <button class="flex items-center space-x-2 p-2 rounded-md hover:bg-gray-100">
                  <div class="w-8 h-8 bg-purple-500 rounded-full flex items-center justify-center text-white text-sm font-semibold">
                    {user.user.email.charAt(0).toUpperCase()}
                  </div>
                  <span class="text-sm text-gray-700">{user.user.email}</span>
                  <svg class="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"></path>
                  </svg>
                </button>
                
                <!-- 下拉菜单 -->
                <div class="absolute right-0 mt-2 w-48 bg-white rounded-md shadow-lg py-1 z-50 opacity-0 invisible group-hover:opacity-100 group-hover:visible transition-all">
                  <button class="block w-full text-left px-4 py-2 text-sm text-gray-700 hover:bg-gray-100">
                    个人设置
                  </button>
                  <button class="block w-full text-left px-4 py-2 text-sm text-gray-700 hover:bg-gray-100">
                    系统设置
                  </button>
                  <hr class="my-1">
                  <button 
                    on:click={handleSignOut}
                    class="block w-full text-left px-4 py-2 text-sm text-red-600 hover:bg-gray-100"
                  >
                    退出登录
                  </button>
                </div>
              </div>
            {/if}
          </div>
        </div>
      </div>
    </nav>

    <!-- 标签导航 -->
    <div class="bg-white border-b">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex space-x-8">
          {#each tabs as tab}
            <button
              on:click={() => setActiveTab(tab.id)}
              class="flex items-center px-3 py-4 text-sm font-medium border-b-2 transition-colors {
                activeTab === tab.id 
                  ? 'text-purple-600 border-purple-600' 
                  : 'text-gray-500 border-transparent hover:text-gray-700 hover:border-gray-300'
              }"
            >
              <span class="mr-2">{tab.icon}</span>
              {tab.name}
            </button>
          {/each}
        </div>
      </div>
    </div>

    <!-- 主要内容区域 -->
    <main class="max-w-7xl mx-auto py-6 px-4 sm:px-6 lg:px-8">
      {#if activeTab === 'invite'}
        <InviteLink />
      {:else if activeTab === 'fortune'}
        <FortuneManagement />
      {:else if activeTab === 'ecommerce'}
        <EcommerceManagement />
      {:else if activeTab === 'chat'}
        <ChatManagement />
      {/if}
    </main>
  </div>
{/if} 