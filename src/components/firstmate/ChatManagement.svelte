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
  let privateChatMembers = [];

  onMount(() => {
    loadGroupChatInfo();
    loadPrivateChatMembers();
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

  async function loadPrivateChatMembers() {
    try {
      loading = true;
      const response = await fetch('/api/chat/private/members?role=firstmate');
      if (response.ok) {
        privateChatMembers = await response.json();
      }
    } catch (error) {
      console.error('加载私聊成员失败:', error);
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

  function getRemainingDays(expiresAt) {
    if (!expiresAt) return '永久';
    
    const now = new Date();
    const expires = new Date(expiresAt);
    const diff = expires.getTime() - now.getTime();
    const days = Math.ceil(diff / (1000 * 60 * 60 * 24));
    
    if (days <= 0) return '已过期';
    if (days === 1) return '今天到期';
    return `${days}天`;
  }

  function getRemainingDaysColor(expiresAt) {
    if (!expiresAt) return 'text-green-600';
    
    const now = new Date();
    const expires = new Date(expiresAt);
    const diff = expires.getTime() - now.getTime();
    const days = Math.ceil(diff / (1000 * 60 * 60 * 24));
    
    if (days <= 0) return 'text-red-600';
    if (days <= 1) return 'text-red-600';
    if (days <= 3) return 'text-yellow-600';
    return 'text-green-600';
  }

  function getStatusText(member) {
    if (!member.privateChatEnabled) return '未开启';
    if (member.privateChatExpiresAt) {
      const now = new Date();
      const expires = new Date(member.privateChatExpiresAt);
      if (expires <= now) return '已过期';
    }
    return '已开启';
  }

  function getStatusColor(member) {
    if (!member.privateChatEnabled) return 'text-gray-600 bg-gray-100';
    if (member.privateChatExpiresAt) {
      const now = new Date();
      const expires = new Date(member.privateChatExpiresAt);
      if (expires <= now) return 'text-red-600 bg-red-100';
    }
    return 'text-green-600 bg-green-100';
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
          私聊概览
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

    <!-- 私聊概览 -->
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
              <p class="mt-1">作为助理，您无法查看或管理用户的私信内容。此页面仅显示私聊权限的统计信息，不涉及具体聊天内容。</p>
            </div>
          </div>
        </div>

        <div class="flex justify-between items-center">
          <div>
            <h3 class="text-lg font-semibold text-gray-900">私聊权限概览</h3>
            <p class="text-sm text-gray-600">查看 Member 用户的私聊权限状态（不包含聊天内容）</p>
          </div>
        </div>

        {#if loading}
          <div class="text-center py-8">
            <svg class="animate-spin h-8 w-8 text-orange-600 mx-auto mb-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 714 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
            <p class="text-gray-600">加载中...</p>
          </div>
        {:else if privateChatMembers.length === 0}
          <div class="text-center py-8">
            <svg class="w-16 h-16 text-gray-400 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 8h2a2 2 0 012 2v6a2 2 0 01-2 2h-2v4l-4-4H9a2 2 0 01-2-2v-6a2 2 0 012-2h2m5-4v2a2 2 0 01-2 2H9a2 2 0 01-2-2V4a2 2 0 012-2h4a2 2 0 012 2z"></path>
            </svg>
            <p class="text-gray-600">暂无 Member 用户</p>
          </div>
        {:else}
          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200">
              <thead class="bg-gray-50">
                <tr>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">成员</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">私聊开始时间</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">到期时间</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">剩余天数</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">状态</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">操作</th>
                </tr>
              </thead>
              <tbody class="bg-white divide-y divide-gray-200">
                {#each privateChatMembers as member}
                  <tr class="hover:bg-gray-50">
                    <td class="px-6 py-4 whitespace-nowrap">
                      <div class="flex items-center">
                        <div class="w-8 h-8 bg-orange-500 rounded-full flex items-center justify-center text-white text-sm font-semibold mr-3">
                          {member.nickname ? member.nickname.charAt(0).toUpperCase() : member.email.charAt(0).toUpperCase()}
                        </div>
                        <div>
                          <div class="text-sm font-medium text-gray-900">{member.nickname || member.email}</div>
                          <div class="text-sm text-gray-500">{member.email}</div>
                        </div>
                      </div>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                      {member.privateChatStartedAt ? formatDate(member.privateChatStartedAt) : '-'}
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                      {formatDate(member.privateChatExpiresAt)}
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <span class="text-sm {getRemainingDaysColor(member.privateChatExpiresAt)}">
                        {getRemainingDays(member.privateChatExpiresAt)}
                      </span>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <span class="px-2 py-1 text-xs rounded-full {getStatusColor(member)}">
                        {getStatusText(member)}
                      </span>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
                      <span class="text-gray-400">仅查看权限</span>
                    </td>
                  </tr>
                {/each}
              </tbody>
            </table>
          </div>
        {/if}

        <!-- 统计信息 -->
        {#if privateChatMembers.length > 0}
          <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div class="bg-gray-50 rounded-lg p-4">
              <div class="text-sm font-medium text-gray-500">总 Member 数</div>
              <div class="text-2xl font-bold text-gray-900">{privateChatMembers.length}</div>
            </div>
            <div class="bg-gray-50 rounded-lg p-4">
              <div class="text-sm font-medium text-gray-500">已开启私聊</div>
              <div class="text-2xl font-bold text-green-600">{privateChatMembers.filter(m => m.privateChatEnabled).length}</div>
            </div>
            <div class="bg-gray-50 rounded-lg p-4">
              <div class="text-sm font-medium text-gray-500">即将过期</div>
              <div class="text-2xl font-bold text-yellow-600">
                {privateChatMembers.filter(m => {
                  if (!m.privateChatExpiresAt) return false;
                  const now = new Date();
                  const expires = new Date(m.privateChatExpiresAt);
                  const diff = expires.getTime() - now.getTime();
                  const days = Math.ceil(diff / (1000 * 60 * 60 * 24));
                  return days > 0 && days <= 3;
                }).length}
              </div>
            </div>
          </div>
        {/if}
      </div>
    {/if}
  </div>
</div> 