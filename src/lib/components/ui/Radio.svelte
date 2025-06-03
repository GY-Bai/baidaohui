<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { scale } from 'svelte/transition';
  import { backOut } from 'svelte/easing';
  
  export let checked: boolean = false;
  export let disabled: boolean = false;
  export let size: 'sm' | 'md' | 'lg' = 'md';
  export let variant: 'default' | 'success' | 'warning' | 'danger' = 'default';
  export let label: string = '';
  export let description: string = '';
  export let required: boolean = false;
  export let id: string = '';
  export let name: string = '';
  export let value: string = '';
  
  const dispatch = createEventDispatcher();
  
  $: radioClasses = [
    'radio',
    `radio-${size}`,
    `radio-${variant}`,
    checked ? 'radio-checked' : '',
    disabled ? 'radio-disabled' : ''
  ].filter(Boolean).join(' ');
  
  function handleChange() {
    if (disabled) return;
    
    checked = true;
    dispatch('change', { checked, value });
  }
  
  function handleKeydown(event: KeyboardEvent) {
    if (event.key === 'Enter' || event.key === ' ') {
      event.preventDefault();
      handleChange();
    }
  }
</script>

<div class="radio-wrapper">
  <div class="radio-container">
    <div
      class={radioClasses}
      role="radio"
      aria-checked={checked}
      aria-labelledby={label ? `${id}-label` : undefined}
      aria-describedby={description ? `${id}-description` : undefined}
      tabindex={disabled ? -1 : 0}
      on:click={handleChange}
      on:keydown={handleKeydown}
    >
      <input
        type="radio"
        {id}
        {name}
        {value}
        {checked}
        {disabled}
        {required}
        class="radio-input"
        on:change={handleChange}
        aria-hidden="true"
        tabindex="-1"
      />
      
      <div class="radio-indicator">
        {#if checked}
          <span 
            class="radio-dot"
            in:scale={{ duration: 150, easing: backOut }}
          ></span>
        {/if}
      </div>
    </div>
    
    {#if label || description}
      <div class="radio-label-section">
        {#if label}
          <label for={id} class="radio-label" class:required>
            {label}
            {#if required}
              <span class="required-asterisk">*</span>
            {/if}
          </label>
        {/if}
        {#if description}
          <p class="radio-description" id="{id}-description">
            {description}
          </p>
        {/if}
      </div>
    {/if}
  </div>
</div>

<style>
  .radio-wrapper {
    display: inline-block;
    width: 100%;
  }
  
  .radio-container {
    display: flex;
    align-items: flex-start;
    gap: 12px;
    cursor: pointer;
  }
  
  .radio {
    position: relative;
    display: inline-block;
    cursor: pointer;
    outline: none;
    border-radius: 50%;
    transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
    flex-shrink: 0;
    border: 2px solid #d1d5db;
    background: white;
  }
  
  .radio:focus-visible {
    box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.2);
  }
  
  /* 尺寸变体 */
  .radio-sm {
    width: 16px;
    height: 16px;
  }
  
  .radio-md {
    width: 20px;
    height: 20px;
  }
  
  .radio-lg {
    width: 24px;
    height: 24px;
  }
  
  /* 隐藏原生input */
  .radio-input {
    position: absolute;
    opacity: 0;
    width: 0;
    height: 0;
    pointer-events: none;
  }
  
  /* 单选框指示器 */
  .radio-indicator {
    width: 100%;
    height: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
    position: relative;
  }
  
  /* 选中状态 */
  .radio-checked {
    border-color: #667eea;
  }
  
  /* 变体颜色 */
  .radio-success.radio-checked {
    border-color: #10b981;
  }
  
  .radio-warning.radio-checked {
    border-color: #f59e0b;
  }
  
  .radio-danger.radio-checked {
    border-color: #ef4444;
  }
  
  /* 选中点 */
  .radio-dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    background: #667eea;
  }
  
  .radio-sm .radio-dot {
    width: 6px;
    height: 6px;
  }
  
  .radio-lg .radio-dot {
    width: 10px;
    height: 10px;
  }
  
  /* 变体颜色的点 */
  .radio-success .radio-dot {
    background: #10b981;
  }
  
  .radio-warning .radio-dot {
    background: #f59e0b;
  }
  
  .radio-danger .radio-dot {
    background: #ef4444;
  }
  
  /* 禁用状态 */
  .radio-disabled {
    opacity: 0.5;
    cursor: not-allowed;
    pointer-events: none;
  }
  
  /* 悬停效果 */
  .radio:hover:not(.radio-disabled) {
    border-color: #667eea;
    box-shadow: 0 0 0 2px rgba(102, 126, 234, 0.1);
  }
  
  .radio-success:hover:not(.radio-disabled) {
    border-color: #10b981;
    box-shadow: 0 0 0 2px rgba(16, 185, 129, 0.1);
  }
  
  .radio-warning:hover:not(.radio-disabled) {
    border-color: #f59e0b;
    box-shadow: 0 0 0 2px rgba(245, 158, 11, 0.1);
  }
  
  .radio-danger:hover:not(.radio-disabled) {
    border-color: #ef4444;
    box-shadow: 0 0 0 2px rgba(239, 68, 68, 0.1);
  }
  
  /* 标签部分 */
  .radio-label-section {
    flex: 1;
    min-width: 0;
  }
  
  .radio-label {
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
  
  .radio-description {
    margin: 0;
    font-size: 12px;
    color: #6b7280;
    line-height: 1.4;
  }
  
  /* 激活状态动画 */
  .radio:active:not(.radio-disabled) {
    transform: scale(0.95);
  }
  
  /* 深色模式 */
  @media (prefers-color-scheme: dark) {
    .radio {
      background: #374151;
      border-color: #4b5563;
    }
    
    .radio-label {
      color: #f3f4f6;
    }
    
    .radio-description {
      color: #9ca3af;
    }
    
    .radio:hover:not(.radio-disabled) {
      border-color: #667eea;
    }
  }
  
  /* 无障碍优化 */
  @media (prefers-reduced-motion: reduce) {
    .radio {
      transition: none;
    }
  }
  
  /* 高对比度模式 */
  @media (prefers-contrast: high) {
    .radio {
      border-width: 3px;
    }
    
    .radio-checked {
      border-color: #000;
    }
    
    .radio-dot {
      background: #000;
    }
  }
  
  /* 移动端优化 */
  @media (max-width: 480px) {
    .radio-container {
      gap: 8px;
    }
    
    /* 确保足够的触摸目标大小 */
    .radio {
      min-width: 44px;
      min-height: 44px;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    
    .radio-indicator {
      position: relative;
    }
  }
</style> 