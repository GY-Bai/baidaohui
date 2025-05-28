<script>
  export let message;
  export let currentUser;
  export let isPrivateChat = false;
  
  $: isOwnMessage = message.userId === currentUser?.id;
  $: isMasterMessage = message.userRole === 'master';
  
  function formatTime(timestamp) {
    return new Date(timestamp).toLocaleTimeString('zh-CN', {
      hour: '2-digit',
      minute: '2-digit'
    });
  }
  
  function getUserDisplayName(message) {
    if (message.userRole === 'master') {
      return '大师';
    } else if (message.userRole === 'firstmate') {
      return '大副';
    } else if (message.username) {
      return message.username;
    } else {
      return `用户${message.userId.slice(-4)}`;
    }
  }
  
  function getMessageBubbleClass(isOwnMessage, isMasterMessage, isPrivateChat) {
    if (isOwnMessage) {
      return 'bg-blue-500 text-white ml-auto';
    } else if (isMasterMessage && isPrivateChat) {
      // Master在私聊中的黄色气泡样式
      return 'bg-yellow-400 text-gray-900 mr-auto';
    } else {
      return 'bg-gray-200 text-gray-900 mr-auto';
    }
  }
  
  function getAvatarClass(userRole) {
    if (userRole === 'master') {
      return 'bg-yellow-500 text-white';
    } else if (userRole === 'firstmate') {
      return 'bg-purple-500 text-white';
    } else {
      return 'bg-gray-500 text-white';
    }
  }
</script>

<div class="flex items-start space-x-2 mb-4 {isOwnMessage ? 'flex-row-reverse space-x-reverse' : ''}">
  <!-- 头像 -->
  <div class="flex-shrink-0">
    <div class="w-8 h-8 rounded-full flex items-center justify-center text-sm font-medium {getAvatarClass(message.userRole)}">
      {getUserDisplayName(message).charAt(0)}
    </div>
  </div>
  
  <!-- 消息内容 -->
  <div class="flex-1 max-w-xs lg:max-w-md">
    <!-- 用户名和时间 -->
    {#if !isOwnMessage}
      <div class="flex items-center space-x-2 mb-1">
        <span class="text-sm font-medium text-gray-700">
          {getUserDisplayName(message)}
        </span>
        {#if message.userRole === 'master'}
          <span class="inline-flex items-center px-1.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800">
            大师
          </span>
        {:else if message.userRole === 'firstmate'}
          <span class="inline-flex items-center px-1.5 py-0.5 rounded-full text-xs font-medium bg-purple-100 text-purple-800">
            大副
          </span>
        {/if}
        <span class="text-xs text-gray-500">
          {formatTime(message.timestamp)}
        </span>
      </div>
    {/if}
    
    <!-- 消息气泡 -->
    <div class="rounded-lg px-3 py-2 {getMessageBubbleClass(isOwnMessage, isMasterMessage, isPrivateChat)}">
      <p class="text-sm whitespace-pre-wrap break-words">
        {message.content}
      </p>
    </div>
    
    <!-- 自己消息的时间 -->
    {#if isOwnMessage}
      <div class="text-right mt-1">
        <span class="text-xs text-gray-500">
          {formatTime(message.timestamp)}
        </span>
      </div>
    {/if}
  </div>
</div>

<style>
  /* 为master的黄色气泡添加特殊样式 */
  .bg-yellow-400 {
    background: linear-gradient(135deg, #fbbf24 0%, #f59e0b 100%);
    box-shadow: 0 2px 4px rgba(251, 191, 36, 0.3);
  }
  
  /* 确保黄色气泡的文字对比度 */
  .bg-yellow-400.text-gray-900 {
    color: #1f2937;
    font-weight: 500;
  }
</style> 