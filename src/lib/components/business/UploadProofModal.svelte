<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import Modal from '$lib/components/ui/Modal.svelte';
  import Button from '$lib/components/ui/Button.svelte';
  import ImageUploader from '$lib/components/ui/ImageUploader.svelte';
  
  const dispatch = createEventDispatcher();
  
  export let isOpen = false;
  export let title = '上传支付凭证';
  export let description = '请上传您的支付截图或凭证';
  export let orderId = '';
  export let amount = 0;
  
  let uploadedImages = [];
  let uploading = false;
  let error = '';
  
  function handleClose() {
    dispatch('close');
    resetForm();
  }
  
  function handleImageUpload(event) {
    uploadedImages = event.detail.images;
    error = '';
  }
  
  function handleImageError(event) {
    error = event.detail.error;
  }
  
  async function handleSubmit() {
    if (uploadedImages.length === 0) {
      error = '请至少上传一张支付凭证图片';
      return;
    }
    
    uploading = true;
    error = '';
    
    try {
      // 模拟提交支付凭证
      await new Promise(resolve => setTimeout(resolve, 1000));
      
      dispatch('submit', {
        orderId,
        amount,
        images: uploadedImages,
        success: true
      });
      
      handleClose();
    } catch (err) {
      error = '提交失败，请重试';
    } finally {
      uploading = false;
    }
  }
  
  function resetForm() {
    uploadedImages = [];
    uploading = false;
    error = '';
  }
</script>

<Modal {isOpen} {title} size="md" on:close={handleClose}>
  <div class="upload-proof-content">
    <div class="order-info">
      <p class="description">{description}</p>
      {#if orderId}
        <div class="order-details">
          <span class="label">订单号：</span>
          <span class="value">{orderId}</span>
        </div>
      {/if}
      {#if amount > 0}
        <div class="order-details">
          <span class="label">支付金额：</span>
          <span class="value amount">¥{amount}</span>
        </div>
      {/if}
    </div>
    
    <div class="upload-section">
      <ImageUploader
        accept="image/*"
        maxFiles={3}
        maxSize={5}
        placeholder="点击或拖拽上传支付凭证图片"
        helpText="支持 JPG、PNG 格式，最多3张，每张不超过5MB"
        on:upload={handleImageUpload}
        on:error={handleImageError}
      />
    </div>
    
    {#if error}
      <div class="error-message">
        <i class="fas fa-exclamation-triangle"></i>
        {error}
      </div>
    {/if}
    
    <div class="modal-actions">
      <Button variant="secondary" on:click={handleClose} disabled={uploading}>
        取消
      </Button>
      <Button 
        variant="primary" 
        on:click={handleSubmit} 
        disabled={uploading || uploadedImages.length === 0}
        loading={uploading}
      >
        {uploading ? '提交中...' : '提交凭证'}
      </Button>
    </div>
  </div>
</Modal>

<style>
  .upload-proof-content {
    padding: 20px 0;
  }
  
  .order-info {
    margin-bottom: 24px;
  }
  
  .description {
    color: #6b7280;
    margin-bottom: 16px;
    line-height: 1.5;
  }
  
  .order-details {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 8px 0;
    border-bottom: 1px solid #f3f4f6;
  }
  
  .order-details:last-child {
    border-bottom: none;
  }
  
  .label {
    color: #6b7280;
    font-size: 14px;
  }
  
  .value {
    color: #111827;
    font-weight: 500;
  }
  
  .value.amount {
    color: #dc2626;
    font-weight: 600;
    font-size: 16px;
  }
  
  .upload-section {
    margin-bottom: 24px;
  }
  
  .error-message {
    display: flex;
    align-items: center;
    gap: 8px;
    color: #dc2626;
    background: #fef2f2;
    border: 1px solid #fecaca;
    border-radius: 8px;
    padding: 12px;
    margin-bottom: 20px;
    font-size: 14px;
  }
  
  .error-message i {
    flex-shrink: 0;
  }
  
  .modal-actions {
    display: flex;
    gap: 12px;
    justify-content: flex-end;
  }
  
  /* 响应式优化 */
  @media (max-width: 480px) {
    .upload-proof-content {
      padding: 16px 0;
    }
    
    .order-details {
      flex-direction: column;
      align-items: flex-start;
      gap: 4px;
    }
    
    .modal-actions {
      flex-direction: column-reverse;
    }
  }
  
  /* 深色模式 */
  @media (prefers-color-scheme: dark) {
    .order-details {
      border-bottom-color: #374151;
    }
    
    .error-message {
      background: #1f2937;
      border-color: #374151;
    }
  }
</style> 