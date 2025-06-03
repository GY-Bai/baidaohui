<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { scale } from 'svelte/transition';
  import { backOut } from 'svelte/easing';
  
  export let checked: boolean = false;
  export let indeterminate: boolean = false;
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
  
  $: checkboxClasses = [
    'checkbox',
    `checkbox-${size}`,
    `checkbox-${variant}`,
    checked || indeterminate ? 'checkbox-checked' : '',
    indeterminate ? 'checkbox-indeterminate' : '',
    disabled ? 'checkbox-disabled' : ''
  ].filter(Boolean).join(' ');
  
  function handleChange() {
    if (disabled) return;
    
    if (indeterminate) {
      indeterminate = false;
      checked = true;
    } else {
      checked = !checked;
    }
    
    dispatch('change', { checked, value, indeterminate });
  }
  
  function handleKeydown(event: KeyboardEvent) {
    if (event.key === 'Enter' || event.key === ' ') {
      event.preventDefault();
      handleChange();
    }
  }
</script>

<div class="checkbox-wrapper">
  <div class="checkbox-container">
    <div
      class={checkboxClasses}
      role="checkbox"
      aria-checked={indeterminate ? 'mixed' : checked}
      aria-labelledby={label ? `${id}-label` : undefined}
      aria-describedby={description ? `${id}-description` : undefined}
      tabindex={disabled ? -1 : 0}
      on:click={handleChange}
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
        class="checkbox-input"
        on:change={handleChange}
        aria-hidden="true"
        tabindex="-1"
      />
      
      <div class="checkbox-checkmark">
        {#if indeterminate}
          <span 
            class="checkbox-icon indeterminate-icon"
            in:scale={{ duration: 150, easing: backOut }}
          >
            ─
          </span>
        {:else if checked}
          <span 
            class="checkbox-icon checked-icon"
            in:scale={{ duration: 150, easing: backOut }}
          >
            ✓
          </span>
        {/if}
      </div>
    </div>
    
    {#if label || description}
      <div class="checkbox-label-section">
        {#if label}
          <label for={id} class="checkbox-label" class:required>
            {label}
            {#if required}
              <span class="required-asterisk">*</span>
            {/if}
          </label>
        {/if}
        {#if description}
          <p class="checkbox-description" id="{id}-description">
            {description}
          </p>
        {/if}
      </div>
    {/if}
  </div>
</div>

<style>
  .checkbox-wrapper {
    display: inline-block;
    width: 100%;
  }
  
  .checkbox-container {
    display: flex;
    align-items: flex-start;
    gap: 12px;
    cursor: pointer;
  }
  
  .checkbox {
    position: relative;
    display: inline-block;
    cursor: pointer;
    outline: none;
    border-radius: 4px;
    transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
    flex-shrink: 0;
    border: 2px solid #d1d5db;
    background: white;
  }
  
  .checkbox:focus-visible {
    box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.2);
  }
  
  /* 尺寸变体 */
  .checkbox-sm {
    width: 16px;
    height: 16px;
  }
  
  .checkbox-md {
    width: 20px;
    height: 20px;
  }
  
  .checkbox-lg {
    width: 24px;
    height: 24px;
  }
  
  /* 隐藏原生input */
  .checkbox-input {
    position: absolute;
    opacity: 0;
    width: 0;
    height: 0;
    pointer-events: none;
  }
  
  /* 复选框标记 */
  .checkbox-checkmark {
    width: 100%;
    height: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
    position: relative;
  }
  
  /* 选中状态 */
  .checkbox-checked {
    background: #667eea;
    border-color: #667eea;
  }
  
  /* 变体颜色 */
  .checkbox-success.checkbox-checked {
    background: #10b981;
    border-color: #10b981;
  }
  
  .checkbox-warning.checkbox-checked {
    background: #f59e0b;
    border-color: #f59e0b;
  }
  
  .checkbox-danger.checkbox-checked {
    background: #ef4444;
    border-color: #ef4444;
  }
  
  /* 半选中状态 */
  .checkbox-indeterminate {
    background: #667eea;
    border-color: #667eea;
  }
  
  /* 图标样式 */
  .checkbox-icon {
    color: white;
    font-weight: 700;
    line-height: 1;
  }
  
  .checkbox-sm .checkbox-icon {
    font-size: 10px;
  }
  
  .checkbox-md .checkbox-icon {
    font-size: 12px;
  }
  
  .checkbox-lg .checkbox-icon {
    font-size: 14px;
  }
  
  .indeterminate-icon {
    font-size: 8px;
    transform: translateY(-1px);
  }
  
  .checkbox-lg .indeterminate-icon {
    font-size: 10px;
  }
  
  /* 禁用状态 */
  .checkbox-disabled {
    opacity: 0.5;
    cursor: not-allowed;
    pointer-events: none;
  }
  
  /* 悬停效果 */
  .checkbox:hover:not(.checkbox-disabled) {
    border-color: #667eea;
    box-shadow: 0 0 0 2px rgba(102, 126, 234, 0.1);
  }
  
  .checkbox-checked:hover:not(.checkbox-disabled) {
    background: #5a67d8;
    border-color: #5a67d8;
  }
  
  /* 标签部分 */
  .checkbox-label-section {
    flex: 1;
    min-width: 0;
  }
  
  .checkbox-label {
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
  
  .checkbox-description {
    margin: 0;
    font-size: 12px;
    color: #6b7280;
    line-height: 1.4;
  }
  
  /* 激活状态动画 */
  .checkbox:active:not(.checkbox-disabled) {
    transform: scale(0.95);
  }
  
  /* 深色模式 */
  @media (prefers-color-scheme: dark) {
    .checkbox {
      background: #374151;
      border-color: #4b5563;
    }
    
    .checkbox-label {
      color: #f3f4f6;
    }
    
    .checkbox-description {
      color: #9ca3af;
    }
    
    .checkbox:hover:not(.checkbox-disabled) {
      border-color: #667eea;
    }
  }
  
  /* 无障碍优化 */
  @media (prefers-reduced-motion: reduce) {
    .checkbox {
      transition: none;
    }
  }
  
  /* 高对比度模式 */
  @media (prefers-contrast: high) {
    .checkbox {
      border-width: 3px;
    }
    
    .checkbox-checked {
      border-color: #000;
    }
  }
  
  /* 移动端优化 */
  @media (max-width: 480px) {
    .checkbox-container {
      gap: 8px;
    }
    
    /* 确保足够的触摸目标大小 */
    .checkbox {
      min-width: 44px;
      min-height: 44px;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    
    .checkbox-checkmark {
      position: relative;
    }
  }
</style> 