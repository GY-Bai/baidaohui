<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  
  export let value = '';
  export let options = [];
  export let placeholder = '请选择...';
  export let disabled = false;
  export let size: 'xs' | 'sm' | 'default' | 'lg' = 'default';
  export let variant: 'default' | 'error' | 'success' = 'default';
  export let className = '';
  
  const dispatch = createEventDispatcher();
  
  function handleChange(event) {
    value = event.target.value;
    dispatch('change', event);
  }
</script>

<div class="select-wrapper select-{size} select-{variant} {className}">
  <select
    {value}
    {disabled}
    class="select"
    on:change={handleChange}
    {...$$restProps}
  >
    {#if placeholder}
      <option value="" disabled selected={!value}>{placeholder}</option>
    {/if}
    
    {#each options as option}
      <option value={option.value} selected={value === option.value}>
        {option.label}
      </option>
    {/each}
  </select>
  
  <div class="select-arrow">
    <svg width="12" height="8" viewBox="0 0 12 8" fill="none">
      <path d="M1 1.5L6 6.5L11 1.5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
    </svg>
  </div>
</div>

<style>
  .select-wrapper {
    position: relative;
    display: inline-block;
    width: 100%;
  }
  
  .select {
    width: 100%;
    background: white;
    border: 1px solid #d1d5db;
    border-radius: 8px;
    appearance: none;
    cursor: pointer;
    font-family: inherit;
    color: #111827;
    transition: all 0.2s ease;
  }
  
  .select:focus {
    outline: none;
    border-color: #3b82f6;
    box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
  }
  
  .select:disabled {
    background: #f9fafb;
    color: #9ca3af;
    cursor: not-allowed;
    border-color: #e5e7eb;
  }
  
  .select-arrow {
    position: absolute;
    right: 12px;
    top: 50%;
    transform: translateY(-50%);
    pointer-events: none;
    color: #6b7280;
    transition: color 0.2s ease;
  }
  
  .select:focus + .select-arrow {
    color: #3b82f6;
  }
  
  .select:disabled + .select-arrow {
    color: #9ca3af;
  }
  
  /* 尺寸 */
  .select-xs .select {
    padding: 4px 32px 4px 8px;
    font-size: 12px;
    min-height: 24px;
  }
  
  .select-xs .select-arrow {
    right: 8px;
  }
  
  .select-sm .select {
    padding: 6px 36px 6px 12px;
    font-size: 13px;
    min-height: 32px;
  }
  
  .select-sm .select-arrow {
    right: 10px;
  }
  
  .select-default .select {
    padding: 8px 40px 8px 12px;
    font-size: 14px;
    min-height: 40px;
  }
  
  .select-lg .select {
    padding: 12px 44px 12px 16px;
    font-size: 16px;
    min-height: 48px;
  }
  
  .select-lg .select-arrow {
    right: 14px;
  }
  
  /* 变体 */
  .select-error .select {
    border-color: #ef4444;
  }
  
  .select-error .select:focus {
    border-color: #ef4444;
    box-shadow: 0 0 0 3px rgba(239, 68, 68, 0.1);
  }
  
  .select-success .select {
    border-color: #10b981;
  }
  
  .select-success .select:focus {
    border-color: #10b981;
    box-shadow: 0 0 0 3px rgba(16, 185, 129, 0.1);
  }
  
  /* 深色模式 */
  @media (prefers-color-scheme: dark) {
    .select {
      background: #1f2937;
      border-color: #374151;
      color: #f9fafb;
    }
    
    .select:focus {
      border-color: #60a5fa;
      box-shadow: 0 0 0 3px rgba(96, 165, 250, 0.1);
    }
    
    .select:disabled {
      background: #374151;
      color: #6b7280;
      border-color: #4b5563;
    }
    
    .select-arrow {
      color: #9ca3af;
    }
    
    .select:focus + .select-arrow {
      color: #60a5fa;
    }
    
    .select-error .select {
      border-color: #f87171;
    }
    
    .select-error .select:focus {
      border-color: #f87171;
      box-shadow: 0 0 0 3px rgba(248, 113, 113, 0.1);
    }
    
    .select-success .select {
      border-color: #34d399;
    }
    
    .select-success .select:focus {
      border-color: #34d399;
      box-shadow: 0 0 0 3px rgba(52, 211, 153, 0.1);
    }
  }
  
  /* 高对比度模式 */
  @media (prefers-contrast: high) {
    .select {
      border-width: 2px;
    }
    
    .select:focus {
      border-color: #000;
    }
  }
</style> 