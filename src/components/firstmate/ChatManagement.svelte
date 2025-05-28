<!-- Firstmate的聊天管理组件，不能查看私信内容但可以管理群聊 -->
<script>
  import { onMount, onDestroy } from 'svelte';

  let loading = true;
  let chatList = []; // 聊天列表，Firstmate只有群聊
  let currentChat = null; // 当前选中的聊天
  let showChatWindow = false; // 是否显示聊天窗口
  let messages = []; // 当前聊天的消息
  let chatContainer;
  let currentUserId = null;

  onMount(async () => {
    await initializeChat();
    loadChatList();
  });

  async function initializeChat() {
    try {
      const sessionResponse = await fetch('/api/sso/session');
      if (sessionResponse.ok) {
        const session = await sessionResponse.json();
        currentUserId = session.user.id;
      }
    } catch (error) {
      console.error('初始化聊天失败:', error);
    }
  }

  async function loadChatList() {
    try {
      loading = true;
      
      // 获取群聊信息
      const groupResponse = await fetch('/api/chat/group/general');
      const groupChat = groupResponse.ok ? await groupResponse.json() : {
        id: 'general',
        type: 'group',
        name: '#general 群聊',
        memberCount: 0,
        lastMessage: null,
        unreadCount: 0,
        isActive: true,
        isPinned: true
      };

      // Firstmate只有群聊，没有私聊
      chatList = [groupChat];
      
    } catch (error) {
      console.error('加载聊天列表失败:', error);
    } finally {
      loading = false;
    }
  }

  async function openChat(chat) {
    currentChat = chat;
    showChatWindow = true;
    
    if (chat.type === 'group') {
      await loadAggregatedMessages();
    }
    
    // 标记消息为已读
    await markChatAsRead(chat);
  }

  async function loadAggregatedMessages() {
    try {
      const response = await fetch('/api/messages/aggregated?limit=50');
      if (response.ok) {
        const data = await response.json();
        messages = data.messages;
        
        // 标记群聊中的member消息为已读
        await markGroupMessagesAsRead();
        scrollToBottom();
      }
    } catch (error) {
      console.error('加载聚合消息失败:', error);
    }
  }

  async function markChatAsRead(chat) {
    try {
      if (chat.type === 'group') {
        // 群聊标记已读逻辑在loadAggregatedMessages中处理
      }
    } catch (error) {
      console.error('标记已读失败:', error);
    }
  }

  async function markGroupMessagesAsRead() {
    try {
      await fetch('/api/chat/mark-group-read', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ chatId: 'general' })
      });
      
      // 更新群聊未读计数
      const groupChatIndex = chatList.findIndex(c => c.id === 'general');
      if (groupChatIndex !== -1) {
        chatList[groupChatIndex].unreadCount = 0;
      }
    } catch (error) {
      console.error('标记群聊已读失败:', error);
    }
  }

  function closeChatWindow() {
    showChatWindow = false;
    currentChat = null;
    messages = [];
  }

  function scrollToBottom() {
    if (chatContainer) {
      setTimeout(() => {
        chatContainer.scrollTop = chatContainer.scrollHeight;
      }, 100);
    }
  }

  function formatTime(timestamp) {
    if (!timestamp) return '';
    const date = new Date(timestamp);
    const now = new Date();
    const diff = now.getTime() - date.getTime();
    const days = Math.floor(diff / (1000 * 60 * 60 * 24));
    
    if (days === 0) {
      return date.toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' });
    } else if (days === 1) {
      return '昨天';
    } else if (days < 7) {
      return `${days}天前`;
    } else {
      return date.toLocaleDateString('zh-CN', { month: 'short', day: 'numeric' });
    }
  }

  function getUserDisplayName(message) {
    if (message.sender_role === 'Master') {
      return '大师';
    } else if (message.sender_role === 'Firstmate') {
      return '大副';
    } else if (message.sender_name) {
      return message.sender_name;
    } else {
      return `用户${message.sender_id.slice(-4)}`;
    }
  }

  function getMessageBubbleClass(message) {
    const isOwnMessage = message.sender_id === currentUserId;
    const isMasterMessage = message.sender_role === 'Master';
    
    if (isMasterMessage) {
      const alignment = isOwnMessage ? 'ml-auto' : 'mr-auto';
      return `bg-yellow-400 text-gray-900 ${alignment}`;
    } else if (isOwnMessage) {
      return 'bg-blue-500 text-white ml-auto';
    } else {
      return 'bg-gray-200 text-gray-900 mr-auto';
    }
  }
</script>

<div class="flex h-full bg-white rounded-lg shadow overflow-hidden">
  <!-- 左侧聊天列表 -->
  <div class="w-1/3 border-r border-gray-200 flex flex-col">
    <!-- 头部 -->
    <div class="p-4 border-b border-gray-200">
      <div class="flex items-center space-x-2">
        <h2 class="text-xl font-semibold text-gray-900">消息</h2>
        <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-purple-100 text-purple-800">
          助理模式
        </span>
      </div>
    </div>

    <!-- 聊天列表 -->
    <div class="flex-1 overflow-y-auto">
      {#if loading}
        <div class="p-4 text-center">
          <svg class="animate-spin h-6 w-6 text-gray-600 mx-auto" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 714 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
          </svg>
          <p class="text-sm text-gray-600 mt-2">加载中...</p>
        </div>
      {:else}
        {#each chatList as chat}
          <button
            on:click={() => openChat(chat)}
            class="w-full p-4 border-b border-gray-100 hover:bg-gray-50 text-left transition-colors
              {currentChat && currentChat.id === chat.id ? 'bg-blue-50 border-blue-200' : ''}"
          >
            <div class="flex items-center space-x-3">
              <!-- 聊天头像 -->
              <div class="relative">
                <div class="w-12 h-12 bg-purple-500 rounded-full flex items-center justify-center text-white font-semibold">
                  #
                </div>
                {#if chat.unreadCount > 0}
                  <div class="absolute -top-1 -right-1 w-5 h-5 bg-red-500 text-white text-xs rounded-full flex items-center justify-center">
                    {chat.unreadCount > 99 ? '99+' : chat.unreadCount}
                  </div>
                {/if}
                {#if chat.isPinned}
                  <div class="absolute -top-1 -left-1 w-4 h-4 bg-yellow-500 rounded-full flex items-center justify-center">
                    <svg class="w-2 h-2 text-white" fill="currentColor" viewBox="0 0 20 20">
                      <path d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                    </svg>
                  </div>
                {/if}
              </div>

              <!-- 聊天信息 -->
              <div class="flex-1 min-w-0">
                <div class="flex items-center justify-between">
                  <h3 class="font-medium text-gray-900">{chat.name}</h3>
                  <div class="flex flex-col items-end">
                    {#if chat.lastMessage}
                      <span class="text-xs text-gray-500">{formatTime(chat.lastMessage.timestamp)}</span>
                    {/if}
                  </div>
                </div>
                
                <div class="flex items-center justify-between mt-1">
                  <p class="text-sm text-gray-600 truncate">
                    {#if chat.lastMessage}
                      {chat.lastMessage.content}
                    {:else}
                      所有Member消息聚合显示
                    {/if}
                  </p>
                </div>
              </div>
            </div>
          </button>
        {/each}
      {/if}
    </div>

    <!-- 权限说明 -->
    <div class="p-4 border-t border-gray-200 bg-gray-50">
      <div class="bg-purple-50 border border-purple-200 rounded-lg p-3">
        <div class="flex">
          <svg class="w-5 h-5 text-purple-400 mr-2" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd"></path>
          </svg>
          <div class="text-sm text-purple-800">
            <p class="font-medium">助理权限说明:</p>
            <ul class="mt-1 list-disc list-inside">
              <li>可查看群聊消息</li>
              <li>不能管理私聊</li>
              <li>仅 Master 可开启私聊</li>
            </ul>
          </div>
        </div>
      </div>
    </div>
  </div>

  <!-- 右侧聊天窗口 -->
  <div class="flex-1 flex flex-col">
    {#if !showChatWindow}
      <!-- 未选择聊天时的占位界面 -->
      <div class="flex-1 flex items-center justify-center bg-gray-50">
        <div class="text-center">
          <svg class="w-16 h-16 text-gray-400 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"></path>
          </svg>
          <h3 class="text-lg font-medium text-gray-900 mb-2">选择群聊查看消息</h3>
          <p class="text-gray-600">点击左侧的群聊开始查看对话</p>
        </div>
      </div>
    {:else}
      <!-- 聊天头部 -->
      <div class="p-4 border-b border-gray-200 bg-white">
        <div class="flex items-center justify-between">
          <div class="flex items-center space-x-3">
            <button
              on:click={closeChatWindow}
              class="text-gray-500 hover:text-gray-700"
            >
              <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7"></path>
              </svg>
            </button>
            <div>
              <h3 class="font-semibold text-gray-900">{currentChat.name}</h3>
              <p class="text-sm text-gray-600">群聊 · {currentChat.memberCount || 0} 人 · 只读模式</p>
            </div>
          </div>
          
          <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-purple-100 text-purple-800">
            助理模式
          </span>
        </div>
      </div>

      <!-- 消息区域 -->
      <div bind:this={chatContainer} class="flex-1 overflow-y-auto p-4 space-y-4 bg-gray-50">
        {#if messages.length === 0}
          <div class="text-center py-8">
            <svg class="w-16 h-16 text-gray-400 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"></path>
            </svg>
            <p class="text-gray-600">暂无群聊消息</p>
          </div>
        {:else}
          {#each messages as message}
            <div class="flex items-start space-x-3">
              <!-- 用户头像（不可点击） -->
              <div class="w-8 h-8 rounded-full flex items-center justify-center text-white text-sm font-semibold
                {message.sender_role === 'Master' ? 'bg-yellow-500' : 
                 message.sender_role === 'Firstmate' ? 'bg-purple-500' : 'bg-green-500'}">
                {getUserDisplayName(message).charAt(0)}
              </div>

              <!-- 消息内容 -->
              <div class="flex-1 max-w-xs">
                <div class="flex items-center space-x-2 mb-1">
                  <span class="text-sm font-medium text-gray-900">{getUserDisplayName(message)}</span>
                  {#if message.sender_role === 'Master'}
                    <span class="inline-flex items-center px-1.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800">
                      大师
                    </span>
                  {:else if message.sender_role === 'Firstmate'}
                    <span class="inline-flex items-center px-1.5 py-0.5 rounded-full text-xs font-medium bg-purple-100 text-purple-800">
                      大副
                    </span>
                  {/if}
                  <span class="text-xs text-gray-500">{formatTime(message.timestamp)}</span>
                </div>
                
                <div class="rounded-lg px-3 py-2 {getMessageBubbleClass(message)}">
                  <p class="text-sm">{message.content}</p>
                  {#if message.attachments && message.attachments.length > 0}
                    <div class="mt-2 space-y-1">
                      {#each message.attachments as attachment}
                        <div class="text-xs text-blue-600 hover:text-blue-800">
                          📎 {attachment.name}
                        </div>
                      {/each}
                    </div>
                  {/if}
                </div>
              </div>
            </div>
          {/each}
        {/if}
      </div>

      <!-- 底部说明（不能发送消息） -->
      <div class="border-t border-gray-200 p-4 bg-gray-50">
        <div class="text-center text-gray-500">
          <svg class="w-6 h-6 mx-auto mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"></path>
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"></path>
          </svg>
          <p class="text-sm">助理模式 - 只能查看消息，不能发送</p>
          <p class="text-xs text-gray-400 mt-1">仅 Master 可管理私聊和发送消息</p>
        </div>
      </div>
    {/if}
  </div>
</div>

<style>
  /* Master的黄色气泡特殊样式 */
  .bg-yellow-400 {
    background: linear-gradient(135deg, #fbbf24 0%, #f59e0b 100%);
    box-shadow: 0 2px 4px rgba(251, 191, 36, 0.3);
    font-weight: 500;
  }
</style> 