<script>
  import { onMount } from 'svelte';
  import { validateRoleAndRedirect, signOut, getSession } from '$lib/auth';
  import InviteLink from '$components/firstmate/InviteLink.svelte';
  import FortuneManagement from '$components/firstmate/FortuneManagement.svelte';
  import EcommerceManagement from '$components/firstmate/EcommerceManagement.svelte';
  import ChatManagement from '$components/firstmate/ChatManagement.svelte';

  let activeTab = 'invite';
  let loading = true;
  let user = null;
  let onlineStatus = true;
  let operationLogs = [];

  onMount(async () => {
    const isValid = await validateRoleAndRedirect('Firstmate');
    if (isValid) {
      user = await getSession();
      loadOperationLogs();
      loading = false;
    }
  });

  const tabs = [
    { id: 'invite', name: '邀请链接', icon: '🔗' },
    { id: 'fortune', name: '算命管理', icon: '🔮' },
    { id: 'ecommerce', name: '电商管理', icon: '🛍️' },
    { id: 'chat', name: '聊天管理', icon: '💬' }
  ];

  function setActiveTab(tabId) {
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

  async function loadOperationLogs() {
    try {
      const response = await fetch('/api/firstmate/operation-logs?limit=50');
      if (response.ok) {
        operationLogs = await response.json();
      }
    } catch (error) {
      console.error('加载操作日志失败:', error);
    }
  }

  function formatLogTime(timestamp) {
    return new Date(timestamp).toLocaleString('zh-CN');
  }

  function getLogTypeIcon(type) {
    const iconMap = {
      'invite_link': '🔗',
      'fortune_reply': '🔮',
      'ecommerce_key': '🛍️',
      'chat_management': '💬'
    };
    return iconMap[type] || '📝';
  }

  function getLogTypeText(type) {
    const textMap = {
      'invite_link': '生成邀请链接',
      'fortune_reply': '回复算命',
      'ecommerce_key': '电商操作',
      'chat_management': '聊天管理'
    };
    return textMap[type] || '其他操作';
  }
</script>

<svelte:head>
  <title>百刀会 - Firstmate 助理后台</title>
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
            <h1 class="text-xl font-semibold text-gray-900">百刀会 - 助理后台</h1>
            <div class="ml-3 flex items-center space-x-2">
              <span class="px-2 py-1 text-xs bg-orange-100 text-orange-800 rounded-full">Firstmate</span>
              <div class="px-2 py-1 text-xs bg-blue-100 text-blue-800 rounded-full flex items-center">
                <svg class="w-3 h-3 mr-1" fill="currentColor" viewBox="0 0 20 20">
                  <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd"></path>
                </svg>
                助理模式
              </div>
            </div>
          </div>
          
          <!-- 用户信息和状态 -->
          <div class="flex items-center space-x-4">
            <!-- 在线状态切换 -->
            <div class="flex items-center space-x-2">
              <span class="text-sm text-gray-600">在线状态:</span>
              <button
                on:click={toggleOnlineStatus}
                class="relative inline-flex h-6 w-11 items-center rounded-full transition-colors {onlineStatus ? 'bg-orange-600' : 'bg-gray-200'}"
              >
                <span class="inline-block h-4 w-4 transform rounded-full bg-white transition-transform {onlineStatus ? 'translate-x-6' : 'translate-x-1'}"></span>
              </button>
              <span class="text-sm {onlineStatus ? 'text-orange-600' : 'text-gray-500'}">
                {onlineStatus ? '在线' : '离线'}
              </span>
            </div>

            <!-- 用户头像和菜单 -->
            {#if user}
              <div class="relative group">
                <button class="flex items-center space-x-2 p-2 rounded-md hover:bg-gray-100">
                  <div class="w-8 h-8 bg-orange-500 rounded-full flex items-center justify-center text-white text-sm font-semibold">
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
                    助理权限说明
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

    <!-- 助理模式说明 -->
    <div class="bg-blue-50 border-b border-blue-200">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-2">
        <div class="flex items-center text-sm text-blue-800">
          <svg class="w-4 h-4 mr-2" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd"></path>
          </svg>
          您以助理身份协助处理，不可查看用户私信。所有操作将被记录供 Master 查看。
        </div>
      </div>
    </div>

    <!-- 标签导航 -->
    <div class="bg-white border-b">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex space-x-8">
          {#each tabs as tab}
            <button
              on:click={() => setActiveTab(tab.id)}
              class="flex items-center px-3 py-4 text-sm font-medium border-b-2 transition-colors {
                activeTab === tab.id 
                  ? 'text-orange-600 border-orange-600' 
                  : 'text-gray-500 border-transparent hover:text-gray-700 hover:border-gray-300'
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

    <!-- 主要内容区域 -->
    <main class="max-w-7xl mx-auto py-6 px-4 sm:px-6 lg:px-8">
      <div class="grid grid-cols-1 lg:grid-cols-4 gap-6">
        <!-- 主要功能区域 -->
        <div class="lg:col-span-3">
          {#if activeTab === 'invite'}
            <InviteLink />
          {:else if activeTab === 'fortune'}
            <FortuneManagement />
          {:else if activeTab === 'ecommerce'}
            <EcommerceManagement />
          {:else if activeTab === 'chat'}
            <ChatManagement />
          {/if}
        </div>

        <!-- 操作日志侧栏 -->
        <div class="lg:col-span-1">
          <div class="bg-white rounded-lg shadow p-4 sticky top-6">
            <div class="flex items-center justify-between mb-4">
              <h3 class="text-lg font-medium text-gray-900">操作日志</h3>
              <button
                on:click={loadOperationLogs}
                class="text-orange-600 hover:text-orange-800 text-sm"
              >
                🔄
              </button>
            </div>

            <div class="space-y-3 max-h-96 overflow-y-auto">
              {#if operationLogs.length === 0}
                <p class="text-sm text-gray-500 text-center py-4">暂无操作记录</p>
              {:else}
                {#each operationLogs as log}
                  <div class="border-l-2 border-orange-200 pl-3 pb-3">
                    <div class="flex items-start space-x-2">
                      <span class="text-sm">{getLogTypeIcon(log.type)}</span>
                      <div class="flex-1 min-w-0">
                        <p class="text-sm font-medium text-gray-900 truncate">
                          {getLogTypeText(log.type)}
                        </p>
                        <p class="text-xs text-gray-500 truncate">
                          {log.description}
                        </p>
                        <p class="text-xs text-gray-400">
                          {formatLogTime(log.timestamp)}
                        </p>
                      </div>
                    </div>
                  </div>
                {/each}
              {/if}
            </div>

            <div class="mt-4 pt-4 border-t border-gray-200">
              <p class="text-xs text-gray-500">
                显示最近 50 条操作记录
              </p>
            </div>
          </div>
        </div>
      </div>
    </main>
  </div>
{/if} 