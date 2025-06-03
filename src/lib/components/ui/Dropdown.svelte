<script lang="ts">
  import { createEventDispatcher, onMount } from 'svelte';
  import { fly, scale } from 'svelte/transition';
  import { quintOut } from 'svelte/easing';
  import { trapFocus } from '$lib/utils/focus-trap';
  
  export let items: Array<{
    label: string;
    value?: any;
    icon?: string;
    disabled?: boolean;
    divider?: boolean;
    danger?: boolean;
    href?: string;
    onClick?: () => void;
  }> = [];
  export let trigger: 'click' | 'hover' = 'click';
  export let position: 'bottom-left' | 'bottom-right' | 'top-left' | 'top-right' = 'bottom-left';
  export let disabled: boolean = false;
  export let closeOnClick: boolean = true;
  export let offset: number = 4;
  export let minWidth: string = '200px';
  export let maxHeight: string = '300px';
  export let searchable: boolean = false;
  export let placeholder: string = '搜索...';
  
  const dispatch = createEventDispatcher();
  
  let isOpen = false;
  let triggerElement: HTMLElement;
  let dropdownElement: HTMLElement;
  let searchInput: HTMLInputElement;
  let searchQuery = '';
  let hoverTimeout: number;
  
  $: dropdownClasses = [
    'dropdown-menu',
    `dropdown-${position}`,
    searchable ? 'dropdown-searchable' : ''
  ].filter(Boolean).join(' ');
  
  $: filteredItems = searchable && searchQuery
    ? items.filter(item => 
        !item.divider && 
        item.label.toLowerCase().includes(searchQuery.toLowerCase())
      )
    : items;
  
  $: flyDirection = position.includes('top') 
    ? { y: 10 } 
    : { y: -10 };
  
  function open() {
    if (disabled) return;
    isOpen = true;
    dispatch('open');
    
    // 聚焦到搜索框
    if (searchable) {
      setTimeout(() => {
        searchInput?.focus();
      }, 100);
    }
  }
  
  function close() {
    isOpen = false;
    searchQuery = '';
    dispatch('close');
  }
  
  function toggle() {
    if (isOpen) {
      close();
    } else {
      open();
    }
  }
  
  function handleItemClick(item: any) {
    if (item.disabled || item.divider) return;
    
    if (item.onClick) {
      item.onClick();
    }
    
    if (item.href) {
      dispatch('navigate', { item });
    } else {
      dispatch('select', { item });
    }
    
    if (closeOnClick) {
      close();
    }
  }
  
  function handleTriggerClick() {
    if (trigger === 'click') {
      toggle();
    }
  }
  
  function handleTriggerMouseEnter() {
    if (trigger === 'hover') {
      clearTimeout(hoverTimeout);
      open();
    }
  }
  
  function handleTriggerMouseLeave() {
    if (trigger === 'hover') {
      hoverTimeout = setTimeout(close, 150);
    }
  }
  
  function handleDropdownMouseEnter() {
    if (trigger === 'hover') {
      clearTimeout(hoverTimeout);
    }
  }
  
  function handleDropdownMouseLeave() {
    if (trigger === 'hover') {
      hoverTimeout = setTimeout(close, 150);
    }
  }
  
  function handleKeydown(event: KeyboardEvent) {
    if (!isOpen) return;
    
    switch (event.key) {
      case 'Escape':
        close();
        triggerElement?.focus();
        break;
      case 'ArrowDown':
        event.preventDefault();
        focusNextItem();
        break;
      case 'ArrowUp':
        event.preventDefault();
        focusPreviousItem();
        break;
    }
  }
  
  function focusNextItem() {
    const items = dropdownElement?.querySelectorAll('.dropdown-item:not([disabled])');
    if (!items?.length) return;
    
    const current = document.activeElement;
    const currentIndex = Array.from(items).indexOf(current as Element);
    const nextIndex = currentIndex < items.length - 1 ? currentIndex + 1 : 0;
    (items[nextIndex] as HTMLElement)?.focus();
  }
  
  function focusPreviousItem() {
    const items = dropdownElement?.querySelectorAll('.dropdown-item:not([disabled])');
    if (!items?.length) return;
    
    const current = document.activeElement;
    const currentIndex = Array.from(items).indexOf(current as Element);
    const prevIndex = currentIndex > 0 ? currentIndex - 1 : items.length - 1;
    (items[prevIndex] as HTMLElement)?.focus();
  }
  
  function positionDropdown() {
    if (!triggerElement || !dropdownElement) return;
    
    const triggerRect = triggerElement.getBoundingClientRect();
    const dropdownRect = dropdownElement.getBoundingClientRect();
    const viewportWidth = window.innerWidth;
    const viewportHeight = window.innerHeight;
    
    let top = 0;
    let left = 0;
    
    // 计算基础位置
    switch (position) {
      case 'bottom-left':
        top = triggerRect.bottom + offset;
        left = triggerRect.left;
        break;
      case 'bottom-right':
        top = triggerRect.bottom + offset;
        left = triggerRect.right - dropdownRect.width;
        break;
      case 'top-left':
        top = triggerRect.top - dropdownRect.height - offset;
        left = triggerRect.left;
        break;
      case 'top-right':
        top = triggerRect.top - dropdownRect.height - offset;
        left = triggerRect.right - dropdownRect.width;
        break;
    }
    
    // 边界检测和调整
    if (left < 8) {
      left = 8;
    } else if (left + dropdownRect.width > viewportWidth - 8) {
      left = viewportWidth - dropdownRect.width - 8;
    }
    
    if (top < 8) {
      top = triggerRect.bottom + offset;
    } else if (top + dropdownRect.height > viewportHeight - 8) {
      top = triggerRect.top - dropdownRect.height - offset;
    }
    
    dropdownElement.style.top = `${top + window.scrollY}px`;
    dropdownElement.style.left = `${left + window.scrollX}px`;
  }
  
  function handleClickOutside(event: Event) {
    if (!isOpen) return;
    
    const target = event.target as Element;
    if (!triggerElement?.contains(target) && !dropdownElement?.contains(target)) {
      close();
    }
  }
  
  onMount(() => {
    document.addEventListener('click', handleClickOutside);
    document.addEventListener('keydown', handleKeydown);
    
    return () => {
      document.removeEventListener('click', handleClickOutside);
      document.removeEventListener('keydown', handleKeydown);
      clearTimeout(hoverTimeout);
    };
  });
  
  $: if (isOpen && dropdownElement) {
    requestAnimationFrame(() => {
      positionDropdown();
    });
  }
</script>

<div class="dropdown">
  <!-- 触发器 -->
  <div 
    bind:this={triggerElement}
    class="dropdown-trigger"
    class:dropdown-disabled={disabled}
    on:click={handleTriggerClick}
    on:mouseenter={handleTriggerMouseEnter}
    on:mouseleave={handleTriggerMouseLeave}
  >
    <slot />
  </div>
  
  <!-- 下拉菜单 -->
  {#if isOpen}
    <div
      bind:this={dropdownElement}
      class={dropdownClasses}
      style="min-width: {minWidth}; max-height: {maxHeight}"
      in:fly={{ ...flyDirection, duration: 200, easing: quintOut }}
      out:fly={{ ...flyDirection, duration: 150, easing: quintOut }}
      on:mouseenter={handleDropdownMouseEnter}
      on:mouseleave={handleDropdownMouseLeave}
      use:focusTrap
      role="menu"
      aria-orientation="vertical"
    >
      <!-- 搜索框 -->
      {#if searchable}
        <div class="dropdown-search">
          <input
            bind:this={searchInput}
            bind:value={searchQuery}
            class="dropdown-search-input"
            placeholder={placeholder}
            type="text"
          />
        </div>
      {/if}
      
      <!-- 菜单项 -->
      <div class="dropdown-content">
        {#each filteredItems as item, index}
          {#if item.divider}
            <div class="dropdown-divider" role="separator"></div>
          {:else}
            {#if item.href}
              <a
                href={item.href}
                class="dropdown-item"
                class:dropdown-item-disabled={item.disabled}
                class:dropdown-item-danger={item.danger}
                on:click|preventDefault={() => handleItemClick(item)}
                role="menuitem"
                tabindex={item.disabled ? -1 : 0}
              >
                {#if item.icon}
                  <span class="dropdown-item-icon">{item.icon}</span>
                {/if}
                <span class="dropdown-item-label">{item.label}</span>
              </a>
            {:else}
              <button
                class="dropdown-item"
                class:dropdown-item-disabled={item.disabled}
                class:dropdown-item-danger={item.danger}
                on:click={() => handleItemClick(item)}
                disabled={item.disabled}
                role="menuitem"
                tabindex={item.disabled ? -1 : 0}
                type="button"
              >
                {#if item.icon}
                  <span class="dropdown-item-icon">{item.icon}</span>
                {/if}
                <span class="dropdown-item-label">{item.label}</span>
              </button>
            {/if}
          {/if}
        {/each}
        
        {#if searchable && filteredItems.length === 0}
          <div class="dropdown-empty">
            没有找到匹配项
          </div>
        {/if}
      </div>
    </div>
  {/if}
</div>

<style>
  .dropdown {
    position: relative;
    display: inline-block;
  }
  
  .dropdown-trigger {
    cursor: pointer;
  }
  
  .dropdown-disabled {
    cursor: not-allowed;
    opacity: 0.5;
  }
  
  /* 下拉菜单 */
  .dropdown-menu {
    position: absolute;
    z-index: 1000;
    background: white;
    border: 1px solid #e5e7eb;
    border-radius: 8px;
    box-shadow: 0 10px 25px rgba(0, 0, 0, 0.1);
    overflow: hidden;
  }
  
  /* 搜索框 */
  .dropdown-search {
    padding: 8px;
    border-bottom: 1px solid #e5e7eb;
  }
  
  .dropdown-search-input {
    width: 100%;
    padding: 6px 8px;
    border: 1px solid #d1d5db;
    border-radius: 4px;
    font-size: 13px;
    background: #f9fafb;
    transition: all 0.2s;
  }
  
  .dropdown-search-input:focus {
    outline: none;
    border-color: #667eea;
    background: white;
  }
  
  /* 内容区域 */
  .dropdown-content {
    padding: 4px 0;
    overflow-y: auto;
  }
  
  /* 菜单项 */
  .dropdown-item {
    display: flex;
    align-items: center;
    gap: 8px;
    width: 100%;
    padding: 8px 12px;
    border: none;
    background: none;
    font: inherit;
    text-align: left;
    color: #374151;
    cursor: pointer;
    transition: all 0.2s;
    text-decoration: none;
    line-height: 1.4;
  }
  
  .dropdown-item:hover {
    background: #f3f4f6;
  }
  
  .dropdown-item:focus {
    outline: none;
    background: #f3f4f6;
  }
  
  .dropdown-item-disabled {
    color: #9ca3af;
    cursor: not-allowed;
  }
  
  .dropdown-item-disabled:hover {
    background: transparent;
  }
  
  .dropdown-item-danger {
    color: #ef4444;
  }
  
  .dropdown-item-danger:hover {
    background: #fef2f2;
  }
  
  /* 图标 */
  .dropdown-item-icon {
    font-size: 16px;
    line-height: 1;
    flex-shrink: 0;
  }
  
  /* 标签 */
  .dropdown-item-label {
    flex: 1;
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  
  /* 分割线 */
  .dropdown-divider {
    height: 1px;
    background: #e5e7eb;
    margin: 4px 0;
  }
  
  /* 空状态 */
  .dropdown-empty {
    padding: 12px;
    text-align: center;
    color: #9ca3af;
    font-size: 13px;
  }
  
  /* 深色模式 */
  @media (prefers-color-scheme: dark) {
    .dropdown-menu {
      background: #1f2937;
      border-color: #374151;
      box-shadow: 0 10px 25px rgba(0, 0, 0, 0.3);
    }
    
    .dropdown-search {
      border-bottom-color: #374151;
    }
    
    .dropdown-search-input {
      background: #374151;
      border-color: #4b5563;
      color: #f3f4f6;
    }
    
    .dropdown-search-input:focus {
      background: #4b5563;
      border-color: #667eea;
    }
    
    .dropdown-item {
      color: #f3f4f6;
    }
    
    .dropdown-item:hover {
      background: #374151;
    }
    
    .dropdown-item:focus {
      background: #374151;
    }
    
    .dropdown-item-disabled {
      color: #6b7280;
    }
    
    .dropdown-item-danger {
      color: #fca5a5;
    }
    
    .dropdown-item-danger:hover {
      background: #7f1d1d;
    }
    
    .dropdown-divider {
      background: #374151;
    }
    
    .dropdown-empty {
      color: #6b7280;
    }
  }
  
  /* 移动端优化 */
  @media (max-width: 768px) {
    .dropdown-menu {
      min-width: 250px !important;
      max-width: calc(100vw - 32px);
    }
    
    .dropdown-item {
      padding: 12px 16px;
      min-height: 44px;
    }
    
    .dropdown-item-icon {
      font-size: 18px;
    }
    
    .dropdown-search-input {
      padding: 8px 12px;
      font-size: 14px;
    }
  }
  
  @media (max-width: 480px) {
    .dropdown-menu {
      left: 8px !important;
      right: 8px !important;
      width: auto !important;
      min-width: auto !important;
    }
  }
  
  /* 无障碍优化 */
  @media (prefers-reduced-motion: reduce) {
    .dropdown-item {
      transition: none;
    }
    
    .dropdown-search-input {
      transition: none;
    }
  }
  
  /* 高对比度模式 */
  @media (prefers-contrast: high) {
    .dropdown-menu {
      border-width: 2px;
    }
    
    .dropdown-item:focus {
      outline: 2px solid currentColor;
      outline-offset: -2px;
    }
    
    .dropdown-search-input:focus {
      outline: 2px solid currentColor;
    }
  }
</style> 