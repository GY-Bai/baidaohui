<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  
  export let variant = 'default'; // default, outlined, elevated, flat
  export let size = 'default'; // compact, default, large
  export let padding = 'default'; // none, sm, default, lg
  export let shadow = 'default'; // none, sm, default, lg, xl
  export let hover = false;
  export let clickable = false;
  export let disabled = false;
  export let rounded = 'default'; // none, sm, default, lg, xl, full
  export let borderColor = null;
  export let backgroundColor = null;
  export let headerTitle = '';
  export let headerSubtitle = '';
  export let showHeader = false;
  export let showFooter = false;
  export let loading = false;
  export let className = '';
  
  const dispatch = createEventDispatcher();
  
  function handleClick(event) {
    if (!disabled && clickable) {
      dispatch('click', event);
    }
  }
  
  function handleKeydown(event) {
    if (!disabled && clickable && (event.key === 'Enter' || event.key === ' ')) {
      event.preventDefault();
      dispatch('click', event);
    }
  }
  
  $: cardClasses = [
    'card',
    `card-${variant}`,
    `card-${size}`,
    `card-padding-${padding}`,
    `card-shadow-${shadow}`,
    `card-rounded-${rounded}`,
    hover && 'card-hover',
    clickable && 'card-clickable',
    disabled && 'card-disabled',
    loading && 'card-loading',
    className
  ].filter(Boolean).join(' ');
  
  $: cardStyle = [
    borderColor && `border-color: ${borderColor}`,
    backgroundColor && `background-color: ${backgroundColor}`
  ].filter(Boolean).join('; ');
</script>

<div
  class={cardClasses}
  style={cardStyle}
  role={clickable ? 'button' : undefined}
  tabindex={clickable && !disabled ? 0 : undefined}
  on:click={handleClick}
  on:keydown={handleKeydown}
>
  <!-- 加载遮罩 -->
  {#if loading}
    <div class="card-loading-overlay">
      <div class="loading-spinner"></div>
    </div>
  {/if}
  
  <!-- 卡片头部 -->
  {#if showHeader || $$slots.header}
    <header class="card-header">
      <slot name="header">
        {#if headerTitle}
          <div class="header-content">
            <h3 class="header-title">{headerTitle}</h3>
            {#if headerSubtitle}
              <p class="header-subtitle">{headerSubtitle}</p>
            {/if}
          </div>
        {/if}
      </slot>
      
      {#if $$slots.headerActions}
        <div class="header-actions">
          <slot name="headerActions" />
        </div>
      {/if}
    </header>
  {/if}
  
  <!-- 卡片内容 -->
  <div class="card-content">
    <slot />
  </div>
  
  <!-- 卡片底部 -->
  {#if showFooter || $$slots.footer}
    <footer class="card-footer">
      <slot name="footer" />
    </footer>
  {/if}
</div>

<style>
  .card {
    position: relative;
    background: white;
    border: 1px solid #e5e7eb;
    transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
    overflow: hidden;
    display: flex;
    flex-direction: column;
  }
  
  /* 变体样式 */
  .card-default {
    background: white;
    border-color: #e5e7eb;
  }
  
  .card-outlined {
    background: white;
    border-color: #d1d5db;
    border-width: 2px;
  }
  
  .card-elevated {
    background: white;
    border: none;
    box-shadow: 0 4px 20px rgba(0, 0, 0, 0.08);
  }
  
  .card-flat {
    background: #f9fafb;
    border: none;
    box-shadow: none;
  }
  
  /* 尺寸样式 */
  .card-compact {
    min-height: auto;
  }
  
  .card-default {
    min-height: 120px;
  }
  
  .card-large {
    min-height: 200px;
  }
  
  /* 内边距样式 */
  .card-padding-none .card-content {
    padding: 0;
  }
  
  .card-padding-sm .card-content {
    padding: 12px;
  }
  
  .card-padding-default .card-content {
    padding: 20px;
  }
  
  .card-padding-lg .card-content {
    padding: 32px;
  }
  
  /* 阴影样式 */
  .card-shadow-none {
    box-shadow: none;
  }
  
  .card-shadow-sm {
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  }
  
  .card-shadow-default {
    box-shadow: 0 4px 20px rgba(0, 0, 0, 0.08);
  }
  
  .card-shadow-lg {
    box-shadow: 0 8px 30px rgba(0, 0, 0, 0.12);
  }
  
  .card-shadow-xl {
    box-shadow: 0 12px 40px rgba(0, 0, 0, 0.15);
  }
  
  /* 圆角样式 */
  .card-rounded-none {
    border-radius: 0;
  }
  
  .card-rounded-sm {
    border-radius: 6px;
  }
  
  .card-rounded-default {
    border-radius: 12px;
  }
  
  .card-rounded-lg {
    border-radius: 16px;
  }
  
  .card-rounded-xl {
    border-radius: 20px;
  }
  
  .card-rounded-full {
    border-radius: 9999px;
  }
  
  /* 交互样式 */
  .card-hover:hover:not(.card-disabled) {
    transform: translateY(-2px);
    box-shadow: 0 8px 30px rgba(0, 0, 0, 0.15);
  }
  
  .card-clickable {
    cursor: pointer;
    user-select: none;
  }
  
  .card-clickable:active:not(.card-disabled) {
    transform: translateY(0);
    transition-duration: 0.1s;
  }
  
  .card-disabled {
    opacity: 0.6;
    cursor: not-allowed;
    pointer-events: none;
  }
  
  /* 卡片头部 */
  .card-header {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    padding: 20px 20px 0 20px;
    border-bottom: 1px solid #f3f4f6;
    margin-bottom: 20px;
    padding-bottom: 16px;
  }
  
  .card-padding-sm .card-header {
    padding: 12px 12px 0 12px;
    margin-bottom: 12px;
    padding-bottom: 12px;
  }
  
  .card-padding-lg .card-header {
    padding: 32px 32px 0 32px;
    margin-bottom: 32px;
    padding-bottom: 24px;
  }
  
  .card-padding-none .card-header {
    padding: 20px 20px 0 20px;
    margin-bottom: 20px;
    padding-bottom: 16px;
  }
  
  .header-content {
    flex: 1;
    min-width: 0;
  }
  
  .header-title {
    font-size: 18px;
    font-weight: 600;
    color: #111827;
    margin: 0 0 4px 0;
    line-height: 1.3;
  }
  
  .header-subtitle {
    font-size: 14px;
    color: #6b7280;
    margin: 0;
    line-height: 1.4;
  }
  
  .header-actions {
    flex-shrink: 0;
    margin-left: 16px;
    display: flex;
    align-items: center;
    gap: 8px;
  }
  
  /* 卡片内容 */
  .card-content {
    flex: 1;
    padding: 20px;
  }
  
  /* 卡片底部 */
  .card-footer {
    border-top: 1px solid #f3f4f6;
    padding: 16px 20px;
    margin-top: auto;
    background: #fafbfc;
  }
  
  .card-padding-sm .card-footer {
    padding: 12px;
  }
  
  .card-padding-lg .card-footer {
    padding: 24px 32px;
  }
  
  .card-padding-none .card-footer {
    padding: 16px 20px;
  }
  
  /* 加载状态 */
  .card-loading {
    position: relative;
  }
  
  .card-loading-overlay {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(255, 255, 255, 0.8);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 10;
    backdrop-filter: blur(2px);
  }
  
  .loading-spinner {
    width: 32px;
    height: 32px;
    border: 3px solid #f3f4f6;
    border-top: 3px solid #667eea;
    border-radius: 50%;
    animation: spin 1s linear infinite;
  }
  
  @keyframes spin {
    from { transform: rotate(0deg); }
    to { transform: rotate(360deg); }
  }
  
  /* 特殊效果 */
  .card::before {
    content: '';
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    height: 4px;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    opacity: 0;
    transition: opacity 0.3s ease;
    border-radius: inherit;
    border-bottom-left-radius: 0;
    border-bottom-right-radius: 0;
  }
  
  .card-hover:hover::before,
  .card-clickable:focus-visible::before {
    opacity: 1;
  }
  
  /* 焦点样式 */
  .card-clickable:focus-visible {
    outline: none;
    ring: 2px solid rgba(102, 126, 234, 0.3);
    box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.3);
  }
  
  /* 移动端适配 */
  @media (max-width: 768px) {
    .card-content {
      padding: 16px;
    }
    
    .card-header {
      padding: 16px 16px 0 16px;
      margin-bottom: 16px;
      padding-bottom: 12px;
    }
    
    .card-footer {
      padding: 12px 16px;
    }
    
    .header-title {
      font-size: 16px;
    }
    
    .header-subtitle {
      font-size: 13px;
    }
    
    .header-actions {
      margin-left: 12px;
      gap: 6px;
    }
    
    /* 移动端减少悬停效果 */
    .card-hover:hover {
      transform: none;
    }
  }
  
  /* 减少动画模式 */
  @media (prefers-reduced-motion: reduce) {
    .card,
    .card::before,
    .loading-spinner {
      transition: none;
      animation: none;
    }
  }
  
  /* 深色模式 */
  @media (prefers-color-scheme: dark) {
    .card-default,
    .card-outlined,
    .card-elevated {
      background: #1f2937;
      border-color: #374151;
    }
    
    .card-flat {
      background: #111827;
    }
    
    .header-title {
      color: #f9fafb;
    }
    
    .header-subtitle {
      color: #d1d5db;
    }
    
    .card-header {
      border-bottom-color: #374151;
    }
    
    .card-footer {
      background: #111827;
      border-top-color: #374151;
    }
    
    .card-loading-overlay {
      background: rgba(31, 41, 55, 0.8);
    }
    
    .loading-spinner {
      border-color: #4b5563;
      border-top-color: #667eea;
    }
  }
  
  /* 高对比度模式 */
  @media (prefers-contrast: high) {
    .card {
      border-width: 2px;
      border-color: #000;
    }
    
    .header-title {
      color: #000;
    }
    
    .header-subtitle {
      color: #333;
    }
  }
</style> 