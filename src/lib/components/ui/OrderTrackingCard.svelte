<script>
  import { createEventDispatcher } from 'svelte';
  import Badge from './Badge.svelte';
  import Button from './Button.svelte';
  import Progress from './Progress.svelte';
  
  export let orderId = '';
  export let orderNumber = '';
  export let status = 'processing'; // processing, shipped, delivering, delivered, cancelled
  export let items = [];
  export let totalAmount = 0;
  export let estimatedDelivery = '';
  export let currentLocation = '';
  export let courierInfo = {};
  export let trackingNumber = '';
  export let orderDate = '';
  export let deliveryAddress = '';
  export let paymentMethod = '';
  export let showDetails = false;
  
  const dispatch = createEventDispatcher();
  
  // 订单状态配置
  const statusConfig = {
    processing: {
      label: '处理中',
      color: 'blue',
      icon: '⚙️',
      progress: 25
    },
    shipped: {
      label: '已发货',
      color: 'orange',
      icon: '📦',
      progress: 50
    },
    delivering: {
      label: '配送中',
      color: 'purple',
      icon: '🚚',
      progress: 75
    },
    delivered: {
      label: '已送达',
      color: 'green',
      icon: '✅',
      progress: 100
    },
    cancelled: {
      label: '已取消',
      color: 'red',
      icon: '❌',
      progress: 0
    }
  };
  
  // 订单状态步骤
  const statusSteps = [
    { key: 'processing', label: '订单处理', icon: '⚙️' },
    { key: 'shipped', label: '商品发货', icon: '📦' },
    { key: 'delivering', label: '运输途中', icon: '🚚' },
    { key: 'delivered', label: '签收完成', icon: '✅' }
  ];
  
  $: currentStatus = statusConfig[status] || statusConfig.processing;
  $: currentStepIndex = statusSteps.findIndex(step => step.key === status);
  $: formattedAmount = new Intl.NumberFormat('zh-CN', {
    style: 'currency',
    currency: 'CNY'
  }).format(totalAmount);
  $: deliveryDate = estimatedDelivery ? new Date(estimatedDelivery) : null;
  $: orderDateFormatted = orderDate ? new Date(orderDate).toLocaleDateString('zh-CN') : '';
  
  function handleToggleDetails() {
    showDetails = !showDetails;
    dispatch('toggleDetails', { showDetails });
  }
  
  function handleViewOrder() {
    dispatch('viewOrder', { orderId, orderNumber });
  }
  
  function handleContactCourier() {
    dispatch('contactCourier', { courierInfo });
  }
  
  function handleTrackingUpdate() {
    dispatch('trackingUpdate', { orderId, trackingNumber });
  }
  
  function getStepStatus(stepIndex) {
    if (status === 'cancelled') return 'cancelled';
    if (stepIndex < currentStepIndex) return 'completed';
    if (stepIndex === currentStepIndex) return 'current';
    return 'pending';
  }
  
  function formatDeliveryTime() {
    if (!deliveryDate) return '';
    
    const now = new Date();
    const diffTime = deliveryDate.getTime() - now.getTime();
    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
    
    if (diffDays < 0) {
      return `预计${Math.abs(diffDays)}天前送达`;
    } else if (diffDays === 0) {
      return '今天预计送达';
    } else if (diffDays === 1) {
      return '明天预计送达';
    } else {
      return `预计${diffDays}天后送达`;
    }
  }
</script>

<div class="order-tracking-card">
  <!-- 卡片头部 -->
  <header class="card-header">
    <div class="order-info">
      <div class="order-number">
        订单号: {orderNumber}
      </div>
      <div class="order-date">
        下单时间: {orderDateFormatted}
      </div>
    </div>
    
    <div class="status-badge">
      <Badge color={currentStatus.color} size="sm">
        <span class="status-icon">{currentStatus.icon}</span>
        {currentStatus.label}
      </Badge>
    </div>
  </header>
  
  <!-- 进度条 -->
  {#if status !== 'cancelled'}
    <div class="progress-section">
      <Progress 
        value={currentStatus.progress} 
        color={currentStatus.color}
        showLabel={false}
        size="sm"
      />
      
      <!-- 步骤指示器 -->
      <div class="status-steps">
        {#each statusSteps as step, index}
          {@const stepStatus = getStepStatus(index)}
          <div class="status-step" class:completed={stepStatus === 'completed'} 
               class:current={stepStatus === 'current'} class:pending={stepStatus === 'pending'}>
            <div class="step-icon">
              {step.icon}
            </div>
            <div class="step-label">
              {step.label}
            </div>
          </div>
        {/each}
      </div>
    </div>
  {/if}
  
  <!-- 当前状态信息 -->
  <div class="current-status">
    {#if status === 'processing'}
      <div class="status-content">
        <h4 class="status-title">商家正在处理您的订单</h4>
        <p class="status-description">预计在24小时内为您发货</p>
      </div>
    {:else if status === 'shipped'}
      <div class="status-content">
        <h4 class="status-title">商品已发货</h4>
        {#if trackingNumber}
          <p class="status-description">
            快递单号: <span class="tracking-number">{trackingNumber}</span>
          </p>
        {/if}
        {#if estimatedDelivery}
          <p class="delivery-estimate">{formatDeliveryTime()}</p>
        {/if}
      </div>
    {:else if status === 'delivering'}
      <div class="status-content">
        <h4 class="status-title">商品配送中</h4>
        {#if currentLocation}
          <p class="status-description">
            当前位置: <span class="location">{currentLocation}</span>
          </p>
        {/if}
        {#if estimatedDelivery}
          <p class="delivery-estimate">{formatDeliveryTime()}</p>
        {/if}
      </div>
    {:else if status === 'delivered'}
      <div class="status-content">
        <h4 class="status-title">订单已送达</h4>
        <p class="status-description">感谢您的购买，欢迎下次光临！</p>
      </div>
    {:else if status === 'cancelled'}
      <div class="status-content">
        <h4 class="status-title">订单已取消</h4>
        <p class="status-description">如有疑问，请联系客服</p>
      </div>
    {/if}
  </div>
  
  <!-- 快递员信息 -->
  {#if courierInfo && courierInfo.name && status === 'delivering'}
    <div class="courier-info">
      <div class="courier-avatar">
        {#if courierInfo.avatar}
          <img src={courierInfo.avatar} alt={courierInfo.name} />
        {:else}
          <div class="avatar-placeholder">🚚</div>
        {/if}
      </div>
      
      <div class="courier-details">
        <div class="courier-name">{courierInfo.name}</div>
        <div class="courier-phone">{courierInfo.phone}</div>
      </div>
      
      <Button 
        variant="outline" 
        size="sm"
        on:click={handleContactCourier}
      >
        联系快递员
      </Button>
    </div>
  {/if}
  
  <!-- 商品信息简览 -->
  <div class="items-preview">
    <div class="items-header">
      <span class="items-count">共{items.length}件商品</span>
      <span class="total-amount">{formattedAmount}</span>
    </div>
    
    {#if items.length > 0}
      <div class="items-list" class:expanded={showDetails}>
        {#each items.slice(0, showDetails ? items.length : 2) as item}
          <div class="item-card">
            <div class="item-image">
              {#if item.image}
                <img src={item.image} alt={item.name} />
              {:else}
                <div class="image-placeholder">📦</div>
              {/if}
            </div>
            
            <div class="item-info">
              <div class="item-name">{item.name}</div>
              <div class="item-specs">
                {#if item.specs}
                  <span class="specs">{item.specs}</span>
                {/if}
                <span class="quantity">x{item.quantity}</span>
              </div>
            </div>
            
            <div class="item-price">
              ¥{item.price}
            </div>
          </div>
        {/each}
      </div>
      
      {#if items.length > 2}
        <button class="toggle-details" on:click={handleToggleDetails}>
          {#if showDetails}
            收起商品 ▲
          {:else}
            查看全部商品 ({items.length}) ▼
          {/if}
        </button>
      {/if}
    {/if}
  </div>
  
  <!-- 详细信息 -->
  {#if showDetails}
    <div class="order-details">
      <div class="detail-section">
        <h5 class="detail-title">配送信息</h5>
        <div class="detail-content">
          <div class="detail-item">
            <span class="detail-label">收货地址:</span>
            <span class="detail-value">{deliveryAddress}</span>
          </div>
          {#if trackingNumber}
            <div class="detail-item">
              <span class="detail-label">快递单号:</span>
              <span class="detail-value">{trackingNumber}</span>
            </div>
          {/if}
        </div>
      </div>
      
      <div class="detail-section">
        <h5 class="detail-title">支付信息</h5>
        <div class="detail-content">
          <div class="detail-item">
            <span class="detail-label">支付方式:</span>
            <span class="detail-value">{paymentMethod}</span>
          </div>
          <div class="detail-item">
            <span class="detail-label">订单金额:</span>
            <span class="detail-value">{formattedAmount}</span>
          </div>
        </div>
      </div>
    </div>
  {/if}
  
  <!-- 操作按钮 -->
  <div class="card-actions">
    <Button variant="outline" on:click={handleViewOrder}>
      查看订单详情
    </Button>
    
    {#if trackingNumber && status !== 'delivered' && status !== 'cancelled'}
      <Button variant="primary" on:click={handleTrackingUpdate}>
        刷新物流信息
      </Button>
    {/if}
  </div>
</div>

<style>
  .order-tracking-card {
    background: white;
    border-radius: 16px;
    box-shadow: 0 4px 20px rgba(0, 0, 0, 0.1);
    border: 1px solid #e5e7eb;
    overflow: hidden;
    transition: all 0.3s ease;
  }
  
  .order-tracking-card:hover {
    transform: translateY(-2px);
    box-shadow: 0 8px 30px rgba(0, 0, 0, 0.15);
  }
  
  /* 卡片头部 */
  .card-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    padding: 20px;
    border-bottom: 1px solid #f3f4f6;
  }
  
  .order-info {
    flex: 1;
  }
  
  .order-number {
    font-size: 16px;
    font-weight: 600;
    color: #111827;
    margin-bottom: 4px;
  }
  
  .order-date {
    font-size: 13px;
    color: #6b7280;
  }
  
  .status-badge {
    flex-shrink: 0;
  }
  
  .status-icon {
    margin-right: 4px;
  }
  
  /* 进度部分 */
  .progress-section {
    padding: 20px;
    border-bottom: 1px solid #f3f4f6;
  }
  
  .status-steps {
    display: flex;
    justify-content: space-between;
    margin-top: 16px;
    position: relative;
  }
  
  .status-step {
    display: flex;
    flex-direction: column;
    align-items: center;
    flex: 1;
    position: relative;
  }
  
  .step-icon {
    width: 32px;
    height: 32px;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 14px;
    margin-bottom: 8px;
    position: relative;
    z-index: 2;
    transition: all 0.3s ease;
  }
  
  .status-step.completed .step-icon {
    background: #10b981;
    color: white;
  }
  
  .status-step.current .step-icon {
    background: #3b82f6;
    color: white;
    animation: pulse 2s ease-in-out infinite;
  }
  
  .status-step.pending .step-icon {
    background: #e5e7eb;
    color: #9ca3af;
  }
  
  @keyframes pulse {
    0%, 100% { transform: scale(1); }
    50% { transform: scale(1.1); }
  }
  
  .step-label {
    font-size: 11px;
    color: #6b7280;
    text-align: center;
    font-weight: 500;
  }
  
  .status-step.completed .step-label,
  .status-step.current .step-label {
    color: #111827;
    font-weight: 600;
  }
  
  /* 当前状态 */
  .current-status {
    padding: 20px;
    border-bottom: 1px solid #f3f4f6;
  }
  
  .status-title {
    font-size: 16px;
    font-weight: 600;
    color: #111827;
    margin: 0 0 8px 0;
  }
  
  .status-description {
    font-size: 14px;
    color: #6b7280;
    margin: 0;
    line-height: 1.5;
  }
  
  .tracking-number {
    font-family: monospace;
    background: #f3f4f6;
    padding: 2px 6px;
    border-radius: 4px;
    font-weight: 600;
  }
  
  .location {
    color: #3b82f6;
    font-weight: 600;
  }
  
  .delivery-estimate {
    font-size: 14px;
    color: #059669;
    font-weight: 600;
    margin: 4px 0 0 0;
  }
  
  /* 快递员信息 */
  .courier-info {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 16px 20px;
    background: #f8fafc;
    border-bottom: 1px solid #e5e7eb;
  }
  
  .courier-avatar {
    width: 40px;
    height: 40px;
    border-radius: 50%;
    overflow: hidden;
    flex-shrink: 0;
  }
  
  .courier-avatar img {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }
  
  .avatar-placeholder {
    width: 100%;
    height: 100%;
    background: #e5e7eb;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 18px;
  }
  
  .courier-details {
    flex: 1;
  }
  
  .courier-name {
    font-size: 14px;
    font-weight: 600;
    color: #111827;
  }
  
  .courier-phone {
    font-size: 13px;
    color: #6b7280;
    font-family: monospace;
  }
  
  /* 商品预览 */
  .items-preview {
    padding: 20px;
    border-bottom: 1px solid #f3f4f6;
  }
  
  .items-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 16px;
  }
  
  .items-count {
    font-size: 14px;
    color: #6b7280;
  }
  
  .total-amount {
    font-size: 16px;
    font-weight: 700;
    color: #ef4444;
  }
  
  .items-list {
    display: flex;
    flex-direction: column;
    gap: 12px;
    max-height: 120px;
    overflow: hidden;
    transition: max-height 0.3s ease;
  }
  
  .items-list.expanded {
    max-height: none;
  }
  
  .item-card {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 12px;
    background: #f9fafb;
    border-radius: 8px;
  }
  
  .item-image {
    width: 48px;
    height: 48px;
    border-radius: 6px;
    overflow: hidden;
    flex-shrink: 0;
  }
  
  .item-image img {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }
  
  .image-placeholder {
    width: 100%;
    height: 100%;
    background: #e5e7eb;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 20px;
  }
  
  .item-info {
    flex: 1;
    min-width: 0;
  }
  
  .item-name {
    font-size: 14px;
    font-weight: 500;
    color: #111827;
    margin-bottom: 4px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  
  .item-specs {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 12px;
    color: #6b7280;
  }
  
  .specs {
    background: #e5e7eb;
    padding: 2px 6px;
    border-radius: 4px;
  }
  
  .quantity {
    font-weight: 600;
  }
  
  .item-price {
    font-size: 14px;
    font-weight: 600;
    color: #ef4444;
    flex-shrink: 0;
  }
  
  .toggle-details {
    width: 100%;
    background: none;
    border: none;
    color: #3b82f6;
    font-size: 13px;
    font-weight: 500;
    padding: 8px;
    margin-top: 8px;
    cursor: pointer;
    border-radius: 6px;
    transition: background 0.2s ease;
  }
  
  .toggle-details:hover {
    background: #f0f9ff;
  }
  
  /* 详细信息 */
  .order-details {
    padding: 20px;
    background: #f8fafc;
    border-bottom: 1px solid #e5e7eb;
  }
  
  .detail-section {
    margin-bottom: 16px;
  }
  
  .detail-section:last-child {
    margin-bottom: 0;
  }
  
  .detail-title {
    font-size: 14px;
    font-weight: 600;
    color: #111827;
    margin: 0 0 8px 0;
  }
  
  .detail-content {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }
  
  .detail-item {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    gap: 12px;
  }
  
  .detail-label {
    font-size: 13px;
    color: #6b7280;
    flex-shrink: 0;
  }
  
  .detail-value {
    font-size: 13px;
    color: #111827;
    text-align: right;
    line-height: 1.4;
  }
  
  /* 操作按钮 */
  .card-actions {
    display: flex;
    gap: 12px;
    padding: 20px;
  }
  
  .card-actions > :global(button) {
    flex: 1;
  }
  
  /* 移动端适配 */
  @media (max-width: 640px) {
    .card-header {
      padding: 16px;
    }
    
    .order-number {
      font-size: 14px;
    }
    
    .progress-section {
      padding: 16px;
    }
    
    .status-steps {
      margin-top: 12px;
    }
    
    .step-icon {
      width: 28px;
      height: 28px;
      font-size: 12px;
    }
    
    .step-label {
      font-size: 10px;
    }
    
    .current-status {
      padding: 16px;
    }
    
    .status-title {
      font-size: 14px;
    }
    
    .status-description {
      font-size: 13px;
    }
    
    .courier-info {
      padding: 12px 16px;
    }
    
    .courier-avatar {
      width: 36px;
      height: 36px;
    }
    
    .items-preview {
      padding: 16px;
    }
    
    .items-header {
      margin-bottom: 12px;
    }
    
    .item-card {
      padding: 10px;
    }
    
    .item-image {
      width: 40px;
      height: 40px;
    }
    
    .order-details {
      padding: 16px;
    }
    
    .card-actions {
      padding: 16px;
      flex-direction: column;
    }
  }
</style> 