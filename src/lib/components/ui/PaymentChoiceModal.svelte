<script>
  import { createEventDispatcher } from 'svelte';
  import Button from './Button.svelte';
  import Badge from './Badge.svelte';
  
  export let isOpen = false;
  export let amount = 0;
  export let title = '完成支付';
  export let description = '';
  export let orderId = '';
  
  const dispatch = createEventDispatcher();
  
  let selectedMethod = '';
  let isProcessing = false;
  
  // 支付方式配置
  const paymentMethods = [
    {
      id: 'wechat',
      name: '微信支付',
      icon: '💚',
      description: '使用微信扫码支付',
      recommended: true,
      available: true
    },
    {
      id: 'alipay',
      name: '支付宝',
      icon: '🔵',
      description: '使用支付宝扫码支付',
      recommended: false,
      available: true
    },
    {
      id: 'unionpay',
      name: '银联支付',
      icon: '🏦',
      description: '银行卡快捷支付',
      recommended: false,
      available: true
    },
    {
      id: 'balance',
      name: '账户余额',
      icon: '💰',
      description: '使用账户余额支付',
      balance: 288.50,
      recommended: false,
      available: true
    }
  ];
  
  $: selectedMethodData = paymentMethods.find(m => m.id === selectedMethod);
  $: canPay = selectedMethod && (!selectedMethodData?.balance || selectedMethodData.balance >= amount);
  
  function handleMethodSelect(methodId) {
    selectedMethod = methodId;
  }
  
  async function handlePay() {
    if (!selectedMethod || isProcessing) return;
    
    isProcessing = true;
    
    try {
      // 模拟支付处理
      await new Promise(resolve => setTimeout(resolve, 1500));
      
      dispatch('pay', {
        method: selectedMethod,
        amount,
        orderId,
        success: true
      });
      
      handleClose();
      
    } catch (error) {
      dispatch('pay', {
        method: selectedMethod,
        amount,
        orderId,
        success: false,
        error: error.message
      });
    } finally {
      isProcessing = false;
    }
  }
  
  function handleClose() {
    if (!isProcessing) {
      selectedMethod = '';
      dispatch('close');
    }
  }
  
  function formatAmount(amount) {
    return `¥${amount.toFixed(2)}`;
  }
</script>

{#if isOpen}
  <div class="modal-overlay" on:click={handleClose}>
    <div class="modal-content" on:click|stopPropagation>
      <!-- 头部 -->
      <header class="modal-header">
        <div class="header-content">
          <h2 class="modal-title">{title}</h2>
          {#if description}
            <p class="modal-description">{description}</p>
          {/if}
          <div class="amount-display">
            <span class="amount-label">支付金额</span>
            <span class="amount-value">{formatAmount(amount)}</span>
          </div>
        </div>
        <button class="close-btn" on:click={handleClose} disabled={isProcessing}>
          <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
            <path d="M18 6L6 18M6 6L18 18" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
          </svg>
        </button>
      </header>
      
      <!-- 支付方式列表 -->
      <div class="payment-methods">
        <h3 class="section-title">选择支付方式</h3>
        
        <div class="methods-list">
          {#each paymentMethods as method}
            <button 
              class="payment-method"
              class:selected={selectedMethod === method.id}
              class:disabled={!method.available || (method.balance && method.balance < amount)}
              on:click={() => handleMethodSelect(method.id)}
              disabled={!method.available || (method.balance && method.balance < amount)}
            >
              <div class="method-icon">
                {method.icon}
              </div>
              
              <div class="method-info">
                <div class="method-header">
                  <span class="method-name">{method.name}</span>
                  {#if method.recommended}
                    <Badge variant="blue" size="xs">推荐</Badge>
                  {/if}
                  {#if method.balance && method.balance < amount}
                    <Badge variant="red" size="xs">余额不足</Badge>
                  {/if}
                </div>
                <p class="method-description">{method.description}</p>
                {#if method.balance !== undefined}
                  <p class="balance-info">
                    余额: {formatAmount(method.balance)}
                  </p>
                {/if}
              </div>
              
              <div class="method-selector">
                <div class="radio-button" class:checked={selectedMethod === method.id}>
                  {#if selectedMethod === method.id}
                    <div class="radio-dot"></div>
                  {/if}
                </div>
              </div>
            </button>
          {/each}
        </div>
      </div>
      
      <!-- 订单信息 -->
      {#if orderId}
        <div class="order-info">
          <div class="info-row">
            <span class="info-label">订单号</span>
            <span class="info-value">{orderId}</span>
          </div>
        </div>
      {/if}
      
      <!-- 安全提示 -->
      <div class="security-notice">
        <div class="notice-icon">🔒</div>
        <div class="notice-content">
          <p class="notice-title">安全保障</p>
          <p class="notice-text">您的支付信息由银行级安全系统保护</p>
        </div>
      </div>
      
      <!-- 操作按钮 -->
      <div class="modal-actions">
        <Button
          variant="outline"
          on:click={handleClose}
          disabled={isProcessing}
          fullWidth
        >
          取消
        </Button>
        
        <Button
          variant="primary"
          on:click={handlePay}
          disabled={!canPay || isProcessing}
          loading={isProcessing}
          fullWidth
        >
          {#if isProcessing}
            处理中...
          {:else if selectedMethodData?.balance !== undefined && selectedMethodData.balance < amount}
            余额不足
          {:else}
            确认支付 {formatAmount(amount)}
          {/if}
        </Button>
      </div>
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
    background: rgba(0, 0, 0, 0.5);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 1000;
    padding: 20px;
  }

  .modal-content {
    background: white;
    border-radius: 20px;
    width: 100%;
    max-width: 420px;
    max-height: 90vh;
    overflow-y: auto;
    box-shadow: 0 20px 40px rgba(0, 0, 0, 0.15);
  }

  /* 头部 */
  .modal-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    padding: 24px 24px 20px 24px;
    border-bottom: 1px solid #f3f4f6;
  }

  .header-content {
    flex: 1;
  }

  .modal-title {
    font-size: 20px;
    font-weight: 700;
    color: #111827;
    margin: 0 0 8px 0;
  }

  .modal-description {
    font-size: 14px;
    color: #6b7280;
    margin: 0 0 16px 0;
  }

  .amount-display {
    display: flex;
    align-items: center;
    gap: 12px;
  }

  .amount-label {
    font-size: 14px;
    color: #6b7280;
  }

  .amount-value {
    font-size: 24px;
    font-weight: 700;
    color: #dc2626;
  }

  .close-btn {
    background: none;
    border: none;
    padding: 8px;
    cursor: pointer;
    color: #6b7280;
    border-radius: 8px;
    transition: all 0.2s ease;
  }

  .close-btn:hover:not(:disabled) {
    color: #111827;
    background: #f3f4f6;
  }

  .close-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  /* 支付方式 */
  .payment-methods {
    padding: 24px;
  }

  .section-title {
    font-size: 16px;
    font-weight: 600;
    color: #111827;
    margin: 0 0 16px 0;
  }

  .methods-list {
    display: flex;
    flex-direction: column;
    gap: 12px;
  }

  .payment-method {
    display: flex;
    align-items: center;
    gap: 16px;
    padding: 16px;
    border: 2px solid #e5e7eb;
    border-radius: 12px;
    background: white;
    cursor: pointer;
    transition: all 0.2s ease;
    text-align: left;
    width: 100%;
  }

  .payment-method:hover:not(:disabled) {
    border-color: #667eea;
    background: #f8faff;
  }

  .payment-method.selected {
    border-color: #667eea;
    background: #f8faff;
    box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
  }

  .payment-method.disabled {
    opacity: 0.6;
    cursor: not-allowed;
    background: #f9fafb;
  }

  .method-icon {
    font-size: 24px;
    width: 40px;
    height: 40px;
    display: flex;
    align-items: center;
    justify-content: center;
    background: #f3f4f6;
    border-radius: 10px;
  }

  .method-info {
    flex: 1;
  }

  .method-header {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-bottom: 4px;
  }

  .method-name {
    font-size: 16px;
    font-weight: 600;
    color: #111827;
  }

  .method-description {
    font-size: 13px;
    color: #6b7280;
    margin: 0;
  }

  .balance-info {
    font-size: 13px;
    color: #059669;
    margin: 4px 0 0 0;
    font-weight: 500;
  }

  .method-selector {
    margin-left: auto;
  }

  .radio-button {
    width: 20px;
    height: 20px;
    border: 2px solid #d1d5db;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: all 0.2s ease;
  }

  .radio-button.checked {
    border-color: #667eea;
    background: #667eea;
  }

  .radio-dot {
    width: 8px;
    height: 8px;
    background: white;
    border-radius: 50%;
  }

  /* 订单信息 */
  .order-info {
    padding: 0 24px 16px 24px;
    border-bottom: 1px solid #f3f4f6;
  }

  .info-row {
    display: flex;
    justify-content: space-between;
    margin-bottom: 8px;
  }

  .info-row:last-child {
    margin-bottom: 0;
  }

  .info-label {
    font-size: 14px;
    color: #6b7280;
  }

  .info-value {
    font-size: 14px;
    color: #111827;
    font-weight: 500;
  }

  /* 安全提示 */
  .security-notice {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 16px 24px;
    background: #f0fdf4;
    margin: 0 24px;
    border-radius: 12px;
    border: 1px solid #bbf7d0;
  }

  .notice-icon {
    font-size: 20px;
  }

  .notice-content {
    flex: 1;
  }

  .notice-title {
    font-size: 14px;
    font-weight: 600;
    color: #166534;
    margin: 0 0 2px 0;
  }

  .notice-text {
    font-size: 12px;
    color: #16a34a;
    margin: 0;
  }

  /* 操作按钮 */
  .modal-actions {
    display: flex;
    gap: 12px;
    padding: 24px;
  }

  /* 移动端适配 */
  @media (max-width: 640px) {
    .modal-overlay {
      padding: 0;
    }

    .modal-content {
      border-radius: 20px 20px 0 0;
      height: auto;
      max-height: 90vh;
      margin-top: auto;
    }

    .modal-header {
      padding: 20px 20px 16px 20px;
    }

    .modal-title {
      font-size: 18px;
    }

    .amount-value {
      font-size: 20px;
    }

    .payment-methods {
      padding: 20px;
    }

    .payment-method {
      padding: 14px;
    }

    .method-icon {
      width: 36px;
      height: 36px;
      font-size: 20px;
    }

    .security-notice {
      margin: 0 20px;
      padding: 12px 16px;
    }

    .modal-actions {
      padding: 20px;
      flex-direction: column;
    }
  }
</style> 