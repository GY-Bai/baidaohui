<script lang="ts">
  import { createEventDispatcher, onMount, tick } from 'svelte';
  import { slide, fly } from 'svelte/transition';
  import { cubicOut, cubicInOut } from 'svelte/easing';
  
  export let tabs: Array<{
    id: string;
    label: string;
    icon?: string;
    count?: number;
    disabled?: boolean;
  }> = [];
  
  export let activeTab: string = '';
  export let variant: 'default' | 'pills' | 'minimal' = 'default';
  export let size: 'sm' | 'md' | 'lg' = 'md';
  export let showIndicator: boolean = true;
  export let scrollable: boolean = false;
  
  const dispatch = createEventDispatcher();
  
  let tabsContainer: HTMLElement;
  let indicatorElement: HTMLElement;
  let mounted = false;
  
  // 响应式指示器位置
  $: if (mounted && activeTab && indicatorElement && tabsContainer) {
    updateIndicatorPosition();
  }
  
  onMount(() => {
    mounted = true;
    updateIndicatorPosition();
  });
  
  async function updateIndicatorPosition() {
    if (!showIndicator || !indicatorElement || !tabsContainer) return;
    
    await tick();
    
    const activeTabElement = tabsContainer.querySelector(`[data-tab-id="${activeTab}"]`) as HTMLElement;
    if (!activeTabElement) return;
    
    const containerRect = tabsContainer.getBoundingClientRect();
    const tabRect = activeTabElement.getBoundingClientRect();
    
    const left = tabRect.left - containerRect.left;
    const width = tabRect.width;
    
    indicatorElement.style.transform = `translateX(${left}px)`;
    indicatorElement.style.width = `${width}px`;
  }
  
  function handleTabClick(tab: any) {
    if (tab.disabled) return;
    
    dispatch('change', { 
      activeTab: tab.id, 
      tab 
    });
  }
  
  function handleKeyDown(event: KeyboardEvent, tab: any) {
    if (event.key === 'Enter' || event.key === ' ') {
      event.preventDefault();
      handleTabClick(tab);
    }
  }
  
  // 计算标签样式类
  function getTabClasses(tab: any) {
    const baseClasses = [
      'tab-item',
      variant,
      size,
      activeTab === tab.id ? 'active' : '',
      tab.disabled ? 'disabled' : ''
    ].filter(Boolean);
    
    return baseClasses.join(' ');
  }
</script>

<div 
  class="tab-navigation"
  class:scrollable
  role="tablist"
  aria-label="内容导航"
>
  <div 
    class="tabs-container {variant} {size}"
    bind:this={tabsContainer}
  >
    <!-- 滑动指示器 -->
    {#if showIndicator && variant !== 'pills'}
      <div 
        class="tab-indicator"
        bind:this={indicatorElement}
        class:visible={activeTab}
      ></div>
    {/if}
    
    <!-- 标签项 -->
    {#each tabs as tab (tab.id)}
      <button
        class={getTabClasses(tab)}
        data-tab-id={tab.id}
        role="tab"
        aria-selected={activeTab === tab.id}
        aria-controls="tabpanel-{tab.id}"
        tabindex={tab.disabled ? -1 : 0}
        disabled={tab.disabled}
        on:click={() => handleTabClick(tab)}
        on:keydown={(e) => handleKeyDown(e, tab)}
      >
        <!-- 图标 -->
        {#if tab.icon}
          <span class="tab-icon">
            {tab.icon}
          </span>
        {/if}
        
        <!-- 标签文字 -->
        <span class="tab-label">
          {tab.label}
        </span>
        
        <!-- 计数徽章 -->
        {#if tab.count !== undefined && tab.count > 0}
          <span 
            class="tab-count"
            in:fly={{ y: -10, duration: 200, easing: cubicOut }}
          >
            {tab.count > 999 ? '999+' : tab.count}
          </span>
        {/if}
        
        <!-- Pills 变体的活跃状态背景 -->
        {#if variant === 'pills' && activeTab === tab.id}
          <div 
            class="pill-background"
            in:slide={{ duration: 200, easing: cubicInOut }}
            out:slide={{ duration: 150, easing: cubicOut }}
          ></div>
        {/if}
      </button>
    {/each}
  </div>
</div>

<style>
  .tab-navigation {
    position: relative;
    width: 100%;
    overflow: hidden;
  }
  
  .tab-navigation.scrollable {
    overflow-x: auto;
    overflow-y: hidden;
    -webkit-overflow-scrolling: touch;
    scrollbar-width: none;
    -ms-overflow-style: none;
  }
  
  .tab-navigation.scrollable::-webkit-scrollbar {
    display: none;
  }
  
  .tabs-container {
    position: relative;
    display: flex;
    align-items: center;
    background: transparent;
    transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
  }
  
  .tabs-container.default {
    border-bottom: 1px solid #e5e7eb;
    min-height: 48px;
  }
  
  .tabs-container.pills {
    background: #f3f4f6;
    border-radius: 12px;
    padding: 4px;
    min-height: 44px;
  }
  
  .tabs-container.minimal {
    min-height: 40px;
  }
  
  /* 尺寸变体 */
  .tabs-container.sm {
    min-height: 36px;
  }
  
  .tabs-container.md {
    min-height: 44px;
  }
  
  .tabs-container.lg {
    min-height: 52px;
  }
  
  .tab-item {
    position: relative;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 6px;
    padding: 8px 16px;
    background: none;
    border: none;
    cursor: pointer;
    transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
    outline: none;
    font-weight: 500;
    white-space: nowrap;
    z-index: 1;
    
    /* 触摸优化 */
    -webkit-tap-highlight-color: transparent;
    touch-action: manipulation;
  }
  
  /* Default 变体样式 */
  .tab-item.default {
    color: #6b7280;
    border-bottom: 2px solid transparent;
    padding-bottom: 14px;
  }
  
  .tab-item.default.active {
    color: #374151;
    font-weight: 600;
  }
  
  .tab-item.default:hover:not(.disabled) {
    color: #374151;
    background: rgba(107, 114, 128, 0.05);
  }
  
  /* Pills 变体样式 */
  .tab-item.pills {
    color: #6b7280;
    border-radius: 8px;
    font-weight: 500;
    position: relative;
    overflow: hidden;
  }
  
  .tab-item.pills.active {
    color: #374151;
    font-weight: 600;
  }
  
  .tab-item.pills:hover:not(.disabled):not(.active) {
    background: rgba(107, 114, 128, 0.1);
  }
  
  /* Minimal 变体样式 */
  .tab-item.minimal {
    color: #9ca3af;
    padding: 6px 12px;
    font-weight: 400;
  }
  
  .tab-item.minimal.active {
    color: #111827;
    font-weight: 600;
  }
  
  .tab-item.minimal:hover:not(.disabled) {
    color: #6b7280;
  }
  
  /* 尺寸变体 */
  .tab-item.sm {
    padding: 6px 12px;
    font-size: 14px;
  }
  
  .tab-item.md {
    padding: 8px 16px;
    font-size: 15px;
  }
  
  .tab-item.lg {
    padding: 12px 20px;
    font-size: 16px;
  }
  
  /* 禁用状态 */
  .tab-item.disabled {
    opacity: 0.4;
    cursor: not-allowed;
    pointer-events: none;
  }
  
  /* 图标样式 */
  .tab-icon {
    font-size: 1.1em;
    line-height: 1;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  
  /* 标签文字 */
  .tab-label {
    line-height: 1.4;
    letter-spacing: 0.025em;
  }
  
  /* 计数徽章 */
  .tab-count {
    background: #ef4444;
    color: white;
    font-size: 11px;
    font-weight: 600;
    padding: 2px 6px;
    border-radius: 10px;
    min-width: 18px;
    height: 18px;
    display: flex;
    align-items: center;
    justify-content: center;
    line-height: 1;
  }
  
  .tab-item.active .tab-count {
    background: #dc2626;
  }
  
  /* 滑动指示器 */
  .tab-indicator {
    position: absolute;
    bottom: 0;
    left: 0;
    height: 2px;
    background: linear-gradient(90deg, #667eea 0%, #764ba2 100%);
    border-radius: 1px;
    transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
    opacity: 0;
    transform: translateX(0);
    z-index: 0;
  }
  
  .tab-indicator.visible {
    opacity: 1;
  }
  
  /* Pills 背景 */
  .pill-background {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: white;
    border-radius: 8px;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
    z-index: -1;
  }
  
  /* 焦点状态 */
  .tab-item:focus-visible {
    box-shadow: 0 0 0 2px #667eea, 0 0 0 4px rgba(102, 126, 234, 0.1);
    border-radius: 6px;
  }
  
  /* 滚动容器中的样式调整 */
  .scrollable .tabs-container {
    min-width: min-content;
    padding: 0 16px;
  }
  
  .scrollable .tab-item {
    flex-shrink: 0;
  }
  
  /* 渐变遮罩（用于滚动容器） */
  .scrollable::before,
  .scrollable::after {
    content: '';
    position: absolute;
    top: 0;
    bottom: 0;
    width: 20px;
    pointer-events: none;
    z-index: 2;
  }
  
  .scrollable::before {
    left: 0;
    background: linear-gradient(to right, rgba(255, 255, 255, 1), rgba(255, 255, 255, 0));
  }
  
  .scrollable::after {
    right: 0;
    background: linear-gradient(to left, rgba(255, 255, 255, 1), rgba(255, 255, 255, 0));
  }
  
  /* 深色模式适配 */
  @media (prefers-color-scheme: dark) {
    .tabs-container.default {
      border-bottom-color: #374151;
    }
    
    .tabs-container.pills {
      background: #374151;
    }
    
    .tab-item.default {
      color: #9ca3af;
    }
    
    .tab-item.default.active {
      color: #f3f4f6;
    }
    
    .tab-item.pills {
      color: #9ca3af;
    }
    
    .tab-item.pills.active {
      color: #f3f4f6;
    }
    
    .tab-item.minimal {
      color: #6b7280;
    }
    
    .tab-item.minimal.active {
      color: #f9fafb;
    }
    
    .pill-background {
      background: #4b5563;
    }
    
    .tab-indicator {
      background: linear-gradient(90deg, #818cf8 0%, #a78bfa 100%);
    }
    
    .scrollable::before {
      background: linear-gradient(to right, rgba(17, 24, 39, 1), rgba(17, 24, 39, 0));
    }
    
    .scrollable::after {
      background: linear-gradient(to left, rgba(17, 24, 39, 1), rgba(17, 24, 39, 0));
    }
  }
  
  /* 无障碍优化 */
  @media (prefers-reduced-motion: reduce) {
    .tab-item,
    .tab-indicator,
    .pill-background {
      transition: none;
    }
  }
  
  /* 高对比度模式 */
  @media (prefers-contrast: high) {
    .tab-item {
      border: 1px solid transparent;
    }
    
    .tab-item.active {
      border-color: currentColor;
      background: rgba(0, 0, 0, 0.05);
    }
    
    .tab-indicator {
      height: 3px;
      background: currentColor;
    }
  }
</style> 