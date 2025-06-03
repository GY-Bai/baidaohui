<script>
  import { createEventDispatcher, onMount } from 'svelte';
  import Badge from './Badge.svelte';
  import Button from './Button.svelte';
  import Card from './Card.svelte';
  
  export let masterData = {};
  export let statistics = {};
  export let recentOrders = [];
  export let recentReviews = [];
  export let earnings = {};
  export let showCharts = true;
  export let refreshInterval = 30000; // 30秒自动刷新
  
  const dispatch = createEventDispatcher();
  
  let refreshTimer;
  let isLoading = false;
  let selectedTimeRange = '7d'; // 7d, 30d, 90d
  let chartData = [];
  
  // 时间范围选项
  const timeRangeOptions = [
    { value: '7d', label: '近7天' },
    { value: '30d', label: '近30天' },
    { value: '90d', label: '近90天' }
  ];
  
  // 计算属性
  $: totalOrders = statistics.totalOrders || 0;
  $: completedOrders = statistics.completedOrders || 0;
  $: pendingOrders = statistics.pendingOrders || 0;
  $: totalEarnings = earnings.total || 0;
  $: monthlyEarnings = earnings.monthly || 0;
  $: averageRating = statistics.averageRating || 0;
  $: completionRate = totalOrders > 0 ? ((completedOrders / totalOrders) * 100).toFixed(1) : 0;
  
  // 格式化金额
  function formatCurrency(amount) {
    return new Intl.NumberFormat('zh-CN', {
      style: 'currency',
      currency: 'CNY'
    }).format(amount);
  }
  
  // 格式化数字
  function formatNumber(num) {
    if (num >= 1000000) {
      return (num / 1000000).toFixed(1) + 'M';
    } else if (num >= 1000) {
      return (num / 1000).toFixed(1) + 'K';
    }
    return num.toString();
  }
  
  // 格式化日期
  function formatDate(dateStr) {
    const date = new Date(dateStr);
    return date.toLocaleDateString('zh-CN', {
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  }
  
  // 获取状态颜色
  function getStatusColor(status) {
    const colors = {
      pending: 'orange',
      processing: 'blue',
      completed: 'green',
      cancelled: 'red'
    };
    return colors[status] || 'gray';
  }
  
  // 获取星级评分
  function getStarRating(rating) {
    const stars = '★'.repeat(Math.floor(rating)) + '☆'.repeat(5 - Math.floor(rating));
    return stars;
  }
  
  // 刷新数据
  async function refreshData() {
    if (isLoading) return;
    
    isLoading = true;
    try {
      dispatch('refresh', { timeRange: selectedTimeRange });
      
      // 模拟API调用延迟
      await new Promise(resolve => setTimeout(resolve, 1000));
      
    } catch (error) {
      console.error('刷新数据失败:', error);
      dispatch('error', { error });
    } finally {
      isLoading = false;
    }
  }
  
  // 切换时间范围
  function handleTimeRangeChange(range) {
    selectedTimeRange = range;
    refreshData();
  }
  
  // 事件处理
  function handleViewOrder(orderId) {
    dispatch('viewOrder', { orderId });
  }
  
  function handleViewReview(reviewId) {
    dispatch('viewReview', { reviewId });
  }
  
  function handleQuickAction(action) {
    dispatch('quickAction', { action });
  }
  
  function handleWithdraw() {
    dispatch('withdraw', { amount: totalEarnings });
  }
  
  function handleSettings() {
    dispatch('settings');
  }
  
  function handleViewAll(type) {
    dispatch('viewAll', { type });
  }
  
  // 自动刷新
  function startAutoRefresh() {
    if (refreshTimer) clearInterval(refreshTimer);
    refreshTimer = setInterval(refreshData, refreshInterval);
  }
  
  function stopAutoRefresh() {
    if (refreshTimer) {
      clearInterval(refreshTimer);
      refreshTimer = null;
    }
  }
  
  onMount(() => {
    startAutoRefresh();
    
    return () => {
      stopAutoRefresh();
    };
  });
</script>

<div class="master-dashboard">
  <!-- 仪表板头部 -->
  <header class="dashboard-header">
    <div class="header-info">
      <h1 class="dashboard-title">欢迎回来，{masterData.name || '大师'}！</h1>
      <p class="dashboard-subtitle">今天是你做算命的第{masterData.daysSinceJoined || 0}天</p>
    </div>
    
    <div class="header-actions">
      <!-- 时间范围选择 -->
      <div class="time-range-selector">
        {#each timeRangeOptions as option}
          <button
            class="time-range-btn"
            class:active={selectedTimeRange === option.value}
            on:click={() => handleTimeRangeChange(option.value)}
          >
            {option.label}
          </button>
        {/each}
      </div>
      
      <!-- 刷新按钮 -->
      <Button
        variant="outline"
        size="sm"
        on:click={refreshData}
        disabled={isLoading}
      >
        {#if isLoading}
          🔄 刷新中...
        {:else}
          🔄 刷新
        {/if}
      </Button>
    </div>
  </header>
  
  <!-- 核心统计卡片 -->
  <div class="stats-grid">
    <div class="stat-card primary">
      <div class="stat-icon">💰</div>
      <div class="stat-content">
        <div class="stat-value">{formatCurrency(totalEarnings)}</div>
        <div class="stat-label">总收益</div>
        <div class="stat-change positive">
          +{formatCurrency(monthlyEarnings)} 本月
        </div>
      </div>
    </div>
    
    <div class="stat-card success">
      <div class="stat-icon">📋</div>
      <div class="stat-content">
        <div class="stat-value">{formatNumber(totalOrders)}</div>
        <div class="stat-label">总订单</div>
        <div class="stat-change neutral">
          完成率 {completionRate}%
        </div>
      </div>
    </div>
    
    <div class="stat-card warning">
      <div class="stat-icon">⭐</div>
      <div class="stat-content">
        <div class="stat-value">{averageRating.toFixed(1)}</div>
        <div class="stat-label">平均评分</div>
        <div class="stat-change positive">
          {getStarRating(averageRating)}
        </div>
      </div>
    </div>
    
    <div class="stat-card info">
      <div class="stat-icon">⏳</div>
      <div class="stat-content">
        <div class="stat-value">{formatNumber(pendingOrders)}</div>
        <div class="stat-label">待处理订单</div>
        <div class="stat-change neutral">
          需要关注
        </div>
      </div>
    </div>
  </div>
  
  <!-- 快捷操作 -->
  <div class="quick-actions">
    <h3 class="section-title">快捷操作</h3>
    <div class="actions-grid">
      <button class="action-btn" on:click={() => handleQuickAction('newOrder')}>
        <div class="action-icon">📝</div>
        <span class="action-text">新订单</span>
      </button>
      
      <button class="action-btn" on:click={() => handleQuickAction('schedule')}>
        <div class="action-icon">📅</div>
        <span class="action-text">预约管理</span>
      </button>
      
      <button class="action-btn" on:click={() => handleQuickAction('clients')}>
        <div class="action-icon">👥</div>
        <span class="action-text">客户管理</span>
      </button>
      
      <button class="action-btn" on:click={handleWithdraw}>
        <div class="action-icon">💳</div>
        <span class="action-text">提现</span>
      </button>
      
      <button class="action-btn" on:click={() => handleQuickAction('promotion')}>
        <div class="action-icon">📢</div>
        <span class="action-text">推广</span>
      </button>
      
      <button class="action-btn" on:click={handleSettings}>
        <div class="action-icon">⚙️</div>
        <span class="action-text">设置</span>
      </button>
    </div>
  </div>
  
  <!-- 内容区域 -->
  <div class="dashboard-content">
    <!-- 最近订单 -->
    <div class="content-section">
      <div class="section-header">
        <h3 class="section-title">最近订单</h3>
        <Button variant="outline" size="sm" on:click={() => handleViewAll('orders')}>
          查看全部
        </Button>
      </div>
      
      <div class="orders-list">
        {#if recentOrders.length === 0}
          <div class="empty-state">
            <div class="empty-icon">📋</div>
            <div class="empty-text">暂无最近订单</div>
          </div>
        {:else}
          {#each recentOrders.slice(0, 5) as order}
            <div class="order-item" on:click={() => handleViewOrder(order.id)} role="button" tabindex="0">
              <div class="order-info">
                <div class="order-id">#{order.orderNumber}</div>
                <div class="order-client">{order.clientName}</div>
                <div class="order-service">{order.serviceName}</div>
              </div>
              
              <div class="order-meta">
                <Badge color={getStatusColor(order.status)} size="xs">
                  {order.statusText}
                </Badge>
                <div class="order-amount">{formatCurrency(order.amount)}</div>
                <div class="order-date">{formatDate(order.createdAt)}</div>
              </div>
            </div>
          {/each}
        {/if}
      </div>
    </div>
    
    <!-- 最近评价 -->
    <div class="content-section">
      <div class="section-header">
        <h3 class="section-title">最近评价</h3>
        <Button variant="outline" size="sm" on:click={() => handleViewAll('reviews')}>
          查看全部
        </Button>
      </div>
      
      <div class="reviews-list">
        {#if recentReviews.length === 0}
          <div class="empty-state">
            <div class="empty-icon">⭐</div>
            <div class="empty-text">暂无最近评价</div>
          </div>
        {:else}
          {#each recentReviews.slice(0, 3) as review}
            <div class="review-item" on:click={() => handleViewReview(review.id)} role="button" tabindex="0">
              <div class="review-header">
                <div class="reviewer-info">
                  <div class="reviewer-name">{review.clientName}</div>
                  <div class="review-rating">{getStarRating(review.rating)}</div>
                </div>
                <div class="review-date">{formatDate(review.createdAt)}</div>
              </div>
              
              <div class="review-content">
                <p class="review-text">{review.content}</p>
                {#if review.images && review.images.length > 0}
                  <div class="review-images">
                    {#each review.images.slice(0, 3) as image}
                      <img src={image} alt="评价图片" class="review-image" />
                    {/each}
                    {#if review.images.length > 3}
                      <div class="more-images">+{review.images.length - 3}</div>
                    {/if}
                  </div>
                {/if}
              </div>
            </div>
          {/each}
        {/if}
      </div>
    </div>
  </div>
  
  <!-- 收益趋势图表 -->
  {#if showCharts}
    <div class="chart-section">
      <div class="section-header">
        <h3 class="section-title">收益趋势</h3>
        <div class="chart-legend">
          <span class="legend-item">
            <span class="legend-color primary"></span>
            收益
          </span>
          <span class="legend-item">
            <span class="legend-color secondary"></span>
            订单量
          </span>
        </div>
      </div>
      
      <div class="chart-container">
        <!-- 简化的图表显示 -->
        <div class="chart-placeholder">
          <div class="chart-bars">
            {#each Array(7) as _, i}
              <div class="chart-bar" style="height: {Math.random() * 100}%"></div>
            {/each}
          </div>
          <div class="chart-info">
            <p>📈 收益呈现上升趋势</p>
            <p>本周较上周增长 {((Math.random() * 20) + 5).toFixed(1)}%</p>
          </div>
        </div>
      </div>
    </div>
  {/if}
</div>

<style>
  .master-dashboard {
    max-width: 1200px;
    margin: 0 auto;
    padding: 24px;
    display: flex;
    flex-direction: column;
    gap: 24px;
  }
  
  /* 仪表板头部 */
  .dashboard-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    gap: 20px;
    margin-bottom: 8px;
  }
  
  .header-info {
    flex: 1;
  }
  
  .dashboard-title {
    font-size: 28px;
    font-weight: 700;
    color: #111827;
    margin: 0 0 8px 0;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    background-clip: text;
  }
  
  .dashboard-subtitle {
    font-size: 16px;
    color: #6b7280;
    margin: 0;
  }
  
  .header-actions {
    display: flex;
    align-items: center;
    gap: 16px;
  }
  
  .time-range-selector {
    display: flex;
    background: #f3f4f6;
    border-radius: 8px;
    padding: 4px;
  }
  
  .time-range-btn {
    background: none;
    border: none;
    padding: 6px 12px;
    font-size: 13px;
    font-weight: 500;
    color: #6b7280;
    border-radius: 6px;
    cursor: pointer;
    transition: all 0.2s ease;
  }
  
  .time-range-btn.active {
    background: white;
    color: #111827;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  }
  
  .time-range-btn:hover:not(.active) {
    color: #374151;
  }
  
  /* 统计卡片网格 */
  .stats-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
    gap: 20px;
  }
  
  .stat-card {
    background: white;
    border-radius: 16px;
    padding: 24px;
    box-shadow: 0 4px 20px rgba(0, 0, 0, 0.08);
    border: 1px solid #e5e7eb;
    display: flex;
    align-items: center;
    gap: 16px;
    transition: all 0.3s ease;
    position: relative;
    overflow: hidden;
  }
  
  .stat-card::before {
    content: '';
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    height: 4px;
    border-radius: 16px 16px 0 0;
  }
  
  .stat-card.primary::before {
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  }
  
  .stat-card.success::before {
    background: linear-gradient(135deg, #10b981 0%, #059669 100%);
  }
  
  .stat-card.warning::before {
    background: linear-gradient(135deg, #f59e0b 0%, #d97706 100%);
  }
  
  .stat-card.info::before {
    background: linear-gradient(135deg, #3b82f6 0%, #1d4ed8 100%);
  }
  
  .stat-card:hover {
    transform: translateY(-2px);
    box-shadow: 0 8px 30px rgba(0, 0, 0, 0.12);
  }
  
  .stat-icon {
    font-size: 32px;
    flex-shrink: 0;
  }
  
  .stat-content {
    flex: 1;
    min-width: 0;
  }
  
  .stat-value {
    font-size: 24px;
    font-weight: 700;
    color: #111827;
    margin-bottom: 4px;
    line-height: 1;
  }
  
  .stat-label {
    font-size: 14px;
    color: #6b7280;
    font-weight: 500;
    margin-bottom: 8px;
  }
  
  .stat-change {
    font-size: 12px;
    font-weight: 600;
    padding: 2px 8px;
    border-radius: 6px;
    display: inline-block;
  }
  
  .stat-change.positive {
    background: #dcfce7;
    color: #166534;
  }
  
  .stat-change.negative {
    background: #fef2f2;
    color: #dc2626;
  }
  
  .stat-change.neutral {
    background: #f3f4f6;
    color: #6b7280;
  }
  
  /* 快捷操作 */
  .quick-actions {
    background: white;
    border-radius: 16px;
    padding: 24px;
    box-shadow: 0 4px 20px rgba(0, 0, 0, 0.08);
    border: 1px solid #e5e7eb;
  }
  
  .section-title {
    font-size: 18px;
    font-weight: 600;
    color: #111827;
    margin: 0 0 16px 0;
  }
  
  .actions-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(120px, 1fr));
    gap: 16px;
  }
  
  .action-btn {
    background: none;
    border: 1px solid #e5e7eb;
    border-radius: 12px;
    padding: 16px;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 8px;
    cursor: pointer;
    transition: all 0.2s ease;
  }
  
  .action-btn:hover {
    border-color: #667eea;
    background: #f8fafc;
    transform: translateY(-2px);
  }
  
  .action-icon {
    font-size: 24px;
  }
  
  .action-text {
    font-size: 13px;
    font-weight: 500;
    color: #374151;
  }
  
  /* 内容区域 */
  .dashboard-content {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 24px;
  }
  
  .content-section {
    background: white;
    border-radius: 16px;
    padding: 24px;
    box-shadow: 0 4px 20px rgba(0, 0, 0, 0.08);
    border: 1px solid #e5e7eb;
  }
  
  .section-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 20px;
  }
  
  /* 订单列表 */
  .orders-list {
    display: flex;
    flex-direction: column;
    gap: 12px;
  }
  
  .order-item {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 16px;
    background: #f9fafb;
    border-radius: 8px;
    cursor: pointer;
    transition: background 0.2s ease;
  }
  
  .order-item:hover {
    background: #f3f4f6;
  }
  
  .order-info {
    flex: 1;
  }
  
  .order-id {
    font-size: 14px;
    font-weight: 600;
    color: #111827;
    margin-bottom: 4px;
  }
  
  .order-client {
    font-size: 13px;
    color: #6b7280;
    margin-bottom: 2px;
  }
  
  .order-service {
    font-size: 12px;
    color: #9ca3af;
  }
  
  .order-meta {
    display: flex;
    flex-direction: column;
    align-items: flex-end;
    gap: 4px;
  }
  
  .order-amount {
    font-size: 14px;
    font-weight: 600;
    color: #059669;
  }
  
  .order-date {
    font-size: 11px;
    color: #9ca3af;
  }
  
  /* 评价列表 */
  .reviews-list {
    display: flex;
    flex-direction: column;
    gap: 16px;
  }
  
  .review-item {
    padding: 16px;
    background: #f9fafb;
    border-radius: 8px;
    cursor: pointer;
    transition: background 0.2s ease;
  }
  
  .review-item:hover {
    background: #f3f4f6;
  }
  
  .review-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    margin-bottom: 8px;
  }
  
  .reviewer-name {
    font-size: 14px;
    font-weight: 600;
    color: #111827;
    margin-bottom: 4px;
  }
  
  .review-rating {
    font-size: 12px;
    color: #f59e0b;
  }
  
  .review-date {
    font-size: 11px;
    color: #9ca3af;
  }
  
  .review-text {
    font-size: 13px;
    color: #6b7280;
    line-height: 1.4;
    margin: 0 0 12px 0;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
  }
  
  .review-images {
    display: flex;
    gap: 6px;
  }
  
  .review-image {
    width: 32px;
    height: 32px;
    border-radius: 4px;
    object-fit: cover;
  }
  
  .more-images {
    width: 32px;
    height: 32px;
    background: #e5e7eb;
    border-radius: 4px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 10px;
    color: #6b7280;
  }
  
  /* 空状态 */
  .empty-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 40px;
    text-align: center;
  }
  
  .empty-icon {
    font-size: 48px;
    opacity: 0.5;
    margin-bottom: 12px;
  }
  
  .empty-text {
    font-size: 14px;
    color: #6b7280;
  }
  
  /* 图表部分 */
  .chart-section {
    background: white;
    border-radius: 16px;
    padding: 24px;
    box-shadow: 0 4px 20px rgba(0, 0, 0, 0.08);
    border: 1px solid #e5e7eb;
  }
  
  .chart-legend {
    display: flex;
    gap: 16px;
  }
  
  .legend-item {
    display: flex;
    align-items: center;
    gap: 6px;
    font-size: 13px;
    color: #6b7280;
  }
  
  .legend-color {
    width: 12px;
    height: 12px;
    border-radius: 2px;
  }
  
  .legend-color.primary {
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  }
  
  .legend-color.secondary {
    background: linear-gradient(135deg, #10b981 0%, #059669 100%);
  }
  
  .chart-container {
    margin-top: 20px;
  }
  
  .chart-placeholder {
    height: 200px;
    display: flex;
    align-items: center;
    justify-content: center;
    background: #f9fafb;
    border-radius: 8px;
    position: relative;
  }
  
  .chart-bars {
    display: flex;
    align-items: flex-end;
    gap: 8px;
    height: 120px;
  }
  
  .chart-bar {
    width: 20px;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    border-radius: 4px 4px 0 0;
    transition: height 0.3s ease;
  }
  
  .chart-info {
    position: absolute;
    bottom: 16px;
    right: 16px;
    text-align: right;
  }
  
  .chart-info p {
    font-size: 12px;
    color: #6b7280;
    margin: 0 0 4px 0;
  }
  
  /* 移动端适配 */
  @media (max-width: 768px) {
    .master-dashboard {
      padding: 16px;
      gap: 16px;
    }
    
    .dashboard-header {
      flex-direction: column;
      align-items: stretch;
      gap: 16px;
    }
    
    .dashboard-title {
      font-size: 24px;
    }
    
    .stats-grid {
      grid-template-columns: 1fr;
      gap: 16px;
    }
    
    .stat-card {
      padding: 20px;
    }
    
    .stat-value {
      font-size: 20px;
    }
    
    .actions-grid {
      grid-template-columns: repeat(3, 1fr);
      gap: 12px;
    }
    
    .action-btn {
      padding: 12px;
    }
    
    .action-icon {
      font-size: 20px;
    }
    
    .dashboard-content {
      grid-template-columns: 1fr;
      gap: 16px;
    }
    
    .content-section {
      padding: 20px;
    }
    
    .chart-section {
      padding: 20px;
    }
    
    .chart-placeholder {
      height: 160px;
    }
  }
</style> 