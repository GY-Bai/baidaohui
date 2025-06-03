<script lang="ts">
  import { onMount } from 'svelte';
  import { clientSideRouteGuard, signOut } from '$lib/auth';
  
  // 导入新的UI组件
  import UserProfileDropdown from '$lib/components/ui/UserProfileDropdown.svelte';
  import OnlineStatusIndicator from '$lib/components/ui/OnlineStatusIndicator.svelte';
  import Avatar from '$lib/components/ui/Avatar.svelte';
  import Button from '$lib/components/ui/Button.svelte';
  import Badge from '$lib/components/ui/Badge.svelte';
  import Card from '$lib/components/ui/Card.svelte';
  import ActivityLogList from '$lib/components/ui/ActivityLogList.svelte';
  import InviteLinkGenerator from '$lib/components/ui/InviteLinkGenerator.svelte';
  import ApiKeyManager from '$lib/components/ui/ApiKeyManager.svelte';
  import DataTable from '$lib/components/ui/DataTable.svelte';

  let loading = true;
  let authenticated = false;
  let activeTab = 'activity'; // 默认显示活动日志
  let showDropdown = false;

  // 模拟用户数据
  const firstmateUser = {
    id: 'firstmate',
    name: '助理小王',
    username: 'firstmate_wang',
    email: 'firstmate@baidaohui.com',
    avatar: 'https://api.dicebear.com/7.x/avataaars/svg?seed=firstmate',
    status: 'online',
    verified: true,
    role: 'Firstmate',
    bio: '百道慧资深助理，协助管理日常事务',
    location: '上海市',
    joinDate: '2023-06-01',
    stats: {
      assistedOrders: 1247,
      generatedLinks: 89,
      resolvedIssues: 456
    }
  };

  // 模拟组织数据
  const organization = {
    id: '1',
    name: '百道慧',
    domain: 'https://baidaohui.com'
  };

  // 模拟活动日志数据（助理操作）
  const mockActivities = [
    {
      id: '1',
      type: 'assistant.link_generated',
      description: '助理生成了Member邀请链接',
      status: 'success',
      createdAt: new Date(),
      user: firstmateUser,
      details: { linkType: 'Member', validFor: '24小时', maxUses: 50 }
    },
    {
      id: '2',
      type: 'assistant.fortune_assisted',
      description: '协助回复算命订单 #F001',
      status: 'success',
      createdAt: new Date(Date.now() - 300000),
      user: firstmateUser,
      details: { orderId: 'F001', customer: '张三', responseTime: '15分钟' }
    },
    {
      id: '3',
      type: 'assistant.user_support',
      description: '处理用户支持请求',
      status: 'success',
      createdAt: new Date(Date.now() - 600000),
      user: firstmateUser,
      details: { ticketId: 'T123', category: '账户问题', resolution: '账户激活' }
    },
    {
      id: '4',
      type: 'assistant.content_review',
      description: '审核用户提交的算命申请',
      status: 'success',
      createdAt: new Date(Date.now() - 900000),
      user: firstmateUser,
      details: { applicationId: 'A456', decision: '通过', notes: '内容符合规范' }
    },
    {
      id: '5',
      type: 'assistant.data_export',
      description: '导出用户数据报告',
      status: 'success',
      createdAt: new Date(Date.now() - 1200000),
      user: firstmateUser,
      details: { reportType: '月度用户活跃度', fileSize: '2.5MB', format: 'Excel' }
    }
  ];

  // 模拟API密钥数据（助理权限）
  const mockApiKeys = [
    {
      id: '1',
      name: '助理监控密钥',
      description: '用于助理监控系统状态的只读API密钥',
      key: 'bah_assistant_1234567890abcdef1234567890abcdef',
      permissions: 'read',
      rateLimit: 3000,
      expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
      createdAt: new Date('2024-01-10'),
      lastUsed: new Date('2024-01-20'),
      usageCount: 5678,
      isActive: true
    }
  ];

  onMount(async () => {
    // 使用客户端路由守卫
    authenticated = await clientSideRouteGuard('Firstmate');
    loading = false;
  });

  async function handleSignOut() {
    await signOut();
  }

  const tabs = [
    { 
      id: 'invite', 
      name: '助理生成链接', 
      icon: '🔗',
      description: '协助生成邀请链接',
      disabled: false
    },
    { 
      id: 'fortune', 
      name: '协助回复', 
      icon: '🔮',
      description: '协助处理算命申请',
      disabled: false
    },
    { 
      id: 'ecommerce', 
      name: '电商管理', 
      icon: '🛍️',
      description: '管理商户API密钥',
      disabled: false
    },
    { 
      id: 'chat', 
      name: '群聊管理', 
      icon: '💬',
      description: '仅群聊功能，私聊权限受限',
      disabled: true // 私聊功能灰显
    },
    { 
      id: 'activity', 
      name: '活动日志', 
      icon: '📊',
      description: '查看助理操作记录'
    }
  ];

  function setActiveTab(tabId) {
    if (tabs.find(t => t.id === tabId)?.disabled) {
      return; // 禁用的标签不可点击
    }
    activeTab = tabId;
  }

  function getTabTitle() {
    const tab = tabs.find(t => t.id === activeTab);
    return tab ? tab.name : '助理工作台';
  }

  // 处理邀请链接事件
  function handleLinkGenerated(event) {
    console.log('助理生成邀请链接:', event.detail);
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
    console.log('正在导出助理操作日志...');
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

  // 模拟算命订单数据（助理视角）
  const mockFortuneOrders = [
    {
      id: 'F004',
      user: '李华',
      userId: '234',
      amount: '$40 CAD',
      priority: 'normal',
      status: 'review_required',
      assignedTo: '教主',
      createdAt: '2024-01-20',
      description: '关于投资理财的咨询...',
      assistantNotes: '需要重点关注风险评估部分'
    },
    {
      id: 'F005',
      user: '王芳',
      userId: '345',
      amount: '$60 CAD',
      priority: 'high',
      status: 'draft_ready',
      assignedTo: '教主',
      createdAt: '2024-01-19',
      description: '婚姻感情问题咨询...',
      assistantNotes: '已准备初步回复草稿，等待审核'
    }
  ];

  // 表格列定义
  const fortuneColumns = [
    { key: 'id', label: '订单ID', sortable: true },
    { key: 'user', label: '用户', sortable: true },
    { key: 'amount', label: '金额', sortable: true },
    { key: 'priority', label: '优先级', sortable: true },
    { key: 'status', label: '状态', sortable: true },
    { key: 'assignedTo', label: '负责人', sortable: true },
    { key: 'assistantNotes', label: '助理备注', sortable: false },
    { key: 'actions', label: '操作', sortable: false }
  ];

  function getStatusBadgeVariant(status) {
    switch (status) {
      case 'review_required': return 'warning';
      case 'draft_ready': return 'info';
      case 'completed': return 'success';
      case 'cancelled': return 'error';
      default: return 'secondary';
    }
  }

  function getStatusText(status) {
    switch (status) {
      case 'review_required': return '需要审核';
      case 'draft_ready': return '草稿准备就绪';
      case 'completed': return '已完成';
      case 'cancelled': return '已取消';
      default: return status;
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

  function handleOrderAction(orderId, action) {
    console.log(`助理对订单 ${orderId} 执行操作: ${action}`);
  }
</script>

<svelte:head>
  <title>{getTabTitle()} - 百道慧助理工作台</title>
</svelte:head>

{#if loading}
  <div class="loading-screen">
    <div class="loading-content">
      <div class="loading-spinner"></div>
      <p>正在验证身份...</p>
    </div>
  </div>
{:else if authenticated}
  <div class="firstmate-container">
    <!-- 顶部头部 -->
    <header class="firstmate-header">
      <div class="header-left">
        <h1>👩‍💼 Firstmate助理工作台</h1>
        <Badge variant="warning" size="sm">助理模式</Badge>
        <div class="stats-overview">
          <span class="stat-item">{firstmateUser.stats.assistedOrders} 协助订单</span>
          <span class="stat-item">{firstmateUser.stats.generatedLinks} 生成链接</span>
          <span class="stat-item">{firstmateUser.stats.resolvedIssues} 解决问题</span>
        </div>
      </div>
      
      <div class="header-right">
        <UserProfileDropdown 
          user={firstmateUser}
          bind:visible={showDropdown}
          on:menuClick={handleMenuClick}
          on:statusChange={handleStatusChange}
        />
        <Button variant="ghost" on:click={() => showDropdown = !showDropdown}>
          <Avatar src={firstmateUser.avatar} size="sm" />
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
          class:disabled={tab.disabled}
          on:click={() => setActiveTab(tab.id)}
          title={tab.description}
          disabled={tab.disabled}
        >
          <span class="tab-icon">{tab.icon}</span>
          <span class="tab-label">{tab.name}</span>
          {#if tab.disabled}
            <span class="disabled-indicator">🔒</span>
          {/if}
        </button>
      {/each}
    </nav>

    <!-- 主要内容区域 -->
    <main class="firstmate-content">
      {#if activeTab === 'invite'}
        <!-- 助理生成邀请链接 -->
        <div class="content-section">
          <Card variant="elevated">
            <div slot="header" class="section-header">
              <h2>🔗 助理生成邀请链接</h2>
              <Badge variant="info" size="sm">助理权限</Badge>
            </div>
            
            <InviteLinkGenerator
              {organization}
              user={firstmateUser}
              showAdvanced={false}
              assistantMode={true}
              on:linkGenerated={handleLinkGenerated}
              on:linkCopied={handleLinkCopied}
            />
          </Card>
        </div>
        
      {:else if activeTab === 'fortune'}
        <!-- 协助算命回复 -->
        <div class="content-section">
          <Card variant="elevated">
            <div slot="header" class="section-header">
              <h2>🔮 协助算命回复</h2>
              <Badge variant="info" size="sm">协助模式</Badge>
            </div>
            
            <DataTable
              data={mockFortuneOrders}
              columns={fortuneColumns}
              searchable={true}
              sortable={true}
              pagination={true}
              pageSize={10}
              showSelection={false}
              emptyMessage="暂无需要协助的订单"
            >
              <svelte:fragment slot="cell" let:row let:column>
                {#if column.key === 'priority'}
                  <Badge variant={getPriorityBadgeVariant(row.priority)} size="sm">
                    {row.priority === 'urgent' ? '紧急' : 
                     row.priority === 'high' ? '高' : '普通'}
                  </Badge>
                {:else if column.key === 'status'}
                  <Badge variant={getStatusBadgeVariant(row.status)} size="sm">
                    {getStatusText(row.status)}
                  </Badge>
                {:else if column.key === 'assistantNotes'}
                  <span class="assistant-notes">{row.assistantNotes}</span>
                {:else if column.key === 'actions'}
                  <div class="table-actions">
                    <Button variant="outline" size="xs" on:click={() => handleOrderAction(row.id, 'view')}>
                      查看
                    </Button>
                    {#if row.status === 'review_required'}
                      <Button variant="primary" size="xs" on:click={() => handleOrderAction(row.id, 'draft')}>
                        准备草稿
                      </Button>
                    {:else if row.status === 'draft_ready'}
                      <Button variant="success" size="xs" on:click={() => handleOrderAction(row.id, 'submit')}>
                        提交审核
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
        <!-- 电商管理（助理权限） -->
        <div class="content-section">
          <Card variant="elevated">
            <div slot="header" class="section-header">
              <h2>🛍️ API密钥管理</h2>
              <Badge variant="warning" size="sm">只读权限</Badge>
            </div>
            
            <ApiKeyManager
              keys={mockApiKeys}
              canCreate={false}
              canRevoke={false}
              canEdit={false}
              readOnly={true}
              on:keyCreated={handleKeyCreated}
              on:keyRevoked={handleKeyRevoked}
              on:keyDeleted={handleKeyDeleted}
            />
          </Card>
        </div>
        
      {:else if activeTab === 'chat'}
        <!-- 群聊管理（私聊功能受限） -->
        <div class="content-section">
          <Card variant="elevated">
            <div slot="header" class="section-header">
              <h2>💬 群聊管理</h2>
              <Badge variant="secondary" size="sm">仅群聊</Badge>
            </div>
            
            <div class="chat-management">
              <div class="access-notice">
                <p><strong>权限说明：</strong>助理只能管理群聊功能，私聊管理需要Master权限。</p>
              </div>
              
              <div class="chat-stats">
                <div class="stat-card">
                  <h3>活跃群聊</h3>
                  <p class="stat-number">3</p>
                </div>
                <div class="stat-card">
                  <h3>群聊成员</h3>
                  <p class="stat-number">1,247</p>
                </div>
                <div class="stat-card">
                  <h3>今日群聊消息</h3>
                  <p class="stat-number">1,856</p>
                </div>
              </div>
              
              <div class="chat-controls">
                <h3>群聊操作</h3>
                <div class="control-buttons">
                  <Button variant="primary" size="sm">发送群聊公告</Button>
                  <Button variant="outline" size="sm">导出群聊记录</Button>
                  <Button variant="outline" size="sm">管理群聊成员</Button>
                  <Button variant="secondary" size="sm" disabled>私聊管理 🔒</Button>
                </div>
              </div>
            </div>
          </Card>
        </div>
        
      {:else if activeTab === 'activity'}
        <!-- 活动日志 -->
        <div class="content-section">
          <Card variant="elevated">
            <div slot="header" class="section-header">
              <h2>📊 助理活动日志</h2>
              <Badge variant="success" size="sm">实时更新</Badge>
            </div>
            
            <ActivityLogList
              activities={mockActivities}
              pagination={{ page: 1, size: 20, total: 150 }}
              showFilters={true}
              showExport={true}
              filterByUser={firstmateUser.id}
              on:filterChange={handleFilterChange}
              on:export={handleExport}
              on:activityClick={handleActivityClick}
            />
          </Card>
        </div>
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
    background: linear-gradient(135deg, #8b5cf6 0%, #a78bfa 100%);
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

  .firstmate-container {
    min-height: 100vh;
    background: #f8fafc;
    display: flex;
    flex-direction: column;
  }

  /* 头部样式 */
  .firstmate-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 16px 24px;
    background: white;
    border-bottom: 1px solid #e5e7eb;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  }

  .header-left {
    display: flex;
    align-items: center;
    gap: 12px;
    flex-wrap: wrap;
  }

  .header-left h1 {
    margin: 0;
    font-size: 24px;
    font-weight: 700;
    color: #111827;
  }

  .stats-overview {
    display: flex;
    gap: 16px;
    font-size: 14px;
    margin-left: 16px;
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
    position: relative;
  }

  .tab:hover:not(.disabled) {
    color: #374151;
    background: #f9fafb;
  }

  .tab.active {
    color: #8b5cf6;
    border-bottom-color: #8b5cf6;
    background: #f8fafc;
  }

  .tab.disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .tab-icon {
    font-size: 18px;
  }

  .tab-label {
    font-size: 14px;
  }

  .disabled-indicator {
    font-size: 12px;
    margin-left: 4px;
  }

  /* 主要内容 */
  .firstmate-content {
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

  .section-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 0;
  }

  .section-header h2 {
    margin: 0;
    font-size: 18px;
    font-weight: 600;
    color: #111827;
  }

  /* 聊天管理样式 */
  .chat-management {
    display: flex;
    flex-direction: column;
    gap: 24px;
  }

  .access-notice {
    padding: 16px;
    background: #fef3c7;
    border: 1px solid #fbbf24;
    border-radius: 8px;
    color: #92400e;
  }

  .access-notice p {
    margin: 0;
    font-size: 14px;
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

  .assistant-notes {
    font-style: italic;
    color: #6b7280;
    font-size: 13px;
  }

  /* 移动端适配 */
  @media (max-width: 768px) {
    .firstmate-header {
      flex-direction: column;
      gap: 12px;
      padding: 12px 16px;
    }

    .header-left {
      flex-direction: column;
      text-align: center;
      gap: 8px;
    }

    .header-left h1 {
      font-size: 20px;
    }

    .stats-overview {
      justify-content: center;
      flex-wrap: wrap;
      gap: 12px;
      margin-left: 0;
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

    .firstmate-content {
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

    .section-header {
      flex-direction: column;
      gap: 8px;
      align-items: flex-start;
    }
  }

  /* 深色模式 */
  @media (prefers-color-scheme: dark) {
    .firstmate-container {
      background: #111827;
    }

    .firstmate-header {
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

    .tab:hover:not(.disabled) {
      color: #f3f4f6;
      background: #374151;
    }

    .tab.active {
      background: #374151;
    }

    .section-header h2 {
      color: #f9fafb;
    }

    .access-notice {
      background: #451a03;
      border-color: #d97706;
      color: #fbbf24;
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

    .assistant-notes {
      color: #d1d5db;
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
</style> 