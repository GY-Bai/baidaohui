<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { page } from '$app/stores';
  import { clientSideRouteGuard, signOut, startRoleChangeListener } from '$lib/auth';
  
  // 导入新的UI组件
  import Card from '$lib/components/ui/Card.svelte';
  import Alert from '$lib/components/ui/Alert.svelte';
  import Button from '$lib/components/ui/Button.svelte';
  import Badge from '$lib/components/ui/Badge.svelte';
  import Avatar from '$lib/components/ui/Avatar.svelte';

  let loading = true;
  let authenticated = false;
  
  // 角色监听器清理函数
  let stopRoleListener: (() => void) | null = null;

  // 模拟用户数据
  const mockUser = {
    id: '1',
    name: '张三',
    username: 'zhangsan',
    email: 'zhangsan@example.com',
    avatar: 'https://api.dicebear.com/7.x/avataaars/svg?seed=zhang',
    verified: false,
    premium: false,
    stats: {
      orders: 3,
      messages: 12,
      level: 'Fan'
    }
  };

  // 模拟算命申请数据
  const mockFortuneRequests = [
    {
      id: '1',
      description: '关于事业发展的问题，希望教主能够指点迷津...',
      amount: 50,
      currency: 'CAD',
      priority: 'urgent',
      queuePosition: 3,
      status: 'pending',
      remainingModifications: 2,
      createdAt: '2024-01-20'
    },
    {
      id: '2',
      description: '感情方面的困惑，想要了解未来的发展...',
      amount: 30,
      currency: 'CAD',
      priority: 'normal',
      queuePosition: 8,
      status: 'completed',
      remainingModifications: 0,
      createdAt: '2024-01-15'
    }
  ];

  onMount(async () => {
    console.log('🏗️ Fan页面：开始初始化...');
    
    // 🚀 使用增强的客户端路由守卫（会查询最新角色）
    authenticated = await clientSideRouteGuard('Fan');
    loading = false;

    if (authenticated) {
      console.log('✅ Fan页面：身份验证成功，启动角色监听器');
      // 🔄 启动角色变更监听器（每30秒检查一次）
      stopRoleListener = startRoleChangeListener(30000);
    }
  });

  onDestroy(() => {
    // 🧹 清理角色监听器
    if (stopRoleListener) {
      console.log('🧹 Fan页面：清理角色监听器');
      stopRoleListener();
    }
  });

  async function handleSignOut() {
    console.log('👋 Fan页面：用户登出');
    // 停止角色监听器
    if (stopRoleListener) {
      stopRoleListener();
      stopRoleListener = null;
    }
    await signOut();
  }

  function handleUpgrade() {
    // 跳转到会员认证页面
    console.log('升级到会员');
  }

  function handleCreateFortune() {
    // 打开新建算命申请模态框
    console.log('新建算命申请');
  }

  function handleModifyRequest(requestId) {
    // 打开修改申请模态框
    console.log('修改申请：', requestId);
  }

  function getStatusColor(status) {
    switch (status) {
      case 'pending': return 'warning';
      case 'completed': return 'success';
      case 'cancelled': return 'error';
      default: return 'secondary';
    }
  }

  function getStatusText(status) {
    switch (status) {
      case 'pending': return '等待中';
      case 'completed': return '已完成';
      case 'cancelled': return '已取消';
      default: return status;
    }
  }

  function getPriorityColor(priority) {
    switch (priority) {
      case 'urgent': return 'error';
      case 'high': return 'warning';
      case 'normal': return 'secondary';
      default: return 'secondary';
    }
  }

  function getPriorityText(priority) {
    switch (priority) {
      case 'urgent': return '紧急';
      case 'high': return '高优先级';
      case 'normal': return '普通';
      default: return priority;
    }
  }
</script>

<svelte:head>
  <title>百道慧 - Fan用户专区</title>
</svelte:head>

{#if loading}
  <div class="loading-screen">
    <div class="loading-content">
      <div class="loading-spinner"></div>
      <p>正在验证身份...</p>
    </div>
  </div>
{:else if authenticated}
  <div class="fan-container">
    <!-- 用户信息头部 -->
    <section class="user-header">
      <div class="user-info">
        <Avatar
          src={mockUser.avatar}
          alt={mockUser.name}
          size="lg"
        />
        <div class="user-details">
          <h2>{mockUser.name}</h2>
          <p>@{mockUser.username}</p>
          <Badge variant="secondary" size="sm">{mockUser.stats.level}</Badge>
        </div>
      </div>
      
      <div class="quick-stats">
        <div class="stat-item">
          <span class="stat-number">{mockUser.stats.orders}</span>
          <span class="stat-label">订单</span>
        </div>
        <div class="stat-item">
          <span class="stat-number">{mockUser.stats.messages}</span>
          <span class="stat-label">消息</span>
        </div>
      </div>
    </section>

    <!-- 权限提示区域 -->
    <section class="permissions-section">
      <Alert type="warning" showIcon closable={false}>
        <strong>会员权限提示：</strong>您还不是会员，无法使用私信功能和高级服务。
        <Button slot="action" variant="outline" size="xs" on:click={handleUpgrade}>
          完成会员认证
        </Button>
      </Alert>
    </section>

    <!-- 算命申请区域 -->
    <section class="fortune-section">
      <Card variant="elevated">
        <div class="section-header" slot="header">
          <h3>🔮 我的算命申请</h3>
          <Button variant="primary" size="sm" on:click={handleCreateFortune}>
            + 新建申请
          </Button>
        </div>
        
        <div class="fortune-list">
          {#each mockFortuneRequests as request}
            <div class="fortune-item">
              <div class="fortune-header">
                <div class="fortune-badges">
                  <Badge variant={getPriorityColor(request.priority)} size="sm">
                    {getPriorityText(request.priority)}
                  </Badge>
                  <Badge variant={getStatusColor(request.status)} size="sm">
                    {getStatusText(request.status)}
                  </Badge>
                  {#if request.status === 'pending'}
                    <Badge variant="secondary" size="sm">
                      排队第{request.queuePosition}位
                    </Badge>
                  {/if}
                </div>
                
                <div class="fortune-amount">
                  ${request.amount} {request.currency}
                </div>
              </div>
              
              <div class="fortune-content">
                <p class="fortune-description">{request.description}</p>
                
                <div class="fortune-meta">
                  <span class="meta-item">创建时间: {request.createdAt}</span>
                  {#if request.remainingModifications > 0}
                    <span class="meta-item">剩余修改: {request.remainingModifications}次</span>
                  {/if}
                </div>
              </div>
              
              <div class="fortune-actions">
                {#if request.status === 'pending'}
                  <Button variant="outline" size="xs" on:click={() => handleModifyRequest(request.id)}>
                    修改申请
                  </Button>
                {/if}
                <Button variant="ghost" size="xs">
                  查看详情
                </Button>
              </div>
            </div>
          {/each}
        </div>
      </Card>
    </section>

    <!-- 快速操作区域 -->
    <section class="quick-actions">
      <Card variant="outlined">
        <h3 slot="header">快速操作</h3>
        
        <div class="action-grid">
          <button class="action-item disabled" disabled>
            <span class="action-icon">💬</span>
            <span class="action-label">私信聊天</span>
            <span class="action-desc">需要会员权限</span>
          </button>
          
          <button class="action-item" on:click={handleCreateFortune}>
            <span class="action-icon">🔮</span>
            <span class="action-label">算命申请</span>
            <span class="action-desc">获得专业指导</span>
          </button>
          
          <button class="action-item">
            <span class="action-icon">🛍️</span>
            <span class="action-label">好物推荐</span>
            <span class="action-desc">发现优质商品</span>
          </button>
          
          <button class="action-item">
            <span class="action-icon">👤</span>
            <span class="action-label">个人设置</span>
            <span class="action-desc">管理个人信息</span>
          </button>
        </div>
      </Card>
    </section>

    <!-- 底部安全退出 -->
    <section class="logout-section">
      <Button variant="ghost" size="sm" on:click={handleSignOut}>
        🚪 安全退出
      </Button>
    </section>
  </div>
{/if}

<style>
  .loading-screen {
    min-height: 100vh;
    display: flex;
    align-items: center;
    justify-content: center;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  }

  .loading-content {
    text-align: center;
    color: white;
  }

  .loading-spinner {
    width: 40px;
    height: 40px;
    border: 4px solid rgba(255, 255, 255, 0.3);
    border-top: 4px solid white;
    border-radius: 50%;
    animation: spin 1s linear infinite;
    margin: 0 auto 16px auto;
  }

  @keyframes spin {
    0% { transform: rotate(0deg); }
    100% { transform: rotate(360deg); }
  }

  .fan-container {
    min-height: 100vh;
    background: #f8fafc;
    padding: 20px;
    max-width: 768px;
    margin: 0 auto;
  }

  /* 用户头部 */
  .user-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    background: white;
    padding: 24px;
    border-radius: 16px;
    box-shadow: 0 4px 20px rgba(0, 0, 0, 0.1);
    margin-bottom: 20px;
  }

  .user-info {
    display: flex;
    align-items: center;
    gap: 16px;
  }

  .user-details h2 {
    margin: 0 0 4px 0;
    font-size: 20px;
    font-weight: 600;
    color: #111827;
  }

  .user-details p {
    margin: 0 0 8px 0;
    color: #6b7280;
    font-size: 14px;
  }

  .quick-stats {
    display: flex;
    gap: 24px;
  }

  .stat-item {
    text-align: center;
  }

  .stat-number {
    display: block;
    font-size: 24px;
    font-weight: 700;
    color: #111827;
  }

  .stat-label {
    font-size: 12px;
    color: #6b7280;
  }

  /* 权限提示 */
  .permissions-section {
    margin-bottom: 20px;
  }

  /* 算命申请区域 */
  .fortune-section {
    margin-bottom: 20px;
  }

  .section-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 0;
  }

  .section-header h3 {
    margin: 0;
    font-size: 18px;
    font-weight: 600;
    color: #111827;
  }

  .fortune-list {
    display: flex;
    flex-direction: column;
    gap: 16px;
  }

  .fortune-item {
    padding: 16px;
    border: 1px solid #e5e7eb;
    border-radius: 12px;
    background: #f9fafb;
  }

  .fortune-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    margin-bottom: 12px;
  }

  .fortune-badges {
    display: flex;
    gap: 8px;
    flex-wrap: wrap;
  }

  .fortune-amount {
    font-size: 18px;
    font-weight: 600;
    color: #059669;
  }

  .fortune-content {
    margin-bottom: 12px;
  }

  .fortune-description {
    margin: 0 0 8px 0;
    color: #374151;
    line-height: 1.5;
  }

  .fortune-meta {
    display: flex;
    gap: 16px;
    flex-wrap: wrap;
  }

  .meta-item {
    font-size: 12px;
    color: #6b7280;
  }

  .fortune-actions {
    display: flex;
    gap: 8px;
    justify-content: flex-end;
  }

  /* 快速操作 */
  .quick-actions {
    margin-bottom: 20px;
  }

  .action-grid {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: 12px;
  }

  .action-item {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 8px;
    padding: 16px;
    border: 1px solid #e5e7eb;
    border-radius: 12px;
    background: white;
    cursor: pointer;
    transition: all 0.2s ease;
  }

  .action-item:hover:not(.disabled) {
    border-color: #667eea;
    box-shadow: 0 4px 12px rgba(102, 126, 234, 0.15);
  }

  .action-item.disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .action-icon {
    font-size: 24px;
  }

  .action-label {
    font-weight: 500;
    color: #111827;
  }

  .action-desc {
    font-size: 12px;
    color: #6b7280;
    text-align: center;
  }

  /* 底部退出 */
  .logout-section {
    text-align: center;
    padding: 20px 0;
  }

  /* 移动端适配 */
  @media (max-width: 768px) {
    .fan-container {
      padding: 16px;
    }

    .user-header {
      flex-direction: column;
      gap: 16px;
      text-align: center;
    }

    .user-info {
      flex-direction: column;
      text-align: center;
    }

    .quick-stats {
      justify-content: center;
    }

    .fortune-header {
      flex-direction: column;
      gap: 8px;
      align-items: flex-start;
    }

    .fortune-badges {
      justify-content: flex-start;
    }

    .fortune-actions {
      justify-content: flex-start;
    }

    .action-grid {
      grid-template-columns: 1fr;
    }
  }

  /* 深色模式 */
  @media (prefers-color-scheme: dark) {
    .fan-container {
      background: #111827;
    }

    .user-header {
      background: #1f2937;
    }

    .user-details h2 {
      color: #f9fafb;
    }

    .user-details p {
      color: #d1d5db;
    }

    .stat-number {
      color: #f9fafb;
    }

    .stat-label {
      color: #d1d5db;
    }

    .section-header h3 {
      color: #f9fafb;
    }

    .fortune-item {
      background: #374151;
      border-color: #4b5563;
    }

    .fortune-description {
      color: #e5e7eb;
    }

    .meta-item {
      color: #d1d5db;
    }

    .action-item {
      background: #1f2937;
      border-color: #374151;
    }

    .action-item:hover:not(.disabled) {
      border-color: #60a5fa;
    }

    .action-label {
      color: #f9fafb;
    }

    .action-desc {
      color: #d1d5db;
    }
  }
</style> 