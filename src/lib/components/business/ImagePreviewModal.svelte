<script>
  import { createEventDispatcher } from 'svelte';
  import { onMount, onDestroy } from 'svelte';
  
  export let isOpen = false;
  export let images = [];
  export let currentIndex = 0;
  export let title = '';
  export let allowDownload = true;
  export let allowShare = true;
  
  const dispatch = createEventDispatcher();
  
  let scale = 1;
  let rotation = 0;
  let translateX = 0;
  let translateY = 0;
  let isDragging = false;
  let dragStartX = 0;
  let dragStartY = 0;
  let startTranslateX = 0;
  let startTranslateY = 0;
  
  let imageContainer;
  let isLoading = false;
  
  $: currentImage = images[currentIndex];
  $: hasPrevious = currentIndex > 0;
  $: hasNext = currentIndex < images.length - 1;
  
  // 重置变换状态
  function resetTransform() {
    scale = 1;
    rotation = 0;
    translateX = 0;
    translateY = 0;
  }
  
  // 监听当前图片变化，重置变换
  $: if (currentImage) {
    resetTransform();
  }
  
  function handleClose() {
    resetTransform();
    dispatch('close');
  }
  
  function handlePrevious() {
    if (hasPrevious) {
      currentIndex -= 1;
      dispatch('indexChange', { index: currentIndex });
    }
  }
  
  function handleNext() {
    if (hasNext) {
      currentIndex += 1;
      dispatch('indexChange', { index: currentIndex });
    }
  }
  
  function handleZoomIn() {
    scale = Math.min(scale * 1.2, 3);
  }
  
  function handleZoomOut() {
    scale = Math.max(scale / 1.2, 0.5);
  }
  
  function handleRotate() {
    rotation = (rotation + 90) % 360;
  }
  
  function handleReset() {
    resetTransform();
  }
  
  function handleDownload() {
    if (!allowDownload || !currentImage) return;
    
    const link = document.createElement('a');
    link.href = currentImage.url || currentImage;
    link.download = currentImage.name || `image-${currentIndex + 1}.jpg`;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    
    dispatch('download', { image: currentImage, index: currentIndex });
  }
  
  function handleShare() {
    if (!allowShare || !currentImage) return;
    
    if (navigator.share) {
      navigator.share({
        title: title || '图片分享',
        url: currentImage.url || currentImage
      });
    } else {
      // 复制链接到剪贴板
      navigator.clipboard.writeText(currentImage.url || currentImage);
    }
    
    dispatch('share', { image: currentImage, index: currentIndex });
  }
  
  // 鼠标拖拽
  function handleMouseDown(event) {
    if (scale <= 1) return;
    
    isDragging = true;
    dragStartX = event.clientX;
    dragStartY = event.clientY;
    startTranslateX = translateX;
    startTranslateY = translateY;
    
    document.addEventListener('mousemove', handleMouseMove);
    document.addEventListener('mouseup', handleMouseUp);
    event.preventDefault();
  }
  
  function handleMouseMove(event) {
    if (!isDragging) return;
    
    const deltaX = event.clientX - dragStartX;
    const deltaY = event.clientY - dragStartY;
    
    translateX = startTranslateX + deltaX;
    translateY = startTranslateY + deltaY;
  }
  
  function handleMouseUp() {
    isDragging = false;
    document.removeEventListener('mousemove', handleMouseMove);
    document.removeEventListener('mouseup', handleMouseUp);
  }
  
  // 滚轮缩放
  function handleWheel(event) {
    event.preventDefault();
    
    if (event.deltaY < 0) {
      handleZoomIn();
    } else {
      handleZoomOut();
    }
  }
  
  // 键盘事件
  function handleKeydown(event) {
    if (!isOpen) return;
    
    switch (event.key) {
      case 'Escape':
        handleClose();
        break;
      case 'ArrowLeft':
        handlePrevious();
        break;
      case 'ArrowRight':
        handleNext();
        break;
      case '+':
      case '=':
        handleZoomIn();
        break;
      case '-':
        handleZoomOut();
        break;
      case 'r':
      case 'R':
        handleRotate();
        break;
      case '0':
        handleReset();
        break;
    }
  }
  
  onMount(() => {
    document.addEventListener('keydown', handleKeydown);
  });
  
  onDestroy(() => {
    document.removeEventListener('keydown', handleKeydown);
    document.removeEventListener('mousemove', handleMouseMove);
    document.removeEventListener('mouseup', handleMouseUp);
  });
  
  function handleImageLoad() {
    isLoading = false;
  }
  
  function handleImageError() {
    isLoading = false;
  }
  
  // 当图片变化时设置加载状态
  $: if (currentImage) {
    isLoading = true;
  }
</script>

{#if isOpen}
  <div class="modal-overlay" on:click={handleClose}>
    <div class="modal-content" on:click|stopPropagation>
      <!-- 头部工具栏 -->
      <header class="modal-header">
        <div class="header-info">
          <h3 class="modal-title">{title || '图片预览'}</h3>
          {#if images.length > 1}
            <span class="image-counter">{currentIndex + 1} / {images.length}</span>
          {/if}
        </div>
        
        <div class="header-actions">
          <!-- 缩放控制 -->
          <button class="tool-btn" on:click={handleZoomOut} title="缩小 (-)">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
              <circle cx="11" cy="11" r="8" stroke="currentColor" stroke-width="2"/>
              <path d="M21 21l-4.35-4.35" stroke="currentColor" stroke-width="2"/>
              <path d="M8 11h6" stroke="currentColor" stroke-width="2"/>
            </svg>
          </button>
          
          <span class="zoom-indicator">{Math.round(scale * 100)}%</span>
          
          <button class="tool-btn" on:click={handleZoomIn} title="放大 (+)">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
              <circle cx="11" cy="11" r="8" stroke="currentColor" stroke-width="2"/>
              <path d="M21 21l-4.35-4.35" stroke="currentColor" stroke-width="2"/>
              <path d="M11 8v6M8 11h6" stroke="currentColor" stroke-width="2"/>
            </svg>
          </button>
          
          <!-- 旋转 -->
          <button class="tool-btn" on:click={handleRotate} title="旋转 (R)">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
              <path d="M1 4v6h6" stroke="currentColor" stroke-width="2"/>
              <path d="M3.51 15a9 9 0 1 0 2.13-9.36L1 10" stroke="currentColor" stroke-width="2"/>
            </svg>
          </button>
          
          <!-- 重置 -->
          <button class="tool-btn" on:click={handleReset} title="重置 (0)">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
              <path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8" stroke="currentColor" stroke-width="2"/>
              <path d="M3 3v5h5" stroke="currentColor" stroke-width="2"/>
            </svg>
          </button>
          
          <!-- 下载 -->
          {#if allowDownload}
            <button class="tool-btn" on:click={handleDownload} title="下载">
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
                <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" stroke="currentColor" stroke-width="2"/>
                <polyline points="7,10 12,15 17,10" stroke="currentColor" stroke-width="2"/>
                <line x1="12" y1="15" x2="12" y2="3" stroke="currentColor" stroke-width="2"/>
              </svg>
            </button>
          {/if}
          
          <!-- 分享 -->
          {#if allowShare}
            <button class="tool-btn" on:click={handleShare} title="分享">
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
                <path d="M4 12v8a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-8" stroke="currentColor" stroke-width="2"/>
                <polyline points="16,6 12,2 8,6" stroke="currentColor" stroke-width="2"/>
                <line x1="12" y1="2" x2="12" y2="15" stroke="currentColor" stroke-width="2"/>
              </svg>
            </button>
          {/if}
          
          <!-- 关闭 -->
          <button class="tool-btn close-btn" on:click={handleClose} title="关闭 (ESC)">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
              <path d="M18 6L6 18M6 6L18 18" stroke="currentColor" stroke-width="2"/>
            </svg>
          </button>
        </div>
      </header>
      
      <!-- 图片容器 -->
      <div 
        class="image-container"
        bind:this={imageContainer}
        on:wheel={handleWheel}
        on:mousedown={handleMouseDown}
      >
        {#if isLoading}
          <div class="loading-overlay">
            <div class="loading-spinner"></div>
          </div>
        {/if}
        
        {#if currentImage}
          <img
            src={currentImage.url || currentImage}
            alt={currentImage.alt || `图片 ${currentIndex + 1}`}
            class="preview-image"
            style="
              transform: translate({translateX}px, {translateY}px) scale({scale}) rotate({rotation}deg);
              cursor: {scale > 1 ? (isDragging ? 'grabbing' : 'grab') : 'default'};
            "
            on:load={handleImageLoad}
            on:error={handleImageError}
            draggable="false"
          />
        {/if}
        
        <!-- 导航按钮 -->
        {#if images.length > 1}
          <button 
            class="nav-btn prev-btn"
            class:disabled={!hasPrevious}
            on:click|stopPropagation={handlePrevious}
            disabled={!hasPrevious}
            title="上一张 (←)"
          >
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
              <path d="M15 18l-6-6 6-6" stroke="currentColor" stroke-width="2"/>
            </svg>
          </button>
          
          <button 
            class="nav-btn next-btn"
            class:disabled={!hasNext}
            on:click|stopPropagation={handleNext}
            disabled={!hasNext}
            title="下一张 (→)"
          >
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
              <path d="M9 18l6-6-6-6" stroke="currentColor" stroke-width="2"/>
            </svg>
          </button>
        {/if}
      </div>
      
      <!-- 缩略图导航 -->
      {#if images.length > 1}
        <div class="thumbnail-nav">
          {#each images as image, index}
            <button
              class="thumbnail-btn"
              class:active={index === currentIndex}
              on:click={() => { currentIndex = index; }}
            >
              <img
                src={image.thumbnail || image.url || image}
                alt={`缩略图 ${index + 1}`}
                loading="lazy"
              />
            </button>
          {/each}
        </div>
      {/if}
    </div>
  </div>
{/if}

<style>
  .modal-overlay {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.9);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 2000;
    padding: 20px;
  }
  
  .modal-content {
    width: 100%;
    height: 100%;
    max-width: 90vw;
    max-height: 90vh;
    display: flex;
    flex-direction: column;
    background: #1f2937;
    border-radius: 12px;
    overflow: hidden;
  }
  
  /* 头部工具栏 */
  .modal-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 16px 20px;
    background: rgba(0, 0, 0, 0.5);
    border-bottom: 1px solid rgba(255, 255, 255, 0.1);
  }
  
  .header-info {
    display: flex;
    align-items: center;
    gap: 12px;
  }
  
  .modal-title {
    color: white;
    font-size: 16px;
    font-weight: 600;
    margin: 0;
  }
  
  .image-counter {
    color: rgba(255, 255, 255, 0.7);
    font-size: 14px;
  }
  
  .header-actions {
    display: flex;
    align-items: center;
    gap: 8px;
  }
  
  .tool-btn {
    background: rgba(255, 255, 255, 0.1);
    border: none;
    color: white;
    padding: 8px;
    border-radius: 6px;
    cursor: pointer;
    transition: all 0.2s ease;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  
  .tool-btn:hover {
    background: rgba(255, 255, 255, 0.2);
  }
  
  .tool-btn.close-btn {
    background: rgba(239, 68, 68, 0.2);
  }
  
  .tool-btn.close-btn:hover {
    background: rgba(239, 68, 68, 0.3);
  }
  
  .zoom-indicator {
    color: rgba(255, 255, 255, 0.8);
    font-size: 12px;
    min-width: 40px;
    text-align: center;
  }
  
  /* 图片容器 */
  .image-container {
    flex: 1;
    position: relative;
    overflow: hidden;
    display: flex;
    align-items: center;
    justify-content: center;
    background: #111827;
  }
  
  .loading-overlay {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    background: rgba(0, 0, 0, 0.5);
    z-index: 10;
  }
  
  .loading-spinner {
    width: 40px;
    height: 40px;
    border: 3px solid rgba(255, 255, 255, 0.3);
    border-top: 3px solid white;
    border-radius: 50%;
    animation: spin 1s linear infinite;
  }
  
  @keyframes spin {
    0% { transform: rotate(0deg); }
    100% { transform: rotate(360deg); }
  }
  
  .preview-image {
    max-width: 100%;
    max-height: 100%;
    object-fit: contain;
    transition: transform 0.2s ease;
    user-select: none;
  }
  
  /* 导航按钮 */
  .nav-btn {
    position: absolute;
    top: 50%;
    transform: translateY(-50%);
    background: rgba(0, 0, 0, 0.5);
    border: none;
    color: white;
    padding: 12px;
    border-radius: 50%;
    cursor: pointer;
    transition: all 0.2s ease;
    z-index: 10;
  }
  
  .nav-btn:hover:not(.disabled) {
    background: rgba(0, 0, 0, 0.7);
    transform: translateY(-50%) scale(1.1);
  }
  
  .nav-btn.disabled {
    opacity: 0.3;
    cursor: not-allowed;
  }
  
  .prev-btn {
    left: 20px;
  }
  
  .next-btn {
    right: 20px;
  }
  
  /* 缩略图导航 */
  .thumbnail-nav {
    display: flex;
    gap: 8px;
    padding: 16px 20px;
    background: rgba(0, 0, 0, 0.5);
    overflow-x: auto;
    border-top: 1px solid rgba(255, 255, 255, 0.1);
  }
  
  .thumbnail-btn {
    background: none;
    border: 2px solid transparent;
    padding: 0;
    border-radius: 6px;
    cursor: pointer;
    transition: all 0.2s ease;
    overflow: hidden;
    flex-shrink: 0;
  }
  
  .thumbnail-btn.active {
    border-color: #667eea;
  }
  
  .thumbnail-btn:hover {
    border-color: rgba(255, 255, 255, 0.5);
  }
  
  .thumbnail-btn img {
    width: 60px;
    height: 60px;
    object-fit: cover;
    display: block;
  }
  
  /* 移动端适配 */
  @media (max-width: 640px) {
    .modal-overlay {
      padding: 0;
    }
    
    .modal-content {
      max-width: 100vw;
      max-height: 100vh;
      border-radius: 0;
    }
    
    .modal-header {
      padding: 12px 16px;
    }
    
    .header-actions {
      gap: 4px;
    }
    
    .tool-btn {
      padding: 6px;
    }
    
    .nav-btn {
      padding: 8px;
    }
    
    .prev-btn {
      left: 12px;
    }
    
    .next-btn {
      right: 12px;
    }
    
    .thumbnail-nav {
      padding: 12px 16px;
    }
    
    .thumbnail-btn img {
      width: 50px;
      height: 50px;
    }
    
    .modal-title {
      font-size: 14px;
    }
    
    .image-counter {
      font-size: 12px;
    }
  }
</style> 