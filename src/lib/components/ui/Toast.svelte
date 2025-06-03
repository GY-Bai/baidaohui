<script lang="ts">
  import { createEventDispatcher, onMount } from 'svelte';
  import { fly, scale } from 'svelte/transition';
  import { quintOut } from 'svelte/easing';
  import Button from './Button.svelte';
  
  export let type: 'success' | 'error' | 'warning' | 'info' = 'info';
  export let title: string = '';
  export let message: string = '';
  export let duration: number = 4000; // 0 = 不自动关闭
  export let position: 'top-left' | 'top-center' | 'top-right' | 'bottom-left' | 'bottom-center' | 'bottom-right' = 'top-right';
  export let closable: boolean = true;
  export let icon: string = '';
  export let action: string = '';
  export let visible: boolean = true;
  export let showIcon = true;
  export let actions = [];
  export let progress = false;
  export let className = '';
  
  const dispatch = createEventDispatcher();
  
  let progressWidth = 100;
  let progressInterval: number;
  let timeoutId: number;
  let toastElement;
  
  $: toastClasses = [
    'toast',
    `toast-${type}`,
    `toast-${position}`,
    !closable ? 'toast-no-close' : ''
  ].filter(Boolean).join(' ');
  
  $: defaultIcon = {
    success: '✅',
    error: '❌', 
    warning: '⚠️',
    info: 'ℹ️'
  }[type];
  
  $: displayIcon = icon || defaultIcon;
  
  // 颜色配置
  const colors = {
    success: {
      bg: '#f0fdf4',
      border: '#bbf7d0',
      text: '#15803d',
      icon: '#16a34a'
    },
    error: {
      bg: '#fef2f2',
      border: '#fecaca',
      text: '#dc2626',
      icon: '#ef4444'
    },
    warning: {
      bg: '#fffbeb',
      border: '#fed7aa',
      text: '#d97706',
      icon: '#f59e0b'
    },
    info: {
      bg: '#eff6ff',
      border: '#bfdbfe',
      text: '#2563eb',
      icon: '#3b82f6'
    }
  };
  
  $: currentColors = colors[type];
  
  function handleClose() {
    visible = false;
    dispatch('close');
  }
  
  function handleAction() {
    dispatch('action');
    if (action) {
      handleClose();
    }
  }
  
  function startTimer() {
    if (duration <= 0) return;
    
    const startTime = Date.now();
    const updateProgress = () => {
      const elapsed = Date.now() - startTime;
      const remaining = Math.max(0, duration - elapsed);
      progressWidth = (remaining / duration) * 100;
      
      if (remaining > 0) {
        progressInterval = requestAnimationFrame(updateProgress);
      } else {
        handleClose();
      }
    };
    
    progressInterval = requestAnimationFrame(updateProgress);
    timeoutId = setTimeout(handleClose, duration);
  }
  
  function pauseTimer() {
    if (progressInterval) {
      cancelAnimationFrame(progressInterval);
    }
    if (timeoutId) {
      clearTimeout(timeoutId);
    }
  }
  
  function resumeTimer() {
    startTimer();
  }
  
  onMount(() => {
    if (visible && duration > 0) {
      startTimer();
    }
    
    return () => {
      pauseTimer();
    };
  });
</script>

{#if visible}
  <div 
    bind:this={toastElement}
    class={toastClasses}
    style="--bg-color: {currentColors.bg}; --border-color: {currentColors.border}; --text-color: {currentColors.text}; --icon-color: {currentColors.icon}"
    in:fly={{ 
      y: position.includes('top') ? -100 : 100,
      duration: 300,
      easing: quintOut 
    }}
    out:fly={{ 
      y: position.includes('top') ? -100 : 100,
      duration: 200,
      easing: quintOut 
    }}
    on:mouseenter={pauseTimer}
    on:mouseleave={resumeTimer}
    role="alert"
    aria-live="polite"
  >
    <!-- 进度条 -->
    {#if duration > 0}
      <div class="toast-progress">
        <div 
          class="toast-progress-bar"
          style="width: {progressWidth}%"
        ></div>
      </div>
    {/if}
    
    <!-- 主要内容 -->
    <div class="toast-content">
      <!-- 图标 -->
      {#if showIcon}
        <div class="toast-icon">
          {displayIcon}
        </div>
      {/if}
      
      <!-- 文本内容 -->
      <div class="toast-text">
        {#if title}
          <div class="toast-title">{title}</div>
        {/if}
        {#if message}
          <div class="toast-message">{message}</div>
        {:else}
          <slot />
        {/if}
      </div>
      
      <!-- 操作按钮 -->
      {#if actions.length > 0}
        <div class="toast-actions">
          {#each actions as action}
            <Button
              variant={action.variant || 'text'}
              size="xs"
              on:click={() => handleAction(action)}
            >
              {action.label}
            </Button>
          {/each}
        </div>
      {/if}
      
      <!-- 关闭按钮 -->
      {#if closable}
        <button 
          class="toast-close"
          on:click={handleClose}
          aria-label="关闭通知"
          type="button"
        >
          ✕
        </button>
      {/if}
    </div>
  </div>
{/if}

<style>
  .toast {
    position: fixed;
    z-index: 1000;
    max-width: 400px;
    min-width: 320px;
    background: var(--bg-color, white);
    border-radius: 12px;
    box-shadow: 0 10px 25px rgba(0, 0, 0, 0.15);
    border: 1px solid var(--border-color, #e5e7eb);
    overflow: hidden;
    cursor: default;
    transition: all 0.3s ease;
  }
  
  .toast:hover {
    transform: translateY(-2px);
    box-shadow: 0 15px 50px rgba(0, 0, 0, 0.2);
  }
  
  /* 位置定位 */
  .toast-top-left {
    top: 20px;
    left: 20px;
  }
  
  .toast-top-center {
    top: 20px;
    left: 50%;
    transform: translateX(-50%);
  }
  
  .toast-top-right {
    top: 20px;
    right: 20px;
  }
  
  .toast-bottom-left {
    bottom: 20px;
    left: 20px;
  }
  
  .toast-bottom-center {
    bottom: 20px;
    left: 50%;
    transform: translateX(-50%);
  }
  
  .toast-bottom-right {
    bottom: 20px;
    right: 20px;
  }
  
  /* 类型变体 */
  .toast-success {
    border-left: 4px solid #10b981;
  }
  
  .toast-error {
    border-left: 4px solid #ef4444;
  }
  
  .toast-warning {
    border-left: 4px solid #f59e0b;
  }
  
  .toast-info {
    border-left: 4px solid #3b82f6;
  }
  
  /* 进度条 */
  .toast-progress {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    height: 3px;
    background: rgba(0, 0, 0, 0.1);
    overflow: hidden;
  }
  
  .toast-progress-bar {
    height: 100%;
    background: var(--icon-color, #3b82f6);
    transition: width 0.1s linear;
  }
  
  .toast-success .toast-progress-bar {
    background: #10b981;
  }
  
  .toast-error .toast-progress-bar {
    background: #ef4444;
  }
  
  .toast-warning .toast-progress-bar {
    background: #f59e0b;
  }
  
  .toast-info .toast-progress-bar {
    background: #3b82f6;
  }
  
  /* 主要内容 */
  .toast-content {
    display: flex;
    align-items: flex-start;
    gap: 12px;
    padding: 16px;
    padding-top: 19px; /* 为进度条留空间 */
  }
  
  /* 图标 */
  .toast-icon {
    font-size: 20px;
    line-height: 1;
    flex-shrink: 0;
    margin-top: 1px;
  }
  
  /* 文本内容 */
  .toast-text {
    flex: 1;
    min-width: 0;
  }
  
  .toast-title {
    font-size: 14px;
    font-weight: 600;
    color: var(--text-color, #374151);
    line-height: 1.4;
    margin-bottom: 4px;
  }
  
  .toast-message {
    font-size: 13px;
    color: var(--text-color, #6b7280);
    line-height: 1.4;
  }
  
  /* 操作按钮 */
  .toast-action {
    flex-shrink: 0;
    background: none;
    border: none;
    color: #667eea;
    font-size: 13px;
    font-weight: 600;
    cursor: pointer;
    padding: 4px 8px;
    border-radius: 4px;
    transition: all 0.2s;
    line-height: 1.4;
  }
  
  .toast-action:hover {
    background: rgba(102, 126, 234, 0.1);
  }
  
  /* 关闭按钮 */
  .toast-close {
    flex-shrink: 0;
    width: 20px;
    height: 20px;
    background: none;
    border: none;
    color: var(--text-color, #9ca3af);
    font-size: 12px;
    cursor: pointer;
    border-radius: 4px;
    transition: all 0.2s;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  
  .toast-close:hover {
    color: var(--text-color, #6b7280);
    background: rgba(0, 0, 0, 0.1);
  }
  
  /* 无关闭按钮时的样式调整 */
  .toast-no-close .toast-content {
    padding-right: 16px;
  }
  
  /* 深色模式 */
  @media (prefers-color-scheme: dark) {
    .toast {
      background: #1f2937;
      border-color: #374151;
      box-shadow: 0 10px 25px rgba(0, 0, 0, 0.3);
    }
    
    .toast-title {
      color: #f3f4f6;
    }
    
    .toast-message {
      color: #d1d5db;
    }
    
    .toast-close {
      color: #6b7280;
    }
    
    .toast-close:hover {
      color: #9ca3af;
      background: #374151;
    }
    
    .toast-progress {
      background: rgba(255, 255, 255, 0.1);
    }
  }
  
  /* 移动端优化 */
  @media (max-width: 480px) {
    .toast {
      max-width: calc(100vw - 32px);
      min-width: 280px;
    }
    
    .toast-top-left,
    .toast-top-right {
      top: 16px;
      left: 16px;
      right: 16px;
      transform: none;
    }
    
    .toast-bottom-left,
    .toast-bottom-right {
      bottom: 16px;
      left: 16px;
      right: 16px;
      transform: none;
    }
    
    .toast-top-center {
      top: 16px;
      left: 16px;
      right: 16px;
      transform: none;
    }
    
    .toast-bottom-center {
      bottom: 16px;
      left: 16px;
      right: 16px;
      transform: none;
    }
    
    .toast-content {
      padding: 12px;
      padding-top: 15px;
      gap: 8px;
    }
    
    .toast-icon {
      font-size: 18px;
    }
    
    .toast-title {
      font-size: 13px;
    }
    
    .toast-message {
      font-size: 12px;
    }
  }
  
  /* 无障碍优化 */
  @media (prefers-reduced-motion: reduce) {
    .toast-progress-bar {
      transition: none;
    }
  }
  
  /* 高对比度模式 */
  @media (prefers-contrast: high) {
    .toast {
      border-width: 2px;
    }
    
    .toast-success {
      border-left-width: 6px;
    }
    
    .toast-error {
      border-left-width: 6px;
    }
    
    .toast-warning {
      border-left-width: 6px;
    }
    
    .toast-info {
      border-left-width: 6px;
    }
  }
</style> 