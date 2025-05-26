<script>
  import { onMount, onDestroy } from 'svelte';
  
  let ws = null;
  let messages = [];
  let privateMessages = [];
  let newMessage = '';
  let isConnected = false;
  let isConnecting = false;
  let chatContainer;
  let privateContainer;
  let currentUser = null;
  let selectedTab = 'group'; // 'group' or 'private'
  let unreadPrivateCount = 0;
  
  // 响应式布局
  let isMobile = false;
  
  onMount(() => {
    checkMobileLayout();
    window.addEventListener('resize', checkMobileLayout);
    loadCurrentUser();
    connectWebSocket();
    loadChatHistory();
  });
  
  onDestroy(() => {
    if (ws) {
      ws.close();
    }
    window.removeEventListener('resize', checkMobileLayout);
  });
  
  function checkMobileLayout() {
    isMobile = window.innerWidth < 768;
  }
  
  async function loadCurrentUser() {
    try {
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
      ws = new WebSocket('wss://chat.baiduohui.com/ws');
      
      ws.onopen = () => {
        console.log('WebSocket 连接已建立');
        isConnected = true;
        isConnecting = false;
        
        // 发送认证信息
        ws.send(JSON.stringify({
          type: 'auth',
          token: getAuthToken(),
          role: 'master'
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
      case 'group_message':
        addGroupMessage(data.message);
        break;
      case 'private_message':
        addPrivateMessage(data.message);
        if (selectedTab !== 'private') {
          unreadPrivateCount++;
        }
        break;
      case 'message_history':
        messages = data.messages || [];
        scrollToBottom('group');
        break;
      case 'private_history':
        privateMessages = data.messages || [];
        scrollToBottom('private');
        break;
      case 'message_recalled':
        handleMessageRecall(data.messageId);
        break;
      case 'read_receipt':
        handleReadReceipt(data);
        break;
      default:
        console.log('未知消息类型:', data.type);
    }
  }
  
  function addGroupMessage(message) {
    messages = [...messages, {
      id: message.id || Date.now(),
      from: message.from,
      content: message.content,
      timestamp: message.timestamp || new Date().toISOString(),
      type: message.type || 'text',
      recalled: false,
      readBy: message.readBy || []
    }];
    
    setTimeout(() => scrollToBottom('group'), 100);
  }
  
  function addPrivateMessage(message) {
    privateMessages = [...privateMessages, {
      id: message.id || Date.now(),
      from: message.from,
      to: message.to,
      content: message.content,
      timestamp: message.timestamp || new Date().toISOString(),
      type: message.type || 'text',
      recalled: false
    }];
    
    setTimeout(() => scrollToBottom('private'), 100);
  }
  
  function handleMessageRecall(messageId) {
    messages = messages.map(msg => 
      msg.id === messageId ? { ...msg, recalled: true } : msg
    );
    privateMessages = privateMessages.map(msg => 
      msg.id === messageId ? { ...msg, recalled: true } : msg
    );
  }
  
  function handleReadReceipt(data) {
    messages = messages.map(msg => {
      if (msg.id === data.messageId) {
        return {
          ...msg,
          readBy: [...(msg.readBy || []), data.userId]
        };
      }
      return msg;
    });
  }
  
  async function loadChatHistory() {
    try {
      const [groupResponse, privateResponse] = await Promise.all([
        fetch('/api/chat/group_messages', {
          headers: { 'Authorization': `Bearer ${getAuthToken()}` }
        }),
        fetch('/api/chat/private_messages', {
          headers: { 'Authorization': `Bearer ${getAuthToken()}` }
        })
      ]);
      
      if (groupResponse.ok) {
        const groupData = await groupResponse.json();
        messages = groupData.messages || [];
      }
      
      if (privateResponse.ok) {
        const privateData = await privateResponse.json();
        privateMessages = privateData.messages || [];
      }
      
      setTimeout(() => {
        scrollToBottom('group');
        scrollToBottom('private');
      }, 100);
      
    } catch (error) {
      console.error('加载聊天历史失败:', error);
    }
  }
  
  function sendMessage() {
    if (!newMessage.trim() || !isConnected) return;
    
    const message = {
      type: selectedTab === 'group' ? 'send_group_message' : 'send_private_message',
      content: newMessage.trim(),
      timestamp: new Date().toISOString()
    };
    
    ws.send(JSON.stringify(message));
    
    // 立即显示发送的消息
    if (selectedTab === 'group') {
      addGroupMessage({
        from: currentUser?.id || 'master',
        content: newMessage.trim(),
        timestamp: new Date().toISOString()
      });
    }
    
    newMessage = '';
  }
  
  function recallMessage(messageId) {
    if (!isConnected) return;
    
    ws.send(JSON.stringify({
      type: 'recall_message',
      messageId: messageId
    }));
  }
  
  function handleKeyPress(event) {
    if (event.key === 'Enter' && !event.shiftKey) {
      event.preventDefault();
      sendMessage();
    }
  }
  
  function scrollToBottom(type) {
    const container = type === 'group' ? chatContainer : privateContainer;
    if (container) {
      container.scrollTop = container.scrollHeight;
    }
  }
  
  function switchTab(tab) {
    selectedTab = tab;
    if (tab === 'private') {
      unreadPrivateCount = 0;
    }
    setTimeout(() => scrollToBottom(tab), 100);
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
    return message.from === currentUser?.id || message.from === 'master';
  }
  
  function getUserDisplayName(userId) {
    // 实际项目中应该从用户数据库获取
    if (userId === 'master') return '主播';
    if (userId.includes('member')) return '会员';
    if (userId.includes('fan')) return '粉丝';
    return userId;
  }
</script>

<svelte:head>
  <title>群聊管理 - 百刀会</title>
</svelte:head>

<div class="flex flex-col h-screen bg-gray-50">
  <!-- 头部 -->
  <div class="bg-white border-b border-gray-200 px-4 py-3">
    <div class="flex items-center justify-between">
      <div>
        <h1 class="text-lg font-semibold text-gray-900">群聊管理</h1>
        <p class="text-sm text-gray-500">
          {isConnected ? '在线' : isConnecting ? '连接中...' : '离线'}
        </p>
      </div>
      
      <!-- 连接状态 -->
      <div class="flex items-center">
        <div class="h-2 w-2 rounded-full {isConnected ? 'bg-green-500' : 'bg-red-500'} mr-2"></div>
        <span class="text-sm text-gray-500">
          {isConnected ? '已连接' : '未连接'}
        </span>
      </div>
    </div>
    
    <!-- 移动端标签切换 -->
    {#if isMobile}
      <div class="mt-3 flex space-x-1">
        <button
          on:click={() => switchTab('group')}
          class="flex-1 px-3 py-2 text-sm font-medium rounded-md {selectedTab === 'group' ? 'bg-blue-100 text-blue-700' : 'text-gray-500 hover:text-gray-700'}"
        >
          群聊
        </button>
        <button
          on:click={() => switchTab('private')}
          class="flex-1 px-3 py-2 text-sm font-medium rounded-md relative {selectedTab === 'private' ? 'bg-blue-100 text-blue-700' : 'text-gray-500 hover:text-gray-700'}"
        >
          私信
          {#if unreadPrivateCount > 0}
            <span class="absolute -top-1 -right-1 h-5 w-5 bg-red-500 text-white text-xs rounded-full flex items-center justify-center">
              {unreadPrivateCount}
            </span>
          {/if}
        </button>
      </div>
    {/if}
  </div>
  
  <!-- 主要内容区域 -->
  <div class="flex-1 flex {isMobile ? 'flex-col' : 'flex-row'}">
    <!-- 群聊区域 -->
    <div class="flex-1 flex flex-col {isMobile && selectedTab !== 'group' ? 'hidden' : ''}">
      <div class="bg-white border-b border-gray-200 px-4 py-2">
        <h2 class="font-medium text-gray-900">群聊消息</h2>
      </div>
      
      <!-- 群聊消息列表 -->
      <div class="flex-1 overflow-y-auto p-4" bind:this={chatContainer}>
        <div class="space-y-4">
          {#each messages as message}
            <div class="flex {isMyMessage(message) ? 'justify-end' : 'justify-start'}">
              <div class="max-w-xs lg:max-w-md">
                {#if message.recalled}
                  <div class="text-center text-gray-400 text-sm italic py-2">
                    消息已撤回
                  </div>
                {:else}
                  <div class="flex items-end {isMyMessage(message) ? 'flex-row-reverse' : 'flex-row'}">
                    <!-- 头像 -->
                    <div class="flex-shrink-0 {isMyMessage(message) ? 'ml-2' : 'mr-2'}">
                      <div class="h-8 w-8 rounded-full {isMyMessage(message) ? 'bg-blue-500' : 'bg-gray-500'} flex items-center justify-center">
                        <span class="text-sm text-white">
                          {isMyMessage(message) ? '主' : getUserDisplayName(message.from).charAt(0)}
                        </span>
                      </div>
                    </div>
                    
                    <!-- 消息内容 -->
                    <div class="flex flex-col">
                      <div class="px-4 py-2 rounded-lg {isMyMessage(message) ? 'bg-blue-500 text-white' : 'bg-white text-gray-900'} shadow-sm relative group">
                        <p class="text-sm whitespace-pre-wrap">{message.content}</p>
                        
                        <!-- 撤回按钮 -->
                        {#if isMyMessage(message)}
                          <button
                            on:click={() => recallMessage(message.id)}
                            class="absolute -top-2 -right-2 opacity-0 group-hover:opacity-100 bg-red-500 text-white rounded-full p-1 text-xs hover:bg-red-600 transition-opacity duration-200"
                            title="撤回消息"
                          >
                            ✕
                          </button>
                        {/if}
                      </div>
                      
                      <div class="flex items-center justify-between mt-1">
                        <span class="text-xs text-gray-500 {isMyMessage(message) ? 'text-right' : 'text-left'}">
                          {formatTime(message.timestamp)}
                        </span>
                        
                        <!-- 已读状态 -->
                        {#if isMyMessage(message) && message.readBy && message.readBy.length > 0}
                          <span class="text-xs text-gray-400">
                            {message.readBy.length} 人已读
                          </span>
                        {/if}
                      </div>
                    </div>
                  </div>
                {/if}
              </div>
            </div>
          {:else}
            <div class="text-center py-8">
              <div class="text-gray-400 mb-2">
                <svg class="h-12 w-12 mx-auto" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 8h2a2 2 0 012 2v6a2 2 0 01-2 2h-2v4l-4-4H9a2 2 0 01-2-2v-6a2 2 0 012-2h8z" />
                </svg>
              </div>
              <p class="text-gray-500">暂无群聊消息</p>
            </div>
          {/each}
        </div>
      </div>
    </div>
    
    <!-- 私信区域 -->
    <div class="flex-1 flex flex-col border-l border-gray-200 {isMobile && selectedTab !== 'private' ? 'hidden' : ''}">
      <div class="bg-white border-b border-gray-200 px-4 py-2">
        <h2 class="font-medium text-gray-900 flex items-center">
          私信消息
          {#if unreadPrivateCount > 0}
            <span class="ml-2 bg-red-500 text-white text-xs px-2 py-1 rounded-full">
              {unreadPrivateCount}
            </span>
          {/if}
        </h2>
      </div>
      
      <!-- 私信消息列表 -->
      <div class="flex-1 overflow-y-auto p-4" bind:this={privateContainer}>
        <div class="space-y-4">
          {#each privateMessages as message}
            <div class="border-b border-gray-100 pb-4">
              <div class="flex items-start space-x-3">
                <div class="flex-shrink-0">
                  <div class="h-8 w-8 rounded-full bg-purple-500 flex items-center justify-center">
                    <span class="text-sm text-white">
                      {getUserDisplayName(message.from).charAt(0)}
                    </span>
                  </div>
                </div>
                
                <div class="flex-1">
                  <div class="flex items-center space-x-2">
                    <span class="font-medium text-gray-900">
                      {getUserDisplayName(message.from)}
                    </span>
                    <span class="text-xs text-gray-500">
                      {formatTime(message.timestamp)}
                    </span>
                  </div>
                  
                  {#if message.recalled}
                    <p class="text-gray-400 text-sm italic mt-1">消息已撤回</p>
                  {:else}
                    <p class="text-gray-700 mt-1">{message.content}</p>
                  {/if}
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
              <p class="text-gray-500">暂无私信消息</p>
            </div>
          {/each}
        </div>
      </div>
    </div>
  </div>
  
  <!-- 消息输入区域 -->
  <div class="bg-white border-t border-gray-200 p-4">
    <div class="flex items-end space-x-3">
      <div class="flex-1">
        <textarea
          bind:value={newMessage}
          on:keypress={handleKeyPress}
          placeholder={selectedTab === 'group' ? '发送群聊消息...' : '回复私信...'}
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