<script>
  import Chat from '$components/member/Chat.svelte';
  import Fortune from '$components/member/Fortune.svelte';
  import Ecommerce from '$components/member/Ecommerce.svelte';
  import Profile from '$components/member/Profile.svelte';

  export let data;
  
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
  <title>百刀会 - Member</title>
</svelte:head>

<div class="min-h-screen bg-gray-50">
  <!-- 顶部导航栏 -->
  <nav class="bg-white shadow-sm border-b">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <div class="flex justify-between h-16">
        <div class="flex items-center">
          <h1 class="text-xl font-semibold text-gray-900">百刀会</h1>
          <span class="ml-2 px-2 py-1 text-xs bg-green-100 text-green-800 rounded-full">Member</span>
        </div>
        
        <!-- 用户信息 -->
        <div class="flex items-center space-x-4">
          <span class="text-sm text-gray-600">欢迎，{data.session.user.email}</span>
          
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
                aria-label="切换到{tab.name}标签"
                aria-current={activeTab === tab.id ? 'page' : undefined}
              >
                <span class="mr-2">{tab.icon}</span>
                {tab.name}
              </button>
            {/each}
          </div>
        </div>
      </div>
    </div>
  </nav>

  <!-- 主要内容区域 -->
  <main class="max-w-7xl mx-auto py-6 px-4 sm:px-6 lg:px-8">
    {#if activeTab === 'chat'}
      <Chat session={data.session} />
    {:else if activeTab === 'fortune'}
      <Fortune session={data.session} />
    {:else if activeTab === 'ecommerce'}
      <Ecommerce session={data.session} />
    {:else if activeTab === 'profile'}
      <Profile session={data.session} />
    {/if}
  </main>
</div> 