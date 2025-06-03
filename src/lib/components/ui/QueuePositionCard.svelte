<script>
  import { onMount, onDestroy } from 'svelte';
  import { createEventDispatcher } from 'svelte';
  import Progress from './Progress.svelte';
  import Button from './Button.svelte';
  
  export let position = 1;
  export let totalQueue = 10;
  export let estimatedWaitTime = '15分钟';
  export let masterName = '慧眼大师';
  export let masterAvatar = '';
  export let orderId = '';
  export let canCancel = true;
  export let showProgress = true;
  
  const dispatch = createEventDispatcher();
  
  let timeLeft = estimatedWaitTime;
  let progressValue = 0;
  let isRefreshing = false;
  let refreshInterval;
  
  // 模拟实时更新
  onMount(() => {
    updateProgress();
    // 每30秒更新一次队列状态
    refreshInterval = setInterval(() => {
      handleRefresh();
    }, 30000);
  });
  
  onDestroy(() => {
    if (refreshInterval) {
      clearInterval(refreshInterval);
    }
  });
  
  function updateProgress() {
    if (totalQueue > 0) {
      progressValue = ((totalQueue - position) / totalQueue) * 100;
    }
  }
  
  $: progressValue = totalQueue > 0 ? ((totalQueue - position) / totalQueue) * 100 : 0;
  
  async function handleRefresh() {
    isRefreshing = true;
    
    try {
      // 模拟刷新延迟
      await new Promise(resolve => setTimeout(resolve, 800));
      
      dispatch('refresh', { 
        orderId,
        position,
        totalQueue
      });
      
    } catch (error) {
      console.error('刷新队列状态失败:', error);
    } finally {
      isRefreshing = false;
    }
  }
  
  function handleCancel() {
    dispatch('cancel', { orderId });
  }
  
  function handleContact() {
    dispatch('contact', { masterName, orderId });
  }
  
  function getPositionText() {
    if (position === 1) return '下一位就是您';
    if (position <= 3) return `还有 ${position - 1} 位`;
    return `排队第 ${position} 位`;
  }
  
  function getStatusColor() {
    if (position === 1) return 'green';
    if (position <= 3) return 'yellow';
    return 'blue';
  }
  
  function getWaitTimeColor() {
    const timeMatch = estimatedWaitTime.match(/(\d+)/);
    if (!timeMatch) return 'blue';
    
    const minutes = parseInt(timeMatch[1]);
    if (minutes <= 5) return 'green';
    if (minutes <= 15) return 'yellow';
    return 'blue';
  }
</script>

<div class="queue-card">
  <!-- 头部信息 -->
  <header class="card-header">
    <div class="master-info">
      <div class="master-avatar">
        {#if masterAvatar}
          <img src={masterAvatar} alt={masterName} />
        {:else}
          <div class="avatar-placeholder">🔮</div>
        {/if}
        <div class="online-indicator"></div>
      </div>
      <div class="master-details">
        <h3 class="master-name">{masterName}</h3>
        <p class="service-type">正在为您算命</p>
      </div>
    </div>
    
    <button 
      class="refresh-btn"
      class:refreshing={isRefreshing}
      on:click={handleRefresh}
      disabled={isRefreshing}
    >
      <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
        <path 
          d="M1 4v6h6M23 20v-6h-6"
          stroke="currentColor" 
          stroke-width="2" 
          stroke-linecap="round" 
          stroke-linejoin="round"
        />
        <path 
          d="M20.49 9A9 9 0 0 0 5.64 5.64L1 10m22 4l-4.64 4.36A9 9 0 0 1 3.51 15"
          stroke="currentColor" 
          stroke-width="2" 
          stroke-linecap="round" 
          stroke-linejoin="round"
        />
      </svg>
    </button>
  </header>
  
  <!-- 排队状态 -->
  <div class="queue-status">
    <div class="position-display">
      <div class="position-icon" data-color={getStatusColor()}>
        {#if position === 1}
          🎯
        {:else if position <= 3}
          ⚡
        {:else}
          📍
        {/if}
      </div>
      <div class="position-info">
        <h2 class="position-text">{getPositionText()}</h2>
        <p class="queue-details">共 {totalQueue} 人排队</p>
      </div>
    </div>
    
    <div class="time-estimate">
      <div class="time-icon" data-color={getWaitTimeColor()}>⏰</div>
      <div class="time-info">
        <span class="time-label">预计等待</span>
        <span class="time-value">{timeLeft}</span>
      </div>
    </div>
  </div>
  
  <!-- 进度条 -->
  {#if showProgress}
    <div class="progress-section">
      <div class="progress-header">
        <span class="progress-label">队列进度</span>
        <span class="progress-detail">{totalQueue - position}/{totalQueue}</span>
      </div>
      <Progress 
        value={progressValue} 
        size="md"
        variant={getStatusColor()}
        showPercentage={false}
      />
    </div>
  {/if}
  
  <!-- 订单信息 -->
  {#if orderId}
    <div class="order-section">
      <div class="order-item">
        <span class="order-label">订单号</span>
        <span class="order-value">{orderId}</span>
      </div>
    </div>
  {/if}
  
  <!-- 温馨提示 -->
  <div class="notice-section">
    <div class="notice-icon">💡</div>
    <div class="notice-content">
      <p class="notice-text">
        {#if position === 1}
          请保持关注，大师即将开始为您服务
        {:else if position <= 3}
          您的排队位置较前，请耐心等候
        {:else}
          可暂时离开，我们会提前通知您
        {/if}
      </p>
    </div>
  </div>
  
  <!-- 操作按钮 -->
  <div class="actions">
    <Button
      variant="outline"
      size="sm"
      on:click={handleContact}
    >
      联系大师
    </Button>
    
    {#if canCancel}
      <Button
        variant="danger"
        size="sm"
        on:click={handleCancel}
      >
        取消排队
      </Button>
    {/if}
  </div>
</div>

<style>
  .queue-card {
    background: white;
    border-radius: 20px;
    padding: 24px;
    box-shadow: 0 4px 20px rgba(0, 0, 0, 0.08);
    border: 1px solid rgba(0, 0, 0, 0.04);
    position: relative;
    overflow: hidden;
  }
  
  .queue-card::before {
    content: '';
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    height: 4px;
    background: linear-gradient(90deg, #667eea 0%, #764ba2 100%);
  }
  
  /* 头部信息 */
  .card-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 24px;
  }
  
  .master-info {
    display: flex;
    align-items: center;
    gap: 12px;
  }
  
  .master-avatar {
    position: relative;
    width: 48px;
    height: 48px;
    border-radius: 50%;
    overflow: hidden;
  }
  
  .master-avatar img {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }
  
  .avatar-placeholder {
    width: 100%;
    height: 100%;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 20px;
  }
  
  .online-indicator {
    position: absolute;
    bottom: 2px;
    right: 2px;
    width: 12px;
    height: 12px;
    background: #10b981;
    border: 2px solid white;
    border-radius: 50%;
  }
  
  .master-details {
    flex: 1;
  }
  
  .master-name {
    font-size: 16px;
    font-weight: 600;
    color: #111827;
    margin: 0 0 4px 0;
  }
  
  .service-type {
    font-size: 13px;
    color: #6b7280;
    margin: 0;
  }
  
  .refresh-btn {
    background: none;
    border: none;
    padding: 8px;
    cursor: pointer;
    color: #6b7280;
    border-radius: 8px;
    transition: all 0.2s ease;
  }
  
  .refresh-btn:hover:not(:disabled) {
    color: #111827;
    background: #f3f4f6;
  }
  
  .refresh-btn.refreshing {
    animation: spin 1s linear infinite;
  }
  
  @keyframes spin {
    from { transform: rotate(0deg); }
    to { transform: rotate(360deg); }
  }
  
  /* 排队状态 */
  .queue-status {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 20px;
    margin-bottom: 24px;
    padding: 20px;
    background: #f8fafc;
    border-radius: 16px;
  }
  
  .position-display,
  .time-estimate {
    display: flex;
    align-items: center;
    gap: 12px;
  }
  
  .position-icon,
  .time-icon {
    width: 40px;
    height: 40px;
    border-radius: 12px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 18px;
  }
  
  .position-icon[data-color="green"],
  .time-icon[data-color="green"] {
    background: rgba(16, 185, 129, 0.1);
  }
  
  .position-icon[data-color="yellow"],
  .time-icon[data-color="yellow"] {
    background: rgba(245, 158, 11, 0.1);
  }
  
  .position-icon[data-color="blue"],
  .time-icon[data-color="blue"] {
    background: rgba(59, 130, 246, 0.1);
  }
  
  .position-info,
  .time-info {
    flex: 1;
  }
  
  .position-text {
    font-size: 16px;
    font-weight: 600;
    color: #111827;
    margin: 0 0 4px 0;
  }
  
  .queue-details {
    font-size: 13px;
    color: #6b7280;
    margin: 0;
  }
  
  .time-info {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }
  
  .time-label {
    font-size: 13px;
    color: #6b7280;
  }
  
  .time-value {
    font-size: 16px;
    font-weight: 600;
    color: #111827;
  }
  
  /* 进度条部分 */
  .progress-section {
    margin-bottom: 20px;
  }
  
  .progress-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 8px;
  }
  
  .progress-label {
    font-size: 14px;
    color: #4b5563;
    font-weight: 500;
  }
  
  .progress-detail {
    font-size: 13px;
    color: #6b7280;
  }
  
  /* 订单信息 */
  .order-section {
    margin-bottom: 20px;
    padding: 12px 16px;
    background: #fafafa;
    border-radius: 12px;
    border: 1px solid #e5e7eb;
  }
  
  .order-item {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }
  
  .order-label {
    font-size: 13px;
    color: #6b7280;
  }
  
  .order-value {
    font-size: 13px;
    color: #111827;
    font-weight: 500;
    font-family: monospace;
  }
  
  /* 温馨提示 */
  .notice-section {
    display: flex;
    align-items: flex-start;
    gap: 10px;
    margin-bottom: 20px;
    padding: 12px 16px;
    background: #fffbeb;
    border-radius: 12px;
    border: 1px solid #fde68a;
  }
  
  .notice-icon {
    font-size: 16px;
  }
  
  .notice-content {
    flex: 1;
  }
  
  .notice-text {
    font-size: 13px;
    color: #92400e;
    margin: 0;
    line-height: 1.4;
  }
  
  /* 操作按钮 */
  .actions {
    display: flex;
    gap: 12px;
  }
  
  .actions > :global(button) {
    flex: 1;
  }
  
  /* 移动端适配 */
  @media (max-width: 640px) {
    .queue-card {
      padding: 20px;
      border-radius: 16px;
    }
    
    .card-header {
      margin-bottom: 20px;
    }
    
    .master-avatar {
      width: 44px;
      height: 44px;
    }
    
    .queue-status {
      grid-template-columns: 1fr;
      gap: 16px;
      padding: 16px;
      margin-bottom: 20px;
    }
    
    .position-icon,
    .time-icon {
      width: 36px;
      height: 36px;
      font-size: 16px;
    }
    
    .position-text,
    .time-value {
      font-size: 15px;
    }
    
    .actions {
      flex-direction: column;
      gap: 10px;
    }
  }
</style> 