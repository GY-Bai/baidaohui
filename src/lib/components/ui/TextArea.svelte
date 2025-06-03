<script lang="ts">
  import { createEventDispatcher, onMount } from 'svelte';
  import { fly } from 'svelte/transition';
  import { cubicOut } from 'svelte/easing';
  
  export let value: string = '';
  export let placeholder: string = '';
  export let label: string = '';
  export let hint: string = '';
  export let error: string = '';
  export let required: boolean = false;
  export let disabled: boolean = false;
  export let readonly: boolean = false;
  export let maxlength: number | undefined = undefined;
  export let minlength: number | undefined = undefined;
  export let rows: number = 3;
  export let autoResize: boolean = true;
  export let resize: 'none' | 'both' | 'horizontal' | 'vertical' = 'vertical';
  export let size: 'sm' | 'md' | 'lg' = 'md';
  export let variant: 'default' | 'filled' | 'outlined' = 'default';
  export let showCounter: boolean = false;
  export let id: string = '';
  
  const dispatch = createEventDispatcher();
  
  let textareaElement: HTMLTextAreaElement;
  let focused: boolean = false;
  let initialHeight: number = 0;
  
  $: hasError = !!error;
  $: hasValue = value !== '';
  $: characterCount = value.length;
  $: isOverLimit = maxlength && characterCount > maxlength;
  
  $: textareaClasses = [
    'textarea',
    `textarea-${size}`,
    `textarea-${variant}`,
    hasError ? 'textarea-error' : '',
    focused ? 'textarea-focused' : '',
    disabled ? 'textarea-disabled' : '',
    autoResize ? 'textarea-auto-resize' : ''
  ].filter(Boolean).join(' ');
  
  function handleInput(event: Event) {
    const target = event.target as HTMLTextAreaElement;
    value = target.value;
    
    if (autoResize) {
      adjustHeight();
    }
    
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
    // 处理Tab键插入
    if (event.key === 'Tab' && !event.shiftKey) {
      event.preventDefault();
      const start = textareaElement.selectionStart;
      const end = textareaElement.selectionEnd;
      
      value = value.substring(0, start) + '\t' + value.substring(end);
      
      // 设置光标位置
      setTimeout(() => {
        textareaElement.selectionStart = textareaElement.selectionEnd = start + 1;
      });
    }
    
    dispatch('keydown', event);
  }
  
  function adjustHeight() {
    if (!textareaElement || !autoResize) return;
    
    // 临时重置高度以获取正确的scrollHeight
    textareaElement.style.height = 'auto';
    
    // 计算新高度
    const newHeight = Math.max(initialHeight, textareaElement.scrollHeight);
    textareaElement.style.height = `${newHeight}px`;
  }
  
  export function focus() {
    textareaElement?.focus();
  }
  
  export function blur() {
    textareaElement?.blur();
  }
  
  export function selectAll() {
    textareaElement?.select();
  }
  
  onMount(() => {
    if (textareaElement) {
      initialHeight = textareaElement.scrollHeight;
      
      if (autoResize && value) {
        adjustHeight();
      }
    }
  });
</script>

<div class="textarea-wrapper">
  {#if label}
    <label 
      for={id} 
      class="textarea-label"
      class:required
    >
      {label}
      {#if required}
        <span class="required-asterisk">*</span>
      {/if}
    </label>
  {/if}
  
  <div class="textarea-container">
    <textarea
      bind:this={textareaElement}
      {id}
      {placeholder}
      {required}
      {disabled}
      {readonly}
      {maxlength}
      {minlength}
      {rows}
      class={textareaClasses}
      style="resize: {resize};"
      bind:value
      on:input={handleInput}
      on:focus={handleFocus}
      on:blur={handleBlur}
      on:change={handleChange}
      on:keydown={handleKeydown}
      aria-label={label || placeholder}
      aria-invalid={hasError}
      aria-describedby={error ? `${id}-error` : hint ? `${id}-hint` : undefined}
    ></textarea>
    
    {#if showCounter && maxlength}
      <div class="character-counter">
        <span class:over-limit={isOverLimit}>
          {characterCount}
        </span>
        <span class="counter-separator">/</span>
        <span>{maxlength}</span>
      </div>
    {/if}
  </div>
  
  {#if error}
    <div 
      class="textarea-error-message"
      id="{id}-error"
      role="alert"
      in:fly={{ y: -10, duration: 200, easing: cubicOut }}
    >
      <span class="error-icon">⚠️</span>
      {error}
    </div>
  {:else if hint}
    <div 
      class="textarea-hint"
      id="{id}-hint"
    >
      {hint}
    </div>
  {/if}
</div>

<style>
  .textarea-wrapper {
    display: flex;
    flex-direction: column;
    gap: 6px;
    width: 100%;
  }
  
  .textarea-label {
    font-size: 14px;
    font-weight: 600;
    color: #374151;
    line-height: 1.4;
  }
  
  .required-asterisk {
    color: #ef4444;
    margin-left: 2px;
  }
  
  .textarea-container {
    position: relative;
  }
  
  .textarea {
    width: 100%;
    border: 1px solid #d1d5db;
    border-radius: 8px;
    background: white;
    font-family: inherit;
    font-size: 16px;
    line-height: 1.5;
    transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
    outline: none;
    color: #374151;
    resize: vertical;
  }
  
  /* 尺寸变体 */
  .textarea-sm {
    padding: 8px 12px;
    font-size: 14px;
  }
  
  .textarea-md {
    padding: 12px 16px;
    font-size: 16px;
  }
  
  .textarea-lg {
    padding: 16px 20px;
    font-size: 18px;
  }
  
  /* 样式变体 */
  .textarea-filled {
    background: #f9fafb;
    border: 1px solid transparent;
  }
  
  .textarea-outlined {
    background: transparent;
    border: 2px solid #d1d5db;
  }
  
  /* 状态 */
  .textarea:hover:not(:disabled) {
    border-color: #9ca3af;
  }
  
  .textarea:focus,
  .textarea-focused {
    border-color: #667eea;
    box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
  }
  
  .textarea-error {
    border-color: #ef4444;
  }
  
  .textarea-error:focus {
    box-shadow: 0 0 0 3px rgba(239, 68, 68, 0.1);
  }
  
  .textarea-disabled {
    background: #f3f4f6;
    color: #9ca3af;
    cursor: not-allowed;
    resize: none;
  }
  
  .textarea-auto-resize {
    overflow-y: hidden;
    min-height: auto;
  }
  
  /* 字符计数器 */
  .character-counter {
    position: absolute;
    bottom: 8px;
    right: 12px;
    display: flex;
    align-items: center;
    gap: 2px;
    font-size: 12px;
    color: #9ca3af;
    background: rgba(255, 255, 255, 0.9);
    padding: 2px 6px;
    border-radius: 4px;
    backdrop-filter: blur(4px);
  }
  
  .over-limit {
    color: #ef4444;
    font-weight: 600;
  }
  
  .counter-separator {
    color: #d1d5db;
  }
  
  /* 错误和提示信息 */
  .textarea-error-message {
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
  
  .textarea-hint {
    font-size: 12px;
    color: #6b7280;
    line-height: 1.4;
  }
  
  /* 占位符样式 */
  .textarea::placeholder {
    color: #9ca3af;
  }
  
  /* 滚动条样式 */
  .textarea {
    scrollbar-width: thin;
    scrollbar-color: #d1d5db transparent;
  }
  
  .textarea::-webkit-scrollbar {
    width: 8px;
  }
  
  .textarea::-webkit-scrollbar-track {
    background: transparent;
  }
  
  .textarea::-webkit-scrollbar-thumb {
    background: #d1d5db;
    border-radius: 4px;
  }
  
  .textarea::-webkit-scrollbar-thumb:hover {
    background: #9ca3af;
  }
  
  /* 深色模式 */
  @media (prefers-color-scheme: dark) {
    .textarea-label {
      color: #f3f4f6;
    }
    
    .textarea {
      background: #374151;
      border-color: #4b5563;
      color: #f9fafb;
    }
    
    .textarea::placeholder {
      color: #6b7280;
    }
    
    .textarea-filled {
      background: #4b5563;
    }
    
    .textarea-disabled {
      background: #1f2937;
      color: #6b7280;
    }
    
    .textarea-hint {
      color: #9ca3af;
    }
    
    .character-counter {
      background: rgba(55, 65, 81, 0.9);
      color: #d1d5db;
    }
    
    .textarea::-webkit-scrollbar-thumb {
      background: #4b5563;
    }
    
    .textarea::-webkit-scrollbar-thumb:hover {
      background: #6b7280;
    }
  }
  
  /* 无障碍优化 */
  @media (prefers-reduced-motion: reduce) {
    .textarea {
      transition: none;
    }
  }
  
  /* 移动端优化 */
  @media (max-width: 480px) {
    .textarea {
      font-size: 16px; /* 防止iOS缩放 */
    }
    
    .character-counter {
      position: static;
      margin-top: 4px;
      background: transparent;
      justify-content: flex-end;
    }
  }
  
  /* 聚焦时隐藏计数器避免遮挡 */
  .textarea:focus + .character-counter {
    opacity: 0.7;
  }
</style> 