<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  
  export let items: Array<{
    label: string;
    href?: string;
    disabled?: boolean;
    current?: boolean;
  }> = [];
  export let separator: string = '/';
  export let showHome: boolean = true;
  export let homeIcon: string = '🏠';
  export let maxItems: number = 0; // 0 = 不限制
  export let size: 'sm' | 'md' = 'md';
  
  const dispatch = createEventDispatcher();
  
  $: breadcrumbClasses = [
    'breadcrumb',
    `breadcrumb-${size}`
  ].filter(Boolean).join(' ');
  
  $: displayItems = maxItems > 0 && items.length > maxItems
    ? [
        ...items.slice(0, 1),
        { label: '...', disabled: true },
        ...items.slice(-(maxItems - 2))
      ]
    : items;
  
  function handleItemClick(item: any, index: number) {
    if (item.disabled || item.current) return;
    
    if (item.href) {
      dispatch('navigate', { item, href: item.href, index });
    } else {
      dispatch('click', { item, index });
    }
  }
  
  function handleHomeClick() {
    dispatch('home');
  }
</script>

<nav class={breadcrumbClasses} aria-label="面包屑导航">
  <ol class="breadcrumb-list">
    <!-- 首页链接 -->
    {#if showHome}
      <li class="breadcrumb-item breadcrumb-home">
        <button 
          class="breadcrumb-link breadcrumb-home-link"
          on:click={handleHomeClick}
          type="button"
          aria-label="返回首页"
        >
          <span class="breadcrumb-home-icon">{homeIcon}</span>
        </button>
        {#if displayItems.length > 0}
          <span class="breadcrumb-separator" aria-hidden="true">{separator}</span>
        {/if}
      </li>
    {/if}
    
    <!-- 面包屑项目 -->
    {#each displayItems as item, index}
      <li class="breadcrumb-item">
        {#if item.disabled}
          <span class="breadcrumb-ellipsis">{item.label}</span>
        {:else if item.current}
          <span 
            class="breadcrumb-current"
            aria-current="page"
          >
            {item.label}
          </span>
        {:else if item.href}
          <a 
            href={item.href}
            class="breadcrumb-link"
            on:click|preventDefault={() => handleItemClick(item, index)}
          >
            {item.label}
          </a>
        {:else}
          <button 
            class="breadcrumb-link breadcrumb-button"
            on:click={() => handleItemClick(item, index)}
            type="button"
          >
            {item.label}
          </button>
        {/if}
        
        {#if index < displayItems.length - 1}
          <span class="breadcrumb-separator" aria-hidden="true">{separator}</span>
        {/if}
      </li>
    {/each}
  </ol>
</nav>

<style>
  .breadcrumb {
    display: flex;
    align-items: center;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  }
  
  .breadcrumb-list {
    display: flex;
    align-items: center;
    flex-wrap: wrap;
    gap: 0;
    list-style: none;
    margin: 0;
    padding: 0;
  }
  
  .breadcrumb-item {
    display: flex;
    align-items: center;
    gap: 8px;
  }
  
  /* 尺寸变体 */
  .breadcrumb-sm {
    font-size: 12px;
  }
  
  .breadcrumb-sm .breadcrumb-separator {
    font-size: 10px;
  }
  
  .breadcrumb-md {
    font-size: 14px;
  }
  
  .breadcrumb-md .breadcrumb-separator {
    font-size: 12px;
  }
  
  /* 链接样式 */
  .breadcrumb-link {
    color: #6b7280;
    text-decoration: none;
    border: none;
    background: none;
    font: inherit;
    cursor: pointer;
    padding: 4px 0;
    border-radius: 4px;
    transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
    line-height: 1.4;
    max-width: 200px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  
  .breadcrumb-link:hover {
    color: #374151;
    background: #f3f4f6;
    padding: 4px 8px;
    margin: 0 -8px;
  }
  
  .breadcrumb-link:focus {
    outline: 2px solid #667eea;
    outline-offset: 2px;
  }
  
  /* 首页链接 */
  .breadcrumb-home-link {
    padding: 4px;
    border-radius: 6px;
    display: flex;
    align-items: center;
    justify-content: center;
    min-width: 28px;
    height: 28px;
  }
  
  .breadcrumb-home-link:hover {
    margin: 0;
    padding: 4px;
  }
  
  .breadcrumb-home-icon {
    font-size: 14px;
    line-height: 1;
  }
  
  /* 当前页面 */
  .breadcrumb-current {
    color: #374151;
    font-weight: 600;
    max-width: 200px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  
  /* 省略号 */
  .breadcrumb-ellipsis {
    color: #9ca3af;
    font-weight: 600;
    user-select: none;
    padding: 4px 0;
  }
  
  /* 分隔符 */
  .breadcrumb-separator {
    color: #9ca3af;
    font-weight: 300;
    margin: 0 4px;
    user-select: none;
  }
  
  /* 深色模式 */
  @media (prefers-color-scheme: dark) {
    .breadcrumb-link {
      color: #d1d5db;
    }
    
    .breadcrumb-link:hover {
      color: #f3f4f6;
      background: #374151;
    }
    
    .breadcrumb-current {
      color: #f3f4f6;
    }
    
    .breadcrumb-separator {
      color: #6b7280;
    }
    
    .breadcrumb-ellipsis {
      color: #6b7280;
    }
  }
  
  /* 移动端优化 */
  @media (max-width: 768px) {
    .breadcrumb-link,
    .breadcrumb-current {
      max-width: 120px;
    }
    
    .breadcrumb-separator {
      margin: 0 2px;
    }
    
    .breadcrumb-item {
      gap: 4px;
    }
  }
  
  @media (max-width: 480px) {
    .breadcrumb {
      font-size: 12px;
    }
    
    .breadcrumb-link,
    .breadcrumb-current {
      max-width: 80px;
    }
    
    .breadcrumb-home-link {
      min-width: 24px;
      height: 24px;
    }
    
    .breadcrumb-home-icon {
      font-size: 12px;
    }
    
    /* 在小屏幕上只显示最后两级 */
    .breadcrumb-list {
      overflow: hidden;
    }
    
    .breadcrumb-item:not(:nth-last-child(-n+3)):not(.breadcrumb-home) {
      display: none;
    }
    
    .breadcrumb-item:nth-last-child(3):not(.breadcrumb-home):before {
      content: '...';
      color: #9ca3af;
      margin-right: 8px;
    }
  }
  
  /* 无障碍优化 */
  @media (prefers-reduced-motion: reduce) {
    .breadcrumb-link {
      transition: none;
    }
  }
  
  /* 高对比度模式 */
  @media (prefers-contrast: high) {
    .breadcrumb-link {
      border: 1px solid transparent;
    }
    
    .breadcrumb-link:focus {
      border-color: currentColor;
    }
    
    .breadcrumb-current {
      border-bottom: 2px solid currentColor;
    }
  }
</style> 