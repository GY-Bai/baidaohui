<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import Avatar from '$lib/components/ui/Avatar.svelte';
  import OnlineStatusIndicator from '$lib/components/business/OnlineStatusIndicator.svelte';
  import Badge from '$lib/components/ui/Badge.svelte';
  import Button from '$lib/components/ui/Button.svelte';
  
  export let user = {
    id: '',
    name: '',
    avatar: '',
    status: 'offline'
  };
  export let chatTitle = '';
  export let isGroup = false;
  export let memberCount = 0;
  export let typing = false;
  export let typingUsers = [];
  export let lastSeen = null;
  export let showActions = true;
  export let actions = [
    { key: 'call', icon: '📞', label: '语音通话' },
    { key: 'video', icon: '📹', label: '视频通话' },
    { key: 'info', icon: 'ℹ️', label: '详细信息' },
    { key: 'more', icon: '⋯', label: '更多' }
  ];
  export let className = '';
  
  const dispatch = createEventDispatcher();
  
  $: displayTitle = chatTitle || user.name || '未知用户';
  $: subtitle = (() => {
    if (typing && typingUsers.length > 0) {
      if (typingUsers.length === 1) {
        return `${typingUsers[0]} 正在输入...`;
      } else {
        return `${typingUsers.length} 人正在输入...`;
      }
    }
    
    if (isGroup) {
      return `${memberCount} 位成员`;
    }
    
    if (user.status === 'online') {
      return '在线';
    }
    
    if (lastSeen) {
      const now = new Date();
      const lastSeenDate = new Date(lastSeen);
      const diffMinutes = Math.floor((now.getTime() - lastSeenDate.getTime()) / (1000 * 60));
      
      if (diffMinutes < 1) return '刚刚在线';
      if (diffMinutes < 60) return `${diffMinutes} 分钟前在线`;
      if (diffMinutes < 1440) return `${Math.floor(diffMinutes / 60)} 小时前在线`;
      return `${Math.floor(diffMinutes / 1440)} 天前在线`;
    }
    
    return '离线';
  })();
  
  function handleBack() {
    dispatch('back');
  }
  
  function handleAction(action) {
    dispatch('action', { action });
  }
  
  function handleAvatarClick() {
    dispatch('avatarClick', { user });
  }
  
  function handleTitleClick() {
    dispatch('titleClick', { user, isGroup });
  }
</script>

<header class="chat-header {className}">
  <!-- 返回按钮 -->
  <Button 
    variant="ghost" 
    size="sm" 
    className="back-button"
    on:click={handleBack}
    aria-label="返回"
  >
    ← 
  </Button>
  
  <!-- 用户信息区域 -->
  <div class="chat-info" on:click={handleTitleClick} role="button" tabindex="0">
    <!-- 头像区域 -->
    <div class="avatar-container">
      <Avatar
        src={user.avatar}
        alt={user.name}
        size="default"
        clickable
        on:click={handleAvatarClick}
      />
      
      <!-- 状态指示器 -->
      {#if !isGroup}
        <OnlineStatusIndicator 
          status={user.status}
          position="bottom-right"
          size="sm"
        />
      {/if}
      
      <!-- 群组标识 -->
      {#if isGroup}
        <div class="group-indicator">
          👥
        </div>
      {/if}
    </div>
    
    <!-- 文本信息 -->
    <div class="chat-text">
      <h2 class="chat-title">{displayTitle}</h2>
      <p class="chat-subtitle" class:typing>
        {#if typing}
          <span class="typing-indicator">
            <span class="typing-dot"></span>
            <span class="typing-dot"></span>
            <span class="typing-dot"></span>
          </span>
        {/if}
        {subtitle}
      </p>
    </div>
  </div>
  
  <!-- 操作按钮区域 -->
  {#if showActions}
    <div class="chat-actions">
      {#each actions as action}
        <Button
          variant="ghost"
          size="sm"
          on:click={() => handleAction(action)}
          title={action.label}
          aria-label={action.label}
        >
          {action.icon}
        </Button>
      {/each}
    </div>
  {/if}
</header>

<style>
  .chat-header {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 16px 20px;
    background: white;
    border-bottom: 1px solid #f3f4f6;
    position: sticky;
    top: 0;
    z-index: 100;
    backdrop-filter: blur(10px);
    background: rgba(255, 255, 255, 0.95);
  }
  
  .back-button {
    flex-shrink: 0;
    width: 40px;
    height: 40px;
    border-radius: 50%;
    font-size: 18px;
  }
  
  .chat-info {
    display: flex;
    align-items: center;
    gap: 12px;
    flex: 1;
    min-width: 0;
    cursor: pointer;
    padding: 8px;
    border-radius: 12px;
    transition: background-color 0.2s ease;
  }
  
  .chat-info:hover {
    background: #f9fafb;
  }
  
  .avatar-container {
    position: relative;
    flex-shrink: 0;
  }
  
  .group-indicator {
    position: absolute;
    bottom: -2px;
    right: -2px;
    width: 20px;
    height: 20px;
    background: white;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 10px;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
    border: 2px solid white;
  }
  
  .chat-text {
    flex: 1;
    min-width: 0;
  }
  
  .chat-title {
    font-size: 16px;
    font-weight: 600;
    color: #111827;
    margin: 0;
    line-height: 1.3;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  
  .chat-subtitle {
    font-size: 13px;
    color: #6b7280;
    margin: 2px 0 0 0;
    line-height: 1.3;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    display: flex;
    align-items: center;
    gap: 6px;
  }
  
  .chat-subtitle.typing {
    color: #16a34a;
    font-weight: 500;
  }
  
  .typing-indicator {
    display: inline-flex;
    align-items: center;
    gap: 2px;
  }
  
  .typing-dot {
    width: 4px;
    height: 4px;
    border-radius: 50%;
    background: #16a34a;
    animation: typingPulse 1.4s infinite ease-in-out;
  }
  
  .typing-dot:nth-child(1) {
    animation-delay: 0s;
  }
  
  .typing-dot:nth-child(2) {
    animation-delay: 0.2s;
  }
  
  .typing-dot:nth-child(3) {
    animation-delay: 0.4s;
  }
  
  @keyframes typingPulse {
    0%, 80%, 100% {
      transform: scale(0.8);
      opacity: 0.5;
    }
    40% {
      transform: scale(1);
      opacity: 1;
    }
  }
  
  .chat-actions {
    display: flex;
    align-items: center;
    gap: 4px;
    flex-shrink: 0;
  }
  
  /* 移动端适配 */
  @media (max-width: 768px) {
    .chat-header {
      padding: 12px 16px;
      gap: 8px;
    }
    
    .chat-info {
      gap: 8px;
      padding: 4px;
    }
    
    .chat-title {
      font-size: 15px;
    }
    
    .chat-subtitle {
      font-size: 12px;
    }
    
    .chat-actions {
      gap: 2px;
    }
    
    .chat-actions :global(.btn) {
      width: 36px;
      height: 36px;
      font-size: 16px;
    }
  }
  
  /* 深色模式 */
  @media (prefers-color-scheme: dark) {
    .chat-header {
      background: rgba(31, 41, 55, 0.95);
      border-bottom-color: #374151;
    }
    
    .chat-title {
      color: #f9fafb;
    }
    
    .chat-subtitle {
      color: #d1d5db;
    }
    
    .chat-info:hover {
      background: #374151;
    }
    
    .group-indicator {
      background: #1f2937;
      border-color: #1f2937;
    }
  }
  
  /* 高对比度模式 */
  @media (prefers-contrast: high) {
    .chat-header {
      border-bottom-width: 2px;
      border-bottom-color: #000;
    }
    
    .chat-title {
      color: #000;
    }
    
    .chat-subtitle {
      color: #333;
    }
  }
  
  /* 减少动画模式 */
  @media (prefers-reduced-motion: reduce) {
    .chat-info {
      transition: none;
    }
    
    .typing-dot {
      animation: none;
      opacity: 1;
      transform: scale(1);
    }
  }
</style> 