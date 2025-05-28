<script>
  import { onMount, onDestroy } from 'svelte';

  let loading = true;
  let chatList = []; // 聊天列表，包含群聊和私聊
  let currentChat = null; // 当前选中的聊天
  let showChatWindow = false; // 是否显示聊天窗口
  let messages = []; // 当前聊天的消息
  let newMessage = '';
  let chatContainer;
  let currentUserId = null;
  
  // 私聊权限设置
  let showPermissionModal = false;
  let selectedMember = null;
  let permissionForm = {
    duration: '7',
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

  let expiredChatCheckInterval;

  onMount(async () => {
    await initializeChat();
    loadChatList();
    
    // 每分钟检查一次过期的私聊
    expiredChatCheckInterval = setInterval(checkExpiredChats, 60000);
  });

  onDestroy(() => {
    if (expiredChatCheckInterval) {
      clearInterval(expiredChatCheckInterval);
    }
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

      // 获取私聊列表
      const privateResponse = await fetch('/api/chat/members');
      let privateChats = [];
      if (privateResponse.ok) {
        const members = await privateResponse.json();
        privateChats = members
          .filter(member => member.privateChatEnabled && !isPrivateChatExpired(member.privateChatExpiresAt))
          .map(member => ({
            id: `private_${member.id}`,
            type: 'private',
            name: member.nickname || member.email,
            memberId: member.id,
            lastMessage: member.lastMessage,
            unreadCount: member.unreadCount || 0,
            expiresAt: member.privateChatExpiresAt,
            isActive: true,
            isPinned: false
          }));
      }

      // 合并聊天列表，群聊置顶
      chatList = [groupChat, ...privateChats];
      
    } catch (error) {
      console.error('加载聊天列表失败:', error);
    } finally {
      loading = false;
    }
  }

  function isPrivateChatExpired(expiresAt) {
    if (!expiresAt) return false; // 永久有效
    return new Date(expiresAt) <= new Date();
  }

  async function checkExpiredChats() {
    const expiredChats = chatList.filter(chat => 
      chat.type === 'private' && isPrivateChatExpired(chat.expiresAt)
    );

    if (expiredChats.length > 0) {
      // 从前端列表中移除过期的私聊
      chatList = chatList.filter(chat => 
        !(chat.type === 'private' && isPrivateChatExpired(chat.expiresAt))
      );

      // 通知后端清理过期数据
      for (const chat of expiredChats) {
        try {
          await fetch('/api/chat/cleanup', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ memberId: chat.memberId })
          });
        } catch (error) {
          console.error('清理过期聊天失败:', error);
        }
      }

      // 如果当前正在查看过期的私聊，关闭聊天窗口并提示
      if (currentChat && expiredChats.some(chat => chat.id === currentChat.id)) {
        alert('私聊已过期，将返回消息列表');
        closeChatWindow();
      }
    }
  }

  async function openChat(chat) {
    currentChat = chat;
    showChatWindow = true;
    
    if (chat.type === 'group') {
      await loadAggregatedMessages();
    } else {
      await loadPrivateMessages(chat.memberId);
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

  async function loadPrivateMessages(memberId) {
    try {
      const response = await fetch(`/api/messages/private/${memberId}?limit=50`);
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
      if (chat.type === 'group') {
        // 群聊标记已读逻辑在loadAggregatedMessages中处理
      } else {
        await fetch('/api/chat/mark-read', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ 
            chatId: chat.id,
            memberId: chat.memberId 
          })
        });
        
        // 更新本地未读计数
        const chatIndex = chatList.findIndex(c => c.id === chat.id);
        if (chatIndex !== -1) {
          chatList[chatIndex].unreadCount = 0;
        }
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
    newMessage = '';
  }

  async function sendMessage() {
    if (!newMessage.trim() || !currentChat) return;

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

  function openPermissionModal(member) {
    selectedMember = member;
    showPermissionModal = true;
    permissionForm = {
      duration: '7',
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
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          memberId: selectedMember.id,
          enabled: enable,
          expiresAt: expiresAt
        })
      });

      if (response.ok) {
        alert(enable ? '私聊权限已开启' : '私聊权限已关闭');
        closePermissionModal();
        loadChatList(); // 重新加载聊天列表
      } else {
        const error = await response.json();
        alert(error.message || '操作失败');
      }
    } catch (error) {
      console.error('更新私聊权限失败:', error);
      alert('操作失败，请重试');
    }
  }

  async function deletePrivateChat(chat) {
    if (!confirm('确定要删除这个私聊吗？聊天记录将被永久删除。')) {
      return;
    }

    try {
      const response = await fetch('/api/chat/private/delete', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ memberId: chat.memberId })
      });

      if (response.ok) {
        // 从聊天列表中移除
        chatList = chatList.filter(c => c.id !== chat.id);
        
        // 如果当前正在查看这个私聊，关闭窗口
        if (currentChat && currentChat.id === chat.id) {
          closeChatWindow();
        }
        
        alert('私聊已删除');
      } else {
        alert('删除失败');
      }
    } catch (error) {
      console.error('删除私聊失败:', error);
      alert('删除失败');
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

  function handleKeyPress(event) {
    if (event.key === 'Enter' && !event.shiftKey) {
      event.preventDefault();
      sendMessage();
    }
  }

  function handleMemberClick(message) {
    // 在群聊中点击member头像，显示私聊气泡按钮
    if (currentChat && currentChat.type === 'group' && message.sender_role === 'Member') {
      const member = {
        id: message.sender_id,
        nickname: message.sender_name,
        email: message.sender_email || `user${message.sender_id.slice(-4)}@example.com`
      };
      openPermissionModal(member);
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
            class="w-full p-4 border-b border-gray-100 hover:bg-gray-50 text-left transition-colors
              {currentChat && currentChat.id === chat.id ? 'bg-blue-50 border-blue-200' : ''}"
          >
            <div class="flex items-center space-x-3">
              <!-- 聊天头像 -->
              <div class="relative">
                <div class="w-12 h-12 rounded-full flex items-center justify-center text-white font-semibold
                  {chat.type === 'group' ? 'bg-purple-500' : 'bg-green-500'}">
                  {chat.type === 'group' ? '#' : chat.name.charAt(0).toUpperCase()}
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
                  <h3 class="font-medium text-gray-900 truncate">{chat.name}</h3>
                  <div class="flex flex-col items-end">
                    {#if chat.lastMessage}
                      <span class="text-xs text-gray-500">{formatTime(chat.lastMessage.timestamp)}</span>
                    {/if}
                    {#if chat.type === 'private'}
                      <span class="text-xs text-yellow-600 mt-1">{getRemainingTime(chat.expiresAt)}</span>
                    {/if}
                  </div>
                </div>
                
                <div class="flex items-center justify-between mt-1">
                  <p class="text-sm text-gray-600 truncate">
                    {#if chat.lastMessage}
                      {chat.lastMessage.content}
                    {:else if chat.type === 'group'}
                      所有Member消息聚合显示
                    {:else}
                      私聊已开启
                    {/if}
                  </p>
                  
                  {#if chat.type === 'private'}
                    <button
                      on:click|stopPropagation={() => deletePrivateChat(chat)}
                      class="text-red-500 hover:text-red-700 p-1"
                      title="删除私聊"
                    >
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"></path>
                      </svg>
                    </button>
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
          <h3 class="text-lg font-medium text-gray-900 mb-2">选择一个聊天</h3>
          <p class="text-gray-600">从左侧列表中选择群聊或私聊开始对话</p>
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
              {#if currentChat.type === 'private'}
                <p class="text-sm text-yellow-600">剩余时间: {getRemainingTime(currentChat.expiresAt)}</p>
              {:else}
                <p class="text-sm text-gray-600">群聊 · {currentChat.memberCount || 0} 人</p>
              {/if}
            </div>
          </div>
          
          {#if currentChat.type === 'private'}
            <button
              on:click={() => deletePrivateChat(currentChat)}
              class="text-red-500 hover:text-red-700 p-2"
              title="删除私聊"
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"></path>
              </svg>
            </button>
          {/if}
        </div>
      </div>

      <!-- 消息区域 -->
      <div bind:this={chatContainer} class="flex-1 overflow-y-auto p-4 space-y-4 bg-gray-50">
        {#if messages.length === 0}
          <div class="text-center py-8">
            <svg class="w-16 h-16 text-gray-400 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"></path>
            </svg>
            <p class="text-gray-600">
              {currentChat.type === 'group' ? '开始群聊对话' : '开始私聊对话'}
            </p>
          </div>
        {:else}
          {#each messages as message}
            <div class="flex items-start space-x-3">
              <!-- 用户头像 -->
              <button
                on:click={() => handleMemberClick(message)}
                class="w-8 h-8 rounded-full flex items-center justify-center text-white text-sm font-semibold
                  {message.sender_role === 'Master' ? 'bg-yellow-500' : 
                   message.sender_role === 'Firstmate' ? 'bg-purple-500' : 'bg-green-500'}
                  {currentChat.type === 'group' && message.sender_role === 'Member' ? 'hover:opacity-80 cursor-pointer' : 'cursor-default'}"
                disabled={!(currentChat.type === 'group' && message.sender_role === 'Member')}
              >
                {getUserDisplayName(message).charAt(0)}
              </button>

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
                  {#if currentChat.type === 'private' && message.sender_role === 'Master'}
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
            disabled={!newMessage.trim()}
            class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            发送
          </button>
        </div>
        
        <div class="mt-2 text-xs text-gray-500">
          按 Enter 发送，Shift + Enter 换行
          {#if currentChat.type === 'group'}
            · 点击Member头像可开启私聊
          {/if}
        </div>
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
          <h3 class="text-lg font-medium text-gray-900">开启私聊权限</h3>
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
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
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
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>
          {/if}

          <div class="flex space-x-3">
            <button
              on:click={closePermissionModal}
              class="flex-1 px-4 py-2 bg-gray-300 text-gray-700 rounded-md hover:bg-gray-400 focus:outline-none focus:ring-2 focus:ring-gray-500"
            >
              取消
            </button>
            <button
              on:click={() => updatePrivateChatPermission(true)}
              class="flex-1 px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
              确定
            </button>
          </div>
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
                <li>私聊期间消息不会出现在群聊中</li>
              </ul>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
{/if}

<style>
  /* Master的黄色气泡特殊样式 */
  .bg-yellow-400 {
    background: linear-gradient(135deg, #fbbf24 0%, #f59e0b 100%);
    box-shadow: 0 2px 4px rgba(251, 191, 36, 0.3);
    font-weight: 500;
  }
</style> 