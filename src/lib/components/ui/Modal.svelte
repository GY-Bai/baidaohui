<script lang="ts">
  import { createEventDispatcher, onMount } from 'svelte';
  import { fly, fade, scale } from 'svelte/transition';
  import { cubicOut, backOut } from 'svelte/easing';
  import { trapFocus } from '$lib/utils/focus-trap';
  
  export let isOpen: boolean = false;
  export let title: string = '';
  export let subtitle: string = '';
  export let size: 'sm' | 'md' | 'lg' | 'xl' | 'full' = 'md';
  export let variant: 'default' | 'centered' | 'drawer' = 'default';
  export let closeOnEscape: boolean = true;
  export let closeOnBackdrop: boolean = true;
  export let showCloseButton: boolean = true;
  export let persistent: boolean = false;
  export let fullscreen: boolean = false;
  
  const dispatch = createEventDispatcher();
  
  let modalElement: HTMLElement;
  let previouslyFocused: HTMLElement | null = null;
  
  // 监听 ESC 键
  function handleKeydown(event: KeyboardEvent) {
    if (event.key === 'Escape' && isOpen && closeOnEscape && !persistent) {
      handleClose();
    }
  }
  
  // 关闭模态框
  function handleClose() {
    if (persistent) return;
    dispatch('close');
  }
  
  // 点击背景关闭
  function handleBackdropClick(event: MouseEvent) {
    if (event.target === event.currentTarget && closeOnBackdrop && !persistent) {
      handleClose();
    }
  }
  
  // 阻止模态框内容区域的点击冒泡
  function handleContentClick(event: MouseEvent) {
    event.stopPropagation();
  }
  
  onMount(() => {
    document.addEventListener('keydown', handleKeydown);
    return () => {
      document.removeEventListener('keydown', handleKeydown);
    };
  });
  
  // 获取模态框尺寸类
  $: sizeClasses = {
    'sm': 'max-w-sm',
    'md': 'max-w-md',
    'lg': 'max-w-lg', 
    'xl': 'max-w-xl',
    'full': 'max-w-full'
  };
  
  $: modalClasses = [
    'modal-container',
    sizeClasses[size],
    variant === 'centered' ? 'modal-centered' : '',
    variant === 'drawer' ? 'modal-drawer' : '',
    fullscreen ? 'modal-fullscreen' : ''
  ].filter(Boolean).join(' ');
</script>

{#if isOpen}
  <!-- 模态框背景遮罩 -->
  <div 
    class="modal-backdrop"
    class:fullscreen
    on:click={handleBackdropClick}
    in:fade={{ duration: 200 }}
    out:fade={{ duration: 150 }}
    use:trapFocus
  >
    <!-- 模态框容器 -->
    <div 
      class={modalClasses}
      bind:this={modalElement}
      role="dialog"
      aria-modal="true"
      aria-labelledby={title ? 'modal-title' : undefined}
      aria-describedby={subtitle ? 'modal-subtitle' : undefined}
      on:click={handleContentClick}
      in:fly={{ 
        y: variant === 'drawer' ? 100 : 50, 
        duration: 300, 
        easing: variant === 'centered' ? backOut : cubicOut 
      }}
      out:fly={{ 
        y: variant === 'drawer' ? 100 : 30, 
        duration: 200, 
        easing: cubicOut 
      }}
    >
      <!-- 模态框头部 -->
      {#if title || showCloseButton || $$slots.header}
        <header class="modal-header">
          <slot name="header">
            <div class="modal-header-content">
              {#if title || subtitle}
                <div class="modal-title-section">
                  {#if title}
                    <h2 id="modal-title" class="modal-title">{title}</h2>
                  {/if}
                  {#if subtitle}
                    <p id="modal-subtitle" class="modal-subtitle">{subtitle}</p>
                  {/if}
                </div>
              {/if}
              
              {#if showCloseButton}
                <button 
                  class="modal-close-button"
                  on:click={handleClose}
                  aria-label="关闭"
                  disabled={persistent}
                >
                  <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
                    <path d="M18 6L6 18M6 6l12 12" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
                  </svg>
                </button>
              {/if}
            </div>
          </slot>
        </header>
      {/if}
      
      <!-- 模态框内容 -->
      <main class="modal-content">
        <slot />
      </main>
      
      <!-- 模态框底部 -->
      {#if $$slots.footer}
        <footer class="modal-footer">
          <slot name="footer" />
        </footer>
      {/if}
    </div>
  </div>
{/if}

<style>
  .modal-backdrop {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.6);
    backdrop-filter: blur(4px);
    -webkit-backdrop-filter: blur(4px);
    z-index: 9999;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 16px;
    overflow-y: auto;
  }
  
  .modal-backdrop.fullscreen {
    padding: 0;
  }
  
  .modal-container {
    background: white;
    border-radius: 16px;
    box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
    width: 100%;
    max-height: 90vh;
    display: flex;
    flex-direction: column;
    overflow: hidden;
    position: relative;
  }
  
  .modal-centered {
    margin: auto;
  }
  
  .modal-drawer {
    position: fixed;
    bottom: 0;
    left: 0;
    right: 0;
    max-height: 85vh;
    border-radius: 24px 24px 0 0;
    margin: 0;
  }
  
  .modal-fullscreen {
    width: 100vw;
    height: 100vh;
    max-width: none;
    max-height: none;
    border-radius: 0;
  }
  
  /* 头部 */
  .modal-header {
    border-bottom: 1px solid #e5e7eb;
    background: white;
    border-radius: 16px 16px 0 0;
  }
  
  .modal-drawer .modal-header {
    border-radius: 24px 24px 0 0;
  }
  
  .modal-fullscreen .modal-header {
    border-radius: 0;
  }
  
  .modal-header-content {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    padding: 20px 24px;
    gap: 16px;
  }
  
  .modal-title-section {
    flex: 1;
    min-width: 0;
  }
  
  .modal-title {
    margin: 0;
    font-size: 20px;
    font-weight: 600;
    color: #111827;
    line-height: 1.4;
  }
  
  .modal-subtitle {
    margin: 4px 0 0 0;
    font-size: 14px;
    color: #6b7280;
    line-height: 1.4;
  }
  
  .modal-close-button {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 40px;
    height: 40px;
    border: none;
    background: none;
    color: #6b7280;
    cursor: pointer;
    border-radius: 8px;
    transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
    flex-shrink: 0;
  }
  
  .modal-close-button:hover:not(:disabled) {
    background: #f3f4f6;
    color: #374151;
  }
  
  .modal-close-button:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }
  
  /* 内容区域 */
  .modal-content {
    flex: 1;
    overflow-y: auto;
    padding: 24px;
    
    /* 自定义滚动条 */
    scrollbar-width: thin;
    scrollbar-color: #d1d5db transparent;
  }
  
  .modal-content::-webkit-scrollbar {
    width: 6px;
  }
  
  .modal-content::-webkit-scrollbar-track {
    background: transparent;
  }
  
  .modal-content::-webkit-scrollbar-thumb {
    background: #d1d5db;
    border-radius: 3px;
  }
  
  .modal-content::-webkit-scrollbar-thumb:hover {
    background: #9ca3af;
  }
  
  /* 底部 */
  .modal-footer {
    border-top: 1px solid #e5e7eb;
    padding: 16px 24px;
    background: #fafafa;
    display: flex;
    align-items: center;
    justify-content: flex-end;
    gap: 12px;
  }
  
  /* 响应式设计 */
  @media (max-width: 768px) {
    .modal-backdrop {
      padding: 8px;
    }
    
    .modal-container {
      max-height: 95vh;
    }
    
    .modal-header-content {
      padding: 16px 20px;
    }
    
    .modal-content {
      padding: 20px;
    }
    
    .modal-footer {
      padding: 12px 20px;
    }
    
    .modal-title {
      font-size: 18px;
    }
    
    /* 在小屏幕上，抽屉样式占据更多高度 */
    .modal-drawer {
      max-height: 95vh;
    }
  }
  
  @media (max-width: 480px) {
    .modal-backdrop {
      padding: 4px;
    }
    
    .modal-drawer {
      max-height: 98vh;
      border-radius: 16px 16px 0 0;
    }
    
    .modal-drawer .modal-header {
      border-radius: 16px 16px 0 0;
    }
  }
  
  /* 深色模式适配 */
  @media (prefers-color-scheme: dark) {
    .modal-container {
      background: #1f2937;
    }
    
    .modal-header {
      background: #1f2937;
      border-bottom-color: #374151;
    }
    
    .modal-title {
      color: #f9fafb;
    }
    
    .modal-subtitle {
      color: #9ca3af;
    }
    
    .modal-close-button {
      color: #9ca3af;
    }
    
    .modal-close-button:hover:not(:disabled) {
      background: #374151;
      color: #f3f4f6;
    }
    
    .modal-footer {
      background: #111827;
      border-top-color: #374151;
    }
    
    .modal-content::-webkit-scrollbar-thumb {
      background: #4b5563;
    }
    
    .modal-content::-webkit-scrollbar-thumb:hover {
      background: #6b7280;
    }
  }
  
  /* 无障碍优化 */
  @media (prefers-reduced-motion: reduce) {
    .modal-backdrop,
    .modal-container {
      animation: none;
      transition: none;
    }
  }
  
  /* 高对比度模式 */
  @media (prefers-contrast: high) {
    .modal-container {
      border: 2px solid #000;
    }
    
    .modal-header {
      border-bottom-width: 2px;
    }
    
    .modal-footer {
      border-top-width: 2px;
    }
  }
</style> 