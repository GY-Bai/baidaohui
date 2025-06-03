<script lang="ts">
  export let status: 'online' | 'offline' | 'busy' | 'away' | 'invisible' = 'offline';
  export let size: 'xs' | 'sm' | 'default' | 'lg' = 'default';
  export let position: 'top-left' | 'top-right' | 'bottom-left' | 'bottom-right' = 'bottom-right';
  export let showText = false;
  export let animated = true;
  export let className = '';
  
  // 状态配置
  const statusConfig = {
    online: {
      color: '#16a34a',
      bgColor: '#dcfce7',
      text: '在线',
      icon: '●'
    },
    offline: {
      color: '#6b7280',
      bgColor: '#f3f4f6',
      text: '离线',
      icon: '●'
    },
    busy: {
      color: '#ef4444',
      bgColor: '#fee2e2',
      text: '忙碌',
      icon: '●'
    },
    away: {
      color: '#f59e0b',
      bgColor: '#fef3c7',
      text: '离开',
      icon: '●'
    },
    invisible: {
      color: '#d1d5db',
      bgColor: '#f9fafb',
      text: '隐身',
      icon: '●'
    }
  };
  
  // 尺寸配置
  const sizeConfig = {
    xs: {
      size: '6px',
      fontSize: '10px',
      padding: '2px 4px'
    },
    sm: {
      size: '8px',
      fontSize: '11px',
      padding: '2px 6px'
    },
    default: {
      size: '10px',
      fontSize: '12px',
      padding: '4px 8px'
    },
    lg: {
      size: '12px',
      fontSize: '13px',
      padding: '4px 10px'
    }
  };
  
  $: currentStatus = statusConfig[status];
  $: currentSize = sizeConfig[size];
  
  $: indicatorClasses = [
    'status-indicator',
    `status-${status}`,
    `size-${size}`,
    `position-${position}`,
    animated && 'animated',
    showText && 'with-text',
    className
  ].filter(Boolean).join(' ');
  
  $: indicatorStyle = [
    `--status-color: ${currentStatus.color}`,
    `--status-bg-color: ${currentStatus.bgColor}`,
    `--indicator-size: ${currentSize.size}`,
    `--font-size: ${currentSize.fontSize}`,
    `--padding: ${currentSize.padding}`
  ].join('; ');
</script>

<div 
  class={indicatorClasses}
  style={indicatorStyle}
  title={currentStatus.text}
  role="status"
  aria-label={`状态: ${currentStatus.text}`}
>
  {#if showText}
    <span class="status-icon">{currentStatus.icon}</span>
    <span class="status-text">{currentStatus.text}</span>
  {:else}
    <div class="status-dot"></div>
  {/if}
</div>

<style>
  .status-indicator {
    position: absolute;
    display: flex;
    align-items: center;
    gap: 4px;
    z-index: 1;
    border-radius: 50px;
    font-size: var(--font-size);
    font-weight: 500;
    line-height: 1;
  }
  
  /* 位置样式 */
  .position-top-left {
    top: 0;
    left: 0;
  }
  
  .position-top-right {
    top: 0;
    right: 0;
  }
  
  .position-bottom-left {
    bottom: 0;
    left: 0;
  }
  
  .position-bottom-right {
    bottom: 0;
    right: 0;
  }
  
  /* 状态点 */
  .status-dot {
    width: var(--indicator-size);
    height: var(--indicator-size);
    border-radius: 50%;
    background-color: var(--status-color);
    border: 2px solid white;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  }
  
  /* 带文本的状态 */
  .with-text {
    background-color: var(--status-bg-color);
    color: var(--status-color);
    padding: var(--padding);
    border: 1px solid var(--status-color);
    border-radius: 12px;
    position: relative;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  }
  
  .status-icon {
    font-size: 0.8em;
  }
  
  .status-text {
    white-space: nowrap;
  }
  
  /* 动画效果 */
  .animated .status-dot {
    transition: all 0.3s ease;
  }
  
  .animated.status-online .status-dot {
    animation: onlinePulse 2s infinite;
  }
  
  .animated.status-busy .status-dot {
    animation: busyPulse 1s infinite alternate;
  }
  
  .animated.status-away .status-dot {
    animation: awayBlink 2s infinite;
  }
  
  @keyframes onlinePulse {
    0%, 100% {
      box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1), 0 0 0 0 rgba(22, 163, 74, 0.4);
    }
    50% {
      box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1), 0 0 0 4px rgba(22, 163, 74, 0.1);
    }
  }
  
  @keyframes busyPulse {
    0% {
      transform: scale(1);
    }
    100% {
      transform: scale(1.1);
    }
  }
  
  @keyframes awayBlink {
    0%, 50% {
      opacity: 1;
    }
    25%, 75% {
      opacity: 0.5;
    }
  }
  
  /* 尺寸变体 */
  .size-xs .status-dot {
    border-width: 1px;
  }
  
  .size-sm .status-dot {
    border-width: 1px;
  }
  
  .size-lg .status-dot {
    border-width: 3px;
  }
  
  /* 悬停效果 */
  .status-indicator:hover .status-dot {
    transform: scale(1.1);
  }
  
  .with-text:hover {
    transform: scale(1.05);
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
  }
  
  /* 深色模式 */
  @media (prefers-color-scheme: dark) {
    .status-dot {
      border-color: #1f2937;
    }
    
    .with-text {
      box-shadow: 0 2px 8px rgba(0, 0, 0, 0.3);
    }
    
    .status-online {
      --status-bg-color: #064e3b;
    }
    
    .status-offline {
      --status-bg-color: #374151;
    }
    
    .status-busy {
      --status-bg-color: #7f1d1d;
    }
    
    .status-away {
      --status-bg-color: #78350f;
    }
    
    .status-invisible {
      --status-bg-color: #1f2937;
    }
  }
  
  /* 高对比度模式 */
  @media (prefers-contrast: high) {
    .status-dot {
      border-width: 3px;
    }
    
    .with-text {
      border-width: 2px;
      font-weight: 600;
    }
  }
  
  /* 减少动画模式 */
  @media (prefers-reduced-motion: reduce) {
    .animated .status-dot,
    .with-text {
      animation: none;
      transition: none;
    }
    
    .status-indicator:hover .status-dot,
    .with-text:hover {
      transform: none;
    }
  }
</style> 