<script lang="ts">
  import { onMount } from 'svelte';
  import { clientSideRouteGuard, signOut } from '$lib/auth';
  
  // 导入新的UI组件
  import UserProfileDropdown from '$lib/components/ui/UserProfileDropdown.svelte';
  import OnlineStatusIndicator from '$lib/components/ui/OnlineStatusIndicator.svelte';
  import Avatar from '$lib/components/ui/Avatar.svelte';
  import Button from '$lib/components/ui/Button.svelte';
  import InviteLinkGenerator from '$lib/components/ui/InviteLinkGenerator.svelte';
  import ApiKeyManager from '$lib/components/ui/ApiKeyManager.svelte';
  import ActivityLogList from '$lib/components/ui/ActivityLogList.svelte';
  import Card from '$lib/components/ui/Card.svelte';
  import DataTable from '$lib/components/ui/DataTable.svelte';
  import Badge from '$lib/components/ui/Badge.svelte';

  let loading = true;
  let authenticated = false;
  let activeTab = 'invite'; // 默认显示邀请链接
  let showDropdown = false;

  // 模拟用户数据
  const masterUser = {
    id: 'master',
    name: '教主',
    username: 'master',
    email: 'master@baidaohui.com',
    avatar: 'https://api.dicebear.com/7.x/avataaars/svg?seed=master',
    status: 'online',
    verified: true,
    role: 'Master',
    bio: '百道慧创始人，专业算命师',
    location: '北京市',
    joinDate: '2020-01-01',
    stats: {
      totalUsers: 15847,
      activeMembers: 3521,
      totalOrders: 8932
    }
  };

  // 模拟组织数据
  const organization = {
    id: '1',
    name: '百道慧',
    domain: 'https://baidaohui.com'
  };

  // 模拟API密钥数据
  const mockApiKeys = [
    {
      id: '1',
      name: '主要API密钥',
      description: '用于核心系统集成的主要API访问密钥',
      key: 'bah_1234567890abcdef1234567890abcdef1234567890',
      permissions: 'admin',
      rateLimit: 10000,
      expiresAt: new Date(Date.now() + 90 * 24 * 60 * 60 * 1000),
      createdAt: new Date('2024-01-01'),
      lastUsed: new Date('2024-01-20'),
      usageCount: 25847,
      isActive: true
    },
    {
      id: '2',
      name: '监控API密钥',
      description: '用于系统监控和统计的只读API密钥',
      key: 'bah_0987654321fedcba0987654321fedcba0987654321',
      permissions: 'read',
      rateLimit: 5000,
      expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
      createdAt: new Date('2024-01-10'),
      lastUsed: new Date('2024-01-19'),
      usageCount: 8234,
      isActive: true
    }
  ];

  // 模拟活动日志数据
  const mockActivities = [
    {
      id: '1',
      type: 'user.login',
      description: '用户登录系统',
      status: 'success',
      createdAt: new Date(),
      user: { name: '张三', id: '123' },
      ip: '192.168.1.100',
      location: '北京市'
    },
    {
      id: '2',
      type: 'fortune.created',
      description: '创建新算命订单',
      status: 'success',
      createdAt: new Date(Date.now() - 60000),
      user: { name: '李四', id: '456' },
      details: { amount: '$50 CAD', priority: 'urgent' }
    },
    {
      id: '3',
      type: 'api.request',
      description: 'API请求 - 获取用户信息',
      status: 'success',
      createdAt: new Date(Date.now() - 120000),
      user: { name: 'System', id: 'system' },
      details: { endpoint: '/api/users', method: 'GET' }
    },
    {
      id: '4',
      type: 'payment.processed',
      description: '处理支付',
      status: 'success',
      createdAt: new Date(Date.now() - 180000),
      user: { name: '王五', id: '789' },
      details: { amount: '$30 CAD', method: 'credit_card' }
    }
  ];

  // 模拟算命订单数据
  const mockFortuneOrders = [
    {
      id: 'F001',
      user: '张三',
      userId: '123',
      amount: '$50 CAD',
      priority: 'urgent',
      status: 'pending',
      queuePosition: 1,
      createdAt: '2024-01-20',
      description: '关于事业发展的问题...',
      remainingModifications: 2
    },
    {
      id: 'F002',
      user: '李四',
      userId: '456',
      amount: '$30 CAD',
      priority: 'normal',
      status: 'processing',
      queuePosition: 2,
      createdAt: '2024-01-19',
      description: '感情方面的困惑...',
      remainingModifications: 1
    },
    {
      id: 'F003',
      user: '王五',
      userId: '789',
      amount: '$80 CAD',
      priority: 'high',
      status: 'completed',
      queuePosition: null,
      createdAt: '2024-01-18',
      description: '财运和投资建议...',
      remainingModifications: 0
    }
  ];

  onMount(async () => {
    // 使用客户端路由守卫
    authenticated = await clientSideRouteGuard('Master');
    loading = false;
  });

  async function handleSignOut() {
    await signOut();
  }

  const tabs = [
    { 
      id: 'invite', 
      name: '邀请链接', 
      icon: '🔗',
      description: '管理邀请链接和用户注册'
    },
    { 
      id: 'fortune', 
      name: '算命管理', 
      icon: '🔮',
      description: '管理所有用户的算命申请和订单'
    },
    { 
      id: 'ecommerce', 
      name: '电商管理', 
      icon: '🛍️',
      description: '管理商户和API密钥'
    },
    { 
      id: 'chat', 
      name: '聊天管理', 
      icon: '💬',
      description: '管理聊天室和私聊权限'
    }
  ];

  function setActiveTab(tabId) {
    activeTab = tabId;
  }

  function getTabTitle() {
    const tab = tabs.find(t => t.id === activeTab);
    return tab ? tab.name : '管理控制台';
  }

  // 表格列定义
  const fortuneColumns = [
    { key: 'id', label: '订单ID', sortable: true },
    { key: 'user', label: '用户', sortable: true },
    { key: 'amount', label: '金额', sortable: true },
    { key: 'priority', label: '优先级', sortable: true },
    { key: 'status', label: '状态', sortable: true },
    { key: 'createdAt', label: '创建时间', sortable: true },
    { key: 'actions', label: '操作', sortable: false }
  ];

  // 处理邀请链接事件
  function handleLinkGenerated(event) {
    console.log('邀请链接已生成:', event.detail);
  }

  function handleLinkCopied() {
    console.log('链接已复制到剪贴板');
  }

  // 处理API密钥事件
  function handleKeyCreated() {
    console.log('API密钥创建成功');
  }

  function handleKeyRevoked() {
    console.log('API密钥已撤销');
  }

  function handleKeyDeleted() {
    console.log('API密钥已删除');
  }

  // 处理活动日志事件
  function handleActivityClick(event) {
    console.log('查看活动详情:', event.detail.activity);
  }

  function handleFilterChange() {
    console.log('筛选条件已更新');
  }

  function handleExport() {
    console.log('正在导出日志...');
  }

  // 处理用户菜单事件
  function handleMenuClick(event) {
    const item = event.detail.item;
    if (item.id === 'logout') {
      handleSignOut();
    } else {
      console.log('点击菜单:', item.label);
    }
  }

  function handleStatusChange(event) {
    console.log('状态变更:', event.detail.status);
  }

  // 处理算命订单操作
  function handleOrderAction(orderId, action) {
    console.log(`对订单 ${orderId} 执行操作: ${action}`);
  }

  function getStatusBadgeVariant(status) {
    switch (status) {
      case 'pending': return 'warning';
      case 'processing': return 'info';
      case 'completed': return 'success';
      case 'cancelled': return 'error';
      default: return 'secondary';
    }
  }

  function getPriorityBadgeVariant(priority) {
    switch (priority) {
      case 'urgent': return 'error';
      case 'high': return 'warning';
      case 'normal': return 'secondary';
      default: return 'secondary';
    }
  }
</script>

<svelte:head>
  <title>{getTabTitle()} - 百道慧管理控制台</title>
</svelte:head>

{#if loading}
  <div class="loading-screen">
    <div class="loading-content">
      <div class="loading-spinner"></div>
      <p>正在验证身份...</p>
    </div>
  </div>
{:else if authenticated}
  <div class="master-container">
    <!-- 顶部头部 -->
    <header class="master-header">
      <div class="header-left">
        <h1>🏢 Master管理控制台</h1>
        <div class="stats-overview">
          <span class="stat-item">{masterUser.stats.totalUsers} 总用户</span>
          <span class="stat-item">{masterUser.stats.activeMembers} 活跃会员</span>
          <span class="stat-item">{masterUser.stats.totalOrders} 总订单</span>
        </div>
      </div>
      
      <div class="header-right">
        <UserProfileDropdown 
          user={masterUser}
          bind:visible={showDropdown}
          on:menuClick={handleMenuClick}
          on:statusChange={handleStatusChange}
        />
        <Button variant="ghost" on:click={() => showDropdown = !showDropdown}>
          <Avatar src={masterUser.avatar} size="sm" />
          <OnlineStatusIndicator status="online" position="bottom-right" size="xs" />
        </Button>
      </div>
    </header>

    <!-- 顶部标签导航 -->
    <nav class="top-tabs">
      {#each tabs as tab}
        <button 
          class="tab"
          class:active={activeTab === tab.id}
          on:click={() => setActiveTab(tab.id)}
          title={tab.description}
        >
          <span class="tab-icon">{tab.icon}</span>
          <span class="tab-label">{tab.name}</span>
        </button>
      {/each}
    </nav>

    <!-- 主要内容区域 -->
    <main class="master-content">
      {#if activeTab === 'invite'}
        <!-- 邀请链接管理 -->
        <div class="content-section">
          <Card variant="elevated">
            <h2 slot="header">🔗 邀请链接管理</h2>
            
            <InviteLinkGenerator
              {organization}
              user={masterUser}
              showAdvanced={true}
              on:linkGenerated={handleLinkGenerated}
              on:linkCopied={handleLinkCopied}
            />
          </Card>
        </div>
        
      {:else if activeTab === 'fortune'}
        <!-- 算命管理 -->
        <div class="content-section">
          <Card variant="elevated">
            <h2 slot="header">🔮 算命订单管理</h2>
            
            <DataTable
              data={mockFortuneOrders}
              columns={fortuneColumns}
              searchable={true}
              sortable={true}
              pagination={true}
              pageSize={10}
              showSelection={true}
              emptyMessage="暂无算命订单"
            >
              <svelte:fragment slot="cell" let:row let:column>
                {#if column.key === 'priority'}
                  <Badge variant={getPriorityBadgeVariant(row.priority)} size="sm">
                    {row.priority === 'urgent' ? '紧急' : 
                     row.priority === 'high' ? '高' : '普通'}
                  </Badge>
                {:else if column.key === 'status'}
                  <Badge variant={getStatusBadgeVariant(row.status)} size="sm">
                    {row.status === 'pending' ? '等待中' :
                     row.status === 'processing' ? '处理中' :
                     row.status === 'completed' ? '已完成' : '已取消'}
                  </Badge>
                {:else if column.key === 'actions'}
                  <div class="table-actions">
                    <Button variant="outline" size="xs" on:click={() => handleOrderAction(row.id, 'view')}>
                      查看
                    </Button>
                    {#if row.status === 'pending'}
                      <Button variant="primary" size="xs" on:click={() => handleOrderAction(row.id, 'process')}>
                        处理
                      </Button>
                    {/if}
                  </div>
                {:else}
                  {row[column.key]}
                {/if}
              </svelte:fragment>
            </DataTable>
          </Card>
        </div>
        
      {:else if activeTab === 'ecommerce'}
        <!-- 电商管理 -->
        <div class="content-section">
          <Card variant="elevated">
            <h2 slot="header">🛍️ API密钥管理</h2>
            
            <ApiKeyManager
              keys={mockApiKeys}
              canCreate={true}
              canRevoke={true}
              canEdit={true}
              on:keyCreated={handleKeyCreated}
              on:keyRevoked={handleKeyRevoked}
              on:keyDeleted={handleKeyDeleted}
            />
          </Card>
        </div>
        
      {:else if activeTab === 'chat'}
        <!-- 聊天管理 */
        <div class="content-section">
          <Card variant="elevated">
            <h2 slot="header">💬 聊天管理</h2>
            
            <div class="chat-management">
              <div class="chat-stats">
                <div class="stat-card">
                  <h3>在线用户</h3>
                  <p class="stat-number">156</p>
                </div>
                <div class="stat-card">
                  <h3>活跃群聊</h3>
                  <p class="stat-number">3</p>
                </div>
                <div class="stat-card">
                  <h3>私聊会话</h3>
                  <p class="stat-number">89</p>
                </div>
                <div class="stat-card">
                  <h3>今日消息</h3>
                  <p class="stat-number">2,847</p>
                </div>
              </div>
              
              <div class="chat-controls">
                <h3>快速操作</h3>
                <div class="control-buttons">
                  <Button variant="primary" size="sm">广播消息</Button>
                  <Button variant="outline" size="sm">导出聊天记录</Button>
                  <Button variant="outline" size="sm">清理过期消息</Button>
                  <Button variant="secondary" size="sm">用户权限管理</Button>
                </div>
              </div>
            </div>
          </Card>
          
          <!-- 活动日志 -->
          <Card variant="outlined">
            <h3 slot="header">📊 系统活动日志</h3>
            
            <ActivityLogList
              activities={mockActivities}
              pagination={{ page: 1, size: 20, total: 100 }}
              showFilters={true}
              showExport={true}
              on:filterChange={handleFilterChange}
              on:export={handleExport}
              on:activityClick={handleActivityClick}
            />
          </Card>
      {/if}
    </main>
  </div>
{/if}

<style>
  .loading-screen {
    min-height: 100vh;
    display: flex;
    align-items: center;
    justify-content: center;
    background: linear-gradient(135deg, #ffd700 0%, #ffb300 100%);
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

  .master-container {
    min-height: 100vh;
    background: #f8fafc;
    display: flex;
    flex-direction: column;
  }

  /* 头部样式 */
  .master-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 16px 24px;
    background: white;
    border-bottom: 1px solid #e5e7eb;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  }

  .header-left h1 {
    margin: 0 0 8px 0;
    font-size: 24px;
    font-weight: 700;
    color: #111827;
  }

  .stats-overview {
    display: flex;
    gap: 16px;
    font-size: 14px;
  }

  .stat-item {
    color: #6b7280;
    font-weight: 500;
  }

  .header-right {
    display: flex;
    align-items: center;
    gap: 12px;
    position: relative;
  }

  /* 顶部标签导航 */
  .top-tabs {
    display: flex;
    background: white;
    border-bottom: 1px solid #e5e7eb;
    overflow-x: auto;
  }

  .tab {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 12px 24px;
    border: none;
    background: transparent;
    color: #6b7280;
    cursor: pointer;
    border-bottom: 2px solid transparent;
    transition: all 0.2s ease;
    white-space: nowrap;
    font-weight: 500;
  }

  .tab:hover {
    color: #374151;
    background: #f9fafb;
  }

  .tab.active {
    color: #667eea;
    border-bottom-color: #667eea;
    background: #f8fafc;
  }

  .tab-icon {
    font-size: 18px;
  }

  .tab-label {
    font-size: 14px;
  }

  /* 主要内容 */
  .master-content {
    flex: 1;
    padding: 24px;
    overflow-y: auto;
  }

  .content-section {
    display: flex;
    flex-direction: column;
    gap: 24px;
    max-width: 1200px;
    margin: 0 auto;
  }

  /* 聊天管理样式 */
  .chat-management {
    display: flex;
    flex-direction: column;
    gap: 24px;
  }

  .chat-stats {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 16px;
  }

  .stat-card {
    padding: 20px;
    background: #f9fafb;
    border-radius: 12px;
    text-align: center;
    border: 1px solid #e5e7eb;
  }

  .stat-card h3 {
    margin: 0 0 8px 0;
    font-size: 14px;
    font-weight: 500;
    color: #6b7280;
  }

  .stat-number {
    margin: 0;
    font-size: 32px;
    font-weight: 700;
    color: #111827;
  }

  .chat-controls h3 {
    margin: 0 0 16px 0;
    font-size: 16px;
    font-weight: 600;
    color: #111827;
  }

  .control-buttons {
    display: flex;
    gap: 12px;
    flex-wrap: wrap;
  }

  /* 表格操作 */
  .table-actions {
    display: flex;
    gap: 8px;
  }

  /* 移动端适配 */
  @media (max-width: 768px) {
    .master-header {
      flex-direction: column;
      gap: 12px;
      padding: 12px 16px;
    }

    .header-left h1 {
      font-size: 20px;
      text-align: center;
    }

    .stats-overview {
      justify-content: center;
      flex-wrap: wrap;
      gap: 12px;
    }

    .header-right {
      justify-content: center;
    }

    .top-tabs {
      overflow-x: auto;
      scrollbar-width: none;
      -ms-overflow-style: none;
    }

    .top-tabs::-webkit-scrollbar {
      display: none;
    }

    .tab {
      padding: 8px 16px;
      font-size: 13px;
    }

    .tab-icon {
      font-size: 16px;
    }

    .master-content {
      padding: 16px;
    }

    .chat-stats {
      grid-template-columns: repeat(2, 1fr);
    }

    .stat-number {
      font-size: 24px;
    }

    .control-buttons {
      flex-direction: column;
    }

    .table-actions {
      flex-direction: column;
      gap: 4px;
    }
  }

  /* 深色模式 */
  @media (prefers-color-scheme: dark) {
    .master-container {
      background: #111827;
    }

    .master-header {
      background: #1f2937;
      border-bottom-color: #374151;
    }

    .header-left h1 {
      color: #f9fafb;
    }

    .stat-item {
      color: #d1d5db;
    }

    .top-tabs {
      background: #1f2937;
      border-bottom-color: #374151;
    }

    .tab {
      color: #d1d5db;
    }

    .tab:hover {
      color: #f3f4f6;
      background: #374151;
    }

    .tab.active {
      background: #374151;
    }

    .stat-card {
      background: #374151;
      border-color: #4b5563;
    }

    .stat-card h3 {
      color: #d1d5db;
    }

    .stat-number {
      color: #f9fafb;
    }

    .chat-controls h3 {
      color: #f9fafb;
    }
  }

  /* 无障碍支持 */
  @media (prefers-reduced-motion: reduce) {
    .loading-spinner {
      animation: none;
    }

    .tab {
      transition: none;
    }
  }

  /* 打印样式 */
  @media print {
    .master-header,
    .top-tabs {
      display: none;
    }

    .master-content {
      padding: 0;
    }
  }
</style> 