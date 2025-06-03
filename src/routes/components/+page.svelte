<script>
  import { onMount } from 'svelte';
  
  // 导入基础组件
  import DataTable from '$lib/components/ui/DataTable.svelte';
  import Pagination from '$lib/components/ui/Pagination.svelte';
  import Card from '$lib/components/ui/Card.svelte';
  import Skeleton from '$lib/components/ui/Skeleton.svelte';
  import Toast from '$lib/components/ui/Toast.svelte';
  import Alert from '$lib/components/ui/Alert.svelte';
  import Progress from '$lib/components/ui/Progress.svelte';
  import Badge from '$lib/components/ui/Badge.svelte';
  import Avatar from '$lib/components/ui/Avatar.svelte';
  import Button from '$lib/components/ui/Button.svelte';
  import Input from '$lib/components/ui/Input.svelte';
  import Select from '$lib/components/ui/Select.svelte';
  
  // 导入聊天和用户组件
  import ChatHeader from '$lib/components/ui/ChatHeader.svelte';
  import OnlineStatusIndicator from '$lib/components/ui/OnlineStatusIndicator.svelte';
  import UserProfileCard from '$lib/components/ui/UserProfileCard.svelte';
  import UserProfileDropdown from '$lib/components/ui/UserProfileDropdown.svelte';
  
  // 导入管理组件
  import InviteLinkGenerator from '$lib/components/ui/InviteLinkGenerator.svelte';
  import QRCodeModal from '$lib/components/ui/QRCodeModal.svelte';
  import ApiKeyManager from '$lib/components/ui/ApiKeyManager.svelte';
  import ActivityLogList from '$lib/components/ui/ActivityLogList.svelte';
  
  // 状态管理
  let currentView = 'overview';
  let showToast = false;
  let toastMessage = '';
  let showQRModal = false;
  let showDropdown = false;
  
  // 模拟数据
  const mockUser = {
    id: '1',
    name: '张三',
    username: 'zhangsan',
    email: 'zhangsan@example.com',
    avatar: 'https://api.dicebear.com/7.x/avataaars/svg?seed=zhang',
    bio: '百道慧资深用户，专注算命和带货领域',
    status: 'online',
    location: '北京市',
    website: 'https://zhangsan.blog',
    joinDate: '2023-01-15',
    verified: true,
    premium: true,
    stats: {
      followers: 1284,
      following: 567,
      posts: 89
    },
    badges: [
      { label: 'VIP用户', variant: 'warning', icon: '👑' },
      { label: '认证商家', variant: 'success', icon: '✅' }
    ]
  };

  const mockApiKeys = [
    {
      id: '1',
      name: '移动应用API',
      description: '用于移动端应用的API访问',
      key: 'bah_1234567890abcdef1234567890abcdef1234567890',
      permissions: 'read',
      rateLimit: 1000,
      expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
      createdAt: new Date('2024-01-15'),
      lastUsed: new Date('2024-01-20'),
      usageCount: 2580,
      isActive: true
    }
  ];

  const mockActivities = [
    {
      id: '1',
      type: 'user.login',
      description: '用户登录系统',
      status: 'success',
      createdAt: new Date(),
      user: mockUser,
      ip: '192.168.1.100',
      location: '北京市'
    },
    {
      id: '2',
      type: 'api.request',
      description: 'API请求 - 获取用户信息',
      status: 'success',
      createdAt: new Date(Date.now() - 60000),
      user: mockUser,
      ip: '192.168.1.100'
    }
  ];

  // 视图切换
  const views = [
    { id: 'overview', label: '总览', icon: '🏠' },
    { id: 'fan', label: 'Fan用户界面', icon: '👤' },
    { id: 'member', label: 'Member用户界面', icon: '💎' },
    { id: 'master', label: 'Master用户界面', icon: '👨‍💼' },
    { id: 'firstmate', label: 'Firstmate用户界面', icon: '👩‍💼' },
    { id: 'seller', label: 'Seller用户界面', icon: '🏪' }
  ];

  function switchView(viewId) {
    currentView = viewId;
  }

  function handleToast(message) {
    toastMessage = message;
    showToast = true;
  }
</script>

<svelte:head>
  <title>百道慧 - 组件架构演示</title>
  <meta name="description" content="基于Instagram风格的移动端优先组件库" />
</svelte:head>

<div class="demo-container">
  <!-- 顶部导航 -->
  <header class="demo-header">
    <div class="header-content">
      <div class="header-info">
        <h1>📱 百道慧前端组件架构演示</h1>
        <p>基于Instagram风格的移动端优先组件库</p>
      </div>
      
      <!-- 角色切换 -->
      <nav class="view-nav">
        {#each views as view}
          <button 
            class="nav-item"
            class:active={currentView === view.id}
            on:click={() => switchView(view.id)}
          >
            <span class="nav-icon">{view.icon}</span>
            <span class="nav-label">{view.label}</span>
          </button>
        {/each}
      </nav>
    </div>
  </header>

  <!-- 主要内容区域 -->
  <main class="demo-main">
    {#if currentView === 'overview'}
      <!-- 总览页面 -->
      <div class="overview-content">
        <Card variant="elevated" padding="lg">
          <h2 slot="header">🎯 页面结构设计总览</h2>
          
          <div class="architecture-grid">
            <div class="role-card">
              <h3>🔑 FE1: 登录页面</h3>
              <p>baidaohui.com</p>
              <ul>
                <li>Google OAuth 登录</li>
                <li>角色验证和重定向</li>
                <li>居中布局设计</li>
              </ul>
            </div>
            
            <div class="role-card">
              <h3>👤 FE2: Fan用户界面</h3>
              <p>fan.baidaohui.com</p>
              <ul>
                <li>底部导航栏</li>
                <li>私信、算命、带货、个人</li>
                <li>权限提示和申请功能</li>
              </ul>
            </div>
            
            <div class="role-card">
              <h3>💎 FE3: Member用户界面</h3>
              <p>member.baidaohui.com</p>
              <ul>
                <li>增强版私信功能</li>
                <li>实时聊天系统</li>
                <li>WebSocket通信</li>
              </ul>
            </div>
            
            <div class="role-card">
              <h3>👨‍💼 FE4: Master用户界面</h3>
              <p>master.baidaohui.com</p>
              <ul>
                <li>顶部标签导航</li>
                <li>邀请链接、算命管理</li>
                <li>电商管理、聊天管理</li>
              </ul>
            </div>
            
            <div class="role-card">
              <h3>👩‍💼 FE5: Firstmate用户界面</h3>
              <p>firstmate.baidaohui.com</p>
              <ul>
                <li>基于Master布局</li>
                <li>助理模式功能</li>
                <li>活动日志系统</li>
              </ul>
            </div>
            
            <div class="role-card">
              <h3>🏪 FE6: Seller用户界面</h3>
              <p>seller.baidaohui.com</p>
              <ul>
                <li>API密钥管理</li>
                <li>商户信息设置</li>
                <li>教程视频中心</li>
              </ul>
            </div>
          </div>
        </Card>
        
        <!-- 设计原则 -->
        <Card variant="outlined">
          <h2 slot="header">🎨 Instagram风格设计原则</h2>
          
          <div class="principles-grid">
            <div class="principle-item">
              <h4>简洁性</h4>
              <p>避免视觉混乱，突出核心功能</p>
            </div>
            <div class="principle-item">
              <h4>一致性</h4>
              <p>统一的色彩、字体、间距、圆角</p>
            </div>
            <div class="principle-item">
              <h4>即时反馈</h4>
              <p>每个操作都有明确的视觉响应</p>
            </div>
            <div class="principle-item">
              <h4>移动端优先</h4>
              <p>底部导航、触摸友好、安全区域</p>
            </div>
          </div>
        </Card>
      </div>
      
    {:else if currentView === 'fan'}
      <!-- Fan用户界面演示 -->
      <div class="mobile-demo">
        <div class="mobile-frame">
          <div class="mobile-content">
            <!-- 模拟Fan界面 -->
            <div class="fan-header">
              <h2>🔮 算命申请</h2>
              <Button variant="primary" size="sm">+ 新建申请</Button>
            </div>
            
            <!-- 权限提示卡片 -->
            <Alert type="warning" showIcon>
              您还不是会员，无法使用私信功能。
              <Button slot="action" variant="outline" size="xs">完成会员认证</Button>
            </Alert>
            
            <!-- 模拟算命申请列表 -->
            <Card variant="outlined">
              <h3 slot="header">我的申请</h3>
              <div class="request-item">
                <div class="request-header">
                  <Badge variant="error" size="sm">紧急</Badge>
                  <Badge variant="secondary" size="sm">排队第3位</Badge>
                </div>
                <p>关于事业发展的问题...</p>
                <div class="request-meta">
                  <span>金额: $50 CAD</span>
                  <span>剩余修改: 2次</span>
                </div>
              </div>
            </Card>
            
            <!-- 底部导航栏 -->
            <div class="bottom-dock">
              <div class="dock-item active">
                <span>💬</span>
                <span>私信</span>
              </div>
              <div class="dock-item">
                <span>🔮</span>
                <span>算命</span>
              </div>
              <div class="dock-item">
                <span>🛍️</span>
                <span>带货</span>
              </div>
              <div class="dock-item">
                <span>👤</span>
                <span>个人</span>
              </div>
            </div>
          </div>
        </div>
      </div>
      
    {:else if currentView === 'member'}
      <!-- Member用户界面演示 -->
      <div class="mobile-demo">
        <div class="mobile-frame">
          <div class="mobile-content">
            <!-- 聊天头部 -->
            <ChatHeader
              user={mockUser}
              chatTitle="与主播的私信"
              typing={true}
              typingUsers={['主播']}
              on:back={() => handleToast('返回聊天列表')}
              on:action={(e) => handleToast(`执行操作: ${e.detail.action.label}`)}
            />
            
            <!-- 消息列表区域 -->
            <div class="chat-messages">
              <div class="message received">
                <Avatar src={mockUser.avatar} size="sm" />
                <div class="message-content">
                  <p>你好！欢迎来到百道慧</p>
                  <span class="message-time">14:30</span>
                </div>
              </div>
              
              <div class="message sent">
                <div class="message-content">
                  <p>谢谢！我想了解一下算命服务</p>
                  <span class="message-time">14:32</span>
                </div>
              </div>
              
              <div class="typing-indicator">
                <Avatar src={mockUser.avatar} size="sm" />
                <div class="typing-dots">
                  <span></span>
                  <span></span>
                  <span></span>
                </div>
              </div>
            </div>
            
            <!-- 输入区域 -->
            <div class="chat-input">
              <Input placeholder="输入消息..." />
              <Button variant="primary" size="sm">发送</Button>
            </div>
          </div>
        </div>
      </div>
      
    {:else if currentView === 'master'}
      <!-- Master用户界面演示 -->
      <div class="desktop-demo">
        <!-- 顶部头部 -->
        <div class="master-header">
          <div class="header-left">
            <h2>🏢 Master管理面板</h2>
          </div>
          
          <div class="header-right">
            <UserProfileDropdown 
              user={mockUser}
              bind:visible={showDropdown}
              on:menuClick={(e) => handleToast(`点击菜单: ${e.detail.item.label}`)}
              on:statusChange={(e) => handleToast(`状态变更: ${e.detail.status}`)}
            />
            <Button variant="ghost" on:click={() => showDropdown = !showDropdown}>
              <Avatar src={mockUser.avatar} size="sm" />
              <OnlineStatusIndicator status="online" position="bottom-right" size="xs" />
            </Button>
          </div>
        </div>
        
        <!-- 顶部标签导航 -->
        <div class="top-tabs">
          <button class="tab active">🔗 邀请链接</button>
          <button class="tab">🔮 算命管理</button>
          <button class="tab">🛍️ 电商管理</button>
          <button class="tab">💬 聊天管理</button>
        </div>
        
        <!-- 内容区域 -->
        <div class="master-content">
          <InviteLinkGenerator
            organization={{ id: '1', name: '百道慧', domain: 'https://baidaohui.com' }}
            user={mockUser}
            showAdvanced={true}
            on:linkGenerated={(e) => handleToast('邀请链接已生成')}
            on:linkCopied={() => handleToast('链接已复制')}
          />
        </div>
      </div>
      
    {:else if currentView === 'firstmate'}
      <!-- Firstmate用户界面演示 -->
      <div class="desktop-demo">
        <!-- 头部 -->
        <div class="master-header">
          <div class="header-left">
            <h2>👩‍💼 Firstmate助理面板</h2>
            <Badge variant="warning" size="sm">助理模式</Badge>
          </div>
          
          <div class="header-right">
            <UserProfileDropdown 
              user={{...mockUser, role: 'Firstmate'}}
              bind:visible={showDropdown}
            />
            <Button variant="ghost" on:click={() => showDropdown = !showDropdown}>
              <Avatar src={mockUser.avatar} size="sm" />
            </Button>
          </div>
        </div>
        
        <!-- 标签导航 -->
        <div class="top-tabs">
          <button class="tab">🔗 助理生成链接</button>
          <button class="tab">🔮 协助回复</button>
          <button class="tab">🛍️ 电商管理</button>
          <button class="tab active">📊 活动日志</button>
        </div>
        
        <!-- 活动日志 -->
        <div class="master-content">
          <ActivityLogList
            activities={mockActivities}
            pagination={{ page: 1, size: 20, total: 50 }}
            showFilters={true}
            showExport={true}
            on:filterChange={() => handleToast('筛选条件已更新')}
            on:export={() => handleToast('正在导出日志...')}
            on:activityClick={(e) => handleToast(`查看活动详情: ${e.detail.activity.description}`)}
          />
        </div>
      </div>
      
    {:else if currentView === 'seller'}
      <!-- Seller用户界面演示 -->
      <div class="desktop-demo">
        <!-- 头部 -->
        <div class="master-header">
          <div class="header-left">
            <h2>🏪 Seller商户面板</h2>
          </div>
          
          <div class="header-right">
            <UserProfileDropdown 
              user={{...mockUser, role: 'Seller'}}
              bind:visible={showDropdown}
            />
            <Button variant="ghost" on:click={() => showDropdown = !showDropdown}>
              <Avatar src={mockUser.avatar} size="sm" />
            </Button>
          </div>
        </div>
        
        <!-- 标签导航 -->
        <div class="top-tabs">
          <button class="tab active">🔑 密钥管理</button>
          <button class="tab">ℹ️ 信息设置</button>
          <button class="tab">📺 教程视频</button>
        </div>
        
        <!-- API密钥管理 -->
        <div class="master-content">
          <ApiKeyManager
            keys={mockApiKeys}
            canCreate={true}
            canRevoke={true}
            canEdit={true}
            on:keyCreated={() => handleToast('API密钥创建成功')}
            on:keyRevoked={() => handleToast('API密钥已撤销')}
            on:keyDeleted={() => handleToast('API密钥已删除')}
          />
        </div>
      </div>
    {/if}
  </main>
</div>

<!-- QR码模态框 -->
<QRCodeModal
  bind:visible={showQRModal}
  title="邀请链接二维码"
  qrData="https://baidaohui.com/invite/ABCD1234"
  description="扫描二维码加入百道慧"
  on:close={() => showQRModal = false}
  on:download={() => handleToast('二维码已下载')}
  on:share={() => handleToast('二维码已分享')}
/>

<!-- Toast消息 -->
{#if showToast}
  <Toast
    type="success"
    message={toastMessage}
    duration={3000}
    bind:visible={showToast}
  />
{/if}

<style>
  .demo-container {
    min-height: 100vh;
    background: #f8fafc;
  }
  
  /* 头部导航 */
  .demo-header {
    background: white;
    border-bottom: 1px solid #e5e7eb;
    position: sticky;
    top: 0;
    z-index: 100;
  }
  
  .header-content {
    max-width: 1400px;
    margin: 0 auto;
    padding: 16px 24px;
  }
  
  .header-info h1 {
    margin: 0 0 4px 0;
    font-size: 24px;
    font-weight: 700;
    color: #111827;
  }
  
  .header-info p {
    margin: 0 0 16px 0;
    color: #6b7280;
    font-size: 14px;
  }
  
  .view-nav {
    display: flex;
    gap: 4px;
    overflow-x: auto;
  }
  
  .nav-item {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 4px;
    padding: 8px 12px;
    border: none;
    background: transparent;
    border-radius: 8px;
    cursor: pointer;
    transition: all 0.2s ease;
    white-space: nowrap;
  }
  
  .nav-item:hover {
    background: #f3f4f6;
  }
  
  .nav-item.active {
    background: #667eea;
    color: white;
  }
  
  .nav-icon {
    font-size: 20px;
  }
  
  .nav-label {
    font-size: 12px;
    font-weight: 500;
  }
  
  /* 主要内容 */
  .demo-main {
    max-width: 1400px;
    margin: 0 auto;
    padding: 24px;
  }
  
  /* 总览页面 */
  .overview-content {
    display: flex;
    flex-direction: column;
    gap: 24px;
  }
  
  .architecture-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
    gap: 20px;
  }
  
  .role-card {
    padding: 20px;
    background: #f9fafb;
    border-radius: 12px;
    border: 1px solid #e5e7eb;
  }
  
  .role-card h3 {
    margin: 0 0 8px 0;
    font-size: 16px;
    font-weight: 600;
    color: #111827;
  }
  
  .role-card p {
    margin: 0 0 12px 0;
    font-size: 13px;
    color: #6b7280;
    font-family: monospace;
  }
  
  .role-card ul {
    margin: 0;
    padding-left: 16px;
    color: #374151;
    font-size: 14px;
  }
  
  .role-card li {
    margin-bottom: 4px;
  }
  
  .principles-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 16px;
  }
  
  .principle-item {
    text-align: center;
    padding: 16px;
  }
  
  .principle-item h4 {
    margin: 0 0 8px 0;
    font-size: 16px;
    font-weight: 600;
    color: #111827;
  }
  
  .principle-item p {
    margin: 0;
    font-size: 14px;
    color: #6b7280;
    line-height: 1.4;
  }
  
  /* 移动端演示 */
  .mobile-demo {
    display: flex;
    justify-content: center;
    padding: 40px 20px;
  }
  
  .mobile-frame {
    width: 375px;
    height: 667px;
    background: #000;
    border-radius: 25px;
    padding: 10px;
    box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
  }
  
  .mobile-content {
    width: 100%;
    height: 100%;
    background: white;
    border-radius: 20px;
    overflow: hidden;
    display: flex;
    flex-direction: column;
    position: relative;
  }
  
  /* Fan界面样式 */
  .fan-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 16px 20px;
    border-bottom: 1px solid #f3f4f6;
  }
  
  .fan-header h2 {
    margin: 0;
    font-size: 18px;
    font-weight: 600;
  }
  
  .request-item {
    padding: 16px;
    border-bottom: 1px solid #f3f4f6;
  }
  
  .request-header {
    display: flex;
    gap: 8px;
    margin-bottom: 8px;
  }
  
  .request-meta {
    display: flex;
    gap: 16px;
    font-size: 12px;
    color: #6b7280;
    margin-top: 8px;
  }
  
  .bottom-dock {
    position: absolute;
    bottom: 0;
    left: 0;
    right: 0;
    display: flex;
    background: white;
    border-top: 1px solid #f3f4f6;
    padding: 8px 0;
  }
  
  .dock-item {
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 4px;
    padding: 8px;
    font-size: 12px;
    color: #6b7280;
    cursor: pointer;
  }
  
  .dock-item.active {
    color: #667eea;
  }
  
  .dock-item span:first-child {
    font-size: 24px;
  }
  
  /* 聊天界面样式 */
  .chat-messages {
    flex: 1;
    padding: 16px;
    overflow-y: auto;
    display: flex;
    flex-direction: column;
    gap: 16px;
  }
  
  .message {
    display: flex;
    gap: 8px;
    align-items: flex-start;
  }
  
  .message.sent {
    flex-direction: row-reverse;
  }
  
  .message-content {
    max-width: 80%;
    padding: 8px 12px;
    border-radius: 12px;
    position: relative;
  }
  
  .message.received .message-content {
    background: #f3f4f6;
    color: #374151;
  }
  
  .message.sent .message-content {
    background: #667eea;
    color: white;
  }
  
  .message-time {
    font-size: 10px;
    opacity: 0.7;
    display: block;
    margin-top: 4px;
  }
  
  .typing-indicator {
    display: flex;
    gap: 8px;
    align-items: center;
  }
  
  .typing-dots {
    display: flex;
    gap: 4px;
    padding: 8px 12px;
    background: #f3f4f6;
    border-radius: 12px;
  }
  
  .typing-dots span {
    width: 6px;
    height: 6px;
    background: #9ca3af;
    border-radius: 50%;
    animation: typingDot 1.4s infinite ease-in-out;
  }
  
  .typing-dots span:nth-child(1) { animation-delay: 0s; }
  .typing-dots span:nth-child(2) { animation-delay: 0.2s; }
  .typing-dots span:nth-child(3) { animation-delay: 0.4s; }
  
  @keyframes typingDot {
    0%, 80%, 100% { transform: scale(0.8); opacity: 0.5; }
    40% { transform: scale(1); opacity: 1; }
  }
  
  .chat-input {
    display: flex;
    gap: 8px;
    padding: 16px;
    border-top: 1px solid #f3f4f6;
  }
  
  /* 桌面端演示 */
  .desktop-demo {
    background: white;
    border-radius: 12px;
    box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
    overflow: hidden;
    min-height: 800px;
  }
  
  .master-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 16px 24px;
    border-bottom: 1px solid #e5e7eb;
    background: white;
  }
  
  .header-left {
    display: flex;
    align-items: center;
    gap: 12px;
  }
  
  .header-left h2 {
    margin: 0;
    font-size: 20px;
    font-weight: 600;
    color: #111827;
  }
  
  .header-right {
    display: flex;
    align-items: center;
    gap: 12px;
    position: relative;
  }
  
  .top-tabs {
    display: flex;
    background: #f9fafb;
    border-bottom: 1px solid #e5e7eb;
  }
  
  .tab {
    padding: 12px 24px;
    border: none;
    background: transparent;
    font-size: 14px;
    font-weight: 500;
    color: #6b7280;
    cursor: pointer;
    border-bottom: 2px solid transparent;
    transition: all 0.2s ease;
  }
  
  .tab:hover {
    color: #374151;
    background: #f3f4f6;
  }
  
  .tab.active {
    color: #667eea;
    border-bottom-color: #667eea;
    background: white;
  }
  
  .master-content {
    padding: 24px;
    min-height: 600px;
  }
  
  /* 移动端适配 */
  @media (max-width: 768px) {
    .header-content {
      padding: 12px 16px;
    }
    
    .header-info h1 {
      font-size: 20px;
    }
    
    .view-nav {
      gap: 2px;
    }
    
    .nav-item {
      padding: 6px 8px;
    }
    
    .nav-icon {
      font-size: 16px;
    }
    
    .nav-label {
      font-size: 10px;
    }
    
    .demo-main {
      padding: 16px;
    }
    
    .mobile-frame {
      width: 100%;
      max-width: 375px;
      height: auto;
      min-height: 600px;
    }
    
    .desktop-demo {
      margin: 0 -16px;
      border-radius: 0;
    }
    
    .master-header {
      flex-direction: column;
      gap: 12px;
      align-items: stretch;
    }
    
    .header-right {
      justify-content: flex-end;
    }
    
    .top-tabs {
      overflow-x: auto;
    }
    
    .tab {
      white-space: nowrap;
      padding: 8px 16px;
      font-size: 13px;
    }
    
    .master-content {
      padding: 16px;
    }
    
    .architecture-grid {
      grid-template-columns: 1fr;
    }
    
    .principles-grid {
      grid-template-columns: repeat(2, 1fr);
    }
  }
  
  /* 深色模式 */
  @media (prefers-color-scheme: dark) {
    .demo-container {
      background: #111827;
    }
    
    .demo-header {
      background: #1f2937;
      border-bottom-color: #374151;
    }
    
    .header-info h1 {
      color: #f9fafb;
    }
    
    .header-info p {
      color: #d1d5db;
    }
    
    .nav-item:hover {
      background: #374151;
    }
    
    .desktop-demo {
      background: #1f2937;
    }
    
    .master-header {
      background: #1f2937;
      border-bottom-color: #374151;
    }
    
    .header-left h2 {
      color: #f9fafb;
    }
    
    .top-tabs {
      background: #374151;
      border-bottom-color: #4b5563;
    }
    
    .tab {
      color: #d1d5db;
    }
    
    .tab:hover {
      color: #f3f4f6;
      background: #4b5563;
    }
    
    .tab.active {
      background: #1f2937;
    }
    
    .role-card {
      background: #374151;
      border-color: #4b5563;
    }
    
    .role-card h3 {
      color: #f9fafb;
    }
    
    .role-card p {
      color: #d1d5db;
    }
    
    .role-card ul {
      color: #e5e7eb;
    }
    
    .principle-item h4 {
      color: #f9fafb;
    }
    
    .principle-item p {
      color: #d1d5db;
    }
  }
  
  /* 减少动画模式 */
  @media (prefers-reduced-motion: reduce) {
    .nav-item,
    .tab {
      transition: none;
    }
    
    .typing-dots span {
      animation: none;
    }
  }
</style> 