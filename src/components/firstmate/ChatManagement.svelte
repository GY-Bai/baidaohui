<!-- Firstmate的聊天管理组件，不能查看私信内容但可以管理群聊 -->
<script lang="ts">
  import { onMount } from 'svelte';

  let activeTab = 'group';
  let loading = true;
  let groupChatInfo = {
    name: '#general',
    memberCount: 0,
    lastMessage: null,
    isActive: true
  };
  let privateChatStats = {
    totalMembers: 0,
    activeChats: 0,
    expiringSoon: 0
  };

  onMount(() => {
    loadGroupChatInfo();
    loadPrivateChatStats();
  });

  async function loadGroupChatInfo() {
    try {
      const response = await fetch('/api/chat/group/general');
      if (response.ok) {
        groupChatInfo = await response.json();
      }
    } catch (error) {
      console.error('加载群聊信息失败:', error);
    }
  }

  async function loadPrivateChatStats() {
    try {
      loading = true;
      // 只获取统计数据，不获取具体的私聊成员信息
      const response = await fetch('/api/chat/private/stats?role=firstmate');
      if (response.ok) {
        privateChatStats = await response.json();
      }
    } catch (error) {
      console.error('加载私聊统计失败:', error);
    } finally {
      loading = false;
    }
  }

  function enterGroupChat() {
    window.open('/chat/group/general', '_blank');
  }

  function formatDate(dateString) {
    if (!dateString) return '永久';
    return new Date(dateString).toLocaleString('zh-CN');
  }
</script>

<div class="space-y-6">
  <div class="bg-white rounded-lg shadow p-6">
    <div class="flex items-center justify-between mb-6">
      <h2 class="text-2xl font-semibold text-gray-900">聊天管理</h2>
      <div class="flex items-center space-x-2">
        <span class="px-2 py-1 text-xs bg-orange-100 text-orange-800 rounded-full">助理权限</span>
      </div>
    </div>

    <!-- 标签切换 -->
    <div class="border-b border-gray-200 mb-6">
      <nav class="-mb-px flex space-x-8">
        <button
          on:click={() => activeTab = 'group'}
          class="py-2 px-1 border-b-2 font-medium text-sm {
            activeTab === 'group'
              ? 'border-orange-500 text-orange-600'
              : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
          }"
        >
          群聊管理
        </button>
        <button
          on:click={() => activeTab = 'private'}
          class="py-2 px-1 border-b-2 font-medium text-sm {
            activeTab === 'private'
              ? 'border-orange-500 text-orange-600'
              : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
          }"
        >
          私聊统计
        </button>
      </nav>
    </div>

    <!-- 群聊管理 -->
    {#if activeTab === 'group'}
      <div class="space-y-6">
        <div class="bg-gradient-to-r from-orange-50 to-yellow-50 rounded-lg p-6">
          <div class="flex items-center justify-between">
            <div>
              <h3 class="text-lg font-semibold text-gray-900 mb-2">
                {groupChatInfo.name} 群聊
              </h3>
              <div class="space-y-1 text-sm text-gray-600">
                <p>成员数量: {groupChatInfo.memberCount}</p>
                <p>状态: {groupChatInfo.isActive ? '活跃' : '非活跃'}</p>
                {#if groupChatInfo.lastMessage}
                  <p>最新消息: {formatDate(groupChatInfo.lastMessage.timestamp)}</p>
                {/if}
              </div>
            </div>
            <button
              on:click={enterGroupChat}
              class="px-4 py-2 bg-orange-600 text-white rounded-md hover:bg-orange-700 focus:outline-none focus:ring-2 focus:ring-orange-500"
            >
              进入群聊
            </button>
          </div>
        </div>

        <div class="bg-gray-50 rounded-lg p-4">
          <h4 class="font-medium text-gray-900 mb-3">助理权限说明</h4>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div class="flex items-center text-gray-700">
              <svg class="w-5 h-5 text-green-500 mr-2" fill="currentColor" viewBox="0 0 20 20">
                <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"></path>
              </svg>
              可参与群聊讨论
            </div>
            <div class="flex items-center text-gray-700">
              <svg class="w-5 h-5 text-green-500 mr-2" fill="currentColor" viewBox="0 0 20 20">
                <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"></path>
              </svg>
              协助管理群聊秩序
            </div>
            <div class="flex items-center text-gray-700">
              <svg class="w-5 h-5 text-green-500 mr-2" fill="currentColor" viewBox="0 0 20 20">
                <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"></path>
              </svg>
              查看消息历史记录
            </div>
            <div class="flex items-center text-gray-700">
              <svg class="w-5 h-5 text-red-500 mr-2" fill="currentColor" viewBox="0 0 20 20">
                <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd"></path>
              </svg>
              无法删除他人消息
            </div>
          </div>
        </div>
      </div>
    {/if}

    <!-- 私聊统计概览 -->
    {#if activeTab === 'private'}
      <div class="space-y-6">
        <!-- 权限说明 -->
        <div class="bg-red-50 border border-red-200 rounded-lg p-4">
          <div class="flex">
            <svg class="w-5 h-5 text-red-400 mr-2" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clip-rule="evenodd"></path>
            </svg>
            <div class="text-sm text-red-800">
              <p class="font-medium">隐私保护说明:</p>
              <p class="mt-1">作为助理，您无法查看、管理或进入任何用户的私信。此页面仅显示私聊权限的统计信息，不涉及具体聊天内容或成员信息。</p>
            </div>
          </div>
        </div>

        <div class="flex justify-between items-center">
          <div>
            <h3 class="text-lg font-semibold text-gray-900">私聊权限统计</h3>
            <p class="text-sm text-gray-600">仅显示统计数据，不包含任何用户信息或聊天内容</p>
          </div>
        </div>

        {#if loading}
          <div class="text-center py-8">
            <svg class="animate-spin h-8 w-8 text-orange-600 mx-auto mb-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
            <p class="text-gray-600">加载中...</p>
          </div>
        {:else}
          <!-- 统计信息卡片 -->
          <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
            <div class="bg-gradient-to-r from-blue-50 to-blue-100 rounded-lg p-6">
              <div class="flex items-center">
                <div class="p-2 bg-blue-500 rounded-lg">
                  <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197m13.5-9a2.5 2.5 0 11-5 0 2.5 2.5 0 015 0z"></path>
                  </svg>
                </div>
                <div class="ml-4">
                  <p class="text-sm font-medium text-blue-600">总 Member 数</p>
                  <p class="text-2xl font-bold text-blue-900">{privateChatStats.totalMembers}</p>
                </div>
              </div>
            </div>

            <div class="bg-gradient-to-r from-green-50 to-green-100 rounded-lg p-6">
              <div class="flex items-center">
                <div class="p-2 bg-green-500 rounded-lg">
                  <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"></path>
                  </svg>
                </div>
                <div class="ml-4">
                  <p class="text-sm font-medium text-green-600">已开启私聊</p>
                  <p class="text-2xl font-bold text-green-900">{privateChatStats.activeChats}</p>
                </div>
              </div>
            </div>

            <div class="bg-gradient-to-r from-yellow-50 to-yellow-100 rounded-lg p-6">
              <div class="flex items-center">
                <div class="p-2 bg-yellow-500 rounded-lg">
                  <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                  </svg>
                </div>
                <div class="ml-4">
                  <p class="text-sm font-medium text-yellow-600">即将过期</p>
                  <p class="text-2xl font-bold text-yellow-900">{privateChatStats.expiringSoon}</p>
                </div>
              </div>
            </div>
          </div>

          <!-- 权限限制说明 -->
          <div class="bg-gray-50 rounded-lg p-6">
            <h4 class="font-medium text-gray-900 mb-4">助理权限限制</h4>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div class="flex items-center text-gray-700">
                <svg class="w-5 h-5 text-red-500 mr-2" fill="currentColor" viewBox="0 0 20 20">
                  <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd"></path>
                </svg>
                无法查看私信内容
              </div>
              <div class="flex items-center text-gray-700">
                <svg class="w-5 h-5 text-red-500 mr-2" fill="currentColor" viewBox="0 0 20 20">
                  <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd"></path>
                </svg>
                无法进入私聊房间
              </div>
              <div class="flex items-center text-gray-700">
                <svg class="w-5 h-5 text-red-500 mr-2" fill="currentColor" viewBox="0 0 20 20">
                  <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd"></path>
                </svg>
                无法开启/关闭私聊权限
              </div>
              <div class="flex items-center text-gray-700">
                <svg class="w-5 h-5 text-red-500 mr-2" fill="currentColor" viewBox="0 0 20 20">
                  <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd"></path>
                </svg>
                无法查看用户个人信息
              </div>
            </div>
          </div>

          <!-- 提示信息 -->
          <div class="bg-blue-50 border border-blue-200 rounded-lg p-4">
            <div class="flex">
              <svg class="w-5 h-5 text-blue-400 mr-2" fill="currentColor" viewBox="0 0 20 20">
                <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd"></path>
              </svg>
              <div class="text-sm text-blue-800">
                <p class="font-medium">提示:</p>
                <p class="mt-1">如需管理私聊权限或查看具体聊天内容，请联系 Master 进行操作。助理角色仅能查看统计数据以协助了解平台使用情况。</p>
              </div>
            </div>
          </div>
        {/if}
      </div>
    {/if}
  </div>
</div> 