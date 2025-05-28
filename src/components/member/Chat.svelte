<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { createWebSocketManager } from '$lib/websocket';
  import { apiCall, uploadFile, formatTime } from '$lib/auth';
  import type { UserSession } from '$lib/auth';
  import type { ChatMessage, WebSocketManager } from '$lib/websocket';

  export let session: UserSession;

  let wsManager: WebSocketManager;
  let messages: ChatMessage[] = [];
  let newMessage = '';
  let chatContainer: HTMLElement;
  let loading = true;
  let connected = false;
  let unreadCount = 0;
  let showImageUpload = false;
  let showEmojiPicker = false;
  let imageInput: HTMLInputElement;

  const ANCHOR_ID = 'anchor@localhost';
  const emojis = ['😊', '😂', '❤️', '👍', '👎', '😢', '😮', '😡', '🎉', '🔥'];

  onMount(() => {
    initializeChat();
    loadChatHistory();
  });

  onDestroy(() => {
    if (wsManager) {
      wsManager.disconnect();
    }
  });

  async function initializeChat() {
    try {
      wsManager = createWebSocketManager(session);
      
      wsManager.onConnect(() => {
        connected = true;
        loading = false;
        console.log('聊天连接成功');
        
        // 加入私聊房间
        wsManager.joinRoom(`private_${session.user.id}`, 'private');
      });

      wsManager.onDisconnect(() => {
        connected = false;
        console.log('聊天连接断开');
      });

      wsManager.onMessage((message) => {
        messages = [...messages, message];
        
        // 如果是主播发送的消息，增加未读计数
        if (message.sender === ANCHOR_ID && !isScrolledToBottom()) {
          unreadCount++;
        }
        
        scrollToBottom();
      });

      wsManager.onError((error) => {
        console.error('聊天错误:', error);
        alert('聊天连接出现问题，请刷新页面重试');
      });

      await wsManager.connect();
    } catch (error) {
      console.error('初始化聊天失败:', error);
      loading = false;
    }
  }

  async function loadChatHistory() {
    try {
      const history = await apiCall(`/messages/history?chatId=private_${session.user.id}&limit=50`);
      messages = history.reverse(); // 最新消息在底部
      scrollToBottom();
    } catch (error) {
      console.error('加载聊天记录失败:', error);
    }
  }

  function sendMessage(content = newMessage, type: 'text' | 'image' = 'text') {
    if (!content.trim() || !connected) return;

    const message = {
      content: content.trim(),
      type: type,
      chatId: `private_${session.user.id}`,
      sender: session.user.id,
      senderName: session.user.nickname || session.user.email
    };

    wsManager.sendMessage(message);
    
    if (type === 'text') {
      newMessage = '';
    }
    scrollToBottom();
  }

  function sendEmoji(emoji: string) {
    sendMessage(emoji, 'text');
    showEmojiPicker = false;
  }

  async function handleImageUpload(event: Event) {
    const target = event.target as HTMLInputElement;
    const file = target.files?.[0];
    if (!file) return;

    if (file.size > 5 * 1024 * 1024) {
      alert('图片大小不能超过5MB');
      return;
    }

    if (!file.type.startsWith('image/')) {
      alert('只能上传图片文件');
      return;
    }

    try {
      const imageUrl = await uploadFile(file, '/chat/upload-image');
      sendMessage(imageUrl, 'image');
    } catch (error) {
      console.error('图片上传失败:', error);
      alert('图片上传失败');
    }

    // 清空文件输入
    target.value = '';
    showImageUpload = false;
  }

  function scrollToBottom() {
    setTimeout(() => {
      if (chatContainer) {
        chatContainer.scrollTop = chatContainer.scrollHeight;
      }
    }, 100);
  }

  function isScrolledToBottom(): boolean {
    if (!chatContainer) return true;
    const { scrollTop, scrollHeight, clientHeight } = chatContainer;
    return scrollTop + clientHeight >= scrollHeight - 10;
  }

  function handleKeyPress(event: KeyboardEvent) {
    if (event.key === 'Enter' && !event.shiftKey) {
      event.preventDefault();
      sendMessage();
    }
  }

  async function markAsRead() {
    if (unreadCount > 0) {
      unreadCount = 0;
      try {
        await apiCall('/chat/mark-read', {
          method: 'POST',
          body: JSON.stringify({ 
            chatId: `private_${session.user.id}`,
            userId: session.user.id
          })
        });
      } catch (error) {
        console.error('标记已读失败:', error);
      }
    }
  }

  // 当用户滚动到底部时标记为已读
  function handleScroll() {
    if (isScrolledToBottom()) {
      markAsRead();
    }
  }

  // 点击外部关闭弹窗
  function handleClickOutside(event: MouseEvent) {
    const target = event.target as Element;
    if (!target.closest('.emoji-picker')) {
      showEmojiPicker = false;
    }
    if (!target.closest('.image-upload')) {
      showImageUpload = false;
    }
  }
</script>

<svelte:window on:click={handleClickOutside} />

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
        <div class="flex {message.sender === session.user.id ? 'justify-end' : 'justify-start'}">
          <div class="max-w-xs lg:max-w-md">
            {#if message.sender !== session.user.id}
              <div class="flex items-center space-x-2 mb-1">
                <span class="text-xs text-gray-500">主播</span>
                <span class="text-xs text-gray-400">{formatTime(message.timestamp)}</span>
              </div>
            {/if}
            
            <div class="px-4 py-2 rounded-lg {
              message.sender === session.user.id
                ? 'bg-blue-500 text-white' 
                : 'bg-gray-100 text-gray-900'
            }">
              {#if message.type === 'text'}
                <p class="text-sm whitespace-pre-wrap">{message.content}</p>
              {:else if message.type === 'image'}
                <img 
                  src={message.content} 
                  alt="图片消息" 
                  class="max-w-full rounded cursor-pointer hover:opacity-90 transition-opacity"
                  on:click={() => window.open(message.content, '_blank')}
                />
              {/if}
            </div>
            
            {#if message.sender === session.user.id}
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
          on:click={() => sendMessage()}
          disabled={!newMessage.trim() || !connected}
          class="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
        >
          发送
        </button>
      </div>
      
      <div class="flex items-center justify-between mt-2">
        <p class="text-xs text-gray-500">按 Enter 发送，Shift + Enter 换行</p>
        <div class="flex space-x-2 relative">
          <!-- 图片上传 -->
          <div class="relative image-upload">
            <button 
              on:click={() => showImageUpload = !showImageUpload}
              class="text-gray-400 hover:text-gray-600 text-sm transition-colors"
            >
              📷 图片
            </button>
            {#if showImageUpload}
              <div class="absolute bottom-full right-0 mb-2 bg-white border rounded-lg shadow-lg p-2">
                <input
                  bind:this={imageInput}
                  type="file"
                  accept="image/*"
                  on:change={handleImageUpload}
                  class="hidden"
                />
                <button
                  on:click={() => imageInput.click()}
                  class="block w-full text-left px-3 py-2 text-sm hover:bg-gray-100 rounded"
                >
                  选择图片
                </button>
              </div>
            {/if}
          </div>
          
          <!-- 表情选择器 -->
          <div class="relative emoji-picker">
            <button 
              on:click={() => showEmojiPicker = !showEmojiPicker}
              class="text-gray-400 hover:text-gray-600 text-sm transition-colors"
            >
              😊 表情
            </button>
            {#if showEmojiPicker}
              <div class="absolute bottom-full right-0 mb-2 bg-white border rounded-lg shadow-lg p-3">
                <div class="grid grid-cols-5 gap-2">
                  {#each emojis as emoji}
                    <button
                      on:click={() => sendEmoji(emoji)}
                      class="text-lg hover:bg-gray-100 rounded p-1 transition-colors"
                    >
                      {emoji}
                    </button>
                  {/each}
                </div>
              </div>
            {/if}
          </div>
        </div>
      </div>
    {/if}
  </div>
</div> 