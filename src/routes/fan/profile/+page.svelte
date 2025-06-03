<script lang="ts">
  import Button from '$lib/components/ui/Button.svelte';
  
  // 模拟用户数据
  const userProfile = {
    nickname: '算命爱好者',
    avatar: '👤',
    membershipStatus: 'fan',
    joinDate: '2024-01-01',
    fortuneCount: 5,
    shoppingCount: 12,
    favoriteCount: 8
  };
  
  function handleQuickAction(action: string) {
    console.log('快捷操作:', action);
    // 这里可以根据action类型跳转到对应页面
  }
</script>

<svelte:head>
  <title>个人中心 - 百刀会</title>
</svelte:head>

<div class="profile-view">
  <!-- 用户资料头部 -->
  <header class="profile-header">
    <div class="user-info">
      <div class="avatar">
        {userProfile.avatar}
      </div>
      <div class="user-details">
        <h2 class="username">{userProfile.nickname}</h2>
        <div class="membership-badge fan">
          <span class="badge-icon">🌟</span>
          <span>Fan 用户</span>
        </div>
        <p class="join-date">加入时间: {userProfile.joinDate}</p>
      </div>
    </div>
    
    <Button variant="secondary" size="sm">
      编辑资料
    </Button>
  </header>
  
  <!-- 统计数据 -->
  <section class="stats-section">
    <div class="stats-grid">
      <div class="stat-card">
        <div class="stat-icon">🔮</div>
        <div class="stat-info">
          <span class="stat-number">{userProfile.fortuneCount}</span>
          <span class="stat-label">算命订单</span>
        </div>
      </div>
      
      <div class="stat-card">
        <div class="stat-icon">🛒</div>
        <div class="stat-info">
          <span class="stat-number">{userProfile.shoppingCount}</span>
          <span class="stat-label">购物订单</span>
        </div>
      </div>
      
      <div class="stat-card">
        <div class="stat-icon">❤️</div>
        <div class="stat-info">
          <span class="stat-number">{userProfile.favoriteCount}</span>
          <span class="stat-label">收藏商品</span>
        </div>
      </div>
    </div>
  </section>
  
  <!-- 快捷操作 -->
  <section class="quick-actions">
    <h3 class="section-title">快捷操作</h3>
    
    <div class="action-grid">
      <button 
        class="action-card"
        on:click={() => handleQuickAction('fortune-orders')}
      >
        <div class="action-icon">🔮</div>
        <div class="action-info">
          <h4>我的算命订单</h4>
          <p>查看所有算命申请和结果</p>
        </div>
        <div class="action-arrow">›</div>
      </button>
      
      <button 
        class="action-card"
        on:click={() => handleQuickAction('shopping-orders')}
      >
        <div class="action-icon">🛒</div>
        <div class="action-info">
          <h4>我的购物订单</h4>
          <p>查看购买记录和物流信息</p>
        </div>
        <div class="action-arrow">›</div>
      </button>
      
      <button 
        class="action-card"
        on:click={() => handleQuickAction('favorites')}
      >
        <div class="action-icon">❤️</div>
        <div class="action-info">
          <h4>我的收藏</h4>
          <p>查看收藏的商品和内容</p>
        </div>
        <div class="action-arrow">›</div>
      </button>
      
      <button 
        class="action-card"
        on:click={() => handleQuickAction('settings')}
      >
        <div class="action-icon">⚙️</div>
        <div class="action-info">
          <h4>设置</h4>
          <p>个人资料和偏好设置</p>
        </div>
        <div class="action-arrow">›</div>
      </button>
    </div>
  </section>
  
  <!-- 会员升级提示 -->
  <section class="upgrade-section">
    <div class="upgrade-card">
      <div class="upgrade-content">
        <div class="upgrade-icon">✨</div>
        <div class="upgrade-text">
          <h3>升级为会员</h3>
          <p>解锁更多功能和专属权益</p>
        </div>
      </div>
      <Button variant="primary">
        立即升级
      </Button>
    </div>
  </section>
</div>

<style>
  .profile-view {
    min-height: 100vh;
    background: #fafafa;
    padding: 20px;
  }
  
  /* 用户资料头部 */
  .profile-header {
    background: white;
    border-radius: 16px;
    padding: 24px;
    margin-bottom: 20px;
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  }
  
  .user-info {
    display: flex;
    align-items: center;
    gap: 16px;
    flex: 1;
  }
  
  .avatar {
    width: 80px;
    height: 80px;
    border-radius: 50%;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 32px;
    color: white;
    flex-shrink: 0;
  }
  
  .user-details {
    flex: 1;
    min-width: 0;
  }
  
  .username {
    margin: 0 0 8px 0;
    font-size: 24px;
    font-weight: 700;
    color: #374151;
  }
  
  .membership-badge {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    padding: 4px 12px;
    border-radius: 16px;
    font-size: 14px;
    font-weight: 600;
    margin-bottom: 8px;
  }
  
  .membership-badge.fan {
    background: #fef3c7;
    color: #92400e;
  }
  
  .badge-icon {
    font-size: 16px;
  }
  
  .join-date {
    margin: 0;
    font-size: 14px;
    color: #6b7280;
  }
  
  /* 统计数据 */
  .stats-section {
    margin-bottom: 24px;
  }
  
  .stats-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 16px;
  }
  
  .stat-card {
    background: white;
    border-radius: 12px;
    padding: 20px;
    display: flex;
    align-items: center;
    gap: 16px;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  }
  
  .stat-icon {
    font-size: 32px;
    flex-shrink: 0;
  }
  
  .stat-info {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }
  
  .stat-number {
    font-size: 24px;
    font-weight: 700;
    color: #374151;
  }
  
  .stat-label {
    font-size: 14px;
    color: #6b7280;
  }
  
  /* 快捷操作 */
  .quick-actions {
    margin-bottom: 24px;
  }
  
  .section-title {
    margin: 0 0 16px 0;
    font-size: 20px;
    font-weight: 600;
    color: #374151;
  }
  
  .action-grid {
    display: grid;
    gap: 12px;
  }
  
  .action-card {
    background: white;
    border: none;
    border-radius: 12px;
    padding: 16px;
    display: flex;
    align-items: center;
    gap: 16px;
    cursor: pointer;
    transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
    text-align: left;
    width: 100%;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  }
  
  .action-card:hover {
    transform: translateY(-2px);
    box-shadow: 0 4px 16px rgba(0, 0, 0, 0.15);
  }
  
  .action-icon {
    font-size: 24px;
    flex-shrink: 0;
  }
  
  .action-info {
    flex: 1;
    min-width: 0;
  }
  
  .action-info h4 {
    margin: 0 0 4px 0;
    font-size: 16px;
    font-weight: 600;
    color: #374151;
  }
  
  .action-info p {
    margin: 0;
    font-size: 14px;
    color: #6b7280;
    line-height: 1.4;
  }
  
  .action-arrow {
    font-size: 20px;
    color: #9ca3af;
    flex-shrink: 0;
  }
  
  /* 会员升级 */
  .upgrade-section {
    margin-bottom: 20px;
  }
  
  .upgrade-card {
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    border-radius: 16px;
    padding: 24px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    color: white;
  }
  
  .upgrade-content {
    display: flex;
    align-items: center;
    gap: 16px;
    flex: 1;
  }
  
  .upgrade-icon {
    font-size: 32px;
    flex-shrink: 0;
  }
  
  .upgrade-text h3 {
    margin: 0 0 4px 0;
    font-size: 20px;
    font-weight: 700;
  }
  
  .upgrade-text p {
    margin: 0;
    opacity: 0.9;
    font-size: 14px;
  }
  
  /* 响应式优化 */
  @media (max-width: 768px) {
    .profile-view {
      padding: 16px;
    }
    
    .profile-header {
      flex-direction: column;
      align-items: flex-start;
      gap: 16px;
      padding: 20px;
    }
    
    .avatar {
      width: 64px;
      height: 64px;
      font-size: 24px;
    }
    
    .username {
      font-size: 20px;
    }
    
    .stats-grid {
      grid-template-columns: 1fr;
      gap: 12px;
    }
    
    .stat-card {
      padding: 16px;
    }
    
    .action-card {
      padding: 12px;
    }
    
    .upgrade-card {
      flex-direction: column;
      align-items: flex-start;
      gap: 16px;
      text-align: left;
    }
  }
  
  @media (max-width: 480px) {
    .user-info {
      flex-direction: column;
      align-items: flex-start;
      text-align: left;
    }
    
    .stats-grid {
      grid-template-columns: 1fr;
    }
    
    .stat-card {
      justify-content: center;
      text-align: center;
    }
  }
  
  /* 深色模式 */
  @media (prefers-color-scheme: dark) {
    .profile-view {
      background: #111827;
    }
    
    .profile-header,
    .stat-card,
    .action-card {
      background: #1f2937;
    }
    
    .username,
    .stat-number,
    .section-title,
    .action-info h4 {
      color: #f3f4f6;
    }
    
    .join-date,
    .stat-label,
    .action-info p {
      color: #9ca3af;
    }
  }
</style> 