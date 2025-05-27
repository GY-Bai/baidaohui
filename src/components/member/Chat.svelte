<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { io } from 'socket.io-client';

  let socket;
  let messages = [];
  let newMessage = '';
  let chatContainer;
  let loading = true;
  let connected = false;
  let unreadCount = 0;

  const ANCHOR_ID = 'anchor@localhost';

  onMount(() => {
    initializeChat();
    loadChatHistory();
  });

  onDestroy(() => {
    if (socket) {
      socket.disconnect();
    }
  });

  function initializeChat() {
    // 连接WebSocket
    socket = io('/chat', {
      auth: {
        token: localStorage.getItem('access_token') // 从localStorage获取JWT
      }
    });

    socket.on('connect', () => {
      connected = true;
      loading = false;
      console.log('聊天连接成功');
    });

    socket.on('disconnect', () => {
      connected = false;
      console.log('聊天连接断开');
    });

    socket.on('message', (message) => {
      messages = [...messages, message];
      
      // 如果是主播发送的消息，增加未读计数
      if (message.sender === ANCHOR_ID) {
        unreadCount++;
      }
      
      scrollToBottom();
    });

    socket.on('error', (error) => {
      console.error('聊天错误:', error);
      alert('聊天连接出现问题，请刷新页面重试');
    });
  }

  async function loadChatHistory() {
    try {
      const response = await fetch('/api/messages/history?chatId=private&limit=50');
      if (response.ok) {
        const history = await response.json();
        messages = history.reverse(); // 最新消息在底部
        scrollToBottom();
      }
    } catch (error) {
      console.error('加载聊天记录失败:', error);
    }
  }

  function sendMessage() {
    if (!newMessage.trim() || !connected) return;

    const message = {
      content: newMessage.trim(),
      type: 'text',
      timestamp: new Date().toISOString(),
      chatId: 'private'
    };

    socket.emit('message', message);
    
    // 立即在UI中显示消息
    messages = [...messages, {
      ...message,
      sender: 'me',
      id: Date.now()
    }];
    
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

  function markAsRead() {
    if (unreadCount > 0) {
      unreadCount = 0;
      // 调用API标记消息为已读
      fetch('/api/chat/mark-read', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ chatId: 'private' })
      }).catch(console.error);
    }
  }

  function formatTime(timestamp) {
    return new Date(timestamp).toLocaleTimeString('zh-CN', {
      hour: '2-digit',
      minute: '2-digit'
    });
  }

  // 当用户滚动到底部时标记为已读
  function handleScroll() {
    if (chatContainer) {
      const { scrollTop, scrollHeight, clientHeight } = chatContainer;
      if (scrollTop + clientHeight >= scrollHeight - 10) {
        markAsRead();
      }
    }
  }
</script>

<div class="bg-white rounded-lg shadow h-96 flex flex-col">
  <div class="flex items-center justify-between p-4 border-b">
    <div class="flex items-center space-x-3">
      <div class="w-10 h-10 bg-purple-500 rounded-full flex items-center justify-center text-white font-semibold">
        主
      </div>
      <div>
        <h3 class="font-medium text-gray-900">主播聊天</h3>
        <p class="text-sm text-gray-500">
          {connected ? '在线' : '离线'}
          <span class="inline-block w-2 h-2 rounded-full ml-1 {connected ? 'bg-green-500' : 'bg-gray-400'}"></span>
        </p>
      </div>
    </div>
    
    {#if unreadCount > 0}
      <span class="bg-red-500 text-white text-xs px-2 py-1 rounded-full">
        {unreadCount} 条未读
      </span>
    {/if}
  </div>

  <!-- 聊天消息区域 -->
  <div 
    bind:this={chatContainer}
    on:scroll={handleScroll}
    class="flex-1 overflow-y-auto p-4 space-y-3"
  >
    {#if loading}
      <div class="text-center py-8">
        <svg class="animate-spin h-6 w-6 text-blue-600 mx-auto mb-2" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
        <p class="text-gray-600 text-sm">加载聊天记录...</p>
      </div>
    {:else if messages.length === 0}
      <div class="text-center py-8">
        <svg class="w-12 h-12 text-gray-400 mx-auto mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"></path>
        </svg>
        <p class="text-gray-600 text-sm">开始与主播聊天吧！</p>
      </div>
    {:else}
      {#each messages as message}
        <div class="flex {message.sender === 'me' ? 'justify-end' : 'justify-start'}">
          <div class="max-w-xs lg:max-w-md">
            {#if message.sender !== 'me'}
              <div class="flex items-center space-x-2 mb-1">
                <span class="text-xs text-gray-500">主播</span>
                <span class="text-xs text-gray-400">{formatTime(message.timestamp)}</span>
              </div>
            {/if}
            
            <div class="px-4 py-2 rounded-lg {
              message.sender === 'me' 
                ? 'bg-blue-500 text-white' 
                : 'bg-gray-100 text-gray-900'
            }">
              {#if message.type === 'text'}
                <p class="text-sm whitespace-pre-wrap">{message.content}</p>
              {:else if message.type === 'image'}
                <img src={message.content} alt="图片消息" class="max-w-full rounded" />
              {/if}
            </div>
            
            {#if message.sender === 'me'}
              <div class="text-right mt-1">
                <span class="text-xs text-gray-400">{formatTime(message.timestamp)}</span>
              </div>
            {/if}
          </div>
        </div>
      {/each}
    {/if}
  </div>

  <!-- 消息输入区域 -->
  <div class="border-t p-4">
    {#if !connected}
      <div class="text-center py-2">
        <p class="text-red-600 text-sm">连接已断开，正在重连...</p>
      </div>
    {:else}
      <div class="flex space-x-3">
        <input
          bind:value={newMessage}
          on:keypress={handleKeyPress}
          placeholder="输入消息..."
          class="flex-1 px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
          disabled={!connected}
        />
        <button
          on:click={sendMessage}
          disabled={!newMessage.trim() || !connected}
          class="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
        >
          发送
        </button>
      </div>
      
      <div class="flex items-center justify-between mt-2">
        <p class="text-xs text-gray-500">按 Enter 发送，Shift + Enter 换行</p>
        <div class="flex space-x-2">
          <button class="text-gray-400 hover:text-gray-600 text-sm">
            📷 图片
          </button>
          <button class="text-gray-400 hover:text-gray-600 text-sm">
            😊 表情
          </button>
        </div>
      </div>
    {/if}
  </div>
</div> 