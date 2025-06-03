<script lang="ts">
  import { createEventDispatcher, onMount } from 'svelte';
  import { fade, fly } from 'svelte/transition';
  import { quintOut } from 'svelte/easing';
  
  export let content: string = '';
  export let position: 'top' | 'bottom' | 'left' | 'right' = 'top';
  export let trigger: 'hover' | 'click' | 'focus' | 'manual' = 'hover';
  export let delay: number = 500;
  export let hideDelay: number = 100;
  export let disabled: boolean = false;
  export let visible: boolean = false;
  export let arrow: boolean = true;
  export let maxWidth: string = '300px';
  export let offset: number = 8;
  
  const dispatch = createEventDispatcher();
  
  let triggerElement: HTMLElement;
  let tooltipElement: HTMLElement;
  let showTimeout: number;
  let hideTimeout: number;
  let isHovered = false;
  let isFocused = false;
  
  $: shouldShow = !disabled && (
    visible ||
    (trigger === 'hover' && isHovered) ||
    (trigger === 'focus' && isFocused)
  );
  
  $: tooltipClasses = [
    'tooltip',
    `tooltip-${position}`,
    arrow ? 'tooltip-arrow' : ''
  ].filter(Boolean).join(' ');
  
  $: flyDirection = {
    top: { y: 10, x: 0 },
    bottom: { y: -10, x: 0 },
    left: { x: 10, y: 0 },
    right: { x: -10, y: 0 }
  }[position];
  
  function show() {
    if (disabled) return;
    
    clearTimeout(hideTimeout);
    
    if (trigger === 'hover' && delay > 0) {
      showTimeout = setTimeout(() => {
        isHovered = true;
        dispatch('show');
      }, delay);
    } else {
      isHovered = true;
      dispatch('show');
    }
  }
  
  function hide() {
    clearTimeout(showTimeout);
    
    if (trigger === 'hover' && hideDelay > 0) {
      hideTimeout = setTimeout(() => {
        isHovered = false;
        dispatch('hide');
      }, hideDelay);
    } else {
      isHovered = false;
      dispatch('hide');
    }
  }
  
  function handleClick() {
    if (trigger === 'click') {
      if (shouldShow) {
        hide();
      } else {
        show();
      }
    }
  }
  
  function handleFocus() {
    if (trigger === 'focus') {
      isFocused = true;
      dispatch('show');
    }
  }
  
  function handleBlur() {
    if (trigger === 'focus') {
      isFocused = false;
      dispatch('hide');
    }
  }
  
  function handleKeydown(event: KeyboardEvent) {
    if (event.key === 'Escape' && shouldShow) {
      hide();
      isFocused = false;
    }
  }
  
  function positionTooltip() {
    if (!triggerElement || !tooltipElement) return;
    
    const triggerRect = triggerElement.getBoundingClientRect();
    const tooltipRect = tooltipElement.getBoundingClientRect();
    const viewportWidth = window.innerWidth;
    const viewportHeight = window.innerHeight;
    
    let top = 0;
    let left = 0;
    
    switch (position) {
      case 'top':
        top = triggerRect.top - tooltipRect.height - offset;
        left = triggerRect.left + (triggerRect.width - tooltipRect.width) / 2;
        break;
      case 'bottom':
        top = triggerRect.bottom + offset;
        left = triggerRect.left + (triggerRect.width - tooltipRect.width) / 2;
        break;
      case 'left':
        top = triggerRect.top + (triggerRect.height - tooltipRect.height) / 2;
        left = triggerRect.left - tooltipRect.width - offset;
        break;
      case 'right':
        top = triggerRect.top + (triggerRect.height - tooltipRect.height) / 2;
        left = triggerRect.right + offset;
        break;
    }
    
    // 边界检测和调整
    if (left < 8) {
      left = 8;
    } else if (left + tooltipRect.width > viewportWidth - 8) {
      left = viewportWidth - tooltipRect.width - 8;
    }
    
    if (top < 8) {
      top = 8;
    } else if (top + tooltipRect.height > viewportHeight - 8) {
      top = viewportHeight - tooltipRect.height - 8;
    }
    
    tooltipElement.style.top = `${top + window.scrollY}px`;
    tooltipElement.style.left = `${left + window.scrollX}px`;
  }
  
  onMount(() => {
    if (trigger === 'hover') {
      triggerElement.addEventListener('mouseenter', show);
      triggerElement.addEventListener('mouseleave', hide);
    }
    
    if (trigger === 'click') {
      triggerElement.addEventListener('click', handleClick);
    }
    
    if (trigger === 'focus') {
      triggerElement.addEventListener('focus', handleFocus);
      triggerElement.addEventListener('blur', handleBlur);
    }
    
    document.addEventListener('keydown', handleKeydown);
    
    return () => {
      clearTimeout(showTimeout);
      clearTimeout(hideTimeout);
      
      if (triggerElement) {
        triggerElement.removeEventListener('mouseenter', show);
        triggerElement.removeEventListener('mouseleave', hide);
        triggerElement.removeEventListener('click', handleClick);
        triggerElement.removeEventListener('focus', handleFocus);
        triggerElement.removeEventListener('blur', handleBlur);
      }
      
      document.removeEventListener('keydown', handleKeydown);
    };
  });
  
  $: if (shouldShow && tooltipElement) {
    // 使用 requestAnimationFrame 确保元素已渲染
    requestAnimationFrame(() => {
      positionTooltip();
    });
  }
</script>

<div class="tooltip-wrapper">
  <!-- 触发元素 -->
  <div 
    bind:this={triggerElement}
    class="tooltip-trigger"
    on:click={handleClick}
    on:focus={handleFocus}
    on:blur={handleBlur}
  >
    <slot />
  </div>
  
  <!-- Tooltip内容 -->
  {#if shouldShow && content}
    <div
      bind:this={tooltipElement}
      class={tooltipClasses}
      style="max-width: {maxWidth}"
      in:fly={{ ...flyDirection, duration: 200, easing: quintOut }}
      out:fly={{ ...flyDirection, duration: 150, easing: quintOut }}
      role="tooltip"
      aria-hidden="false"
    >
      {content}
      
      {#if arrow}
        <div class="tooltip-arrow-element"></div>
      {/if}
    </div>
  {/if}
</div>

<style>
  .tooltip-wrapper {
    position: relative;
    display: inline-block;
  }
  
  .tooltip-trigger {
    display: inline-block;
  }
  
  .tooltip {
    position: absolute;
    z-index: 1000;
    padding: 8px 12px;
    background: #1f2937;
    color: white;
    font-size: 12px;
    line-height: 1.4;
    border-radius: 6px;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
    word-wrap: break-word;
    pointer-events: none;
  }
  
  /* 箭头 */
  .tooltip-arrow .tooltip-arrow-element {
    position: absolute;
    width: 0;
    height: 0;
    border: 4px solid transparent;
  }
  
  /* 不同位置的箭头 */
  .tooltip-top .tooltip-arrow-element {
    bottom: -8px;
    left: 50%;
    transform: translateX(-50%);
    border-top-color: #1f2937;
  }
  
  .tooltip-bottom .tooltip-arrow-element {
    top: -8px;
    left: 50%;
    transform: translateX(-50%);
    border-bottom-color: #1f2937;
  }
  
  .tooltip-left .tooltip-arrow-element {
    right: -8px;
    top: 50%;
    transform: translateY(-50%);
    border-left-color: #1f2937;
  }
  
  .tooltip-right .tooltip-arrow-element {
    left: -8px;
    top: 50%;
    transform: translateY(-50%);
    border-right-color: #1f2937;
  }
  
  /* 深色模式 */
  @media (prefers-color-scheme: dark) {
    .tooltip {
      background: #374151;
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
    }
    
    .tooltip-top .tooltip-arrow-element {
      border-top-color: #374151;
    }
    
    .tooltip-bottom .tooltip-arrow-element {
      border-bottom-color: #374151;
    }
    
    .tooltip-left .tooltip-arrow-element {
      border-left-color: #374151;
    }
    
    .tooltip-right .tooltip-arrow-element {
      border-right-color: #374151;
    }
  }
  
  /* 移动端优化 */
  @media (max-width: 768px) {
    .tooltip {
      font-size: 11px;
      padding: 6px 10px;
      max-width: 250px !important;
    }
    
    .tooltip-arrow .tooltip-arrow-element {
      border-width: 3px;
    }
    
    .tooltip-top .tooltip-arrow-element {
      bottom: -6px;
    }
    
    .tooltip-bottom .tooltip-arrow-element {
      top: -6px;
    }
    
    .tooltip-left .tooltip-arrow-element {
      right: -6px;
    }
    
    .tooltip-right .tooltip-arrow-element {
      left: -6px;
    }
  }
  
  @media (max-width: 480px) {
    .tooltip {
      max-width: 200px !important;
      padding: 4px 8px;
      font-size: 10px;
    }
  }
  
  /* 无障碍优化 */
  @media (prefers-reduced-motion: reduce) {
    .tooltip {
      transition: none;
    }
  }
  
  /* 高对比度模式 */
  @media (prefers-contrast: high) {
    .tooltip {
      border: 1px solid #fff;
    }
  }
</style> 