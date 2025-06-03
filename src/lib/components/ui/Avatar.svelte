<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  
  export let src = ''; // 头像图片地址
  export let alt = ''; // 图片替代文本
  export let size = 'default'; // xs, sm, default, lg, xl, 2xl
  export let shape = 'circle'; // circle, square, rounded
  export let status = null; // online, offline, busy, away
  export let showStatus = false; // 显示状态指示器
  export let fallback = ''; // 备用文本或图标
  export let placeholder = true; // 显示占位符
  export let bordered = false; // 边框
  export let clickable = false; // 可点击
  export let loading = false; // 加载状态
  export let className = '';
  export let statusPosition = 'bottom-right'; // top-left, top-right, bottom-left, bottom-right
  
  const dispatch = createEventDispatcher();
  
  let imageLoaded = false;
  let imageError = false;
  let imageElement;
  
  // 尺寸配置
  const sizes = {
    xs: { size: '24px', fontSize: '10px', statusSize: '6px' },
    sm: { size: '32px', fontSize: '12px', statusSize: '8px' },
    default: { size: '40px', fontSize: '14px', statusSize: '10px' },
    lg: { size: '48px', fontSize: '16px', statusSize: '12px' },
    xl: { size: '64px', fontSize: '20px', statusSize: '16px' },
    '2xl': { size: '80px', fontSize: '24px', statusSize: '20px' }
  };
  
  // 状态颜色
  const statusColors = {
    online: '#16a34a',
    offline: '#6b7280',
    busy: '#ef4444',
    away: '#f59e0b'
  };
  
  $: currentSize = sizes[size];
  $: currentStatusColor = statusColors[status];
  $: showImage = src && !imageError;
  $: showFallback = !showImage && (fallback || placeholder);
  
  // 从alt或fallback生成首字母
  $: initials = (() => {
    const text = fallback || alt || '用户';
    return text
      .split(' ')
      .map(word => word.charAt(0))
      .join('')
      .substring(0, 2)
      .toUpperCase();
  })();
  
  $: avatarClasses = [
    'avatar',
    `avatar-${size}`,
    `avatar-${shape}`,
    bordered && 'avatar-bordered',
    clickable && 'avatar-clickable',
    loading && 'avatar-loading',
    showStatus && 'avatar-with-status',
    className
  ].filter(Boolean).join(' ');
  
  function handleImageLoad() {
    imageLoaded = true;
    imageError = false;
    dispatch('load');
  }
  
  function handleImageError() {
    imageLoaded = false;
    imageError = true;
    dispatch('error');
  }
  
  function handleClick(event) {
    if (clickable) {
      dispatch('click', { event });
    }
  }
  
  function handleKeydown(event) {
    if (clickable && (event.key === 'Enter' || event.key === ' ')) {
      event.preventDefault();
      handleClick(event);
    }
  }
</script>

<div
  class={avatarClasses}
  style="width: {currentSize.size}; height: {currentSize.size}; font-size: {currentSize.fontSize}"
  on:click={handleClick}
  on:keydown={handleKeydown}
  role={clickable ? 'button' : 'img'}
  tabindex={clickable ? 0 : -1}
  aria-label={alt || '头像'}
>
  <!-- 头像内容 -->
  <div class="avatar-content">
    {#if showImage}
      <!-- 头像图片 -->
      <img
        bind:this={imageElement}
        {src}
        {alt}
        class="avatar-image"
        on:load={handleImageLoad}
        on:error={handleImageError}
      />
    {:else if showFallback}
      <!-- 备用内容 -->
      <div class="avatar-fallback">
        {#if fallback}
          {fallback}
        {:else}
          {initials}
        {/if}
      </div>
    {:else}
      <!-- 默认占位符 -->
      <div class="avatar-placeholder">
        <svg viewBox="0 0 24 24" class="avatar-placeholder-icon">
          <path fill="currentColor" d="M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z"/>
        </svg>
      </div>
    {/if}
    
    <!-- 加载状态 -->
    {#if loading}
      <div class="avatar-loading-overlay">
        <div class="avatar-spinner"></div>
      </div>
    {/if}
  </div>
  
  <!-- 状态指示器 -->
  {#if showStatus && status}
    <div
      class="avatar-status avatar-status-{statusPosition}"
      style="background-color: {currentStatusColor}; width: {currentSize.statusSize}; height: {currentSize.statusSize}"
      aria-label="状态: {status}"
    ></div>
  {/if}
</div>

<style>
  .avatar {
    position: relative;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
    border-radius: 50%;
    overflow: hidden;
    background-color: #f3f4f6;
    transition: all 0.2s ease;
    cursor: default;
  }
  
  /* 形状样式 */
  .avatar-circle {
    border-radius: 50%;
  }
  
  .avatar-square {
    border-radius: 0;
  }
  
  .avatar-rounded {
    border-radius: 8px;
  }
  
  /* 尺寸样式 */
  .avatar-xs {
    width: 24px;
    height: 24px;
    font-size: 10px;
  }
  
  .avatar-sm {
    width: 32px;
    height: 32px;
    font-size: 12px;
  }
  
  .avatar-default {
    width: 40px;
    height: 40px;
    font-size: 14px;
  }
  
  .avatar-lg {
    width: 48px;
    height: 48px;
    font-size: 16px;
  }
  
  .avatar-xl {
    width: 64px;
    height: 64px;
    font-size: 20px;
  }
  
  .avatar-2xl {
    width: 80px;
    height: 80px;
    font-size: 24px;
  }
  
  /* 边框样式 */
  .avatar-bordered {
    border: 2px solid #ffffff;
    box-shadow: 0 0 0 1px rgba(0, 0, 0, 0.1);
  }
  
  /* 可点击样式 */
  .avatar-clickable {
    cursor: pointer;
  }
  
  .avatar-clickable:hover {
    transform: scale(1.05);
  }
  
  .avatar-clickable:active {
    transform: scale(0.95);
  }
  
  .avatar-clickable:focus {
    outline: none;
    box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.3);
  }
  
  /* 内容容器 */
  .avatar-content {
    width: 100%;
    height: 100%;
    position: relative;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  
  /* 头像图片 */
  .avatar-image {
    width: 100%;
    height: 100%;
    object-fit: cover;
    border-radius: inherit;
  }
  
  /* 备用内容 */
  .avatar-fallback {
    width: 100%;
    height: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    color: white;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }
  
  /* 占位符 */
  .avatar-placeholder {
    width: 100%;
    height: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
    background-color: #e5e7eb;
    color: #9ca3af;
  }
  
  .avatar-placeholder-icon {
    width: 60%;
    height: 60%;
  }
  
  /* 加载状态 */
  .avatar-loading .avatar-content::after {
    content: '';
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(255, 255, 255, 0.8);
    border-radius: inherit;
  }
  
  .avatar-loading-overlay {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    background: rgba(255, 255, 255, 0.9);
    border-radius: inherit;
  }
  
  .avatar-spinner {
    width: 50%;
    height: 50%;
    border: 2px solid #e5e7eb;
    border-top: 2px solid #3b82f6;
    border-radius: 50%;
    animation: avatarSpin 1s linear infinite;
  }
  
  @keyframes avatarSpin {
    0% {
      transform: rotate(0deg);
    }
    100% {
      transform: rotate(360deg);
    }
  }
  
  /* 状态指示器 */
  .avatar-status {
    position: absolute;
    border: 2px solid #ffffff;
    border-radius: 50%;
    z-index: 1;
  }
  
  .avatar-status-top-left {
    top: 0;
    left: 0;
  }
  
  .avatar-status-top-right {
    top: 0;
    right: 0;
  }
  
  .avatar-status-bottom-left {
    bottom: 0;
    left: 0;
  }
  
  .avatar-status-bottom-right {
    bottom: 0;
    right: 0;
  }
  
  /* 状态指示器尺寸适配 */
  .avatar-xs .avatar-status {
    width: 6px;
    height: 6px;
    border-width: 1px;
  }
  
  .avatar-sm .avatar-status {
    width: 8px;
    height: 8px;
    border-width: 1px;
  }
  
  .avatar-default .avatar-status {
    width: 10px;
    height: 10px;
    border-width: 2px;
  }
  
  .avatar-lg .avatar-status {
    width: 12px;
    height: 12px;
    border-width: 2px;
  }
  
  .avatar-xl .avatar-status {
    width: 16px;
    height: 16px;
    border-width: 2px;
  }
  
  .avatar-2xl .avatar-status {
    width: 20px;
    height: 20px;
    border-width: 3px;
  }
  
  /* 头像组 */
  .avatar-group {
    display: flex;
    align-items: center;
  }
  
  .avatar-group .avatar {
    margin-left: -8px;
    border: 2px solid #ffffff;
    position: relative;
    z-index: 1;
  }
  
  .avatar-group .avatar:first-child {
    margin-left: 0;
  }
  
  .avatar-group .avatar:hover {
    z-index: 2;
  }
  
  /* 移动端适配 */
  @media (max-width: 768px) {
    .avatar-clickable:hover {
      transform: none;
    }
    
    .avatar-clickable:active {
      transform: scale(0.95);
    }
    
    .avatar-group .avatar {
      margin-left: -6px;
    }
  }
  
  /* 高对比度模式 */
  @media (prefers-contrast: high) {
    .avatar-bordered {
      border-width: 3px;
      border-color: #000;
    }
    
    .avatar-status {
      border-width: 3px;
      border-color: #000;
    }
    
    .avatar-placeholder {
      background-color: #000;
      color: #fff;
    }
  }
  
  /* 减少动画模式 */
  @media (prefers-reduced-motion: reduce) {
    .avatar {
      transition: none;
    }
    
    .avatar-clickable:hover {
      transform: none;
    }
    
    .avatar-clickable:active {
      transform: none;
    }
    
    .avatar-spinner {
      animation: none;
    }
  }
  
  /* 深色模式 */
  @media (prefers-color-scheme: dark) {
    .avatar {
      background-color: #374151;
    }
    
    .avatar-bordered {
      border-color: #1f2937;
      box-shadow: 0 0 0 1px rgba(255, 255, 255, 0.1);
    }
    
    .avatar-placeholder {
      background-color: #4b5563;
      color: #d1d5db;
    }
    
    .avatar-fallback {
      background: linear-gradient(135deg, #4f46e5 0%, #7c3aed 100%);
    }
    
    .avatar-loading-overlay {
      background: rgba(0, 0, 0, 0.8);
    }
    
    .avatar-spinner {
      border-color: #4b5563;
      border-top-color: #60a5fa;
    }
    
    .avatar-status {
      border-color: #1f2937;
    }
    
    .avatar-group .avatar {
      border-color: #1f2937;
    }
  }
  
  /* 悬停放大效果 */
  .avatar-hover-grow:hover {
    transform: scale(1.1);
  }
  
  /* 脉冲效果 */
  .avatar-pulse {
    animation: avatarPulse 2s infinite;
  }
  
  @keyframes avatarPulse {
    0%, 100% {
      opacity: 1;
    }
    50% {
      opacity: 0.7;
    }
  }
  
  /* 渐变边框效果 */
  .avatar-gradient-border {
    background: linear-gradient(45deg, #ff6b6b, #4ecdc4, #45b7d1, #96ceb4);
    padding: 2px;
  }
  
  .avatar-gradient-border .avatar-content {
    background: white;
    border-radius: inherit;
  }
  
  /* 故事圈效果（类似Instagram） */
  .avatar-story {
    background: linear-gradient(45deg, #f09433 0%, #e6683c 25%, #dc2743 50%, #cc2366 75%, #bc1888 100%);
    padding: 3px;
  }
  
  .avatar-story .avatar-content {
    background: white;
    border-radius: inherit;
    padding: 2px;
  }
  
  .avatar-story.avatar-viewed {
    background: #d1d5db;
  }
</style> 