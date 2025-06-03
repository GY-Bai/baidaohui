<script lang="ts">
  import { createEventDispatcher, onMount } from 'svelte';
  import { fly, scale } from 'svelte/transition';
  import { cubicOut } from 'svelte/easing';
  import Loading from './Loading.svelte';
  
  export let multiple: boolean = false;
  export let maxFiles: number = 5;
  export let maxSize: number = 5 * 1024 * 1024; // 5MB
  export let accept: string = 'image/*';
  export let disabled: boolean = false;
  export let preview: boolean = true;
  export let compact: boolean = false;
  export let label: string = '';
  export let hint: string = '';
  export let error: string = '';
  export let required: boolean = false;
  export let id: string = '';
  
  const dispatch = createEventDispatcher();
  
  let fileInput: HTMLInputElement;
  let isDragOver = false;
  let isUploading = false;
  let uploadedFiles: Array<{
    id: string;
    file: File;
    url: string;
    progress: number;
    error?: string;
  }> = [];
  
  $: hasError = !!error;
  $: canAddMore = !multiple || uploadedFiles.length < maxFiles;
  
  function generateId(): string {
    return Date.now().toString(36) + Math.random().toString(36).substr(2);
  }
  
  function formatFileSize(bytes: number): string {
    if (bytes === 0) return '0 B';
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
  }
  
  function validateFile(file: File): string | null {
    if (file.size > maxSize) {
      return `文件大小不能超过 ${formatFileSize(maxSize)}`;
    }
    
    if (accept !== '*/*' && !file.type.match(accept.replace('*', '.*'))) {
      return '文件类型不被支持';
    }
    
    return null;
  }
  
  async function handleFiles(files: FileList | File[]) {
    if (disabled || isUploading) return;
    
    const fileArray = Array.from(files);
    
    // 验证文件数量
    if (!multiple && fileArray.length > 1) {
      dispatch('error', { message: '只能上传一个文件' });
      return;
    }
    
    if (multiple && uploadedFiles.length + fileArray.length > maxFiles) {
      dispatch('error', { message: `最多只能上传 ${maxFiles} 个文件` });
      return;
    }
    
    isUploading = true;
    
    for (const file of fileArray) {
      const validationError = validateFile(file);
      if (validationError) {
        dispatch('error', { message: validationError, file });
        continue;
      }
      
      const fileData = {
        id: generateId(),
        file,
        url: '',
        progress: 0,
        error: undefined
      };
      
      // 非多选模式下清空之前的文件
      if (!multiple) {
        uploadedFiles = [];
      }
      
      uploadedFiles = [...uploadedFiles, fileData];
      
      try {
        // 创建预览URL
        if (preview && file.type.startsWith('image/')) {
          fileData.url = URL.createObjectURL(file);
        }
        
        // 模拟上传进度
        await simulateUpload(fileData);
        
        dispatch('upload', { 
          id: fileData.id, 
          file: fileData.file,
          url: fileData.url 
        });
        
      } catch (error) {
        fileData.error = error.message || '上传失败';
        dispatch('error', { message: fileData.error, file, id: fileData.id });
      }
      
      // 更新响应式数组
      uploadedFiles = uploadedFiles;
    }
    
    isUploading = false;
  }
  
  async function simulateUpload(fileData: any) {
    return new Promise((resolve) => {
      const interval = setInterval(() => {
        fileData.progress += Math.random() * 20;
        if (fileData.progress >= 100) {
          fileData.progress = 100;
          clearInterval(interval);
          resolve(true);
        }
        uploadedFiles = uploadedFiles; // 触发响应式更新
      }, 100);
    });
  }
  
  function removeFile(id: string) {
    const fileToRemove = uploadedFiles.find(f => f.id === id);
    if (fileToRemove?.url) {
      URL.revokeObjectURL(fileToRemove.url);
    }
    
    uploadedFiles = uploadedFiles.filter(f => f.id !== id);
    dispatch('remove', { id });
  }
  
  function handleClick() {
    if (!disabled && canAddMore) {
      fileInput.click();
    }
  }
  
  function handleInputChange(event: Event) {
    const input = event.target as HTMLInputElement;
    if (input.files && input.files.length > 0) {
      handleFiles(input.files);
    }
    // 清空input值以允许重复选择同一文件
    input.value = '';
  }
  
  function handleDragOver(event: DragEvent) {
    event.preventDefault();
    if (!disabled && canAddMore) {
      isDragOver = true;
    }
  }
  
  function handleDragLeave(event: DragEvent) {
    event.preventDefault();
    isDragOver = false;
  }
  
  function handleDrop(event: DragEvent) {
    event.preventDefault();
    isDragOver = false;
    
    if (disabled || !canAddMore) return;
    
    const files = event.dataTransfer?.files;
    if (files && files.length > 0) {
      handleFiles(files);
    }
  }
  
  onMount(() => {
    return () => {
      // 清理预览URLs
      uploadedFiles.forEach(file => {
        if (file.url) {
          URL.revokeObjectURL(file.url);
        }
      });
    };
  });
</script>

<div class="uploader-wrapper">
  {#if label}
    <label class="uploader-label" class:required>
      {label}
      {#if required}
        <span class="required-asterisk">*</span>
      {/if}
    </label>
  {/if}
  
  <div class="uploader-container" class:compact>
    <!-- 上传区域 -->
    {#if canAddMore}
      <div
        class="upload-area"
        class:drag-over={isDragOver}
        class:disabled
        class:compact
        on:click={handleClick}
        on:dragover={handleDragOver}
        on:dragleave={handleDragLeave}
        on:drop={handleDrop}
        role="button"
        tabindex={disabled ? -1 : 0}
        aria-label="上传图片"
      >
        <input
          bind:this={fileInput}
          type="file"
          {id}
          {accept}
          {multiple}
          {disabled}
          class="file-input"
          on:change={handleInputChange}
        />
        
        <div class="upload-content">
          {#if compact}
            <div class="upload-icon compact">📷</div>
            <span class="upload-text compact">选择图片</span>
          {:else}
            <div class="upload-icon">📤</div>
            <div class="upload-text">
              <span class="primary-text">点击上传图片</span>
              <span class="secondary-text">或拖拽图片到此处</span>
            </div>
            <div class="upload-specs">
              支持 JPG, PNG, WebP 格式，最大 {formatFileSize(maxSize)}
            </div>
          {/if}
        </div>
        
        {#if isUploading}
          <div class="upload-loading">
            <Loading size="sm" color="primary" />
          </div>
        {/if}
      </div>
    {/if}
    
    <!-- 文件列表 -->
    {#if uploadedFiles.length > 0}
      <div class="file-list" class:compact>
        {#each uploadedFiles as file (file.id)}
          <div 
            class="file-item"
            class:compact
            in:scale={{ duration: 200, easing: cubicOut }}
            out:scale={{ duration: 150, easing: cubicOut }}
          >
            {#if preview && file.url}
              <div class="file-preview">
                <img 
                  src={file.url} 
                  alt={file.file.name}
                  class="preview-image"
                />
              </div>
            {:else}
              <div class="file-icon">📄</div>
            {/if}
            
            <div class="file-info">
              <div class="file-name">{file.file.name}</div>
              <div class="file-size">{formatFileSize(file.file.size)}</div>
              
              {#if file.progress < 100}
                <div class="progress-bar">
                  <div 
                    class="progress-fill" 
                    style="width: {file.progress}%"
                  ></div>
                </div>
              {/if}
              
              {#if file.error}
                <div class="file-error">{file.error}</div>
              {/if}
            </div>
            
            <button
              class="remove-button"
              on:click={() => removeFile(file.id)}
              aria-label="删除文件"
              type="button"
            >
              ✕
            </button>
          </div>
        {/each}
      </div>
    {/if}
  </div>
  
  {#if error}
    <div 
      class="uploader-error"
      role="alert"
      in:fly={{ y: -10, duration: 200, easing: cubicOut }}
    >
      <span class="error-icon">⚠️</span>
      {error}
    </div>
  {:else if hint}
    <div class="uploader-hint">
      {hint}
    </div>
  {/if}
</div>

<style>
  .uploader-wrapper {
    display: flex;
    flex-direction: column;
    gap: 8px;
    width: 100%;
  }
  
  .uploader-label {
    font-size: 14px;
    font-weight: 600;
    color: #374151;
    line-height: 1.4;
  }
  
  .required-asterisk {
    color: #ef4444;
    margin-left: 2px;
  }
  
  .uploader-container {
    display: flex;
    flex-direction: column;
    gap: 12px;
  }
  
  .uploader-container.compact {
    gap: 8px;
  }
  
  /* 上传区域 */
  .upload-area {
    position: relative;
    border: 2px dashed #d1d5db;
    border-radius: 12px;
    padding: 32px 20px;
    text-align: center;
    cursor: pointer;
    transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
    background: #fafafa;
  }
  
  .upload-area.compact {
    padding: 16px 12px;
    border-radius: 8px;
  }
  
  .upload-area:hover:not(.disabled) {
    border-color: #667eea;
    background: #f8faff;
  }
  
  .upload-area.drag-over {
    border-color: #667eea;
    background: #f0f4ff;
    transform: scale(1.02);
  }
  
  .upload-area.disabled {
    opacity: 0.5;
    cursor: not-allowed;
    background: #f3f4f6;
  }
  
  .file-input {
    position: absolute;
    opacity: 0;
    width: 0;
    height: 0;
    pointer-events: none;
  }
  
  .upload-content {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 12px;
  }
  
  .upload-icon {
    font-size: 48px;
    opacity: 0.6;
  }
  
  .upload-icon.compact {
    font-size: 24px;
  }
  
  .upload-text {
    display: flex;
    flex-direction: column;
    gap: 4px;
    align-items: center;
  }
  
  .upload-text.compact {
    font-size: 14px;
    font-weight: 500;
    color: #6b7280;
  }
  
  .primary-text {
    font-size: 16px;
    font-weight: 600;
    color: #374151;
  }
  
  .secondary-text {
    font-size: 14px;
    color: #6b7280;
  }
  
  .upload-specs {
    font-size: 12px;
    color: #9ca3af;
    margin-top: 4px;
  }
  
  .upload-loading {
    position: absolute;
    top: 16px;
    right: 16px;
  }
  
  /* 文件列表 */
  .file-list {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }
  
  .file-list.compact {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(100px, 1fr));
    gap: 8px;
  }
  
  .file-item {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 12px;
    background: white;
    border: 1px solid #e5e7eb;
    border-radius: 8px;
    transition: all 0.2s;
  }
  
  .file-item.compact {
    flex-direction: column;
    padding: 8px;
    text-align: center;
    gap: 6px;
  }
  
  .file-item:hover {
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  }
  
  .file-preview {
    width: 48px;
    height: 48px;
    border-radius: 6px;
    overflow: hidden;
    flex-shrink: 0;
  }
  
  .file-item.compact .file-preview {
    width: 60px;
    height: 60px;
  }
  
  .preview-image {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }
  
  .file-icon {
    width: 48px;
    height: 48px;
    display: flex;
    align-items: center;
    justify-content: center;
    background: #f3f4f6;
    border-radius: 6px;
    font-size: 20px;
    flex-shrink: 0;
  }
  
  .file-info {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: 4px;
  }
  
  .file-item.compact .file-info {
    width: 100%;
  }
  
  .file-name {
    font-size: 14px;
    font-weight: 500;
    color: #374151;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  
  .file-item.compact .file-name {
    font-size: 12px;
    white-space: normal;
    overflow: visible;
    text-overflow: unset;
    line-height: 1.3;
    max-height: 2.6em;
    overflow: hidden;
  }
  
  .file-size {
    font-size: 12px;
    color: #6b7280;
  }
  
  .progress-bar {
    width: 100%;
    height: 4px;
    background: #e5e7eb;
    border-radius: 2px;
    overflow: hidden;
    margin-top: 2px;
  }
  
  .progress-fill {
    height: 100%;
    background: #667eea;
    border-radius: 2px;
    transition: width 0.3s ease;
  }
  
  .file-error {
    font-size: 12px;
    color: #ef4444;
    margin-top: 2px;
  }
  
  .remove-button {
    width: 24px;
    height: 24px;
    border: none;
    background: #f3f4f6;
    color: #6b7280;
    border-radius: 50%;
    cursor: pointer;
    transition: all 0.2s;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 12px;
    flex-shrink: 0;
  }
  
  .remove-button:hover {
    background: #ef4444;
    color: white;
  }
  
  /* 错误和提示信息 */
  .uploader-error {
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
  
  .uploader-hint {
    font-size: 12px;
    color: #6b7280;
    line-height: 1.4;
  }
  
  /* 深色模式 */
  @media (prefers-color-scheme: dark) {
    .uploader-label {
      color: #f3f4f6;
    }
    
    .upload-area {
      background: #374151;
      border-color: #4b5563;
    }
    
    .upload-area:hover:not(.disabled) {
      background: #4b5563;
    }
    
    .upload-area.disabled {
      background: #1f2937;
    }
    
    .primary-text {
      color: #f3f4f6;
    }
    
    .file-item {
      background: #1f2937;
      border-color: #374151;
    }
    
    .file-icon {
      background: #4b5563;
    }
    
    .file-name {
      color: #f3f4f6;
    }
    
    .remove-button {
      background: #374151;
      color: #9ca3af;
    }
    
    .uploader-hint {
      color: #9ca3af;
    }
  }
  
  /* 移动端优化 */
  @media (max-width: 480px) {
    .upload-area {
      padding: 24px 16px;
    }
    
    .upload-area.compact {
      padding: 12px 8px;
    }
    
    .file-list.compact {
      grid-template-columns: repeat(auto-fill, minmax(80px, 1fr));
    }
    
    .file-item.compact .file-preview {
      width: 50px;
      height: 50px;
    }
    
    .upload-icon {
      font-size: 36px;
    }
    
    .primary-text {
      font-size: 14px;
    }
  }
</style> 