<script>
  import { onMount, onDestroy } from 'svelte';
  import { browser } from '$app/environment';

  let chatList = []; // 聊天列表，Member只有与Master的私聊
  let currentChat = null; // 当前选中的聊天
  let showChatWindow = false; // 是否显示聊天窗口
  let messages = [];
  let newMessage = '';
  let chatContainer;
  let loading = true;
  let connected = false;
  let socket = null;
  let currentUserId = null;

  onMount(async () => {
    if (browser) {
      await initializeChat();
      connectWebSocket();
    }
  });

  onDestroy(() => {
    if (socket) {
      socket.disconnect();
    }
  });

  async function initializeChat() {
    try {
      // 获取当前用户信息
      const sessionResponse = await fetch('/api/sso/session');
      if (sessionResponse.ok) {
        const session = await sessionResponse.json();
        currentUserId = session.user.id;
        
        // 加载聊天列表
        await loadChatList();
      }
    } catch (error) {
      console.error('初始化聊天失败:', error);
    } finally {
      loading = false;
    }
  }

  async function loadChatList() {
    try {
      // 检查私聊权限
      const response = await fetch(`/api/messages/private/${currentUserId}`);
      
      if (response.ok) {
        // 私聊已开启，获取聊天信息
        const data = await response.json();
        const masterChat = {
          id: `private_${currentUserId}`,
          type: 'private',
          name: '大师',
          memberId: 'master',
          lastMessage: data.lastMessage,
          unreadCount: data.unreadCount || 0,
          expiresAt: data.expiresAt,
          isActive: true,
          privateChatEnabled: true
        };
        
        chatList = [masterChat];
      } else if (response.status === 403) {
        // 私聊未开启
        const masterChat = {
          id: `private_${currentUserId}`,
          type: 'private',
          name: '大师',
          memberId: 'master',
          lastMessage: null,
          unreadCount: 0,
          expiresAt: null,
          isActive: false,
          privateChatEnabled: false
        };
        
        chatList = [masterChat];
      }
    } catch (error) {
      console.error('加载聊天列表失败:', error);
      // 创建默认的Master聊天项
      const masterChat = {
        id: `private_${currentUserId}`,
        type: 'private',
        name: '大师',
        memberId: 'master',
        lastMessage: null,
        unreadCount: 0,
        expiresAt: null,
        isActive: false,
        privateChatEnabled: false
      };
      
      chatList = [masterChat];
    }
  }

  function connectWebSocket() {
    try {
      // 这里需要根据实际的WebSocket实现来连接
      // socket = io('/chat', { 
      //   auth: { token: getCookie('access_token') }
      // });
      
      // socket.on('connect', () => {
      //   connected = true;
      //   if (privateChatEnabled) {
      //     socket.emit('join_room', `private_${currentUserId}`);
      //   }
      // });

      // socket.on('disconnect', () => {
      //   connected = false;
      // });

      // socket.on('new_message', (message) => {
      //   messages = [...messages, message];
      //   scrollToBottom();
      //   
      //   // 更新聊天列表中的最新消息和未读计数
      //   updateChatListLastMessage(currentChat.id, message);
      // });

      // socket.on('private_chat_updated', (data) => {
      //   if (data.member_id === currentUserId) {
      //     loadChatList(); // 重新加载聊天列表
      //   }
      // });

      // socket.on('message_read', (data) => {
      //   // 更新消息已读状态
      //   if (currentChat && currentChat.id === data.chatId) {
      //     messages = messages.map(msg => 
      //       msg.id === data.messageId ? { ...msg, read_status: true } : msg
      //     );
      //   }
      // });
      
      // 模拟连接成功
      connected = true;
    } catch (error) {
      console.error('WebSocket连接失败:', error);
    }
  }

  async function openChat(chat) {
    if (!chat.privateChatEnabled) {
      return; // 私聊未开启，不能打开
    }

    currentChat = chat;
    showChatWindow = true;
    
    await loadPrivateMessages();
    
    // 标记消息为已读
    await markChatAsRead(chat);
  }

  async function loadPrivateMessages() {
    try {
      const response = await fetch(`/api/messages/private/${currentUserId}?limit=50`);
      if (response.ok) {
        const data = await response.json();
        messages = data.messages;
        scrollToBottom();
      }
    } catch (error) {
      console.error('加载私聊消息失败:', error);
    }
  }

  async function markChatAsRead(chat) {
    try {
      await fetch('/api/chat/mark-read', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ 
          chatId: chat.id,
          memberId: currentUserId 
        })
      });
      
      // 更新本地未读计数
      const chatIndex = chatList.findIndex(c => c.id === chat.id);
      if (chatIndex !== -1) {
        chatList[chatIndex].unreadCount = 0;
      }
    } catch (error) {
      console.error('标记已读失败:', error);
    }
  }

  function closeChatWindow() {
    showChatWindow = false;
    currentChat = null;
    messages = [];
    newMessage = '';
  }

  async function sendMessage() {
    if (!newMessage.trim() || !currentChat || !currentChat.privateChatEnabled) return;

    const messageData = {
      chat_id: currentChat.id,
      content: newMessage.trim(),
      type: 'text'
    };

    try {
      const response = await fetch('/api/messages/send', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(messageData)
      });

      if (response.ok) {
        const sentMessage = await response.json();
        messages = [...messages, sentMessage];
        newMessage = '';
        scrollToBottom();
        
        // 更新聊天列表中的最新消息
        updateChatListLastMessage(currentChat.id, sentMessage);
      }
    } catch (error) {
      console.error('发送消息失败:', error);
    }
  }

  function updateChatListLastMessage(chatId, message) {
    const chatIndex = chatList.findIndex(c => c.id === chatId);
    if (chatIndex !== -1) {
      chatList[chatIndex].lastMessage = message;
    }
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

  function getRemainingTime(expiresAt) {
    if (!expiresAt) return '永久';
    
    const now = new Date();
    const expires = new Date(expiresAt);
    const diff = expires.getTime() - now.getTime();
    
    if (diff <= 0) return '已过期';
    
    const days = Math.floor(diff / (1000 * 60 * 60 * 24));
    const hours = Math.floor((diff % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
    
    if (days > 0) {
      return `${days}天`;
    } else {
      return `${hours}小时`;
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
      return '我';
    }
  }

  function getMessageBubbleClass(message) {
    const isOwnMessage = message.sender_id === currentUserId;
    const isMasterMessage = message.sender_role === 'Master';
    
    // 在私聊中，Master的消息始终显示黄色气泡
    if (isMasterMessage) {
      // 保持正确的对齐方式：自己的消息右对齐，别人的消息左对齐
      const alignment = isOwnMessage ? 'ml-auto' : 'mr-auto';
      return `bg-yellow-400 text-gray-900 ${alignment}`;
    } else if (isOwnMessage) {
      return 'bg-blue-500 text-white ml-auto';
    } else {
      return 'bg-gray-200 text-gray-900 mr-auto';
    }
  }

  function handleKeyPress(event) {
    if (event.key === 'Enter' && !event.shiftKey) {
      event.preventDefault();
      sendMessage();
    }
  }
</script>

<div class="flex h-full bg-white rounded-lg shadow overflow-hidden">
  <!-- 左侧聊天列表 -->
  <div class="w-1/3 border-r border-gray-200 flex flex-col">
    <!-- 头部 -->
    <div class="p-4 border-b border-gray-200">
      <h2 class="text-xl font-semibold text-gray-900">消息</h2>
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
            disabled={!chat.privateChatEnabled}
            class="w-full p-4 border-b border-gray-100 text-left transition-colors
              {chat.privateChatEnabled ? 'hover:bg-gray-50 cursor-pointer' : 'cursor-not-allowed opacity-60'}
              {currentChat && currentChat.id === chat.id ? 'bg-blue-50 border-blue-200' : ''}"
          >
            <div class="flex items-center space-x-3">
              <!-- 聊天头像 -->
              <div class="relative">
                <div class="w-12 h-12 bg-yellow-500 rounded-full flex items-center justify-center text-white font-semibold">
                  大
                </div>
                {#if chat.unreadCount > 0}
                  <div class="absolute -top-1 -right-1 w-5 h-5 bg-red-500 text-white text-xs rounded-full flex items-center justify-center">
                    {chat.unreadCount > 99 ? '99+' : chat.unreadCount}
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
                    {#if chat.privateChatEnabled && chat.expiresAt}
                      <span class="text-xs text-yellow-600 mt-1">{getRemainingTime(chat.expiresAt)}</span>
                    {/if}
                  </div>
                </div>
                
                <div class="flex items-center justify-between mt-1">
                  <p class="text-sm text-gray-600 truncate">
                    {#if !chat.privateChatEnabled}
                      私聊未开启
                    {:else if chat.lastMessage}
                      {chat.lastMessage.content}
                    {:else}
                      开始与大师的私聊
                    {/if}
                  </p>
                  
                  {#if !chat.privateChatEnabled}
                    <span class="text-xs text-red-600 bg-red-100 px-2 py-1 rounded-full">
                      未开启
                    </span>
                  {:else if chat.lastMessage && chat.lastMessage.sender_id === currentUserId}
                    <!-- 显示自己发送消息的已读/未读状态 -->
                    <span class="text-xs {chat.lastMessage.read_status ? 'text-green-600' : 'text-gray-500'}">
                      {chat.lastMessage.read_status ? '已读' : '未读'}
                    </span>
                  {/if}
                </div>
              </div>
            </div>
          </button>
        {/each}
      {/if}
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
          <h3 class="text-lg font-medium text-gray-900 mb-2">选择聊天开始对话</h3>
          <p class="text-gray-600">点击左侧的大师头像开始私聊</p>
        </div>
      </div>
    {:else if !currentChat.privateChatEnabled}
      <!-- 私聊未开启界面 -->
      <div class="flex-1 flex items-center justify-center bg-gray-50">
        <div class="text-center">
          <svg class="w-16 h-16 text-gray-400 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"></path>
          </svg>
          <h3 class="text-lg font-medium text-gray-900 mb-2">私聊未开启</h3>
          <p class="text-gray-600 mb-4">您暂时无法与大师进行私聊</p>
          <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 text-left max-w-md">
            <div class="flex">
              <svg class="w-5 h-5 text-blue-400 mr-2" fill="currentColor" viewBox="0 0 20 20">
                <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd"></path>
              </svg>
              <div class="text-sm text-blue-800">
                <p class="font-medium">如何开启私聊：</p>
                <ul class="mt-1 list-disc list-inside">
                  <li>私聊权限由大师开启</li>
                  <li>开启后可以与大师一对一交流</li>
                  <li>私聊有时间限制，到期后自动关闭</li>
                </ul>
              </div>
            </div>
          </div>
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
            <div class="w-10 h-10 bg-yellow-500 rounded-full flex items-center justify-center text-white font-semibold">
              大
            </div>
            <div>
              <h3 class="font-semibold text-gray-900">与大师私聊</h3>
              <div class="flex items-center space-x-2">
                <div class="w-2 h-2 rounded-full {connected ? 'bg-green-500' : 'bg-red-500'}"></div>
                <span class="text-sm text-gray-500">
                  {connected ? '已连接' : '连接中...'}
                </span>
                {#if currentChat.expiresAt}
                  <span class="text-xs text-yellow-600">
                    · 剩余时间: {getRemainingTime(currentChat.expiresAt)}
                  </span>
                {/if}
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- 消息区域 -->
      <div bind:this={chatContainer} class="flex-1 overflow-y-auto p-4 space-y-4 bg-gray-50">
        {#if messages.length === 0}
          <div class="text-center py-8">
            <svg class="w-16 h-16 text-gray-400 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"></path>
            </svg>
            <p class="text-gray-600">开始与大师的私聊吧</p>
          </div>
        {:else}
          {#each messages as message}
            <div class="flex items-start space-x-3">
              <!-- 用户头像 -->
              <div class="w-8 h-8 rounded-full flex items-center justify-center text-white text-sm font-semibold
                {message.sender_role === 'Master' ? 'bg-yellow-500' : 
                 message.sender_role === 'Firstmate' ? 'bg-purple-500' : 'bg-blue-500'}">
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
                  {#if message.sender_id === currentUserId}
                    <!-- 显示自己发送消息的已读/未读状态 -->
                    <span class="text-xs {message.read_status ? 'text-green-600' : 'text-gray-500'}">
                      {message.read_status ? '已读' : '未读'}
                    </span>
                  {/if}
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

      <!-- 输入区域 -->
      <div class="border-t border-gray-200 p-4 bg-white">
        <div class="flex space-x-3">
          <div class="flex-1">
            <textarea
              bind:value={newMessage}
              on:keypress={handleKeyPress}
              placeholder="输入消息..."
              rows="2"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 resize-none"
            ></textarea>
          </div>
          <button
            on:click={sendMessage}
            disabled={!newMessage.trim() || !connected}
            class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            发送
          </button>
        </div>
        
        <div class="mt-2 text-xs text-gray-500">
          按 Enter 发送，Shift + Enter 换行
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