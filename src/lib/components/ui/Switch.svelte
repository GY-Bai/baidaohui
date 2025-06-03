<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { scale } from 'svelte/transition';
  import { backOut } from 'svelte/easing';
  
  export let checked: boolean = false;
  export let disabled: boolean = false;
  export let size: 'sm' | 'md' | 'lg' = 'md';
  export let variant: 'default' | 'success' | 'warning' | 'danger' = 'default';
  export let label: string = '';
  export let labelPosition: 'left' | 'right' = 'right';
  export let description: string = '';
  export let required: boolean = false;
  export let id: string = '';
  export let name: string = '';
  export let value: string = '';
  
  const dispatch = createEventDispatcher();
  
  $: switchClasses = [
    'switch',
    `switch-${size}`,
    `switch-${variant}`,
    checked ? 'switch-checked' : '',
    disabled ? 'switch-disabled' : ''
  ].filter(Boolean).join(' ');
  
  function handleToggle() {
    if (disabled) return;
    
    checked = !checked;
    dispatch('change', { checked, value });
  }
  
  function handleKeydown(event: KeyboardEvent) {
    if (event.key === 'Enter' || event.key === ' ') {
      event.preventDefault();
      handleToggle();
    }
  }
</script>

<div class="switch-wrapper">
  <div class="switch-container" class:reverse={labelPosition === 'left'}>
    {#if label && labelPosition === 'left'}
      <div class="switch-label-section">
        <label for={id} class="switch-label" class:required>
          {label}
          {#if required}
            <span class="required-asterisk">*</span>
          {/if}
        </label>
        {#if description}
          <p class="switch-description">{description}</p>
        {/if}
      </div>
    {/if}
    
    <div
      class={switchClasses}
      role="switch"
      aria-checked={checked}
      aria-labelledby={label ? `${id}-label` : undefined}
      aria-describedby={description ? `${id}-description` : undefined}
      tabindex={disabled ? -1 : 0}
      on:click={handleToggle}
      on:keydown={handleKeydown}
    >
      <input
        type="checkbox"
        {id}
        {name}
        {value}
        {checked}
        {disabled}
        {required}
        class="switch-input"
        on:change={handleToggle}
        aria-hidden="true"
        tabindex="-1"
      />
      
      <div class="switch-track">
        <div class="switch-thumb" class:checked>
          {#if checked}
            <span 
              class="switch-icon checked-icon"
              in:scale={{ duration: 150, easing: backOut }}
            >
              ✓
            </span>
          {:else}
            <span 
              class="switch-icon unchecked-icon"
              in:scale={{ duration: 150, easing: backOut }}
            >
              ✕
            </span>
          {/if}
        </div>
      </div>
    </div>
    
    {#if label && labelPosition === 'right'}
      <div class="switch-label-section">
        <label for={id} class="switch-label" class:required>
          {label}
          {#if required}
            <span class="required-asterisk">*</span>
          {/if}
        </label>
        {#if description}
          <p class="switch-description">{description}</p>
        {/if}
      </div>
    {/if}
  </div>
</div>

<style>
  .switch-wrapper {
    display: inline-block;
    width: 100%;
  }
  
  .switch-container {
    display: flex;
    align-items: flex-start;
    gap: 12px;
    cursor: pointer;
  }
  
  .switch-container.reverse {
    flex-direction: row-reverse;
    justify-content: flex-end;
  }
  
  .switch {
    position: relative;
    display: inline-block;
    cursor: pointer;
    outline: none;
    border-radius: 9999px;
    transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
    flex-shrink: 0;
  }
  
  .switch:focus-visible {
    box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.2);
  }
  
  /* 尺寸变体 */
  .switch-sm {
    width: 36px;
    height: 20px;
  }
  
  .switch-md {
    width: 44px;
    height: 24px;
  }
  
  .switch-lg {
    width: 52px;
    height: 28px;
  }
  
  /* 隐藏原生input */
  .switch-input {
    position: absolute;
    opacity: 0;
    width: 0;
    height: 0;
    pointer-events: none;
  }
  
  /* 开关轨道 */
  .switch-track {
    width: 100%;
    height: 100%;
    background: #d1d5db;
    border-radius: inherit;
    position: relative;
    transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
  }
  
  .switch-checked .switch-track {
    background: #667eea;
  }
  
  /* 变体颜色 */
  .switch-success.switch-checked .switch-track {
    background: #10b981;
  }
  
  .switch-warning.switch-checked .switch-track {
    background: #f59e0b;
  }
  
  .switch-danger.switch-checked .switch-track {
    background: #ef4444;
  }
  
  /* 开关滑块 */
  .switch-thumb {
    position: absolute;
    top: 2px;
    left: 2px;
    background: white;
    border-radius: 50%;
    transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
    display: flex;
    align-items: center;
    justify-content: center;
  }
  
  /* 小尺寸滑块 */
  .switch-sm .switch-thumb {
    width: 16px;
    height: 16px;
  }
  
  .switch-sm .switch-thumb.checked {
    transform: translateX(16px);
  }
  
  /* 中等尺寸滑块 */
  .switch-md .switch-thumb {
    width: 20px;
    height: 20px;
  }
  
  .switch-md .switch-thumb.checked {
    transform: translateX(20px);
  }
  
  /* 大尺寸滑块 */
  .switch-lg .switch-thumb {
    width: 24px;
    height: 24px;
  }
  
  .switch-lg .switch-thumb.checked {
    transform: translateX(24px);
  }
  
  /* 图标样式 */
  .switch-icon {
    font-size: 10px;
    line-height: 1;
    font-weight: 700;
  }
  
  .switch-lg .switch-icon {
    font-size: 12px;
  }
  
  .checked-icon {
    color: #10b981;
  }
  
  .unchecked-icon {
    color: #9ca3af;
  }
  
  /* 禁用状态 */
  .switch-disabled {
    opacity: 0.5;
    cursor: not-allowed;
    pointer-events: none;
  }
  
  /* 悬停效果 */
  .switch:hover:not(.switch-disabled) .switch-track {
    box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
  }
  
  .switch:hover:not(.switch-disabled) .switch-thumb {
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.3);
  }
  
  /* 标签部分 */
  .switch-label-section {
    flex: 1;
    min-width: 0;
  }
  
  .switch-label {
    display: block;
    font-size: 14px;
    font-weight: 600;
    color: #374151;
    line-height: 1.4;
    cursor: pointer;
    margin-bottom: 2px;
  }
  
  .required-asterisk {
    color: #ef4444;
    margin-left: 2px;
  }
  
  .switch-description {
    margin: 0;
    font-size: 12px;
    color: #6b7280;
    line-height: 1.4;
  }
  
  /* 激活状态动画 */
  .switch:active:not(.switch-disabled) .switch-thumb {
    transform: scale(0.95);
  }
  
  .switch-checked:active:not(.switch-disabled) .switch-thumb {
    transform: scale(0.95);
  }
  
  .switch-sm.switch-checked:active:not(.switch-disabled) .switch-thumb {
    transform: translateX(16px) scale(0.95);
  }
  
  .switch-md.switch-checked:active:not(.switch-disabled) .switch-thumb {
    transform: translateX(20px) scale(0.95);
  }
  
  .switch-lg.switch-checked:active:not(.switch-disabled) .switch-thumb {
    transform: translateX(24px) scale(0.95);
  }
  
  /* 深色模式 */
  @media (prefers-color-scheme: dark) {
    .switch-label {
      color: #f3f4f6;
    }
    
    .switch-description {
      color: #9ca3af;
    }
    
    .switch-track {
      background: #4b5563;
    }
    
    .switch-thumb {
      background: #f9fafb;
    }
    
    .switch-checked .switch-track {
      background: #667eea;
    }
    
    .switch-success.switch-checked .switch-track {
      background: #10b981;
    }
    
    .switch-warning.switch-checked .switch-track {
      background: #f59e0b;
    }
    
    .switch-danger.switch-checked .switch-track {
      background: #ef4444;
    }
  }
  
  /* 无障碍优化 */
  @media (prefers-reduced-motion: reduce) {
    .switch,
    .switch-track,
    .switch-thumb {
      transition: none;
    }
  }
  
  /* 高对比度模式 */
  @media (prefers-contrast: high) {
    .switch-track {
      border: 2px solid #000;
    }
    
    .switch-checked .switch-track {
      border-color: #fff;
    }
    
    .switch-thumb {
      border: 1px solid #000;
    }
  }
  
  /* 移动端优化 */
  @media (max-width: 480px) {
    .switch-container {
      gap: 8px;
    }
    
    /* 确保足够的触摸目标大小 */
    .switch {
      min-width: 44px;
      min-height: 44px;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    
    .switch-track {
      position: relative;
    }
  }
</style> 