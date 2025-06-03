<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { scale } from 'svelte/transition';
  import { quintOut } from 'svelte/easing';
  import Button from './Button.svelte';
  
  export let type = 'info'; // success, error, warning, info
  export let title = '';
  export let message = '';
  export let closable = false;
  export let showIcon = true;
  export let banner = false;
  export let bordered = true;
  export let rounded = true;
  export let actions = [];
  export let className = '';
  export let visible = true;
  
  const dispatch = createEventDispatcher();
  
  // 图标配置
  const icons = {
    success: '✓',
    error: '✕',
    warning: '⚠',
    info: 'ℹ'
  };
  
  // 颜色主题
  const themes = {
    success: {
      bg: '#f0fdf4',
      border: '#bbf7d0',
      text: '#15803d',
      icon: '#16a34a',
      light: '#dcfce7'
    },
    error: {
      bg: '#fef2f2',
      border: '#fecaca', 
      text: '#dc2626',
      icon: '#ef4444',
      light: '#fee2e2'
    },
    warning: {
      bg: '#fffbeb',
      border: '#fed7aa',
      text: '#d97706',
      icon: '#f59e0b',
      light: '#fef3c7'
    },
    info: {
      bg: '#eff6ff',
      border: '#bfdbfe',
      text: '#2563eb',
      icon: '#3b82f6',
      light: '#dbeafe'
    }
  };
  
  $: currentIcon = icons[type];
  $: currentTheme = themes[type];
  
  $: alertClasses = [
    'alert',
    `alert-${type}`,
    banner && 'alert-banner',
    bordered && 'alert-bordered',
    rounded && 'alert-rounded',
    !visible && 'alert-hidden',
    className
  ].filter(Boolean).join(' ');
  
  function handleClose() {
    visible = false;
    dispatch('close');
  }
  
  function handleAction(action) {
    dispatch('action', { action });
  }
</script>

{#if visible}
  <div 
    class={alertClasses}
    style="--bg-color: {currentTheme.bg}; --border-color: {currentTheme.border}; --text-color: {currentTheme.text}; --icon-color: {currentTheme.icon}; --light-color: {currentTheme.light}"
    role="alert"
    aria-live="polite"
  >
    <div class="alert-content">
      <!-- 图标 -->
      {#if showIcon}
        <div class="alert-icon">
          {currentIcon}
        </div>
      {/if}
      
      <!-- 文本内容 -->
      <div class="alert-text">
        {#if title}
          <div class="alert-title">{title}</div>
        {/if}
        
        {#if message}
          <div class="alert-message">{message}</div>
        {/if}
        
        <!-- 插槽内容 -->
        <div class="alert-slot">
          <slot />
        </div>
        
        <!-- 操作按钮 -->
        {#if actions.length > 0}
          <div class="alert-actions">
            {#each actions as action}
              <Button
                variant={action.variant || 'outline'}
                size={banner ? 'sm' : 'xs'}
                on:click={() => handleAction(action)}
              >
                {action.icon || ''} {action.label}
              </Button>
            {/each}
          </div>
        {/if}
      </div>
      
      <!-- 关闭按钮 -->
      {#if closable}
        <button class="alert-close" on:click={handleClose} aria-label="关闭">
          ✕
        </button>
      {/if}
    </div>
  </div>
{/if}

<style>
  .alert {
    background: var(--bg-color, #f9fafb);
    border: 1px solid var(--border-color, #e5e7eb);
    padding: 16px;
    position: relative;
    transition: all 0.3s ease;
    animation: alertSlideIn 0.3s ease-out;
  }
  
  .alert-rounded {
    border-radius: 12px;
  }
  
  .alert-bordered {
    border-left-width: 4px;
    border-left-color: var(--icon-color, #3b82f6);
  }
  
  .alert-banner {
    border-radius: 0;
    border-left: none;
    border-right: none;
    border-top-width: 4px;
    border-top-color: var(--icon-color, #3b82f6);
    margin: 0 -20px;
    padding: 20px;
  }
  
  .alert-hidden {
    display: none;
  }
  
  /* 内容布局 */
  .alert-content {
    display: flex;
    align-items: flex-start;
    gap: 12px;
  }
  
  .alert-icon {
    flex-shrink: 0;
    width: 20px;
    height: 20px;
    display: flex;
    align-items: center;
    justify-content: center;
    background: var(--light-color, #f3f4f6);
    border-radius: 50%;
    color: var(--icon-color, #3b82f6);
    font-size: 12px;
    font-weight: bold;
    margin-top: 2px;
  }
  
  .alert-banner .alert-icon {
    width: 24px;
    height: 24px;
    font-size: 14px;
  }
  
  .alert-text {
    flex: 1;
    min-width: 0;
  }
  
  .alert-title {
    font-size: 14px;
    font-weight: 600;
    color: var(--text-color, #111827);
    margin-bottom: 4px;
    line-height: 1.4;
  }
  
  .alert-banner .alert-title {
    font-size: 16px;
    margin-bottom: 6px;
  }
  
  .alert-message {
    font-size: 13px;
    color: var(--text-color, #6b7280);
    line-height: 1.5;
    margin-bottom: 8px;
  }
  
  .alert-banner .alert-message {
    font-size: 14px;
  }
  
  .alert-slot {
    margin-bottom: 8px;
  }
  
  .alert-slot:empty {
    display: none;
  }
  
  .alert-actions {
    display: flex;
    gap: 8px;
    flex-wrap: wrap;
    margin-top: 12px;
  }
  
  .alert-banner .alert-actions {
    margin-top: 16px;
  }
  
  .alert-close {
    position: absolute;
    top: 12px;
    right: 12px;
    width: 20px;
    height: 20px;
    border: none;
    background: none;
    color: var(--text-color, #9ca3af);
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    border-radius: 4px;
    font-size: 10px;
    transition: all 0.2s ease;
    z-index: 1;
  }
  
  .alert-banner .alert-close {
    top: 16px;
    right: 16px;
    width: 24px;
    height: 24px;
    font-size: 12px;
  }
  
  .alert-close:hover {
    background: var(--light-color, #f3f4f6);
    color: var(--text-color, #6b7280);
  }
  
  /* 类型特定样式 */
  .alert-success {
    box-shadow: 0 1px 3px rgba(16, 185, 129, 0.1);
  }
  
  .alert-error {
    box-shadow: 0 1px 3px rgba(239, 68, 68, 0.1);
  }
  
  .alert-warning {
    box-shadow: 0 1px 3px rgba(245, 158, 11, 0.1);
  }
  
  .alert-info {
    box-shadow: 0 1px 3px rgba(59, 130, 246, 0.1);
  }
  
  /* 动画 */
  @keyframes alertSlideIn {
    from {
      opacity: 0;
      transform: translateY(-10px);
    }
    to {
      opacity: 1;
      transform: translateY(0);
    }
  }
  
  @keyframes alertSlideOut {
    from {
      opacity: 1;
      transform: translateY(0);
    }
    to {
      opacity: 0;
      transform: translateY(-10px);
    }
  }
  
  /* 移动端适配 */
  @media (max-width: 768px) {
    .alert {
      padding: 14px;
    }
    
    .alert-banner {
      padding: 16px;
    }
    
    .alert-content {
      gap: 10px;
    }
    
    .alert-icon {
      width: 18px;
      height: 18px;
      font-size: 10px;
    }
    
    .alert-banner .alert-icon {
      width: 20px;
      height: 20px;
      font-size: 12px;
    }
    
    .alert-title {
      font-size: 13px;
    }
    
    .alert-banner .alert-title {
      font-size: 14px;
    }
    
    .alert-message {
      font-size: 12px;
    }
    
    .alert-banner .alert-message {
      font-size: 13px;
    }
    
    .alert-close {
      top: 10px;
      right: 10px;
      width: 18px;
      height: 18px;
      font-size: 9px;
    }
    
    .alert-banner .alert-close {
      top: 12px;
      right: 12px;
      width: 20px;
      height: 20px;
      font-size: 10px;
    }
    
    .alert-actions {
      flex-direction: column;
      gap: 6px;
    }
  }
  
  /* 减少动画模式 */
  @media (prefers-reduced-motion: reduce) {
    .alert {
      animation: none;
      transition: none;
    }
  }
  
  /* 高对比度模式 */
  @media (prefers-contrast: high) {
    .alert {
      border-width: 2px;
    }
    
    .alert-bordered {
      border-left-width: 6px;
    }
    
    .alert-banner {
      border-top-width: 6px;
    }
    
    .alert-close {
      border: 1px solid currentColor;
    }
  }
  
  /* 深色模式 */
  @media (prefers-color-scheme: dark) {
    .alert {
      --bg-color: #1f2937;
      --border-color: #374151;
      --text-color: #f9fafb;
      --light-color: #374151;
    }
    
    .alert-success {
      --bg-color: #064e3b;
      --border-color: #065f46;
      --text-color: #a7f3d0;
      --icon-color: #34d399;
      --light-color: #047857;
    }
    
    .alert-error {
      --bg-color: #7f1d1d;
      --border-color: #991b1b;
      --text-color: #fca5a5;
      --icon-color: #f87171;
      --light-color: #991b1b;
    }
    
    .alert-warning {
      --bg-color: #78350f;
      --border-color: #92400e;
      --text-color: #fcd34d;
      --icon-color: #fbbf24;
      --light-color: #92400e;
    }
    
    .alert-info {
      --bg-color: #1e3a8a;
      --border-color: #1e40af;
      --text-color: #93c5fd;
      --icon-color: #60a5fa;
      --light-color: #1e40af;
    }
    
    .alert-close:hover {
      background: rgba(255, 255, 255, 0.1);
    }
  }
</style> 