<script lang="ts">
  import { onMount } from 'svelte';

  let activeTab = 'group';
  let loading = true;
  let members = [];
  let groupChatInfo = {
    name: '#general',
    memberCount: 0,
    lastMessage: null,
    isActive: true
  };

  // 私聊管理
  let privateChatMembers = [];
  let showPermissionModal = false;
  let selectedMember = null;
  let permissionForm = {
    duration: '7', // 天数
    customDays: ''
  };

  const durationOptions = [
    { value: '1', label: '1天' },
    { value: '3', label: '3天' },
    { value: '7', label: '7天' },
    { value: '30', label: '30天' },
    { value: 'permanent', label: '永久' },
    { value: 'custom', label: '自定义' }
  ];

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
      const response = await fetch('/api/chat/private/members');
      if (response.ok) {
        privateChatMembers = await response.json();
      }
    } catch (error) {
      console.error('加载私聊成员失败:', error);
    } finally {
      loading = false;
    }
  }

  function openPermissionModal(member) {
    selectedMember = member;
    showPermissionModal = true;
    permissionForm = {
      duration: member.privateChatEnabled ? '7' : '7',
      customDays: ''
    };
  }

  function closePermissionModal() {
    showPermissionModal = false;
    selectedMember = null;
    permissionForm = { duration: '7', customDays: '' };
  }

  async function updatePrivateChatPermission(enable) {
    if (!selectedMember) return;

    let expiresAt = null;
    if (enable) {
      if (permissionForm.duration === 'permanent') {
        expiresAt = null;
      } else if (permissionForm.duration === 'custom') {
        const days = parseInt(permissionForm.customDays);
        if (!days || days < 1) {
          alert('请输入有效的天数');
          return;
        }
        expiresAt = new Date(Date.now() + days * 24 * 60 * 60 * 1000).toISOString();
      } else {
        const days = parseInt(permissionForm.duration);
        expiresAt = new Date(Date.now() + days * 24 * 60 * 60 * 1000).toISOString();
      }
    }

    try {
      const response = await fetch('/api/chat/private/permission', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          memberId: selectedMember.id,
          enabled: enable,
          expiresAt: expiresAt
        })
      });

      if (response.ok) {
        alert(enable ? '私聊权限已开启' : '私聊权限已关闭');
        closePermissionModal();
        loadPrivateChatMembers();
      } else {
        const error = await response.json();
        alert(error.message || '操作失败');
      }
    } catch (error) {
      console.error('更新私聊权限失败:', error);
      alert('操作失败，请重试');
    }
  }

  async function downloadChatHistory(memberId) {
    try {
      const response = await fetch(`/api/chat/private/history/${memberId}/download`);
      if (response.ok) {
        const blob = await response.blob();
        const url = window.URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `chat-history-${memberId}-${new Date().toISOString().split('T')[0]}.json`;
        a.click();
        window.URL.revokeObjectURL(url);
      } else {
        alert('下载失败');
      }
    } catch (error) {
      console.error('下载聊天记录失败:', error);
      alert('下载失败');
    }
  }

  async function cleanupExpiredChats() {
    if (!confirm('确定要清理所有过期的私聊记录吗？此操作不可撤销。')) {
      return;
    }

    try {
      const response = await fetch('/api/chat/cleanup', {
        method: 'POST'
      });

      if (response.ok) {
        const result = await response.json();
        alert(`清理完成，共清理了 ${result.cleanedCount} 个过期聊天`);
        loadPrivateChatMembers();
      } else {
        alert('清理失败');
      }
    } catch (error) {
      console.error('清理过期聊天失败:', error);
      alert('清理失败');
    }
  }

  function enterGroupChat() {
    // 这里应该打开群聊窗口或跳转到群聊页面
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
    <h2 class="text-2xl font-semibold text-gray-900 mb-6">聊天管理</h2>

    <!-- 标签切换 -->
    <div class="border-b border-gray-200 mb-6">
      <nav class="-mb-px flex space-x-8">
        <button
          on:click={() => activeTab = 'group'}
          class="py-2 px-1 border-b-2 font-medium text-sm {
            activeTab === 'group'
              ? 'border-purple-500 text-purple-600'
              : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
          }"
        >
          群聊管理
        </button>
        <button
          on:click={() => activeTab = 'private'}
          class="py-2 px-1 border-b-2 font-medium text-sm {
            activeTab === 'private'
              ? 'border-purple-500 text-purple-600'
              : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
          }"
        >
          私聊管理
        </button>
      </nav>
    </div>

    <!-- 群聊管理 -->
    {#if activeTab === 'group'}
      <div class="space-y-6">
        <div class="bg-gradient-to-r from-purple-50 to-blue-50 rounded-lg p-6">
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
              class="px-4 py-2 bg-purple-600 text-white rounded-md hover:bg-purple-700 focus:outline-none focus:ring-2 focus:ring-purple-500"
            >
              进入群聊
            </button>
          </div>
        </div>

        <div class="bg-gray-50 rounded-lg p-4">
          <h4 class="font-medium text-gray-900 mb-3">群聊功能</h4>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div class="flex items-center text-gray-700">
              <svg class="w-5 h-5 text-green-500 mr-2" fill="currentColor" viewBox="0 0 20 20">
                <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"></path>
              </svg>
              所有 Member 可参与
            </div>
            <div class="flex items-center text-gray-700">
              <svg class="w-5 h-5 text-green-500 mr-2" fill="currentColor" viewBox="0 0 20 20">
                <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"></path>
              </svg>
              Firstmate 可协助管理
            </div>
            <div class="flex items-center text-gray-700">
              <svg class="w-5 h-5 text-green-500 mr-2" fill="currentColor" viewBox="0 0 20 20">
                <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"></path>
              </svg>
              实时消息同步
            </div>
            <div class="flex items-center text-gray-700">
              <svg class="w-5 h-5 text-green-500 mr-2" fill="currentColor" viewBox="0 0 20 20">
                <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"></path>
              </svg>
              消息历史记录
            </div>
          </div>
        </div>
      </div>
    {/if}

    <!-- 私聊管理 -->
    {#if activeTab === 'private'}
      <div class="space-y-6">
        <div class="flex justify-between items-center">
          <div>
            <h3 class="text-lg font-semibold text-gray-900">私聊权限管理</h3>
            <p class="text-sm text-gray-600">管理 Member 用户的私聊权限和到期时间</p>
          </div>
          <button
            on:click={cleanupExpiredChats}
            class="px-4 py-2 bg-red-600 text-white rounded-md hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-red-500"
          >
            清理过期聊天
          </button>
        </div>

        {#if loading}
          <div class="text-center py-8">
            <svg class="animate-spin h-8 w-8 text-purple-600 mx-auto mb-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
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
                        <div class="w-8 h-8 bg-green-500 rounded-full flex items-center justify-center text-white text-sm font-semibold mr-3">
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
                    <td class="px-6 py-4 whitespace-nowrap text-sm font-medium space-x-2">
                      <button
                        on:click={() => openPermissionModal(member)}
                        class="text-purple-600 hover:text-purple-900"
                      >
                        {member.privateChatEnabled ? '修改权限' : '开启私聊'}
                      </button>
                      {#if member.privateChatEnabled}
                        <button
                          on:click={() => downloadChatHistory(member.id)}
                          class="text-blue-600 hover:text-blue-900"
                        >
                          下载记录
                        </button>
                      {/if}
                    </td>
                  </tr>
                {/each}
              </tbody>
            </table>
          </div>
        {/if}
      </div>
    {/if}
  </div>
</div>

<!-- 私聊权限设置模态框 -->
{#if showPermissionModal && selectedMember}
  <div class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50">
    <div class="relative top-20 mx-auto p-5 border w-full max-w-md shadow-lg rounded-md bg-white">
      <div class="mt-3">
        <div class="flex justify-between items-center mb-4">
          <h3 class="text-lg font-medium text-gray-900">
            设置私聊权限
          </h3>
          <button
            on:click={closePermissionModal}
            class="text-gray-400 hover:text-gray-600"
          >
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
            </svg>
          </button>
        </div>

        <div class="mb-4">
          <div class="flex items-center space-x-3 mb-3">
            <div class="w-10 h-10 bg-green-500 rounded-full flex items-center justify-center text-white font-semibold">
              {selectedMember.nickname ? selectedMember.nickname.charAt(0).toUpperCase() : selectedMember.email.charAt(0).toUpperCase()}
            </div>
            <div>
              <div class="font-medium text-gray-900">{selectedMember.nickname || selectedMember.email}</div>
              <div class="text-sm text-gray-500">{selectedMember.email}</div>
            </div>
          </div>
        </div>

        <div class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">
              私聊有效期
            </label>
            <select
              bind:value={permissionForm.duration}
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-purple-500"
            >
              {#each durationOptions as option}
                <option value={option.value}>{option.label}</option>
              {/each}
            </select>
          </div>

          {#if permissionForm.duration === 'custom'}
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">
                自定义天数
              </label>
              <input
                type="number"
                bind:value={permissionForm.customDays}
                min="1"
                placeholder="输入天数"
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-purple-500"
              />
            </div>
          {/if}

          <div class="flex space-x-3">
            <button
              on:click={() => updatePrivateChatPermission(true)}
              class="flex-1 px-4 py-2 bg-purple-600 text-white rounded-md hover:bg-purple-700 focus:outline-none focus:ring-2 focus:ring-purple-500"
            >
              开启私聊
            </button>
            {#if selectedMember.privateChatEnabled}
              <button
                on:click={() => updatePrivateChatPermission(false)}
                class="flex-1 px-4 py-2 bg-red-600 text-white rounded-md hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-red-500"
              >
                关闭私聊
              </button>
            {/if}
          </div>

          <button
            on:click={closePermissionModal}
            class="w-full px-4 py-2 bg-gray-300 text-gray-700 rounded-md hover:bg-gray-400 focus:outline-none focus:ring-2 focus:ring-gray-500"
          >
            取消
          </button>
        </div>

        <div class="mt-4 p-3 bg-blue-50 border border-blue-200 rounded-lg">
          <div class="flex">
            <svg class="w-5 h-5 text-blue-400 mr-2" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd"></path>
            </svg>
            <div class="text-sm text-blue-800">
              <p class="font-medium">说明:</p>
              <ul class="mt-1 list-disc list-inside">
                <li>开启后用户可与您进行私信聊天</li>
                <li>到期后私聊权限将自动关闭</li>
                <li>聊天记录可随时下载备份</li>
              </ul>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
{/if} 