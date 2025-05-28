<script>
  import { signOut } from '$lib/auth';
  import InviteLink from '$components/master/InviteLink.svelte';
  import FortuneManagement from '$components/master/FortuneManagement.svelte';
  import EcommerceManagement from '$components/master/EcommerceManagement.svelte';
  import ChatManagement from '$components/master/ChatManagement.svelte';
  import Profile from '$components/master/Profile.svelte';

  export let data;
  
  let activeTab = 'invite';

  const tabs = [
    { id: 'invite', name: '邀请链接', icon: '🔗' },
    { id: 'fortune', name: '算命管理', icon: '🔮' },
    { id: 'ecommerce', name: '电商管理', icon: '🛍️' },
    { id: 'chat', name: '聊天管理', icon: '💬' },
    { id: 'profile', name: '个人资料', icon: '👤' }
  ];

  function setActiveTab(tabId) {
    activeTab = tabId;
  }

  async function handleSignOut() {
    if (confirm('确定要退出登录吗？')) {
      await signOut();
    }
  }
</script>

<svelte:head>
  <title>百道会 - Master 管理后台</title>
</svelte:head>

<div class="min-h-screen bg-gray-50">
  <!-- 顶部导航栏 -->
  <nav class="bg-white shadow-sm border-b">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <div class="flex justify-between h-16">
        <div class="flex items-center">
          <h1 class="text-xl font-semibold text-gray-900">百道会管理后台</h1>
          <span class="ml-2 px-2 py-1 text-xs bg-purple-100 text-purple-800 rounded-full">Master</span>
        </div>
        
        <!-- 用户信息和导航 -->
        <div class="flex items-center space-x-4">
          <!-- 在线状态 -->
          <div class="flex items-center space-x-2">
            <span class="inline-block w-2 h-2 bg-green-500 rounded-full"></span>
            <span class="text-sm text-gray-600">在线</span>
          </div>
          
          <!-- 用户头像和信息 -->
          <div class="flex items-center space-x-3">
            <div class="w-8 h-8 bg-purple-500 rounded-full flex items-center justify-center text-white font-semibold text-sm">
              {data.session.user.nickname?.charAt(0) || data.session.user.email.charAt(0).toUpperCase()}
            </div>
            <div class="hidden md:block">
              <p class="text-sm font-medium text-gray-900">{data.session.user.nickname || '管理员'}</p>
              <p class="text-xs text-gray-500">{data.session.user.email}</p>
            </div>
          </div>
          
          <!-- 退出按钮 -->
          <button
            on:click={handleSignOut}
            class="text-gray-400 hover:text-gray-600 text-sm transition-colors"
          >
            退出
          </button>
        </div>
      </div>
      
      <!-- 标签导航 -->
      <div class="border-t">
        <nav class="flex space-x-8 px-4 sm:px-6 lg:px-8">
          {#each tabs as tab}
            <button
              on:click={() => setActiveTab(tab.id)}
              class="py-4 px-1 border-b-2 font-medium text-sm transition-colors
                {activeTab === tab.id 
                  ? 'border-purple-500 text-purple-600' 
                  : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'}"
            >
              <span class="mr-2">{tab.icon}</span>
              {tab.name}
            </button>
          {/each}
        </nav>
      </div>
    </div>
  </nav>

  <!-- 主要内容区域 -->
  <main class="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
    <div class="px-4 py-6 sm:px-0">
      {#if activeTab === 'invite'}
        <InviteLink {data} />
      {:else if activeTab === 'fortune'}
        <FortuneManagement {data} />
      {:else if activeTab === 'ecommerce'}
        <EcommerceManagement {data} />
      {:else if activeTab === 'chat'}
        <ChatManagement {data} />
      {:else if activeTab === 'profile'}
        <Profile session={data.session} />
      {/if}
    </div>
  </main>
</div> 