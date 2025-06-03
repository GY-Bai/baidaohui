<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { scale, slide } from 'svelte/transition';
  import { cubicOut, elasticOut } from 'svelte/easing';
  
  export let items: Array<{
    id: string;
    label: string;
    icon: string;
    activeIcon?: string;
    description?: string;
    badge?: number;
  }> = [];
  
  export let activeId: string = '';
  export let theme: 'default' | 'colorful' = 'default';
  
  const dispatch = createEventDispatcher();
  
  let touchStartY = 0;
  let isDragging = false;
  
  function handleItemClick(item: any) {
    if (item.id === 'logout') {
      // 特殊处理登出操作
      dispatch('logout');
      return;
    }
    
    dispatch('change', { id: item.id, item });
  }
  
  function handleTouchStart(e: TouchEvent) {
    touchStartY = e.touches[0].clientY;
    isDragging = false;
  }
  
  function handleTouchMove(e: TouchEvent) {
    const deltaY = Math.abs(e.touches[0].clientY - touchStartY);
    if (deltaY > 10) {
      isDragging = true;
    }
  }
  
  function handleTouchEnd(e: TouchEvent, item: any) {
    if (!isDragging) {
      handleItemClick(item);
    }
    isDragging = false;
  }

  // 获取图标内容（支持emoji和svg路径）
  function getIconContent(item: any, isActive: boolean) {
    const iconToUse = isActive && item.activeIcon ? item.activeIcon : item.icon;
    
    // 如果是emoji，直接返回
    if (iconToUse.length <= 4 && !/^[a-zA-Z]/.test(iconToUse)) {
      return iconToUse;
    }
    
    // 否则假设是SVG路径或图标名称
    return iconToUse;
  }
</script>

<nav 
  class="dock-container {theme}"
  role="navigation"
  aria-label="主导航"
>
  <div class="dock-wrapper">
    {#each items as item (item.id)}
      {@const isActive = activeId === item.id}
      <button
        class="dock-item"
        class:active={isActive}
        on:click={() => handleItemClick(item)}
        on:touchstart={handleTouchStart}
        on:touchmove={handleTouchMove}
        on:touchend={(e) => handleTouchEnd(e, item)}
        aria-label={item.description || item.label}
        title={item.description || item.label}
      >
        <!-- 活跃状态背景指示器 -->
        {#if isActive}
          <div 
            class="active-indicator"
            in:scale={{ duration: 200, easing: elasticOut }}
            out:scale={{ duration: 150 }}
          ></div>
        {/if}
        
        <!-- 图标容器 -->
        <div 
          class="icon-container"
          class:active={isActive}
        >
          <!-- 图标内容 -->
          <div class="icon-content">
            {getIconContent(item, isActive)}
          </div>
          
          <!-- 徽章 -->
          {#if item.badge && item.badge > 0}
            <div 
              class="badge"
              in:scale={{ duration: 200, easing: cubicOut }}
            >
              {item.badge > 99 ? '99+' : item.badge}
            </div>
          {/if}
        </div>
        
        <!-- 文字标签 -->
        <span 
          class="label"
          class:active={isActive}
        >
          {item.label}
        </span>
        
        <!-- 点击波纹效果 -->
        <div class="ripple"></div>
      </button>
    {/each}
  </div>
  
  <!-- 安全区域适配 -->
  <div class="safe-area"></div>
</nav>

<style>
  .dock-container {
    position: fixed;
    bottom: 0;
    left: 0;
    right: 0;
    z-index: 1000;
    background: rgba(255, 255, 255, 0.95);
    backdrop-filter: blur(20px);
    -webkit-backdrop-filter: blur(20px);
    border-top: 1px solid rgba(0, 0, 0, 0.06);
    transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
  }
  
  .dock-container.colorful {
    background: rgba(248, 250, 252, 0.95);
  }
  
  .dock-wrapper {
    display: flex;
    justify-content: space-around;
    align-items: center;
    padding: 8px 16px 4px 16px;
    max-width: 600px;
    margin: 0 auto;
    position: relative;
  }
  
  .dock-item {
    position: relative;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 8px 12px;
    min-width: 60px;
    min-height: 64px;
    background: none;
    border: none;
    border-radius: 16px;
    cursor: pointer;
    transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
    outline: none;
    overflow: hidden;
    
    /* 触摸优化 */
    -webkit-tap-highlight-color: transparent;
    touch-action: manipulation;
  }
  
  .dock-item:active {
    transform: scale(0.95);
  }
  
  .dock-item.active {
    transform: translateY(-2px);
  }
  
  .active-indicator {
    position: absolute;
    top: 6px;
    left: 50%;
    transform: translateX(-50%);
    width: 32px;
    height: 32px;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    border-radius: 50%;
    z-index: -1;
  }
  
  .icon-container {
    position: relative;
    display: flex;
    align-items: center;
    justify-content: center;
    width: 32px;
    height: 32px;
    margin-bottom: 4px;
    transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
  }
  
  .icon-container.active {
    transform: scale(1.1);
  }
  
  .icon-content {
    font-size: 24px;
    line-height: 1;
    transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
    filter: grayscale(0.3);
  }
  
  .dock-item.active .icon-content {
    filter: none;
    color: white;
    text-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  }
  
  .badge {
    position: absolute;
    top: -4px;
    right: -4px;
    min-width: 18px;
    height: 18px;
    padding: 0 4px;
    background: #ef4444;
    color: white;
    font-size: 10px;
    font-weight: 600;
    border-radius: 9px;
    display: flex;
    align-items: center;
    justify-content: center;
    border: 2px solid white;
    box-shadow: 0 2px 8px rgba(239, 68, 68, 0.3);
  }
  
  .label {
    font-size: 11px;
    font-weight: 500;
    color: #6b7280;
    transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
    letter-spacing: 0.025em;
    line-height: 1.2;
    text-align: center;
    max-width: 60px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  
  .label.active {
    color: #374151;
    font-weight: 600;
    transform: scale(1.05);
  }
  
  .ripple {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    border-radius: 16px;
    overflow: hidden;
    pointer-events: none;
  }
  
  .dock-item:active .ripple::before {
    content: '';
    position: absolute;
    top: 50%;
    left: 50%;
    width: 0;
    height: 0;
    background: rgba(102, 126, 234, 0.1);
    border-radius: 50%;
    transform: translate(-50%, -50%);
    animation: ripple 0.6s ease-out;
  }
  
  @keyframes ripple {
    to {
      width: 100px;
      height: 100px;
      opacity: 0;
    }
  }
  
  .safe-area {
    height: env(safe-area-inset-bottom);
    background: inherit;
  }
  
  /* 主题变体 */
  .dock-container.colorful .active-indicator {
    background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
  }
  
  /* 深色模式适配 */
  @media (prefers-color-scheme: dark) {
    .dock-container {
      background: rgba(17, 24, 39, 0.95);
      border-top-color: rgba(255, 255, 255, 0.1);
    }
    
    .icon-content {
      filter: grayscale(0.2) brightness(0.9);
    }
    
    .dock-item.active .icon-content {
      filter: none;
      color: white;
    }
    
    .label {
      color: #9ca3af;
    }
    
    .label.active {
      color: #f3f4f6;
    }
  }
  
  /* 响应式优化 */
  @media (max-width: 480px) {
    .dock-wrapper {
      padding: 6px 8px 4px 8px;
    }
    
    .dock-item {
      min-width: 50px;
      min-height: 58px;
      padding: 6px 8px;
    }
    
    .icon-container {
      width: 28px;
      height: 28px;
    }
    
    .icon-content {
      font-size: 22px;
    }
    
    .label {
      font-size: 10px;
    }
    
    .active-indicator {
      width: 28px;
      height: 28px;
    }
  }
  
  /* 超宽屏优化 */
  @media (min-width: 768px) {
    .dock-wrapper {
      max-width: 400px;
      border-radius: 24px 24px 0 0;
    }
    
    .dock-container {
      left: 50%;
      right: auto;
      transform: translateX(-50%);
      border-radius: 24px 24px 0 0;
      border-left: 1px solid rgba(0, 0, 0, 0.06);
      border-right: 1px solid rgba(0, 0, 0, 0.06);
    }
  }
  
  /* 悬浮态优化（适用于支持hover的设备） */
  @media (hover: hover) {
    .dock-item:hover {
      background: rgba(102, 126, 234, 0.05);
    }
    
    .dock-item:hover .icon-content {
      transform: scale(1.1);
    }
    
    .dock-item:hover .label {
      color: #374151;
    }
  }
  
  /* 无障碍优化 */
  @media (prefers-reduced-motion: reduce) {
    .dock-item,
    .icon-container,
    .icon-content,
    .label {
      transition: none;
    }
    
    .dock-item:active {
      transform: none;
    }
    
    .active-indicator {
      animation: none;
    }
  }
  
  /* 高对比度模式 */
  @media (prefers-contrast: high) {
    .dock-container {
      border-top-width: 2px;
      border-top-color: #000;
    }
    
    .label {
      color: #000;
      font-weight: 600;
    }
    
    .dock-item.active .icon-content {
      color: #000;
      background: #fff;
      border-radius: 50%;
    }
  }
</style> 