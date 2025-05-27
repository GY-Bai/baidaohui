<script lang="ts">
  let showInviteModal = false;
  let inviteLink = '';
  let generating = false;

  async function generateInviteLink() {
    try {
      generating = true;
      // 调用后端API生成Member邀请链接
      const response = await fetch('/api/invite/generate', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          type: 'member',
          validHours: 24,
          maxUses: 1
        })
      });

      if (response.ok) {
        const data = await response.json();
        inviteLink = data.url;
        showInviteModal = true;
      } else {
        alert('生成邀请链接失败，请重试');
      }
    } catch (error) {
      console.error('生成邀请链接失败:', error);
      alert('生成邀请链接失败，请重试');
    } finally {
      generating = false;
    }
  }

  function copyInviteLink() {
    navigator.clipboard.writeText(inviteLink).then(() => {
      alert('邀请链接已复制到剪贴板');
    });
  }

  function closeModal() {
    showInviteModal = false;
    inviteLink = '';
  }
</script>

<div class="bg-white rounded-lg shadow p-6">
  <h2 class="text-2xl font-semibold text-gray-900 mb-6">私信</h2>
  
  <!-- 升级提示卡片 -->
  <div class="bg-gradient-to-r from-blue-50 to-indigo-50 border border-blue-200 rounded-lg p-6 text-center">
    <div class="mb-4">
      <svg class="w-16 h-16 text-blue-500 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"></path>
      </svg>
    </div>
    
    <h3 class="text-xl font-semibold text-gray-900 mb-2">解锁聊天功能</h3>
    <p class="text-gray-600 mb-6">要使用聊天功能，请使用邀请链接升级为 Member</p>
    
    <button
      on:click={generateInviteLink}
      disabled={generating}
      class="inline-flex items-center px-6 py-3 border border-transparent text-base font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
    >
      {#if generating}
        <svg class="animate-spin -ml-1 mr-3 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
        生成中...
      {:else}
        获取邀请链接
      {/if}
    </button>
  </div>

  <!-- 功能说明 -->
  <div class="mt-6 bg-gray-50 rounded-lg p-4">
    <h4 class="font-medium text-gray-900 mb-2">升级为 Member 后您将获得：</h4>
    <ul class="text-sm text-gray-600 space-y-1">
      <li class="flex items-center">
        <svg class="w-4 h-4 text-green-500 mr-2" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"></path>
        </svg>
        与主播进行私信聊天
      </li>
      <li class="flex items-center">
        <svg class="w-4 h-4 text-green-500 mr-2" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"></path>
        </svg>
        参与群聊讨论
      </li>
      <li class="flex items-center">
        <svg class="w-4 h-4 text-green-500 mr-2" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"></path>
        </svg>
        实时消息通知
      </li>
    </ul>
  </div>
</div>

<!-- 邀请链接模态框 -->
{#if showInviteModal}
  <div class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50" on:click={closeModal}>
    <div class="relative top-20 mx-auto p-5 border w-96 shadow-lg rounded-md bg-white" on:click|stopPropagation>
      <div class="mt-3 text-center">
        <h3 class="text-lg font-medium text-gray-900 mb-4">Member 邀请链接</h3>
        
        <div class="mb-4 p-3 bg-gray-50 rounded border text-sm break-all">
          {inviteLink}
        </div>
        
        <div class="flex space-x-3">
          <button
            on:click={copyInviteLink}
            class="flex-1 px-4 py-2 bg-blue-600 text-white text-sm font-medium rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500"
          >
            复制链接
          </button>
          <button
            on:click={closeModal}
            class="flex-1 px-4 py-2 bg-gray-300 text-gray-700 text-sm font-medium rounded-md hover:bg-gray-400 focus:outline-none focus:ring-2 focus:ring-gray-500"
          >
            关闭
          </button>
        </div>
        
        <p class="mt-3 text-xs text-gray-500">
          链接有效期24小时，仅限1人使用
        </p>
      </div>
    </div>
  </div>
{/if} 