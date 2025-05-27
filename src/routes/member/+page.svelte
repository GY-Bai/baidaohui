<script lang="ts">
  import { onMount } from 'svelte';
  import { validateRoleAndRedirect } from '$lib/auth';
  import Chat from '$components/member/Chat.svelte';
  import Fortune from '$components/member/Fortune.svelte';
  import Ecommerce from '$components/member/Ecommerce.svelte';
  import Profile from '$components/member/Profile.svelte';

  let activeTab = 'chat';
  let loading = true;

  onMount(async () => {
    const isValid = await validateRoleAndRedirect('Member');
    if (isValid) {
      loading = false;
    }
  });

  const tabs = [
    { id: 'chat', name: '私信', icon: '💬' },
    { id: 'fortune', name: '算命', icon: '🔮' },
    { id: 'ecommerce', name: '带货', icon: '🛍️' },
    { id: 'profile', name: '个人', icon: '👤' }
  ];

  function setActiveTab(tabId: string) {
    activeTab = tabId;
  }
</script>

<svelte:head>
  <title>百道会 - Member</title>
</svelte:head>

{#if loading}
  <div class="min-h-screen flex items-center justify-center">
    <div class="text-center">
      <svg class="animate-spin h-8 w-8 text-blue-600 mx-auto mb-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
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
            <h1 class="text-xl font-semibold text-gray-900">百道会</h1>
            <span class="ml-2 px-2 py-1 text-xs bg-green-100 text-green-800 rounded-full">Member</span>
          </div>
          
          <!-- 标签导航 -->
          <div class="flex space-x-8">
            {#each tabs as tab}
              <button
                on:click={() => setActiveTab(tab.id)}
                class="flex items-center px-3 py-2 text-sm font-medium rounded-md transition-colors {
                  activeTab === tab.id 
                    ? 'text-green-600 bg-green-50' 
                    : 'text-gray-500 hover:text-gray-700 hover:bg-gray-50'
                }"
              >
                <span class="mr-2">{tab.icon}</span>
                {tab.name}
              </button>
            {/each}
          </div>
        </div>
      </div>
    </nav>

    <!-- 主要内容区域 -->
    <main class="max-w-7xl mx-auto py-6 px-4 sm:px-6 lg:px-8">
      {#if activeTab === 'chat'}
        <Chat />
      {:else if activeTab === 'fortune'}
        <Fortune />
      {:else if activeTab === 'ecommerce'}
        <Ecommerce />
      {:else if activeTab === 'profile'}
        <Profile />
      {/if}
    </main>
  </div>
{/if} 