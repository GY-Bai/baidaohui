<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { fly } from 'svelte/transition';
  import { cubicOut } from 'svelte/easing';
  
  export let type: 'text' | 'email' | 'password' | 'number' | 'tel' | 'url' | 'search' = 'text';
  export let value: string | number = '';
  export let placeholder: string = '';
  export let label: string = '';
  export let hint: string = '';
  export let error: string = '';
  export let required: boolean = false;
  export let disabled: boolean = false;
  export let readonly: boolean = false;
  export let maxlength: number | undefined = undefined;
  export let min: number | undefined = undefined;
  export let max: number | undefined = undefined;
  export let step: number | undefined = undefined;
  export let autocomplete: string = '';
  export let pattern: string = '';
  export let size: 'xs' | 'sm' | 'default' | 'lg' = 'default';
  export let variant: 'default' | 'error' | 'success' = 'default';
  export let leftIcon: string = '';
  export let rightIcon: string = '';
  export let showCounter: boolean = false;
  export let id: string = '';
  export let className = '';
  
  const dispatch = createEventDispatcher();
  
  let inputElement: HTMLInputElement;
  let focused: boolean = false;
  
  $: hasError = !!error;
  $: hasValue = value !== '' && value !== null && value !== undefined;
  $: characterCount = typeof value === 'string' ? value.length : 0;
  
  $: inputClasses = [
    'input',
    `input-${size}`,
    `input-${variant}`,
    hasError ? 'input-error' : '',
    focused ? 'input-focused' : '',
    leftIcon ? 'input-with-left-icon' : '',
    rightIcon ? 'input-with-right-icon' : '',
    disabled ? 'input-disabled' : ''
  ].filter(Boolean).join(' ');
  
  function handleInput(event: Event) {
    const target = event.target as HTMLInputElement;
    value = type === 'number' ? target.valueAsNumber : target.value;
    dispatch('input', { value, event });
  }
  
  function handleFocus(event: FocusEvent) {
    focused = true;
    dispatch('focus', event);
  }
  
  function handleBlur(event: FocusEvent) {
    focused = false;
    dispatch('blur', event);
  }
  
  function handleChange(event: Event) {
    dispatch('change', { value, event });
  }
  
  function handleKeydown(event: KeyboardEvent) {
    dispatch('keydown', event);
  }
  
  export function focus() {
    inputElement?.focus();
  }
  
  export function blur() {
    inputElement?.blur();
  }
</script>

<div class="input-wrapper input-{size} input-{variant} {className}">
  {#if label}
    <label 
      for={id} 
      class="input-label"
      class:required
    >
      {label}
      {#if required}
        <span class="required-asterisk">*</span>
      {/if}
    </label>
  {/if}
  
  <div class="input-container">
    {#if leftIcon}
      <span class="input-icon input-icon-left">
        {leftIcon}
      </span>
    {/if}
    
    <input
      bind:this={inputElement}
      {id}
      {type}
      {placeholder}
      {required}
      {disabled}
      {readonly}
      {maxlength}
      {min}
      {max}
      {step}
      {autocomplete}
      {pattern}
      class={inputClasses}
      value={type === 'number' ? value : value}
      on:input={handleInput}
      on:focus={handleFocus}
      on:blur={handleBlur}
      on:change={handleChange}
      on:keydown={handleKeydown}
      aria-label={label || placeholder}
      aria-invalid={hasError}
      aria-describedby={error ? `${id}-error` : hint ? `${id}-hint` : undefined}
    />
    
    {#if rightIcon}
      <span class="input-icon input-icon-right">
        {rightIcon}
      </span>
    {/if}
  </div>
  
  {#if showCounter && maxlength}
    <div class="input-counter">
      <span class:over-limit={characterCount > maxlength}>
        {characterCount}
      </span>
      <span class="counter-separator">/</span>
      <span>{maxlength}</span>
    </div>
  {/if}
  
  {#if error}
    <div 
      class="input-error-message"
      id="{id}-error"
      role="alert"
      in:fly={{ y: -10, duration: 200, easing: cubicOut }}
    >
      <span class="error-icon">⚠️</span>
      {error}
    </div>
  {:else if hint}
    <div 
      class="input-hint"
      id="{id}-hint"
    >
      {hint}
    </div>
  {/if}
</div>

<style>
  .input-wrapper {
    display: flex;
    flex-direction: column;
    gap: 6px;
    width: 100%;
  }
  
  .input-label {
    font-size: 14px;
    font-weight: 600;
    color: #374151;
    line-height: 1.4;
  }
  
  .required-asterisk {
    color: #ef4444;
    margin-left: 2px;
  }
  
  .input-container {
    position: relative;
    display: flex;
    align-items: center;
  }
  
  .input {
    width: 100%;
    border: 1px solid #d1d5db;
    border-radius: 8px;
    background: white;
    font-size: 16px;
    line-height: 1.5;
    transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
    outline: none;
    color: #374151;
  }
  
  /* 尺寸变体 */
  .input-xs {
    padding: 4px 8px;
    font-size: 12px;
    min-height: 24px;
  }
  
  .input-sm {
    padding: 6px 12px;
    font-size: 13px;
    min-height: 32px;
  }
  
  .input-default {
    padding: 8px 12px;
    font-size: 14px;
    min-height: 40px;
  }
  
  .input-lg {
    padding: 12px 16px;
    font-size: 16px;
    min-height: 48px;
  }
  
  /* 样式变体 */
  .input-filled {
    background: #f9fafb;
    border: 1px solid transparent;
  }
  
  .input-outlined {
    background: transparent;
    border: 2px solid #d1d5db;
  }
  
  /* 状态 */
  .input:focus,
  .input-focused {
    border-color: #667eea;
    box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
  }
  
  .input-error {
    border-color: #ef4444;
  }
  
  .input-error:focus {
    box-shadow: 0 0 0 3px rgba(239, 68, 68, 0.1);
  }
  
  .input-disabled {
    background: #f3f4f6;
    color: #9ca3af;
    cursor: not-allowed;
  }
  
  /* 图标支持 */
  .input-with-left-icon {
    padding-left: 44px;
  }
  
  .input-with-right-icon {
    padding-right: 44px;
  }
  
  .input-icon {
    position: absolute;
    top: 50%;
    transform: translateY(-50%);
    font-size: 20px;
    color: #9ca3af;
    pointer-events: none;
    z-index: 1;
  }
  
  .input-icon-left {
    left: 12px;
  }
  
  .input-icon-right {
    right: 12px;
  }
  
  /* 字符计数器 */
  .input-counter {
    display: flex;
    justify-content: flex-end;
    gap: 2px;
    font-size: 12px;
    color: #9ca3af;
  }
  
  .over-limit {
    color: #ef4444;
    font-weight: 600;
  }
  
  .counter-separator {
    color: #d1d5db;
  }
  
  /* 错误和提示信息 */
  .input-error-message {
    display: flex;
    align-items: center;
    gap: 6px;
    font-size: 14px;
    color: #ef4444;
    line-height: 1.4;
  }
  
  .error-icon {
    font-size: 16px;
    flex-shrink: 0;
  }
  
  .input-hint {
    font-size: 12px;
    color: #6b7280;
    line-height: 1.4;
  }
  
  /* 占位符样式 */
  .input::placeholder {
    color: #9ca3af;
  }
  
  /* 深色模式 */
  @media (prefers-color-scheme: dark) {
    .input-label {
      color: #f3f4f6;
    }
    
    .input {
      background: #374151;
      border-color: #4b5563;
      color: #f9fafb;
    }
    
    .input::placeholder {
      color: #6b7280;
    }
    
    .input-filled {
      background: #4b5563;
    }
    
    .input-disabled {
      background: #1f2937;
      color: #6b7280;
    }
    
    .input-hint {
      color: #9ca3af;
    }
  }
  
  /* 无障碍优化 */
  @media (prefers-reduced-motion: reduce) {
    .input {
      transition: none;
    }
  }
  
  /* 移动端优化 */
  @media (max-width: 480px) {
    .input {
      font-size: 16px; /* 防止iOS缩放 */
    }
  }
</style> 