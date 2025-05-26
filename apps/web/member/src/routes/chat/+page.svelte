<script>
  import { onMount, onDestroy } from 'svelte';
  
  let ws = null;
  let messages = [];
  let newMessage = '';
  let isConnected = false;
  let isConnecting = false;
  let chatContainer;
  let currentUser = null;
  
  // 主播信息
  const anchor = {
    id: 'anchor@localhost',
    name: '主播',
    avatar: '🎭'
  };
  
  onMount(() => {
    loadCurrentUser();
    connectWebSocket();
    loadChatHistory();
  });
  
  onDestroy(() => {
    if (ws) {
      ws.close();
    }
  });
  
  async function loadCurrentUser() {
    try {
      // 从 localStorage 或 API 获取当前用户信息
      const userStr = localStorage.getItem('currentUser');
      if (userStr) {
        currentUser = JSON.parse(userStr);
      }
    } catch (error) {
      console.error('加载用户信息失败:', error);
    }
  }
  
  function connectWebSocket() {
    if (isConnecting || isConnected) return;
    
    isConnecting = true;
    
    try {
      // 连接到聊天服务器
      ws = new WebSocket('wss://chat.baiduohui.com/ws');
      
      ws.onopen = () => {
        console.log('WebSocket 连接已建立');
        isConnected = true;
        isConnecting = false;
        
        // 发送认证信息
        ws.send(JSON.stringify({
          type: 'auth',
          token: getAuthToken()
        }));
      };
      
      ws.onmessage = (event) => {
        try {
          const data = JSON.parse(event.data);
          handleWebSocketMessage(data);
        } catch (error) {
          console.error('解析消息失败:', error);
        }
      };
      
      ws.onclose = () => {
        console.log('WebSocket 连接已关闭');
        isConnected = false;
        isConnecting = false;
        
        // 5秒后尝试重连
        setTimeout(() => {
          if (!isConnected) {
            connectWebSocket();
          }
        }, 5000);
      };
      
      ws.onerror = (error) => {
        console.error('WebSocket 错误:', error);
        isConnecting = false;
      };
      
    } catch (error) {
      console.error('WebSocket 连接失败:', error);
      isConnecting = false;
    }
  }
  
  function handleWebSocketMessage(data) {
    switch (data.type) {
      case 'message':
        addMessage(data.message);
        break;
      case 'message_history':
        messages = data.messages || [];
        scrollToBottom();
        break;
      case 'user_status':
        // 处理用户状态更新
        break;
      default:
        console.log('未知消息类型:', data.type);
    }
  }
  
  function addMessage(message) {
    messages = [...messages, {
      id: message.id || Date.now(),
      from: message.from,
      to: message.to,
      content: message.content,
      timestamp: message.timestamp || new Date().toISOString(),
      type: message.type || 'text'
    }];
    
    setTimeout(scrollToBottom, 100);
  }
  
  async function loadChatHistory() {
    try {
      const response = await fetch('/api/chat/messages', {
        headers: {
          'Authorization': `Bearer ${getAuthToken()}`
        }
      });
      
      if (response.ok) {
        const data = await response.json();
        messages = data.messages || [];
        setTimeout(scrollToBottom, 100);
      }
    } catch (error) {
      console.error('加载聊天历史失败:', error);
    }
  }
  
  function sendMessage() {
    if (!newMessage.trim() || !isConnected) return;
    
    const message = {
      type: 'send_message',
      to: anchor.id,
      content: newMessage.trim(),
      timestamp: new Date().toISOString()
    };
    
    ws.send(JSON.stringify(message));
    
    // 立即显示发送的消息
    addMessage({
      from: currentUser?.id || 'me',
      to: anchor.id,
      content: newMessage.trim(),
      timestamp: new Date().toISOString()
    });
    
    newMessage = '';
  }
  
  function handleKeyPress(event) {
    if (event.key === 'Enter' && !event.shiftKey) {
      event.preventDefault();
      sendMessage();
    }
  }
  
  function scrollToBottom() {
    if (chatContainer) {
      chatContainer.scrollTop = chatContainer.scrollHeight;
    }
  }
  
  function getAuthToken() {
    return localStorage.getItem('supabase.auth.token') || '';
  }
  
  function formatTime(timestamp) {
    return new Date(timestamp).toLocaleTimeString('zh-CN', {
      hour: '2-digit',
      minute: '2-digit'
    });
  }
  
  function isMyMessage(message) {
    return message.from === currentUser?.id || message.from === 'me';
  }
</script>

<svelte:head>
  <title>私信 - 百刀会</title>
</svelte:head>

<div class="flex flex-col h-screen bg-gray-50">
  <!-- 头部 -->
  <div class="bg-white border-b border-gray-200 px-4 py-3">
    <div class="flex items-center">
      <div class="flex-shrink-0">
        <div class="h-10 w-10 rounded-full bg-gradient-to-r from-purple-500 to-pink-500 flex items-center justify-center">
          <span class="text-lg">{anchor.avatar}</span>
        </div>
      </div>
      <div class="ml-3">
        <h1 class="text-lg font-semibold text-gray-900">{anchor.name}</h1>
        <p class="text-sm text-gray-500">
          {isConnected ? '在线' : isConnecting ? '连接中...' : '离线'}
        </p>
      </div>
      
      <!-- 连接状态指示器 -->
      <div class="ml-auto">
        <div class="flex items-center">
          <div class="h-2 w-2 rounded-full {isConnected ? 'bg-green-500' : 'bg-red-500'} mr-2"></div>
          <span class="text-sm text-gray-500">
            {isConnected ? '已连接' : '未连接'}
          </span>
        </div>
      </div>
    </div>
  </div>
  
  <!-- 聊天消息区域 -->
  <div class="flex-1 overflow-y-auto p-4" bind:this={chatContainer}>
    <div class="space-y-4">
      {#each messages as message}
        <div class="flex {isMyMessage(message) ? 'justify-end' : 'justify-start'}">
          <div class="max-w-xs lg:max-w-md">
            <div class="flex items-end {isMyMessage(message) ? 'flex-row-reverse' : 'flex-row'}">
              <!-- 头像 -->
              <div class="flex-shrink-0 {isMyMessage(message) ? 'ml-2' : 'mr-2'}">
                <div class="h-8 w-8 rounded-full {isMyMessage(message) ? 'bg-blue-500' : 'bg-purple-500'} flex items-center justify-center">
                  <span class="text-sm text-white">
                    {isMyMessage(message) ? '我' : anchor.avatar}
                  </span>
                </div>
              </div>
              
              <!-- 消息气泡 -->
              <div class="flex flex-col">
                <div class="px-4 py-2 rounded-lg {isMyMessage(message) ? 'bg-blue-500 text-white' : 'bg-white text-gray-900'} shadow-sm">
                  <p class="text-sm whitespace-pre-wrap">{message.content}</p>
                </div>
                <span class="text-xs text-gray-500 mt-1 {isMyMessage(message) ? 'text-right' : 'text-left'}">
                  {formatTime(message.timestamp)}
                </span>
              </div>
            </div>
          </div>
        </div>
      {:else}
        <div class="text-center py-8">
          <div class="text-gray-400 mb-2">
            <svg class="h-12 w-12 mx-auto" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
            </svg>
          </div>
          <p class="text-gray-500">暂无消息，开始与主播聊天吧！</p>
        </div>
      {/each}
    </div>
  </div>
  
  <!-- 消息输入区域 -->
  <div class="bg-white border-t border-gray-200 p-4">
    <div class="flex items-end space-x-3">
      <div class="flex-1">
        <textarea
          bind:value={newMessage}
          on:keypress={handleKeyPress}
          placeholder="输入消息..."
          rows="1"
          class="block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 resize-none"
          disabled={!isConnected}
        ></textarea>
      </div>
      
      <button
        on:click={sendMessage}
        disabled={!newMessage.trim() || !isConnected}
        class="bg-blue-500 text-white px-4 py-2 rounded-md hover:bg-blue-600 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed transition-colors duration-200"
      >
        发送
      </button>
    </div>
    
    {#if !isConnected}
      <p class="text-sm text-red-500 mt-2">连接已断开，正在尝试重连...</p>
    {/if}
  </div>
</div> 