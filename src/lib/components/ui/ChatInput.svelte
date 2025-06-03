<script>
  import { createEventDispatcher, onMount } from 'svelte';
  import Button from './Button.svelte';
  
  export let placeholder = '输入消息...';
  export let disabled = false;
  export let maxLength = 1000;
  export let showEmojiButton = true;
  export let showVoiceButton = true;
  export let showFileButton = true;
  export let allowMultiline = true;
  export let autoFocus = false;
  
  const dispatch = createEventDispatcher();
  
  let inputText = '';
  let textareaEl;
  let isRecording = false;
  let recordingTime = 0;
  let recordingInterval;
  let isDragging = false;
  let fileInputEl;
  
  $: isEmpty = !inputText.trim();
  $: remainingChars = maxLength - inputText.length;
  
  function handleSubmit() {
    if (isEmpty || disabled) return;
    
    const message = {
      type: 'text',
      content: inputText.trim(),
      timestamp: new Date().toISOString()
    };
    
    dispatch('send', { message });
    inputText = '';
    resizeTextarea();
  }
  
  function handleKeydown(event) {
    if (event.key === 'Enter' && !event.shiftKey) {
      if (allowMultiline) {
        // 允许多行时，Ctrl+Enter 发送
        if (event.ctrlKey || event.metaKey) {
          event.preventDefault();
          handleSubmit();
        }
      } else {
        // 单行模式下，Enter 直接发送
        event.preventDefault();
        handleSubmit();
      }
    }
  }
  
  function handleInput() {
    resizeTextarea();
    dispatch('typing');
  }
  
  function resizeTextarea() {
    if (textareaEl && allowMultiline) {
      textareaEl.style.height = 'auto';
      const newHeight = Math.min(textareaEl.scrollHeight, 120); // 最大高度120px
      textareaEl.style.height = newHeight + 'px';
    }
  }
  
  function handleEmojiClick() {
    dispatch('emojiClick');
  }
  
  function handleVoiceStart() {
    if (disabled) return;
    
    isRecording = true;
    recordingTime = 0;
    
    recordingInterval = setInterval(() => {
      recordingTime++;
    }, 1000);
    
    dispatch('voiceStart');
  }
  
  function handleVoiceStop() {
    if (!isRecording) return;
    
    isRecording = false;
    clearInterval(recordingInterval);
    
    const message = {
      type: 'voice',
      duration: recordingTime,
      timestamp: new Date().toISOString()
    };
    
    dispatch('voiceStop', { message, duration: recordingTime });
    recordingTime = 0;
  }
  
  function handleVoiceCancel() {
    if (!isRecording) return;
    
    isRecording = false;
    clearInterval(recordingInterval);
    recordingTime = 0;
    
    dispatch('voiceCancel');
  }
  
  function handleFileSelect() {
    if (fileInputEl) {
      fileInputEl.click();
    }
  }
  
  function handleFileChange(event) {
    const files = Array.from(event.target.files);
    if (files.length > 0) {
      dispatch('fileSelect', { files });
    }
    
    // 清空文件输入，允许重复选择同一文件
    event.target.value = '';
  }
  
  function handleDragOver(event) {
    event.preventDefault();
    isDragging = true;
  }
  
  function handleDragLeave(event) {
    event.preventDefault();
    isDragging = false;
  }
  
  function handleDrop(event) {
    event.preventDefault();
    isDragging = false;
    
    const files = Array.from(event.dataTransfer.files);
    if (files.length > 0) {
      dispatch('fileSelect', { files });
    }
  }
  
  function formatRecordingTime(seconds) {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  }
  
  function insertEmoji(emoji) {
    const cursorPos = textareaEl.selectionStart;
    const textBefore = inputText.substring(0, cursorPos);
    const textAfter = inputText.substring(textareaEl.selectionEnd);
    
    inputText = textBefore + emoji + textAfter;
    
    // 设置光标位置
    setTimeout(() => {
      const newPos = cursorPos + emoji.length;
      textareaEl.setSelectionRange(newPos, newPos);
      textareaEl.focus();
    });
    
    resizeTextarea();
  }
  
  onMount(() => {
    if (autoFocus && textareaEl) {
      textareaEl.focus();
    }
  });
  
  // 暴露插入表情的方法
  export function insertEmojiText(emoji) {
    insertEmoji(emoji);
  }
</script>

<div 
  class="chat-input-container"
  class:disabled
  class:dragging={isDragging}
  on:dragover={handleDragOver}
  on:dragleave={handleDragLeave}
  on:drop={handleDrop}
>
  <!-- 录音状态覆盖层 -->
  {#if isRecording}
    <div class="recording-overlay">
      <div class="recording-content">
        <div class="recording-animation">
          <div class="recording-dot"></div>
          <div class="recording-ripple"></div>
        </div>
        <div class="recording-info">
          <span class="recording-text">正在录音...</span>
          <span class="recording-time">{formatRecordingTime(recordingTime)}</span>
        </div>
        <div class="recording-actions">
          <button class="recording-cancel" on:click={handleVoiceCancel}>
            取消
          </button>
          <button class="recording-stop" on:click={handleVoiceStop}>
            发送
          </button>
        </div>
      </div>
    </div>
  {/if}
  
  <!-- 拖拽提示 -->
  {#if isDragging}
    <div class="drag-overlay">
      <div class="drag-content">
        <div class="drag-icon">📎</div>
        <div class="drag-text">释放文件以发送</div>
      </div>
    </div>
  {/if}
  
  <!-- 输入区域 -->
  <div class="input-wrapper">
    <!-- 左侧按钮组 -->
    <div class="input-actions left">
      {#if showFileButton}
        <button 
          class="action-btn file-btn"
          on:click={handleFileSelect}
          disabled={disabled}
          title="发送文件"
        >
          📎
        </button>
      {/if}
    </div>
    
    <!-- 文本输入区域 -->
    <div class="text-input-container">
      <textarea
        bind:this={textareaEl}
        bind:value={inputText}
        {placeholder}
        {disabled}
        maxlength={maxLength}
        rows="1"
        class="text-input"
        class:multiline={allowMultiline}
        on:keydown={handleKeydown}
        on:input={handleInput}
      ></textarea>
      
      <!-- 字符计数 -->
      {#if maxLength && inputText.length > maxLength * 0.8}
        <div class="char-counter" class:warning={remainingChars < 50} class:danger={remainingChars < 0}>
          {remainingChars}
        </div>
      {/if}
    </div>
    
    <!-- 右侧按钮组 -->
    <div class="input-actions right">
      {#if showEmojiButton}
        <button 
          class="action-btn emoji-btn"
          on:click={handleEmojiClick}
          disabled={disabled}
          title="表情"
        >
          😊
        </button>
      {/if}
      
      {#if showVoiceButton && isEmpty}
        <button 
          class="action-btn voice-btn"
          class:recording={isRecording}
          on:mousedown={handleVoiceStart}
          on:mouseup={handleVoiceStop}
          on:touchstart={handleVoiceStart}
          on:touchend={handleVoiceStop}
          disabled={disabled}
          title="按住录音"
        >
          🎤
        </button>
      {:else if !isEmpty}
        <button 
          class="action-btn send-btn"
          on:click={handleSubmit}
          disabled={disabled || isEmpty}
          title={allowMultiline ? 'Ctrl+Enter 发送' : 'Enter 发送'}
        >
          ➤
        </button>
      {/if}
    </div>
  </div>
  
  <!-- 快捷提示 -->
  {#if allowMultiline && !isEmpty}
    <div class="input-hint">
      按 Ctrl+Enter 发送消息
    </div>
  {/if}
</div>

<!-- 隐藏的文件选择器 -->
<input
  bind:this={fileInputEl}
  type="file"
  multiple
  accept="image/*,video/*,audio/*,.pdf,.doc,.docx,.txt"
  on:change={handleFileChange}
  style="display: none;"
/>

<style>
  .chat-input-container {
    position: relative;
    background: white;
    border-radius: 20px;
    padding: 12px;
    box-shadow: 0 2px 12px rgba(0, 0, 0, 0.1);
    border: 1px solid #e5e7eb;
    transition: all 0.2s ease;
  }
  
  .chat-input-container:focus-within {
    border-color: #667eea;
    box-shadow: 0 4px 20px rgba(102, 126, 234, 0.15);
  }
  
  .chat-input-container.disabled {
    opacity: 0.6;
    pointer-events: none;
  }
  
  .chat-input-container.dragging {
    border-color: #3b82f6;
    background: #f0f9ff;
  }
  
  /* 录音覆盖层 */
  .recording-overlay {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.9);
    border-radius: 20px;
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 10;
  }
  
  .recording-content {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 16px;
    color: white;
  }
  
  .recording-animation {
    position: relative;
    width: 60px;
    height: 60px;
  }
  
  .recording-dot {
    position: absolute;
    top: 50%;
    left: 50%;
    width: 20px;
    height: 20px;
    background: #ef4444;
    border-radius: 50%;
    transform: translate(-50%, -50%);
    animation: pulse 1.5s ease-in-out infinite;
  }
  
  .recording-ripple {
    position: absolute;
    top: 50%;
    left: 50%;
    width: 60px;
    height: 60px;
    border: 2px solid #ef4444;
    border-radius: 50%;
    transform: translate(-50%, -50%);
    animation: ripple 1.5s ease-out infinite;
  }
  
  @keyframes pulse {
    0%, 100% { transform: translate(-50%, -50%) scale(1); }
    50% { transform: translate(-50%, -50%) scale(1.2); }
  }
  
  @keyframes ripple {
    0% {
      opacity: 1;
      transform: translate(-50%, -50%) scale(0.5);
    }
    100% {
      opacity: 0;
      transform: translate(-50%, -50%) scale(1.5);
    }
  }
  
  .recording-info {
    text-align: center;
  }
  
  .recording-text {
    display: block;
    font-size: 16px;
    font-weight: 600;
    margin-bottom: 4px;
  }
  
  .recording-time {
    display: block;
    font-size: 14px;
    opacity: 0.8;
    font-family: monospace;
  }
  
  .recording-actions {
    display: flex;
    gap: 16px;
  }
  
  .recording-cancel,
  .recording-stop {
    padding: 8px 16px;
    border: none;
    border-radius: 12px;
    font-size: 14px;
    font-weight: 500;
    cursor: pointer;
    transition: all 0.2s ease;
  }
  
  .recording-cancel {
    background: rgba(239, 68, 68, 0.2);
    color: white;
  }
  
  .recording-cancel:hover {
    background: rgba(239, 68, 68, 0.3);
  }
  
  .recording-stop {
    background: rgba(16, 185, 129, 0.2);
    color: white;
  }
  
  .recording-stop:hover {
    background: rgba(16, 185, 129, 0.3);
  }
  
  /* 拖拽覆盖层 */
  .drag-overlay {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(59, 130, 246, 0.1);
    border-radius: 20px;
    border: 2px dashed #3b82f6;
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 5;
  }
  
  .drag-content {
    text-align: center;
    color: #1e40af;
  }
  
  .drag-icon {
    font-size: 32px;
    margin-bottom: 8px;
  }
  
  .drag-text {
    font-size: 14px;
    font-weight: 600;
  }
  
  /* 输入区域 */
  .input-wrapper {
    display: flex;
    align-items: flex-end;
    gap: 8px;
  }
  
  .input-actions {
    display: flex;
    gap: 4px;
    flex-shrink: 0;
  }
  
  .action-btn {
    width: 36px;
    height: 36px;
    border: none;
    background: #f3f4f6;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    transition: all 0.2s ease;
    font-size: 16px;
  }
  
  .action-btn:hover:not(:disabled) {
    background: #e5e7eb;
    transform: scale(1.05);
  }
  
  .action-btn:active {
    transform: scale(0.95);
  }
  
  .action-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }
  
  .send-btn {
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    color: white;
  }
  
  .send-btn:hover:not(:disabled) {
    background: linear-gradient(135deg, #5a6fd8 0%, #6a4190 100%);
    box-shadow: 0 4px 12px rgba(102, 126, 234, 0.3);
  }
  
  .voice-btn.recording {
    background: #ef4444;
    color: white;
    animation: pulse 1s ease-in-out infinite;
  }
  
  /* 文本输入区域 */
  .text-input-container {
    flex: 1;
    position: relative;
  }
  
  .text-input {
    width: 100%;
    min-height: 36px;
    max-height: 120px;
    padding: 8px 12px;
    border: none;
    border-radius: 18px;
    background: #f9fafb;
    font-size: 14px;
    line-height: 1.4;
    resize: none;
    outline: none;
    font-family: inherit;
    transition: background 0.2s ease;
  }
  
  .text-input:focus {
    background: #f3f4f6;
  }
  
  .text-input.multiline {
    min-height: 36px;
  }
  
  .text-input::placeholder {
    color: #9ca3af;
  }
  
  /* 字符计数 */
  .char-counter {
    position: absolute;
    bottom: 4px;
    right: 8px;
    font-size: 11px;
    color: #6b7280;
    background: rgba(255, 255, 255, 0.8);
    padding: 2px 4px;
    border-radius: 4px;
    font-family: monospace;
  }
  
  .char-counter.warning {
    color: #f59e0b;
  }
  
  .char-counter.danger {
    color: #ef4444;
  }
  
  /* 输入提示 */
  .input-hint {
    text-align: center;
    font-size: 11px;
    color: #9ca3af;
    margin-top: 8px;
  }
  
  /* 移动端适配 */
  @media (max-width: 640px) {
    .chat-input-container {
      border-radius: 16px;
      padding: 10px;
    }
    
    .action-btn {
      width: 32px;
      height: 32px;
      font-size: 14px;
    }
    
    .text-input {
      font-size: 16px; /* 防止iOS缩放 */
      padding: 6px 10px;
      min-height: 32px;
    }
    
    .recording-content {
      gap: 12px;
    }
    
    .recording-animation {
      width: 50px;
      height: 50px;
    }
    
    .recording-ripple {
      width: 50px;
      height: 50px;
    }
    
    .recording-text {
      font-size: 14px;
    }
    
    .recording-time {
      font-size: 13px;
    }
    
    .drag-icon {
      font-size: 24px;
    }
    
    .drag-text {
      font-size: 12px;
    }
  }
</style> 