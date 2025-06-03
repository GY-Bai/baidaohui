<script>
  import { createEventDispatcher } from 'svelte';
  import Avatar from '$lib/components/ui/Avatar.svelte';
  import Badge from '$lib/components/ui/Badge.svelte';
  
  export let message = {};
  export let isOwn = false;
  export let showAvatar = true;
  export let showTime = true;
  export let isGroup = false;
  export let previousMessage = null;
  export let nextMessage = null;
  
  const dispatch = createEventDispatcher();
  
  // 消息类型配置
  const messageTypes = {
    text: '文本',
    image: '图片',
    voice: '语音',
    video: '视频',
    file: '文件',
    location: '位置',
    system: '系统消息'
  };
  
  // 检查是否需要显示用户名（群聊中非自己的消息）
  $: showSenderName = isGroup && !isOwn;
  
  // 检查是否与前一条消息是同一用户
  $: isContinuous = previousMessage && 
    previousMessage.senderId === message.senderId &&
    (new Date(message.timestamp) - new Date(previousMessage.timestamp)) < 60000; // 1分钟内
  
  // 检查是否需要显示时间
  $: shouldShowTime = showTime && (!isContinuous || 
    (nextMessage && nextMessage.senderId !== message.senderId));
  
  function handleMessageClick() {
    dispatch('click', { message });
  }
  
  function handleAvatarClick() {
    dispatch('avatarClick', { user: message.sender });
  }
  
  function handleImageClick(imageUrl) {
    dispatch('imageClick', { imageUrl, message });
  }
  
  function handleVoicePlay() {
    dispatch('voicePlay', { message });
  }
  
  function handleRetry() {
    dispatch('retry', { message });
  }
  
  function formatTime(timestamp) {
    const date = new Date(timestamp);
    return date.toLocaleTimeString('zh-CN', {
      hour: '2-digit',
      minute: '2-digit'
    });
  }
  
  function formatFileSize(bytes) {
    if (!bytes) return '';
    const sizes = ['B', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(1024));
    return Math.round(bytes / Math.pow(1024, i) * 100) / 100 + ' ' + sizes[i];
  }
  
  function formatDuration(seconds) {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  }
</script>

<div 
  class="chat-message"
  class:own={isOwn}
  class:continuous={isContinuous}
  class:group={isGroup}
  on:click={handleMessageClick}
>
  <!-- 头像区域 -->
  {#if showAvatar && !isOwn && (!isContinuous || !previousMessage)}
    <div class="avatar-section">
      <Avatar
        src={message.sender?.avatar}
        alt={message.sender?.name}
        size="sm"
        showOnlineStatus={false}
        on:click={handleAvatarClick}
      />
    </div>
  {:else if showAvatar && !isOwn}
    <div class="avatar-spacer"></div>
  {/if}
  
  <!-- 消息内容区域 -->
  <div class="message-content">
    <!-- 发送者名称 -->
    {#if showSenderName && (!isContinuous || !previousMessage)}
      <div class="sender-name">{message.sender?.name}</div>
    {/if}
    
    <!-- 消息气泡 -->
    <div 
      class="message-bubble"
      class:own={isOwn}
      class:failed={message.status === 'failed'}
    >
      <!-- 文本消息 -->
      {#if message.type === 'text'}
        <div class="text-content">
          {message.content}
        </div>
      
      <!-- 图片消息 -->
      {:else if message.type === 'image'}
        <div class="image-content">
          <img 
            src={message.imageUrl} 
            alt="图片消息"
            on:click={() => handleImageClick(message.imageUrl)}
            loading="lazy"
          />
          {#if message.caption}
            <div class="image-caption">{message.caption}</div>
          {/if}
        </div>
      
      <!-- 语音消息 -->
      {:else if message.type === 'voice'}
        <div class="voice-content">
          <button class="voice-play-btn" on:click={handleVoicePlay}>
            {#if message.isPlaying}
              ⏸️
            {:else}
              ▶️
            {/if}
          </button>
          <div class="voice-waveform">
            <div class="waveform-bars">
              {#each Array(12) as _, i}
                <div 
                  class="waveform-bar"
                  style="height: {Math.random() * 20 + 5}px;"
                ></div>
              {/each}
            </div>
          </div>
          <span class="voice-duration">{formatDuration(message.duration || 0)}</span>
        </div>
      
      <!-- 文件消息 -->
      {:else if message.type === 'file'}
        <div class="file-content">
          <div class="file-icon">📎</div>
          <div class="file-info">
            <div class="file-name">{message.fileName}</div>
            <div class="file-size">{formatFileSize(message.fileSize)}</div>
          </div>
          <button class="file-download-btn" title="下载">
            ⬇️
          </button>
        </div>
      
      <!-- 位置消息 -->
      {:else if message.type === 'location'}
        <div class="location-content">
          <div class="location-preview">
            <div class="location-icon">📍</div>
            <div class="location-text">位置信息</div>
          </div>
          <div class="location-address">{message.address}</div>
        </div>
      
      <!-- 系统消息 -->
      {:else if message.type === 'system'}
        <div class="system-content">
          {message.content}
        </div>
      {/if}
      
      <!-- 消息状态指示器 -->
      {#if isOwn && message.type !== 'system'}
        <div class="message-status">
          {#if message.status === 'sending'}
            <div class="status-indicator sending">⏳</div>
          {:else if message.status === 'sent'}
            <div class="status-indicator sent">✓</div>
          {:else if message.status === 'delivered'}
            <div class="status-indicator delivered">✓✓</div>
          {:else if message.status === 'read'}
            <div class="status-indicator read">✓✓</div>
          {:else if message.status === 'failed'}
            <button class="status-indicator failed" on:click={handleRetry}>
              ⚠️
            </button>
          {/if}
        </div>
      {/if}
    </div>
    
    <!-- 时间戳 -->
    {#if shouldShowTime}
      <div class="message-time" class:own={isOwn}>
        {formatTime(message.timestamp)}
      </div>
    {/if}
  </div>
</div>

<style>
  .chat-message {
    display: flex;
    gap: 8px;
    margin-bottom: 4px;
    max-width: 100%;
    animation: messageSlideIn 0.3s ease-out;
  }
  
  .chat-message.continuous {
    margin-bottom: 2px;
  }
  
  .chat-message.own {
    flex-direction: row-reverse;
  }
  
  @keyframes messageSlideIn {
    from {
      opacity: 0;
      transform: translateY(10px);
    }
    to {
      opacity: 1;
      transform: translateY(0);
    }
  }
  
  /* 头像区域 */
  .avatar-section {
    flex-shrink: 0;
    cursor: pointer;
  }
  
  .avatar-spacer {
    width: 40px;
    flex-shrink: 0;
  }
  
  /* 消息内容区域 */
  .message-content {
    flex: 1;
    max-width: calc(100% - 60px);
    min-width: 0;
  }
  
  .chat-message.own .message-content {
    display: flex;
    flex-direction: column;
    align-items: flex-end;
  }
  
  /* 发送者名称 */
  .sender-name {
    font-size: 12px;
    color: #6b7280;
    margin-bottom: 4px;
    font-weight: 500;
  }
  
  /* 消息气泡 */
  .message-bubble {
    position: relative;
    max-width: 280px;
    padding: 12px 16px;
    border-radius: 18px;
    background: #f3f4f6;
    color: #111827;
    word-wrap: break-word;
    box-shadow: 0 1px 2px rgba(0, 0, 0, 0.1);
  }
  
  .message-bubble.own {
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    color: white;
    border-bottom-right-radius: 6px;
  }
  
  .message-bubble:not(.own) {
    border-bottom-left-radius: 6px;
  }
  
  .message-bubble.failed {
    background: #fef2f2;
    border: 1px solid #fecaca;
    color: #dc2626;
  }
  
  /* 文本内容 */
  .text-content {
    font-size: 14px;
    line-height: 1.4;
    white-space: pre-wrap;
  }
  
  /* 图片内容 */
  .image-content {
    padding: 0;
    border-radius: 12px;
    overflow: hidden;
    max-width: 200px;
  }
  
  .image-content img {
    width: 100%;
    height: auto;
    display: block;
    cursor: pointer;
    transition: transform 0.2s ease;
  }
  
  .image-content img:hover {
    transform: scale(1.02);
  }
  
  .image-caption {
    padding: 8px 12px;
    font-size: 13px;
    background: rgba(0, 0, 0, 0.05);
  }
  
  .message-bubble.own .image-caption {
    background: rgba(255, 255, 255, 0.1);
  }
  
  /* 语音内容 */
  .voice-content {
    display: flex;
    align-items: center;
    gap: 8px;
    min-width: 120px;
    padding: 8px 12px;
  }
  
  .voice-play-btn {
    background: none;
    border: none;
    font-size: 16px;
    cursor: pointer;
    padding: 4px;
    border-radius: 50%;
    transition: background 0.2s ease;
  }
  
  .voice-play-btn:hover {
    background: rgba(0, 0, 0, 0.1);
  }
  
  .message-bubble.own .voice-play-btn:hover {
    background: rgba(255, 255, 255, 0.2);
  }
  
  .voice-waveform {
    flex: 1;
    height: 20px;
    display: flex;
    align-items: center;
  }
  
  .waveform-bars {
    display: flex;
    align-items: center;
    gap: 2px;
    height: 100%;
  }
  
  .waveform-bar {
    width: 3px;
    background: #6b7280;
    border-radius: 2px;
    transition: background 0.2s ease;
  }
  
  .message-bubble.own .waveform-bar {
    background: rgba(255, 255, 255, 0.7);
  }
  
  .voice-duration {
    font-size: 12px;
    color: #6b7280;
    font-weight: 500;
  }
  
  .message-bubble.own .voice-duration {
    color: rgba(255, 255, 255, 0.8);
  }
  
  /* 文件内容 */
  .file-content {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 8px 12px;
    min-width: 180px;
  }
  
  .file-icon {
    font-size: 24px;
    opacity: 0.8;
  }
  
  .file-info {
    flex: 1;
  }
  
  .file-name {
    font-size: 14px;
    font-weight: 500;
    margin-bottom: 2px;
  }
  
  .file-size {
    font-size: 12px;
    opacity: 0.7;
  }
  
  .file-download-btn {
    background: none;
    border: none;
    font-size: 16px;
    cursor: pointer;
    padding: 4px;
    border-radius: 4px;
    transition: background 0.2s ease;
  }
  
  .file-download-btn:hover {
    background: rgba(0, 0, 0, 0.1);
  }
  
  .message-bubble.own .file-download-btn:hover {
    background: rgba(255, 255, 255, 0.2);
  }
  
  /* 位置内容 */
  .location-content {
    padding: 8px 12px;
    min-width: 160px;
  }
  
  .location-preview {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-bottom: 4px;
  }
  
  .location-icon {
    font-size: 16px;
  }
  
  .location-text {
    font-size: 14px;
    font-weight: 500;
  }
  
  .location-address {
    font-size: 12px;
    opacity: 0.7;
    line-height: 1.3;
  }
  
  /* 系统消息 */
  .message-bubble .system-content {
    font-size: 12px;
    text-align: center;
    color: #6b7280;
    background: #f9fafb;
    border: 1px solid #e5e7eb;
    border-radius: 12px;
    padding: 8px 12px;
    max-width: none;
  }
  
  /* 消息状态 */
  .message-status {
    position: absolute;
    bottom: 4px;
    right: 8px;
    font-size: 10px;
  }
  
  .status-indicator {
    background: none;
    border: none;
    padding: 0;
    cursor: default;
    opacity: 0.7;
  }
  
  .status-indicator.sending {
    color: #6b7280;
  }
  
  .status-indicator.sent {
    color: #6b7280;
  }
  
  .status-indicator.delivered {
    color: #3b82f6;
  }
  
  .status-indicator.read {
    color: #10b981;
  }
  
  .status-indicator.failed {
    color: #dc2626;
    cursor: pointer;
  }
  
  /* 时间戳 */
  .message-time {
    font-size: 11px;
    color: #9ca3af;
    margin-top: 4px;
    text-align: left;
  }
  
  .message-time.own {
    text-align: right;
  }
  
  /* 移动端适配 */
  @media (max-width: 640px) {
    .message-bubble {
      max-width: 240px;
      padding: 10px 14px;
    }
    
    .text-content {
      font-size: 13px;
    }
    
    .image-content {
      max-width: 180px;
    }
    
    .voice-content {
      min-width: 100px;
    }
    
    .file-content {
      min-width: 160px;
    }
    
    .location-content {
      min-width: 140px;
    }
    
    .message-content {
      max-width: calc(100% - 50px);
    }
    
    .avatar-spacer {
      width: 32px;
    }
  }
</style> 