<script>
  import { onMount, onDestroy } from 'svelte';
  import { page } from '$app/stores';
  import { createWebSocketManager } from '$lib/websocket';
  import { apiCall, formatTime } from '$lib/auth';

  let session;
  let wsManager;
  let messages = [];
  let newMessage = '';
  let chatContainer;
  let loading = true;
  let connected = false;
  let memberInfo = null;
  let memberId;

  $: memberId = $page.params.memberId;

  onMount(async () => {
    try {
      session = await apiCall('/auth/session');
      if (!session || session.user.role !== 'Master') {
        window.location.href = '/login';
        return;
      }
      await loadMemberInfo();
      initializeChat();
      loadChatHistory();
    } catch (error) {
      console.error('获取会话失败:', error);
      window.location.href = '/login';
    }
  });

  onDestroy(() => {
    if (wsManager) {
      wsManager.disconnect();
    }
  });

  async function loadMemberInfo() {
    try {
      memberInfo = await apiCall(`/users/${memberId}`);
    } catch (error) {
      console.error('加载用户信息失败:', error);
      alert('用户不存在或无权限访问');
      window.close();
    }
  }

  async function initializeChat() {
    try {
      wsManager = createWebSocketManager(session);
      
      wsManager.onConnect(() => {
        connected = true;
        loading = false;
        console.log('私聊连接成功');
        wsManager.joinRoom(`private_${memberId}`, 'private');
      });

      wsManager.onDisconnect(() => {
        connected = false;
        console.log('私聊连接断开');
      });

      wsManager.onMessage((message) => {
        messages = [...messages, message];
        scrollToBottom();
      });

      wsManager.onError((error) => {
        console.error('私聊错误:', error);
        alert('聊天连接出现问题，请刷新页面重试');
      });

      await wsManager.connect();
    } catch (error) {
      console.error('初始化私聊失败:', error);
      loading = false;
    }
  }

  async function loadChatHistory() {
    try {
      const history = await apiCall(`/messages/history?chatId=private_${memberId}&limit=100`);
      messages = history.reverse();
      scrollToBottom();
    } catch (error) {
      console.error('加载私聊记录失败:', error);
    }
  }

  function sendMessage() {
    if (!newMessage.trim() || !connected) return;

    const message = {
      content: newMessage.trim(),
      type: 'text',
      chatId: `private_${memberId}`,
      sender: session.user.id,
      senderName: session.user.nickname || session.user.email,
      userRole: session.user.role
    };

    wsManager.sendMessage(message);
    newMessage = '';
    scrollToBottom();
  }

  function scrollToBottom() {
    setTimeout(() => {
      if (chatContainer) {
        chatContainer.scrollTop = chatContainer.scrollHeight;
      }
    }, 100);
  }

  function handleKeyPress(event) {
    if (event.key === 'Enter' && !event.shiftKey) {
      event.preventDefault();
      sendMessage();
    }
  }

  function isMasterMessage(message) {
    return message.userRole === 'Master';
  }

  function getMessageBubbleClass(message, isOwnMessage) {
    if (isMasterMessage(message)) {
      const alignment = isOwnMessage ? 'ml-auto' : 'mr-auto';
      return `bg-yellow-400 text-gray-900 master-bubble ${alignment}`;
    } else if (isOwnMessage) {
      return 'bg-blue-500 text-white ml-auto';
    } else {
      return 'bg-gray-200 text-gray-900 mr-auto';
    }
  }

  function getUserDisplayName(message) {
    if (message.userRole === 'Master') {
      return '大师';
    }
    return message.senderName || '用户';
  }

  function getAvatarClass(userRole) {
    if (userRole === 'Master') {
      return 'bg-yellow-500 text-white';
    } else {
      return 'bg-gray-500 text-white';
    }
  }
</script>

<svelte:head>
  <title>私聊 - {memberInfo?.nickname || memberInfo?.email || '用户'} - 百道会</title>
</svelte:head>

<div class="min-h-screen bg-gray-100">
  <div class="max-w-4xl mx-auto py-6">
    <!-- 聊天头部 -->
    <div class="bg-white rounded-lg shadow mb-4 p-4">
      <div class="flex items-center justify-between">
        <div class="flex items-center space-x-3">
          <div class="w-10 h-10 bg-green-500 rounded-full flex items-center justify-center text-white font-semibold">
            {memberInfo?.nickname?.charAt(0) || memberInfo?.email?.charAt(0) || 'U'}
          </div>
          <div>
            <h1 class="text-lg font-semibold text-gray-900">
              与 {memberInfo?.nickname || memberInfo?.email || '用户'} 的私聊
            </h1>
            <p class="text-sm text-gray-500">
              {connected ? '已连接' : '连接中...'}
              <span class="inline-block w-2 h-2 rounded-full ml-1 {connected ? 'bg-green-500' : 'bg-gray-400'}"></span>
            </p>
          </div>
        </div>
        
        <div class="flex items-center space-x-4">
          <div class="text-sm text-gray-600">私聊模式</div>
          <button
            on:click={() => window.close()}
            class="text-gray-400 hover:text-gray-600"
          >
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
            </svg>
          </button>
        </div>
      </div>
    </div>

    <!-- 聊天区域 -->
    <div class="bg-white rounded-lg shadow flex flex-col h-96">
      <!-- 消息列表 -->
      <div 
        bind:this={chatContainer}
        class="flex-1 overflow-y-auto p-4 space-y-4"
      >
        {#if loading}
          <div class="flex justify-center items-center h-full">
            <div class="text-gray-500">加载中...</div>
          </div>
        {:else if messages.length === 0}
          <div class="flex justify-center items-center h-full">
            <div class="text-gray-500">暂无消息，开始聊天吧！</div>
          </div>
        {:else}
          {#each messages as message}
            {@const isOwnMessage = message.sender === session?.user?.id}
            <div class="flex {isOwnMessage ? 'justify-end' : 'justify-start'}">
              <div class="flex items-end space-x-2 max-w-xs lg:max-w-md">
                {#if !isOwnMessage}
                  <div class="w-8 h-8 rounded-full flex items-center justify-center text-sm font-semibold {getAvatarClass(message.userRole)}">
                    {getUserDisplayName(message).charAt(0)}
                  </div>
                {/if}
                
                <div class="flex flex-col">
                  {#if !isOwnMessage}
                    <div class="text-xs text-gray-500 mb-1">
                      {getUserDisplayName(message)}
                    </div>
                  {/if}
                  
                  <div class="px-4 py-2 rounded-lg {getMessageBubbleClass(message, isOwnMessage)}">
                    <p class="text-sm">{message.content}</p>
                    <div class="text-xs opacity-75 mt-1">
                      {formatTime(message.timestamp)}
                    </div>
                  </div>
                </div>
                
                {#if isOwnMessage}
                  <div class="w-8 h-8 rounded-full flex items-center justify-center text-sm font-semibold {getAvatarClass(message.userRole)}">
                    {getUserDisplayName(message).charAt(0)}
                  </div>
                {/if}
              </div>
            </div>
          {/each}
        {/if}
      </div>

      <!-- 输入区域 -->
      <div class="border-t p-4">
        <div class="flex space-x-2">
          <input
            type="text"
            bind:value={newMessage}
            on:keypress={handleKeyPress}
            placeholder="输入消息..."
            disabled={!connected}
            class="flex-1 px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 disabled:bg-gray-100"
          />
          <button
            on:click={sendMessage}
            disabled={!connected || !newMessage.trim()}
            class="px-4 py-2 bg-blue-500 text-white rounded-lg hover:bg-blue-600 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            发送
          </button>
        </div>
        
        {#if !connected}
          <div class="text-xs text-red-500 mt-2">
            连接已断开，正在重连...
          </div>
        {/if}
      </div>
    </div>
  </div>
</div>

<style>
  .master-bubble {
    background: linear-gradient(135deg, #fbbf24 0%, #f59e0b 100%);
    box-shadow: 0 2px 4px rgba(251, 191, 36, 0.3);
    font-weight: 600;
  }
</style> 