<script lang="ts">
  export let value: number = 0;
  export let max: number = 100;
  export let size: 'xs' | 'sm' | 'default' | 'lg' | 'xl' = 'default';
  export let variant: 'default' | 'success' | 'warning' | 'error' | 'gradient' = 'default';
  export let showLabel: boolean = false;
  export let showPercentage: boolean = false;
  export let label: string = '';
  export let animated: boolean = false;
  export let striped: boolean = false;
  export let className: string = '';
  export let color: string | null = null;
  export let backgroundColor: string | null = null;
  export let rounded: boolean = true;
  export let indeterminate: boolean = false;
  
  $: percentage = Math.min(Math.max((value / max) * 100, 0), 100);
  $: displayValue = Math.round(percentage);
  
  const sizes = {
    xs: { height: '4px', fontSize: '10px' },
    sm: { height: '6px', fontSize: '11px' },
    default: { height: '8px', fontSize: '12px' },
    lg: { height: '12px', fontSize: '14px' },
    xl: { height: '16px', fontSize: '16px' }
  };
  
  const variants = {
    default: {
      bg: '#e5e7eb',
      fill: '#3b82f6',
      gradient: 'linear-gradient(90deg, #3b82f6, #1d4ed8)'
    },
    success: {
      bg: '#dcfce7',
      fill: '#16a34a',
      gradient: 'linear-gradient(90deg, #16a34a, #15803d)'
    },
    warning: {
      bg: '#fef3c7',
      fill: '#f59e0b',
      gradient: 'linear-gradient(90deg, #f59e0b, #d97706)'
    },
    error: {
      bg: '#fee2e2',
      fill: '#ef4444',
      gradient: 'linear-gradient(90deg, #ef4444, #dc2626)'
    },
    gradient: {
      bg: '#e5e7eb',
      fill: '#3b82f6',
      gradient: 'linear-gradient(90deg, #8b5cf6, #3b82f6, #06b6d4, #10b981)'
    }
  };
  
  $: currentSize = sizes[size];
  $: currentVariant = variants[variant];
  $: finalBgColor = backgroundColor || currentVariant.bg;
  $: finalFillColor = color || (variant === 'gradient' ? null : currentVariant.fill);
  $: finalGradient = variant === 'gradient' || !finalFillColor ? currentVariant.gradient : null;
  
  $: progressClasses = [
    'progress',
    `progress-${size}`,
    `progress-${variant}`,
    animated && 'progress-animated',
    striped && 'progress-striped',
    indeterminate && 'progress-indeterminate',
    rounded && 'progress-rounded',
    className
  ].filter(Boolean).join(' ');
  
  $: status = (() => {
    if (indeterminate) return 'loading';
    if (percentage === 100) return 'complete';
    if (percentage === 0) return 'empty';
    return 'progress';
  })();
  
  $: ariaLabel = label || `进度 ${displayValue}%`;
</script>

<div class="progress-container">
  <!-- 标签区域 -->
  {#if showLabel || showPercentage}
    <div class="progress-header">
      {#if showLabel && label}
        <span class="progress-label">{label}</span>
      {/if}
      
      {#if showPercentage}
        <span class="progress-percentage">{displayValue}%</span>
      {/if}
    </div>
  {/if}
  
  <!-- 进度条 -->
  <div
    class={progressClasses}
    style="height: {currentSize.height}; background-color: {finalBgColor}"
    role="progressbar"
    aria-label={ariaLabel}
    aria-valuenow={indeterminate ? null : value}
    aria-valuemin="0"
    aria-valuemax={max}
    aria-valuetext={indeterminate ? '加载中...' : `${displayValue}%`}
  >
    {#if !indeterminate}
      <div
        class="progress-fill"
        style="width: {percentage}%; background: {finalGradient || finalFillColor};"
      >
        <!-- 内部标签 -->
        {#if showLabel && !label && size === 'xl'}
          <span class="progress-inner-label">{displayValue}%</span>
        {/if}
      </div>
    {:else}
      <div class="progress-indeterminate-fill"></div>
    {/if}
  </div>
  
  <!-- 状态指示 -->
  {#if status === 'complete'}
    <div class="progress-status progress-complete">
      <span class="status-icon">✓</span>
      <span class="status-text">完成</span>
    </div>
  {/if}
</div>

<style>
  .progress-container {
    width: 100%;
  }
  
  .progress-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 8px;
    font-size: 13px;
    color: #6b7280;
  }
  
  .progress-label {
    font-weight: 500;
    color: #374151;
  }
  
  .progress-percentage {
    font-weight: 600;
    color: #111827;
    font-variant-numeric: tabular-nums;
  }
  
  .progress {
    width: 100%;
    background-color: #e5e7eb;
    border-radius: 0;
    overflow: hidden;
    position: relative;
    transition: all 0.3s ease;
  }
  
  .progress-rounded {
    border-radius: 9999px;
  }
  
  /* 尺寸样式 */
  .progress-xs {
    height: 4px;
  }
  
  .progress-sm {
    height: 6px;
  }
  
  .progress-default {
    height: 8px;
  }
  
  .progress-lg {
    height: 12px;
  }
  
  .progress-xl {
    height: 16px;
  }
  
  /* 填充条 */
  .progress-fill {
    height: 100%;
    background: #3b82f6;
    transition: width 0.6s cubic-bezier(0.4, 0, 0.2, 1);
    position: relative;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  
  .progress-inner-label {
    color: white;
    font-size: 10px;
    font-weight: 600;
    text-shadow: 0 1px 2px rgba(0, 0, 0, 0.1);
  }
  
  /* 变体样式 */
  .progress-success .progress-fill {
    background: #16a34a;
  }
  
  .progress-warning .progress-fill {
    background: #f59e0b;
  }
  
  .progress-error .progress-fill {
    background: #ef4444;
  }
  
  .progress-gradient .progress-fill {
    background: linear-gradient(90deg, #8b5cf6, #3b82f6, #06b6d4, #10b981);
  }
  
  /* 条纹效果 */
  .progress-striped .progress-fill {
    background-image: linear-gradient(
      45deg,
      rgba(255, 255, 255, 0.15) 25%,
      transparent 25%,
      transparent 50%,
      rgba(255, 255, 255, 0.15) 50%,
      rgba(255, 255, 255, 0.15) 75%,
      transparent 75%,
      transparent
    );
    background-size: 20px 20px;
  }
  
  /* 动画效果 */
  .progress-animated .progress-fill {
    animation: progressPulse 2s infinite;
  }
  
  .progress-striped.progress-animated .progress-fill {
    animation: progressStripe 1s linear infinite;
  }
  
  /* 不确定进度 */
  .progress-indeterminate {
    overflow: hidden;
  }
  
  .progress-indeterminate-fill {
    width: 30%;
    height: 100%;
    background: linear-gradient(90deg, transparent, currentColor, transparent);
    animation: progressIndeterminate 1.5s infinite;
    color: #3b82f6;
  }
  
  .progress-indeterminate.progress-success .progress-indeterminate-fill {
    color: #16a34a;
  }
  
  .progress-indeterminate.progress-warning .progress-indeterminate-fill {
    color: #f59e0b;
  }
  
  .progress-indeterminate.progress-error .progress-indeterminate-fill {
    color: #ef4444;
  }
  
  .progress-indeterminate.progress-gradient .progress-indeterminate-fill {
    background: linear-gradient(90deg, transparent, #8b5cf6, #3b82f6, transparent);
  }
  
  /* 状态指示 */
  .progress-status {
    display: flex;
    align-items: center;
    gap: 6px;
    margin-top: 8px;
    font-size: 12px;
    color: #16a34a;
    font-weight: 500;
  }
  
  .status-icon {
    width: 16px;
    height: 16px;
    background: #16a34a;
    color: white;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 10px;
    font-weight: bold;
  }
  
  /* 动画关键帧 */
  @keyframes progressPulse {
    0%, 100% {
      opacity: 1;
    }
    50% {
      opacity: 0.7;
    }
  }
  
  @keyframes progressStripe {
    0% {
      background-position: 0 0;
    }
    100% {
      background-position: 20px 0;
    }
  }
  
  @keyframes progressIndeterminate {
    0% {
      transform: translateX(-100%);
    }
    100% {
      transform: translateX(400%);
    }
  }
  
  /* 悬停效果 */
  .progress:hover .progress-fill {
    filter: brightness(1.1);
  }
  
  .progress:hover {
    box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
  }
  
  .progress-success:hover {
    box-shadow: 0 0 0 3px rgba(22, 163, 74, 0.1);
  }
  
  .progress-warning:hover {
    box-shadow: 0 0 0 3px rgba(245, 158, 11, 0.1);
  }
  
  .progress-error:hover {
    box-shadow: 0 0 0 3px rgba(239, 68, 68, 0.1);
  }
  
  /* 移动端适配 */
  @media (max-width: 768px) {
    .progress-container {
      font-size: 12px;
    }
    
    .progress-header {
      font-size: 11px;
      margin-bottom: 6px;
    }
    
    .progress-status {
      font-size: 11px;
      margin-top: 6px;
    }
    
    .status-icon {
      width: 14px;
      height: 14px;
      font-size: 8px;
    }
    
    .progress-inner-label {
      font-size: 8px;
    }
  }
  
  /* 高对比度模式 */
  @media (prefers-contrast: high) {
    .progress {
      border: 1px solid #000;
    }
    
    .progress-fill {
      border-right: 1px solid #000;
    }
    
    .progress-header,
    .progress-label,
    .progress-percentage {
      color: #000;
    }
  }
  
  /* 减少动画模式 */
  @media (prefers-reduced-motion: reduce) {
    .progress-fill {
      transition: none;
    }
    
    .progress-animated .progress-fill,
    .progress-striped.progress-animated .progress-fill,
    .progress-indeterminate-fill {
      animation: none;
    }
    
    .progress:hover {
      box-shadow: none;
    }
    
    .progress:hover .progress-fill {
      filter: none;
    }
  }
  
  /* 深色模式 */
  @media (prefers-color-scheme: dark) {
    .progress {
      background-color: #374151;
    }
    
    .progress-header {
      color: #d1d5db;
    }
    
    .progress-label {
      color: #f3f4f6;
    }
    
    .progress-percentage {
      color: #ffffff;
    }
    
    .progress-success {
      background-color: #065f46;
    }
    
    .progress-warning {
      background-color: #92400e;
    }
    
    .progress-error {
      background-color: #991b1b;
    }
    
    .progress-success .progress-fill {
      background: #34d399;
    }
    
    .progress-warning .progress-fill {
      background: #fbbf24;
    }
    
    .progress-error .progress-fill {
      background: #f87171;
    }
    
    .progress-gradient .progress-fill {
      background: linear-gradient(90deg, #a78bfa, #60a5fa, #22d3ee, #4ade80);
    }
    
    .progress:hover {
      box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.2);
    }
    
    .progress-success:hover {
      box-shadow: 0 0 0 3px rgba(52, 211, 153, 0.2);
    }
    
    .progress-warning:hover {
      box-shadow: 0 0 0 3px rgba(251, 191, 36, 0.2);
    }
    
    .progress-error:hover {
      box-shadow: 0 0 0 3px rgba(248, 113, 113, 0.2);
    }
  }
</style> 