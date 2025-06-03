<script>
  import { createEventDispatcher } from 'svelte';
  import Button from './Button.svelte';
  
  export let userId = '';
  export let isFollowing = false;
  export let isLoading = false;
  export let showCount = false;
  export let followerCount = 0;
  export let variant = 'default'; // default, compact, icon-only
  export let size = 'md'; // xs, sm, md, lg
  export let disabled = false;
  export let customText = null;
  export let showIcon = true;
  export let animate = true;
  
  const dispatch = createEventDispatcher();
  
  let isHovered = false;
  let isPressed = false;
  let hasJustFollowed = false;
  let hasJustUnfollowed = false;
  
  // 计算属性
  $: buttonText = getButtonText();
  $: buttonIcon = getButtonIcon();
  $: buttonVariant = getButtonVariant();
  $: formattedCount = formatFollowerCount(followerCount);
  
  function getButtonText() {
    if (customText) return customText;
    if (variant === 'icon-only') return '';
    
    if (isLoading) return '处理中...';
    
    if (isFollowing) {
      if (isHovered) return '取消关注';
      return '已关注';
    }
    
    return '关注';
  }
  
  function getButtonIcon() {
    if (!showIcon) return '';
    if (variant === 'icon-only') {
      return isFollowing ? '✓' : '+';
    }
    
    if (isLoading) return '⏳';
    if (isFollowing) {
      return isHovered ? '×' : '✓';
    }
    return '+';
  }
  
  function getButtonVariant() {
    if (disabled) return 'outline';
    if (isFollowing) {
      return isHovered ? 'danger' : 'outline';
    }
    return 'primary';
  }
  
  function formatFollowerCount(count) {
    if (!showCount) return '';
    if (count >= 1000000) {
      return Math.floor(count / 100000) / 10 + 'M';
    } else if (count >= 1000) {
      return Math.floor(count / 100) / 10 + 'K';
    }
    return count.toString();
  }
  
  async function handleClick() {
    if (disabled || isLoading) return;
    
    const wasFollowing = isFollowing;
    
    try {
      dispatch('click', { 
        userId, 
        action: wasFollowing ? 'unfollow' : 'follow',
        isFollowing: !wasFollowing
      });
      
      // 触发动画效果
      if (animate) {
        if (wasFollowing) {
          hasJustUnfollowed = true;
          setTimeout(() => hasJustUnfollowed = false, 600);
        } else {
          hasJustFollowed = true;
          setTimeout(() => hasJustFollowed = false, 600);
        }
      }
      
    } catch (error) {
      console.error('关注操作失败:', error);
      dispatch('error', { error, userId });
    }
  }
  
  function handleMouseEnter() {
    isHovered = true;
  }
  
  function handleMouseLeave() {
    isHovered = false;
  }
  
  function handleMouseDown() {
    isPressed = true;
  }
  
  function handleMouseUp() {
    isPressed = false;
  }
  
  function handleKeyDown(event) {
    if (event.key === 'Enter' || event.key === ' ') {
      event.preventDefault();
      handleClick();
    }
  }
</script>

<div class="follow-button-wrapper" class:compact={variant === 'compact'} class:icon-only={variant === 'icon-only'}>
  <button
    class="follow-button"
    class:following={isFollowing}
    class:loading={isLoading}
    class:hovered={isHovered}
    class:pressed={isPressed}
    class:just-followed={hasJustFollowed}
    class:just-unfollowed={hasJustUnfollowed}
    class:size-xs={size === 'xs'}
    class:size-sm={size === 'sm'}
    class:size-md={size === 'md'}
    class:size-lg={size === 'lg'}
    {disabled}
    on:click={handleClick}
    on:mouseenter={handleMouseEnter}
    on:mouseleave={handleMouseLeave}
    on:mousedown={handleMouseDown}
    on:mouseup={handleMouseUp}
    on:keydown={handleKeyDown}
    aria-label={isFollowing ? '取消关注' : '关注'}
    aria-pressed={isFollowing}
  >
    <!-- 背景动画 -->
    {#if animate}
      <div class="button-bg"></div>
      <div class="ripple-effect" class:active={hasJustFollowed || hasJustUnfollowed}></div>
    {/if}
    
    <!-- 按钮内容 -->
    <div class="button-content">
      {#if buttonIcon}
        <span class="button-icon" class:spinning={isLoading}>
          {buttonIcon}
        </span>
      {/if}
      
      {#if buttonText && variant !== 'icon-only'}
        <span class="button-text">
          {buttonText}
        </span>
      {/if}
      
      {#if showCount && followerCount > 0 && variant !== 'icon-only'}
        <span class="follower-count">
          ({formattedCount})
        </span>
      {/if}
    </div>
    
    <!-- 加载指示器 -->
    {#if isLoading}
      <div class="loading-overlay">
        <div class="loading-spinner"></div>
      </div>
    {/if}
    
    <!-- 成功动画 -->
    {#if hasJustFollowed}
      <div class="success-animation">
        <div class="success-icon">♥</div>
      </div>
    {/if}
  </button>
  
  <!-- 工具提示 -->
  {#if variant === 'icon-only'}
    <div class="tooltip">
      {isFollowing ? '已关注' : '点击关注'}
    </div>
  {/if}
</div>

<style>
  .follow-button-wrapper {
    position: relative;
    display: inline-block;
  }
  
  .follow-button {
    position: relative;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    color: white;
    border: none;
    border-radius: 24px;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
    overflow: hidden;
    outline: none;
    user-select: none;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 6px;
    min-width: 80px;
  }
  
  /* 尺寸变体 */
  .follow-button.size-xs {
    padding: 4px 12px;
    font-size: 12px;
    border-radius: 16px;
    min-width: 60px;
    gap: 4px;
  }
  
  .follow-button.size-sm {
    padding: 6px 16px;
    font-size: 13px;
    border-radius: 20px;
    min-width: 70px;
    gap: 5px;
  }
  
  .follow-button.size-md {
    padding: 8px 20px;
    font-size: 14px;
    min-width: 80px;
  }
  
  .follow-button.size-lg {
    padding: 12px 24px;
    font-size: 16px;
    border-radius: 28px;
    min-width: 100px;
    gap: 8px;
  }
  
  /* 紧凑变体 */
  .compact .follow-button {
    min-width: auto;
    padding: 6px 12px;
  }
  
  /* 仅图标变体 */
  .icon-only .follow-button {
    min-width: auto;
    width: 36px;
    height: 36px;
    border-radius: 50%;
    padding: 0;
  }
  
  .icon-only.size-xs .follow-button {
    width: 28px;
    height: 28px;
  }
  
  .icon-only.size-sm .follow-button {
    width: 32px;
    height: 32px;
  }
  
  .icon-only.size-lg .follow-button {
    width: 44px;
    height: 44px;
  }
  
  /* 已关注状态 */
  .follow-button.following {
    background: #f3f4f6;
    color: #374151;
    border: 1px solid #d1d5db;
  }
  
  .follow-button.following.hovered {
    background: linear-gradient(135deg, #ef4444 0%, #dc2626 100%);
    color: white;
    border-color: #ef4444;
  }
  
  /* 悬停效果 */
  .follow-button:hover:not(:disabled) {
    transform: translateY(-1px);
    box-shadow: 0 4px 20px rgba(102, 126, 234, 0.4);
  }
  
  .follow-button.following:hover:not(:disabled) {
    box-shadow: 0 4px 20px rgba(239, 68, 68, 0.4);
  }
  
  /* 按下效果 */
  .follow-button.pressed {
    transform: translateY(0) scale(0.95);
  }
  
  /* 禁用状态 */
  .follow-button:disabled {
    opacity: 0.6;
    cursor: not-allowed;
    transform: none !important;
    box-shadow: none !important;
  }
  
  /* 背景动画 */
  .button-bg {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: inherit;
    z-index: 0;
  }
  
  .ripple-effect {
    position: absolute;
    top: 50%;
    left: 50%;
    width: 0;
    height: 0;
    background: rgba(255, 255, 255, 0.5);
    border-radius: 50%;
    transform: translate(-50%, -50%);
    pointer-events: none;
    z-index: 1;
  }
  
  .ripple-effect.active {
    animation: ripple 0.6s ease-out;
  }
  
  @keyframes ripple {
    from {
      width: 0;
      height: 0;
      opacity: 1;
    }
    to {
      width: 200px;
      height: 200px;
      opacity: 0;
    }
  }
  
  /* 按钮内容 */
  .button-content {
    position: relative;
    display: flex;
    align-items: center;
    gap: inherit;
    z-index: 2;
  }
  
  .button-icon {
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 1.1em;
    line-height: 1;
    transition: transform 0.3s ease;
  }
  
  .button-icon.spinning {
    animation: spin 1s linear infinite;
  }
  
  @keyframes spin {
    from { transform: rotate(0deg); }
    to { transform: rotate(360deg); }
  }
  
  .button-text {
    white-space: nowrap;
    transition: all 0.3s ease;
  }
  
  .follower-count {
    font-size: 0.9em;
    opacity: 0.8;
    font-weight: 500;
  }
  
  /* 加载状态 */
  .loading-overlay {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.1);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 3;
  }
  
  .loading-spinner {
    width: 16px;
    height: 16px;
    border: 2px solid rgba(255, 255, 255, 0.3);
    border-top: 2px solid white;
    border-radius: 50%;
    animation: spin 1s linear infinite;
  }
  
  /* 成功动画 */
  .success-animation {
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    z-index: 4;
    pointer-events: none;
  }
  
  .success-icon {
    font-size: 20px;
    color: #ef4444;
    animation: heartBeat 0.6s ease-out;
  }
  
  @keyframes heartBeat {
    0% {
      transform: scale(0);
      opacity: 0;
    }
    50% {
      transform: scale(1.3);
      opacity: 1;
    }
    100% {
      transform: scale(1);
      opacity: 0;
    }
  }
  
  /* 刚关注动画 */
  .follow-button.just-followed {
    animation: followSuccess 0.6s ease-out;
  }
  
  @keyframes followSuccess {
    0% { transform: scale(1); }
    50% { transform: scale(1.1); }
    100% { transform: scale(1); }
  }
  
  /* 刚取消关注动画 */
  .follow-button.just-unfollowed {
    animation: unfollowShake 0.6s ease-out;
  }
  
  @keyframes unfollowShake {
    0%, 100% { transform: translateX(0); }
    25% { transform: translateX(-2px); }
    75% { transform: translateX(2px); }
  }
  
  /* 工具提示 */
  .tooltip {
    position: absolute;
    bottom: 100%;
    left: 50%;
    transform: translateX(-50%);
    background: #1f2937;
    color: white;
    padding: 6px 10px;
    border-radius: 6px;
    font-size: 12px;
    white-space: nowrap;
    opacity: 0;
    visibility: hidden;
    transition: all 0.2s ease;
    z-index: 10;
    margin-bottom: 8px;
  }
  
  .tooltip::after {
    content: '';
    position: absolute;
    top: 100%;
    left: 50%;
    transform: translateX(-50%);
    border: 4px solid transparent;
    border-top-color: #1f2937;
  }
  
  .follow-button-wrapper:hover .tooltip {
    opacity: 1;
    visibility: visible;
  }
  
  /* 焦点样式 */
  .follow-button:focus-visible {
    box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.3);
  }
  
  /* 移动端适配 */
  @media (max-width: 640px) {
    .follow-button {
      min-width: 70px;
    }
    
    .follow-button.size-xs {
      min-width: 50px;
    }
    
    .follow-button.size-lg {
      min-width: 90px;
    }
    
    .tooltip {
      font-size: 11px;
      padding: 4px 8px;
    }
  }
  
  /* 高对比度模式 */
  @media (prefers-contrast: high) {
    .follow-button {
      border: 2px solid currentColor;
    }
    
    .follow-button.following {
      border: 2px solid #374151;
    }
  }
  
  /* 减少动画模式 */
  @media (prefers-reduced-motion: reduce) {
    .follow-button,
    .button-icon,
    .button-text,
    .ripple-effect,
    .tooltip {
      transition: none;
      animation: none;
    }
  }
  
  /* 暗色主题 */
  @media (prefers-color-scheme: dark) {
    .follow-button.following {
      background: #374151;
      color: #d1d5db;
      border-color: #4b5563;
    }
    
    .follow-button.following.hovered {
      background: linear-gradient(135deg, #ef4444 0%, #dc2626 100%);
      color: white;
    }
    
    .tooltip {
      background: #374151;
      color: #f9fafb;
    }
    
    .tooltip::after {
      border-top-color: #374151;
    }
  }
</style> 