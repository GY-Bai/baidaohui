<script lang="ts">
  export let variant = 'default'; // default, primary, secondary, success, warning, error, info
  export let size = 'default'; // xs, sm, default, lg
  export let dot = false; // 圆点模式
  export let outline = false; // 描边模式
  export let pill = false; // 胶囊模式
  export let icon = ''; // 图标
  export let count = null; // 数字计数
  export let max = 99; // 最大显示数字
  export let showZero = false; // 显示零
  export let className = '';
  export let color = null; // 自定义颜色
  export let backgroundColor = null; // 自定义背景色
  
  // 计算显示的计数
  $: displayCount = (() => {
    if (count === null || count === undefined) return null;
    if (count === 0 && !showZero) return null;
    if (count > max) return `${max}+`;
    return count;
  })();
  
  // 尺寸配置
  const sizes = {
    xs: {
      height: '16px',
      padding: '0 4px',
      fontSize: '10px',
      iconSize: '8px',
      dotSize: '6px'
    },
    sm: {
      height: '20px',
      padding: '0 6px',
      fontSize: '11px',
      iconSize: '10px',
      dotSize: '8px'
    },
    default: {
      height: '24px',
      padding: '0 8px',
      fontSize: '12px',
      iconSize: '12px',
      dotSize: '10px'
    },
    lg: {
      height: '28px',
      padding: '0 10px',
      fontSize: '14px',
      iconSize: '14px',
      dotSize: '12px'
    }
  };
  
  // 颜色主题
  const variants = {
    default: {
      bg: '#f3f4f6',
      text: '#374151',
      border: '#e5e7eb'
    },
    primary: {
      bg: '#3b82f6',
      text: '#ffffff',
      border: '#2563eb'
    },
    secondary: {
      bg: '#6b7280',
      text: '#ffffff',
      border: '#4b5563'
    },
    success: {
      bg: '#16a34a',
      text: '#ffffff',
      border: '#15803d'
    },
    warning: {
      bg: '#f59e0b',
      text: '#ffffff',
      border: '#d97706'
    },
    error: {
      bg: '#ef4444',
      text: '#ffffff',
      border: '#dc2626'
    },
    info: {
      bg: '#06b6d4',
      text: '#ffffff',
      border: '#0891b2'
    }
  };
  
  $: currentSize = sizes[size];
  $: currentVariant = variants[variant];
  $: finalBg = backgroundColor || currentVariant.bg;
  $: finalText = color || currentVariant.text;
  $: finalBorder = currentVariant.border;
  
  $: badgeClasses = [
    'badge',
    `badge-${variant}`,
    `badge-${size}`,
    dot && 'badge-dot',
    outline && 'badge-outline',
    pill && 'badge-pill',
    className
  ].filter(Boolean).join(' ');
  
  $: badgeStyle = [
    `background-color: ${outline ? 'transparent' : finalBg}`,
    `color: ${outline ? finalBg : finalText}`,
    `border-color: ${finalBorder}`,
    `height: ${dot ? currentSize.dotSize : currentSize.height}`,
    `min-width: ${dot ? currentSize.dotSize : currentSize.height}`,
    !dot && `padding: ${currentSize.padding}`,
    `font-size: ${currentSize.fontSize}`
  ].filter(Boolean).join('; ');
</script>

<span
  class={badgeClasses}
  style={badgeStyle}
  role={count !== null ? 'status' : 'img'}
  aria-label={count !== null ? `${count} 个通知` : ''}
>
  {#if dot}
    <!-- 圆点模式不显示内容 -->
  {:else if displayCount !== null}
    <!-- 数字计数 -->
    {displayCount}
  {:else if icon}
    <!-- 图标模式 -->
    <span class="badge-icon" style="font-size: {currentSize.iconSize}">
      {icon}
    </span>
    <slot />
  {:else}
    <!-- 文本内容 -->
    <slot />
  {/if}
</span>

<style>
  .badge {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    font-weight: 500;
    line-height: 1;
    white-space: nowrap;
    vertical-align: middle;
    border: 1px solid transparent;
    border-radius: 6px;
    transition: all 0.2s ease;
    cursor: default;
    gap: 4px;
  }
  
  /* 圆点模式 */
  .badge-dot {
    border-radius: 50%;
    padding: 0 !important;
    width: var(--dot-size);
    min-width: var(--dot-size);
  }
  
  /* 描边模式 */
  .badge-outline {
    background-color: transparent !important;
    border-width: 1px;
  }
  
  /* 胶囊模式 */
  .badge-pill {
    border-radius: 50px;
  }
  
  /* 尺寸样式 */
  .badge-xs {
    --dot-size: 6px;
  }
  
  .badge-sm {
    --dot-size: 8px;
  }
  
  .badge-default {
    --dot-size: 10px;
  }
  
  .badge-lg {
    --dot-size: 12px;
  }
  
  /* 图标 */
  .badge-icon {
    display: inline-flex;
    align-items: center;
    justify-content: center;
  }
  
  /* 变体样式 */
  .badge-default {
    background-color: #f3f4f6;
    color: #374151;
    border-color: #e5e7eb;
  }
  
  .badge-primary {
    background-color: #3b82f6;
    color: #ffffff;
    border-color: #2563eb;
  }
  
  .badge-secondary {
    background-color: #6b7280;
    color: #ffffff;
    border-color: #4b5563;
  }
  
  .badge-success {
    background-color: #16a34a;
    color: #ffffff;
    border-color: #15803d;
  }
  
  .badge-warning {
    background-color: #f59e0b;
    color: #ffffff;
    border-color: #d97706;
  }
  
  .badge-error {
    background-color: #ef4444;
    color: #ffffff;
    border-color: #dc2626;
  }
  
  .badge-info {
    background-color: #06b6d4;
    color: #ffffff;
    border-color: #0891b2;
  }
  
  /* 描边变体 */
  .badge-outline.badge-default {
    color: #374151;
    border-color: #e5e7eb;
  }
  
  .badge-outline.badge-primary {
    color: #3b82f6;
    border-color: #3b82f6;
  }
  
  .badge-outline.badge-secondary {
    color: #6b7280;
    border-color: #6b7280;
  }
  
  .badge-outline.badge-success {
    color: #16a34a;
    border-color: #16a34a;
  }
  
  .badge-outline.badge-warning {
    color: #f59e0b;
    border-color: #f59e0b;
  }
  
  .badge-outline.badge-error {
    color: #ef4444;
    border-color: #ef4444;
  }
  
  .badge-outline.badge-info {
    color: #06b6d4;
    border-color: #06b6d4;
  }
  
  /* 悬停效果 */
  .badge:hover {
    transform: scale(1.05);
  }
  
  .badge-primary:hover {
    background-color: #2563eb;
  }
  
  .badge-secondary:hover {
    background-color: #4b5563;
  }
  
  .badge-success:hover {
    background-color: #15803d;
  }
  
  .badge-warning:hover {
    background-color: #d97706;
  }
  
  .badge-error:hover {
    background-color: #dc2626;
  }
  
  .badge-info:hover {
    background-color: #0891b2;
  }
  
  .badge-outline:hover {
    background-color: currentColor;
    color: white;
  }
  
  .badge-outline.badge-default:hover {
    background-color: #374151;
    color: white;
  }
  
  /* 脉冲动画（用于通知徽章） */
  .badge-pulse {
    animation: badgePulse 2s infinite;
  }
  
  @keyframes badgePulse {
    0%, 100% {
      opacity: 1;
    }
    50% {
      opacity: 0.5;
    }
  }
  
  /* 数字计数特殊样式 */
  .badge:has-text {
    font-variant-numeric: tabular-nums;
  }
  
  /* 长文本处理 */
  .badge:not(.badge-dot) {
    max-width: 200px;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  
  /* 移动端适配 */
  @media (max-width: 768px) {
    .badge {
      font-size: 0.75em;
    }
    
    .badge-xs {
      height: 14px;
      min-width: 14px;
      padding: 0 3px;
      font-size: 9px;
    }
    
    .badge-sm {
      height: 18px;
      min-width: 18px;
      padding: 0 5px;
      font-size: 10px;
    }
    
    .badge-default {
      height: 22px;
      min-width: 22px;
      padding: 0 7px;
      font-size: 11px;
    }
    
    .badge-lg {
      height: 26px;
      min-width: 26px;
      padding: 0 9px;
      font-size: 13px;
    }
  }
  
  /* 高对比度模式 */
  @media (prefers-contrast: high) {
    .badge {
      border-width: 2px;
      font-weight: 600;
    }
    
    .badge-outline {
      border-width: 2px;
    }
  }
  
  /* 减少动画模式 */
  @media (prefers-reduced-motion: reduce) {
    .badge {
      transition: none;
    }
    
    .badge:hover {
      transform: none;
    }
    
    .badge-pulse {
      animation: none;
    }
  }
  
  /* 深色模式 */
  @media (prefers-color-scheme: dark) {
    .badge-default {
      background-color: #374151;
      color: #f9fafb;
      border-color: #4b5563;
    }
    
    .badge-outline.badge-default {
      color: #f9fafb;
      border-color: #6b7280;
    }
    
    .badge-primary {
      background-color: #2563eb;
      border-color: #1d4ed8;
    }
    
    .badge-success {
      background-color: #15803d;
      border-color: #166534;
    }
    
    .badge-warning {
      background-color: #d97706;
      border-color: #b45309;
    }
    
    .badge-error {
      background-color: #dc2626;
      border-color: #b91c1c;
    }
    
    .badge-info {
      background-color: #0891b2;
      border-color: #0e7490;
    }
    
    .badge-secondary {
      background-color: #4b5563;
      border-color: #374151;
    }
  }
  
  /* 可点击徽章 */
  .badge-clickable {
    cursor: pointer;
  }
  
  .badge-clickable:hover {
    filter: brightness(1.1);
  }
  
  .badge-clickable:active {
    transform: scale(0.95);
  }
  
  /* 关闭按钮 */
  .badge-closable {
    padding-right: 20px;
    position: relative;
  }
  
  .badge-close {
    position: absolute;
    right: 4px;
    top: 50%;
    transform: translateY(-50%);
    width: 12px;
    height: 12px;
    border: none;
    background: none;
    color: currentColor;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    border-radius: 50%;
    font-size: 8px;
    opacity: 0.7;
    transition: opacity 0.2s ease;
  }
  
  .badge-close:hover {
    opacity: 1;
    background: rgba(0, 0, 0, 0.1);
  }
</style> 