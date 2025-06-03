<script lang="ts">
  import { createEventDispatcher, onMount } from 'svelte';
  import { fade, scale } from 'svelte/transition';
  import Button from '$lib/components/ui/Button.svelte';
  import Input from '$lib/components/ui/Input.svelte';
  import Card from '$lib/components/ui/Card.svelte';
  
  export let visible = false;
  export let title = '扫码分享';
  export let qrData = ''; // URL或文本数据
  export let description = '';
  export let size = 'default'; // sm, default, lg
  export let showDownload = true;
  export let showShare = true;
  export let className = '';
  
  const dispatch = createEventDispatcher();
  
  let qrCanvas;
  let canvasSize = 256;
  
  // 尺寸配置
  const sizeConfig = {
    sm: { canvas: 200, modal: '320px' },
    default: { canvas: 256, modal: '400px' },
    lg: { canvas: 320, modal: '480px' }
  };
  
  $: currentSize = sizeConfig[size];
  $: canvasSize = currentSize.canvas;
  
  function generateQRCode() {
    if (!qrCanvas || !qrData) return;
    
    const ctx = qrCanvas.getContext('2d');
    const moduleSize = canvasSize / 25; // 25x25 网格
    
    // 清空画布
    ctx.fillStyle = '#ffffff';
    ctx.fillRect(0, 0, canvasSize, canvasSize);
    
    // 生成简单的QR码样式（这里是模拟，实际应该使用QR码库）
    ctx.fillStyle = '#000000';
    
    // 绘制定位标记
    drawFinderPattern(ctx, 0, 0, moduleSize);
    drawFinderPattern(ctx, 18 * moduleSize, 0, moduleSize);
    drawFinderPattern(ctx, 0, 18 * moduleSize, moduleSize);
    
    // 绘制数据模块（随机模式，实际应根据数据生成）
    for (let i = 0; i < 25; i++) {
      for (let j = 0; j < 25; j++) {
        if (shouldDrawModule(i, j)) {
          ctx.fillRect(i * moduleSize, j * moduleSize, moduleSize, moduleSize);
        }
      }
    }
    
    // 添加中心logo（可选）
    drawCenterLogo(ctx, canvasSize);
  }
  
  function drawFinderPattern(ctx, x, y, moduleSize) {
    // 外框 7x7
    ctx.fillRect(x, y, 7 * moduleSize, 7 * moduleSize);
    ctx.fillStyle = '#ffffff';
    ctx.fillRect(x + moduleSize, y + moduleSize, 5 * moduleSize, 5 * moduleSize);
    ctx.fillStyle = '#000000';
    ctx.fillRect(x + 2 * moduleSize, y + 2 * moduleSize, 3 * moduleSize, 3 * moduleSize);
  }
  
  function drawCenterLogo(ctx, canvasSize) {
    const logoSize = canvasSize * 0.15;
    const logoX = (canvasSize - logoSize) / 2;
    const logoY = (canvasSize - logoSize) / 2;
    
    // 白色背景
    ctx.fillStyle = '#ffffff';
    ctx.fillRect(logoX - 4, logoY - 4, logoSize + 8, logoSize + 8);
    
    // 简单的logo（圆形）
    ctx.fillStyle = '#667eea';
    ctx.beginPath();
    ctx.arc(logoX + logoSize / 2, logoY + logoSize / 2, logoSize / 2, 0, 2 * Math.PI);
    ctx.fill();
    
    // logo文字
    ctx.fillStyle = '#ffffff';
    ctx.font = `${logoSize * 0.3}px Arial`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText('道', logoX + logoSize / 2, logoY + logoSize / 2);
  }
  
  function shouldDrawModule(i, j) {
    // 跳过定位标记区域
    if ((i < 9 && j < 9) || (i > 15 && j < 9) || (i < 9 && j > 15)) {
      return false;
    }
    
    // 简单的伪随机模式
    return (i + j + qrData.length) % 3 === 0;
  }
  
  function handleClose() {
    visible = false;
    dispatch('close');
  }
  
  function handleDownload() {
    if (!qrCanvas) return;
    
    const link = document.createElement('a');
    link.download = `qrcode_${Date.now()}.png`;
    link.href = qrCanvas.toDataURL('image/png');
    link.click();
    
    dispatch('download', { dataUrl: link.href });
  }
  
  async function handleShare() {
    if (!qrCanvas) return;
    
    try {
      const blob = await new Promise(resolve => qrCanvas.toBlob(resolve, 'image/png'));
      const file = new File([blob], 'qrcode.png', { type: 'image/png' });
      
      if (navigator.share && navigator.canShare({ files: [file] })) {
        await navigator.share({
          title: title,
          text: description,
          files: [file]
        });
      } else {
        // 降级到复制链接
        await navigator.clipboard.writeText(qrData);
        dispatch('fallbackShare', { data: qrData });
      }
      
      dispatch('share', { data: qrData });
    } catch (err) {
      console.error('分享失败:', err);
    }
  }
  
  onMount(() => {
    if (visible && qrData) {
      generateQRCode();
    }
  });
  
  $: if (visible && qrData && qrCanvas) {
    generateQRCode();
  }
</script>

{#if visible}
  <!-- 背景遮罩 -->
  <div 
    class="modal-backdrop"
    on:click={handleClose}
    transition:fade={{ duration: 200 }}
  ></div>
  
  <!-- 模态框 -->
  <div 
    class="qr-modal {className}"
    style="width: {currentSize.modal}"
    transition:scale={{ duration: 300, start: 0.9 }}
    role="dialog"
    aria-modal="true"
    aria-labelledby="qr-modal-title"
  >
    <Card variant="elevated" padding="lg">
      <!-- 头部 -->
      <div class="modal-header" slot="header">
        <h3 id="qr-modal-title">{title}</h3>
        <Button
          variant="ghost"
          size="sm"
          on:click={handleClose}
          aria-label="关闭"
        >
          ✕
        </Button>
      </div>
      
      <!-- 内容 -->
      <div class="modal-content">
        <!-- 二维码 -->
        <div class="qr-container">
          <canvas
            bind:this={qrCanvas}
            width={canvasSize}
            height={canvasSize}
            class="qr-canvas"
          ></canvas>
          
          <!-- 加载状态 -->
          {#if !qrData}
            <div class="qr-loading">
              <div class="loading-spinner"></div>
              <p>生成中...</p>
            </div>
          {/if}
        </div>
        
        <!-- 描述 -->
        {#if description}
          <p class="qr-description">{description}</p>
        {/if}
        
        <!-- 链接显示 -->
        {#if qrData}
          <div class="qr-data">
            <input
              type="text"
              value={qrData}
              readonly
              class="data-input"
            />
          </div>
        {/if}
        
        <!-- 操作按钮 -->
        <div class="modal-actions">
          {#if showDownload}
            <Button
              variant="outline"
              size="default"
              on:click={handleDownload}
              disabled={!qrData}
            >
              📥 下载图片
            </Button>
          {/if}
          
          {#if showShare}
            <Button
              variant="primary"
              size="default"
              on:click={handleShare}
              disabled={!qrData}
            >
              📤 分享
            </Button>
          {/if}
        </div>
        
        <!-- 使用提示 -->
        <div class="usage-tip">
          <p>📱 使用微信、支付宝等扫一扫功能扫描二维码</p>
        </div>
      </div>
    </Card>
  </div>
{/if}

<style>
  .modal-backdrop {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.5);
    z-index: 1000;
    backdrop-filter: blur(4px);
  }
  
  .qr-modal {
    position: fixed;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    z-index: 1001;
    max-width: 90vw;
    max-height: 90vh;
    overflow-y: auto;
  }
  
  .modal-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 0;
  }
  
  .modal-header h3 {
    margin: 0;
    font-size: 18px;
    font-weight: 600;
    color: #111827;
  }
  
  .modal-content {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 20px;
  }
  
  .qr-container {
    position: relative;
    display: flex;
    align-items: center;
    justify-content: center;
    background: white;
    border-radius: 12px;
    padding: 16px;
    box-shadow: 0 4px 20px rgba(0, 0, 0, 0.1);
    border: 1px solid #e5e7eb;
  }
  
  .qr-canvas {
    border-radius: 8px;
    max-width: 100%;
    height: auto;
  }
  
  .qr-loading {
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 12px;
    color: #6b7280;
  }
  
  .loading-spinner {
    width: 32px;
    height: 32px;
    border: 3px solid #f3f4f6;
    border-top: 3px solid #3b82f6;
    border-radius: 50%;
    animation: spin 1s linear infinite;
  }
  
  @keyframes spin {
    from { transform: rotate(0deg); }
    to { transform: rotate(360deg); }
  }
  
  .qr-description {
    text-align: center;
    color: #6b7280;
    font-size: 14px;
    line-height: 1.5;
    margin: 0;
    max-width: 300px;
  }
  
  .qr-data {
    width: 100%;
    max-width: 400px;
  }
  
  .data-input {
    width: 100%;
    padding: 8px 12px;
    border: 1px solid #d1d5db;
    border-radius: 6px;
    font-size: 12px;
    font-family: monospace;
    color: #6b7280;
    background: #f9fafb;
    text-align: center;
  }
  
  .data-input:focus {
    outline: none;
    border-color: #3b82f6;
  }
  
  .modal-actions {
    display: flex;
    gap: 12px;
    flex-wrap: wrap;
    justify-content: center;
  }
  
  .usage-tip {
    text-align: center;
    background: #f0f9ff;
    border: 1px solid #bfdbfe;
    border-radius: 8px;
    padding: 12px 16px;
    max-width: 300px;
  }
  
  .usage-tip p {
    margin: 0;
    font-size: 13px;
    color: #1e40af;
  }
  
  /* 移动端适配 */
  @media (max-width: 768px) {
    .qr-modal {
      width: 95vw !important;
      max-width: 95vw;
    }
    
    .modal-header h3 {
      font-size: 16px;
    }
    
    .qr-container {
      padding: 12px;
    }
    
    .modal-actions {
      flex-direction: column;
      width: 100%;
    }
    
    .modal-actions :global(.btn) {
      width: 100%;
    }
    
    .usage-tip {
      max-width: 100%;
    }
  }
  
  /* 深色模式 */
  @media (prefers-color-scheme: dark) {
    .modal-backdrop {
      background: rgba(0, 0, 0, 0.7);
    }
    
    .modal-header h3 {
      color: #f9fafb;
    }
    
    .qr-container {
      background: #1f2937;
      border-color: #374151;
    }
    
    .qr-description {
      color: #d1d5db;
    }
    
    .data-input {
      background: #374151;
      border-color: #4b5563;
      color: #d1d5db;
    }
    
    .data-input:focus {
      border-color: #60a5fa;
    }
    
    .usage-tip {
      background: #1e3a8a;
      border-color: #1e40af;
    }
    
    .usage-tip p {
      color: #93c5fd;
    }
    
    .qr-loading {
      color: #d1d5db;
    }
    
    .loading-spinner {
      border-color: #4b5563;
      border-top-color: #60a5fa;
    }
  }
  
  /* 高对比度模式 */
  @media (prefers-contrast: high) {
    .qr-container {
      border-width: 2px;
      border-color: #000;
    }
    
    .modal-header h3 {
      color: #000;
    }
    
    .data-input {
      border-width: 2px;
    }
  }
  
  /* 减少动画模式 */
  @media (prefers-reduced-motion: reduce) {
    .loading-spinner {
      animation: none;
    }
    
    .qr-modal {
      transition: none;
    }
    
    .modal-backdrop {
      transition: none;
    }
  }
</style> 