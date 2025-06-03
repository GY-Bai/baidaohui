<script lang="ts">
  export let variant: 'text' | 'rectangle' | 'circle' | 'avatar' | 'card' | 'button' | 'image' = 'text';
  export let width: string = '100%';
  export let height: string = '20px';
  export let animation: 'pulse' | 'wave' | 'none' = 'pulse';
  export let rounded: 'none' | 'sm' | 'default' | 'lg' | 'full' = 'default';
  export let rows: number = 1;
  export let spacing: string = '8px';
  export let className: string = '';
  
  // 预设尺寸
  const presets = {
    avatar: { width: '40px', height: '40px', variant: 'circle' },
    button: { width: '80px', height: '32px', rounded: 'default' },
    title: { width: '60%', height: '24px', rounded: 'sm' },
    subtitle: { width: '40%', height: '16px', rounded: 'sm' },
    paragraph: { width: '100%', height: '16px', rounded: 'sm' },
    image: { width: '100%', height: '200px', rounded: 'default' },
    card: { width: '100%', height: '120px', rounded: 'lg' }
  };
  
  // 获取最终样式
  $: finalWidth = presets[variant]?.width || width;
  $: finalHeight = presets[variant]?.height || height;
  $: finalRounded = presets[variant]?.rounded || rounded;
  $: finalVariant = presets[variant]?.variant || variant;
  
  $: skeletonClasses = [
    'skeleton',
    `skeleton-${finalVariant}`,
    `skeleton-animation-${animation}`,
    `skeleton-rounded-${finalRounded}`,
    className
  ].filter(Boolean).join(' ');
  
  $: skeletonStyle = [
    `width: ${finalWidth}`,
    `height: ${finalHeight}`
  ].join('; ');
  
  // 多行文本
  $: multipleRows = rows > 1;
</script>

{#if multipleRows}
  <div class="skeleton-group" style="gap: {spacing}">
    {#each Array(rows) as _, index}
      <div
        class={skeletonClasses}
        style={index === rows - 1 ? `${skeletonStyle}; width: ${Math.random() * 30 + 60}%` : skeletonStyle}
      ></div>
    {/each}
  </div>
{:else}
  <div class={skeletonClasses} style={skeletonStyle}></div>
{/if}

<style>
  .skeleton {
    background: #f3f4f6;
    position: relative;
    overflow: hidden;
    display: inline-block;
  }
  
  /* 变体样式 */
  .skeleton-text {
    border-radius: 4px;
  }
  
  .skeleton-rectangle {
    border-radius: 6px;
  }
  
  .skeleton-circle {
    border-radius: 50%;
  }
  
  .skeleton-avatar {
    border-radius: 50%;
  }
  
  .skeleton-button {
    border-radius: 6px;
  }
  
  .skeleton-card {
    border-radius: 12px;
  }
  
  .skeleton-image {
    border-radius: 8px;
  }
  
  /* 圆角样式 */
  .skeleton-rounded-none {
    border-radius: 0 !important;
  }
  
  .skeleton-rounded-sm {
    border-radius: 4px !important;
  }
  
  .skeleton-rounded-default {
    border-radius: 6px !important;
  }
  
  .skeleton-rounded-lg {
    border-radius: 12px !important;
  }
  
  .skeleton-rounded-full {
    border-radius: 50% !important;
  }
  
  /* 动画效果 */
  .skeleton-animation-pulse {
    animation: skeletonPulse 1.5s ease-in-out infinite;
  }
  
  .skeleton-animation-wave::before {
    content: '';
    position: absolute;
    top: 0;
    left: -100%;
    width: 100%;
    height: 100%;
    background: linear-gradient(
      90deg,
      transparent,
      rgba(255, 255, 255, 0.6),
      transparent
    );
    animation: skeletonWave 1.5s infinite;
  }
  
  .skeleton-animation-none {
    animation: none;
  }
  
  @keyframes skeletonPulse {
    0%, 100% {
      opacity: 1;
    }
    50% {
      opacity: 0.6;
    }
  }
  
  @keyframes skeletonWave {
    0% {
      left: -100%;
    }
    100% {
      left: 100%;
    }
  }
  
  /* 多行组合 */
  .skeleton-group {
    display: flex;
    flex-direction: column;
    width: 100%;
  }
  
  /* 深色模式 */
  @media (prefers-color-scheme: dark) {
    .skeleton {
      background: #374151;
    }
    
    .skeleton-animation-wave::before {
      background: linear-gradient(
        90deg,
        transparent,
        rgba(255, 255, 255, 0.1),
        transparent
      );
    }
  }
  
  /* 高对比度模式 */
  @media (prefers-contrast: high) {
    .skeleton {
      background: #e5e7eb;
      border: 1px solid #d1d5db;
    }
  }
  
  /* 减少动画模式 */
  @media (prefers-reduced-motion: reduce) {
    .skeleton-animation-pulse,
    .skeleton-animation-wave::before {
      animation: none;
    }
    
    .skeleton {
      opacity: 0.7;
    }
  }
</style> 