<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  
  export let variant: 'primary' | 'secondary' | 'outline' | 'ghost' | 'error' | 'warning' | 'success' = 'primary';
  export let size: 'xs' | 'sm' | 'default' | 'lg' | 'xl' = 'default';
  export let disabled = false;
  export let loading = false;
  export let type: 'button' | 'submit' | 'reset' = 'button';
  export let className = '';
  
  const dispatch = createEventDispatcher();
  
  function handleClick(event) {
    if (disabled || loading) {
      event.preventDefault();
      return;
    }
    dispatch('click', event);
  }
</script>

<button
  {type}
  class="btn btn-{variant} btn-{size} {className}"
  class:disabled
  class:loading
  {disabled}
  on:click={handleClick}
  {...$$restProps}
>
  {#if loading}
    <span class="loading-spinner"></span>
  {/if}
  <slot />
</button>

<style>
  .btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: 8px;
    font-weight: 500;
    text-decoration: none;
    border: 1px solid transparent;
    border-radius: 8px;
    cursor: pointer;
    transition: all 0.2s ease;
    white-space: nowrap;
    position: relative;
    outline: none;
    font-family: inherit;
  }
  
  .btn:focus-visible {
    outline: 2px solid #3b82f6;
    outline-offset: 2px;
  }
  
  /* 尺寸 */
  .btn-xs {
    padding: 4px 8px;
    font-size: 12px;
    min-height: 24px;
  }
  
  .btn-sm {
    padding: 6px 12px;
    font-size: 13px;
    min-height: 32px;
  }
  
  .btn-default {
    padding: 8px 16px;
    font-size: 14px;
    min-height: 40px;
  }
  
  .btn-lg {
    padding: 12px 24px;
    font-size: 16px;
    min-height: 48px;
  }
  
  .btn-xl {
    padding: 16px 32px;
    font-size: 18px;
    min-height: 56px;
  }
  
  /* 变体 */
  .btn-primary {
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    color: white;
    border-color: #667eea;
  }
  
  .btn-primary:hover:not(.disabled) {
    background: linear-gradient(135deg, #5a6fd8 0%, #6b4190 100%);
    transform: translateY(-1px);
    box-shadow: 0 4px 12px rgba(102, 126, 234, 0.4);
  }
  
  .btn-secondary {
    background: #f3f4f6;
    color: #374151;
    border-color: #d1d5db;
  }
  
  .btn-secondary:hover:not(.disabled) {
    background: #e5e7eb;
    border-color: #9ca3af;
  }
  
  .btn-outline {
    background: transparent;
    color: #374151;
    border-color: #d1d5db;
  }
  
  .btn-outline:hover:not(.disabled) {
    background: #f9fafb;
    border-color: #9ca3af;
  }
  
  .btn-ghost {
    background: transparent;
    color: #374151;
    border-color: transparent;
  }
  
  .btn-ghost:hover:not(.disabled) {
    background: #f3f4f6;
  }
  
  .btn-error {
    background: linear-gradient(135deg, #ef4444 0%, #dc2626 100%);
    color: white;
    border-color: #ef4444;
  }
  
  .btn-error:hover:not(.disabled) {
    background: linear-gradient(135deg, #dc2626 0%, #b91c1c 100%);
    transform: translateY(-1px);
    box-shadow: 0 4px 12px rgba(239, 68, 68, 0.4);
  }
  
  .btn-warning {
    background: linear-gradient(135deg, #f59e0b 0%, #d97706 100%);
    color: white;
    border-color: #f59e0b;
  }
  
  .btn-warning:hover:not(.disabled) {
    background: linear-gradient(135deg, #d97706 0%, #b45309 100%);
    transform: translateY(-1px);
    box-shadow: 0 4px 12px rgba(245, 158, 11, 0.4);
  }
  
  .btn-success {
    background: linear-gradient(135deg, #10b981 0%, #059669 100%);
    color: white;
    border-color: #10b981;
  }
  
  .btn-success:hover:not(.disabled) {
    background: linear-gradient(135deg, #059669 0%, #047857 100%);
    transform: translateY(-1px);
    box-shadow: 0 4px 12px rgba(16, 185, 129, 0.4);
  }
  
  /* 状态 */
  .btn.disabled {
    opacity: 0.5;
    cursor: not-allowed;
    transform: none !important;
    box-shadow: none !important;
  }
  
  .btn.loading {
    cursor: wait;
  }
  
  .loading-spinner {
    width: 16px;
    height: 16px;
    border: 2px solid transparent;
    border-top: 2px solid currentColor;
    border-radius: 50%;
    animation: spin 1s linear infinite;
  }
  
  @keyframes spin {
    from { transform: rotate(0deg); }
    to { transform: rotate(360deg); }
  }
  
  /* 深色模式 */
  @media (prefers-color-scheme: dark) {
    .btn-secondary {
      background: #374151;
      color: #f3f4f6;
      border-color: #4b5563;
    }
    
    .btn-secondary:hover:not(.disabled) {
      background: #4b5563;
      border-color: #6b7280;
    }
    
    .btn-outline {
      color: #f3f4f6;
      border-color: #4b5563;
    }
    
    .btn-outline:hover:not(.disabled) {
      background: #374151;
      border-color: #6b7280;
    }
    
    .btn-ghost {
      color: #f3f4f6;
    }
    
    .btn-ghost:hover:not(.disabled) {
      background: #374151;
    }
  }
  
  /* 减少动画模式 */
  @media (prefers-reduced-motion: reduce) {
    .btn {
      transition: none;
    }
    
    .loading-spinner {
      animation: none;
    }
    
    .btn:hover:not(.disabled) {
      transform: none;
    }
  }
</style> 