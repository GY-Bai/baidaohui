<script lang="ts">
  import { onMount } from 'svelte';
  import { clientSideRouteGuard, signOut } from '$lib/auth';
  
  // 导入新的UI组件
  import UserProfileDropdown from '$lib/components/business/UserProfileDropdown.svelte';
  import OnlineStatusIndicator from '$lib/components/business/OnlineStatusIndicator.svelte';
  import Avatar from '$lib/components/ui/Avatar.svelte';
  import Button from '$lib/components/ui/Button.svelte';
  import Badge from '$lib/components/ui/Badge.svelte';
  import Card from '$lib/components/ui/Card.svelte';
  import ApiKeyManager from '$lib/components/business/ApiKeyManager.svelte';
  import Input from '$lib/components/ui/Input.svelte';
  import Select from '$lib/components/ui/Select.svelte';
  import Toast from '$lib/components/ui/Toast.svelte';

  let loading = true;
  let authenticated = false;
  let activeTab = 'keys'; // 默认显示密钥管理
  let showDropdown = false;
  let showToast = false;
  let toastMessage = '';
  let isFirstTime = false; // 是否首次访问

  // 模拟用户数据
  const sellerUser = {
    id: 'seller',
    name: '商户张老板',
    username: 'seller_zhang',
    email: 'seller@example.com',
    avatar: 'https://api.dicebear.com/7.x/avataaars/svg?seed=seller',
    status: 'online',
    verified: true,
    role: 'Seller',
    bio: '专注优质商品，诚信经营',
    location: '广州市',
    joinDate: '2023-09-01',
    stats: {
      totalProducts: 256,
      totalSales: 18567,
      monthlyRevenue: 89234
    },
    storeInfo: {
      storeName: '张老板精品店',
      storeId: 'STORE_12345',
      city: '广州市',
      email: 'orders@zhangstore.com',
      phone: '13800138000',
      address: '广州市天河区xxx街道xxx号',
      businessLicense: 'GZ123456789',
      isActive: true
    }
  };

  // 模拟API密钥数据
  let mockApiKeys = [
    {
      id: '1',
      name: '主要商品API',
      description: '用于商品上传和管理的主要API密钥',
      key: 'bah_seller_1234567890abcdef1234567890abcdef',
      permissions: 'seller',
      rateLimit: 5000,
      expiresAt: new Date(Date.now() + 60 * 24 * 60 * 60 * 1000),
      createdAt: new Date('2024-01-01'),
      lastUsed: new Date('2024-01-20'),
      usageCount: 12456,
      isActive: true
    },
    {
      id: '2',
      name: '订单查询API',
      description: '用于查询订单状态和发货信息的只读API密钥',
      key: 'bah_seller_readonly_0987654321fedcba0987654321',
      permissions: 'read',
      rateLimit: 2000,
      expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
      createdAt: new Date('2024-01-10'),
      lastUsed: new Date('2024-01-19'),
      usageCount: 5643,
      isActive: true
    }
  ];

  // 商户信息表单数据
  let storeForm = {
    storeName: sellerUser.storeInfo.storeName,
    city: sellerUser.storeInfo.city,
    email: sellerUser.storeInfo.email,
    phone: sellerUser.storeInfo.phone,
    address: sellerUser.storeInfo.address
  };

  // 城市选项
  const cityOptions = [
    { value: '北京市', label: '北京市' },
    { value: '上海市', label: '上海市' },
    { value: '广州市', label: '广州市' },
    { value: '深圳市', label: '深圳市' },
    { value: '杭州市', label: '杭州市' },
    { value: '南京市', label: '南京市' },
    { value: '成都市', label: '成都市' },
    { value: '武汉市', label: '武汉市' }
  ];

  onMount(async () => {
    // 使用客户端路由守卫
    authenticated = await clientSideRouteGuard('Seller');
    loading = false;
    
    // 检查是否首次访问（可以通过API或localStorage判断）
    if (authenticated) {
      // 模拟检查是否有API密钥
      if (mockApiKeys.length === 0) {
        isFirstTime = true;
        activeTab = 'keys';
      }
    }
  });

  async function handleSignOut() {
    await signOut();
  }

  const tabs = [
    { 
      id: 'keys', 
      name: '密钥管理', 
      icon: '🔑',
      description: '管理API密钥和访问权限'
    },
    { 
      id: 'info', 
      name: '信息设置', 
      icon: 'ℹ️',
      description: '设置商户信息和通知'
    },
    { 
      id: 'tutorial', 
      name: '教程视频', 
      icon: '📺',
      description: '观看使用教程和帮助文档'
    }
  ];

  function setActiveTab(tabId) {
    activeTab = tabId;
  }

  function getTabTitle() {
    const tab = tabs.find(t => t.id === activeTab);
    return tab ? tab.name : '商户面板';
  }

  // 处理API密钥事件
  function handleKeyCreated(event) {
    const newKey = event.detail.key;
    mockApiKeys = [...mockApiKeys, newKey];
    showToastMessage('API密钥创建成功！');
    if (isFirstTime) {
      isFirstTime = false;
    }
  }

  function handleKeyRevoked(event) {
    const keyId = event.detail.keyId;
    mockApiKeys = mockApiKeys.map(key => 
      key.id === keyId ? { ...key, isActive: false } : key
    );
    showToastMessage('API密钥已撤销');
  }

  function handleKeyDeleted(event) {
    const keyId = event.detail.keyId;
    mockApiKeys = mockApiKeys.filter(key => key.id !== keyId);
    showToastMessage('API密钥已删除');
  }

  // 处理商户信息保存
  function handleSaveStoreInfo() {
    // 这里应该调用API保存数据
    console.log('保存商户信息:', storeForm);
    
    // 更新用户信息
    sellerUser.storeInfo = {
      ...sellerUser.storeInfo,
      ...storeForm
    };
    
    showToastMessage('商户信息已保存！');
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

  function showToastMessage(message) {
    toastMessage = message;
    showToast = true;
  }

  // 教程视频数据
  const tutorialVideos = [
    {
      id: '1',
      title: 'API密钥创建和管理',
      description: '学习如何创建、管理和使用API密钥',
      duration: '5:30',
      thumbnail: 'https://img.youtube.com/vi/dQw4w9WgXcQ/maxresdefault.jpg',
      videoUrl: 'https://www.youtube.com/embed/dQw4w9WgXcQ'
    },
    {
      id: '2',
      title: '商品上传接口使用',
      description: '详细介绍商品信息上传和更新的API使用方法',
      duration: '8:15',
      thumbnail: 'https://img.youtube.com/vi/dQw4w9WgXcQ/maxresdefault.jpg',
      videoUrl: 'https://www.youtube.com/embed/dQw4w9WgXcQ'
    },
    {
      id: '3',
      title: '订单处理和发货',
      description: '了解订单状态查询和发货信息更新流程',
      duration: '6:45',
      thumbnail: 'https://img.youtube.com/vi/dQw4w9WgXcQ/maxresdefault.jpg',
      videoUrl: 'https://www.youtube.com/embed/dQw4w9WgXcQ'
    },
    {
      id: '4',
      title: '数据统计和报表',
      description: '查看销售数据和生成各类统计报表',
      duration: '7:20',
      thumbnail: 'https://img.youtube.com/vi/dQw4w9WgXcQ/maxresdefault.jpg',
      videoUrl: 'https://www.youtube.com/embed/dQw4w9WgXcQ'
    }
  ];

  let currentVideo = null;

  function playVideo(video) {
    currentVideo = video;
  }

  function closeVideo() {
    currentVideo = null;
  }
</script>

<svelte:head>
  <title>{getTabTitle()} - 百刀会商户面板</title>
</svelte:head>

{#if loading}
  <div class="loading-screen">
    <div class="loading-content">
      <div class="loading-spinner"></div>
      <p>正在验证身份...</p>
    </div>
  </div>
{:else if authenticated}
  <div class="seller-container">
    {#if isFirstTime}
      <!-- 首次访问欢迎界面 -->
      <div class="welcome-screen">
        <Card variant="elevated" padding="xl">
          <div class="welcome-content">
            <h1>🎉 欢迎加入百刀会商户平台！</h1>
            <p>为了开始使用我们的服务，您需要先创建API密钥来连接您的系统。</p>
            <div class="welcome-steps">
              <div class="step">
                <span class="step-number">1</span>
                <span class="step-text">创建您的第一个API密钥</span>
              </div>
              <div class="step">
                <span class="step-number">2</span>
                <span class="step-text">配置商户信息</span>
              </div>
              <div class="step">
                <span class="step-number">3</span>
                <span class="step-text">观看教程视频</span>
              </div>
            </div>
            <Button variant="primary" size="lg" on:click={() => setActiveTab('keys')}>
              开始创建API密钥
            </Button>
          </div>
        </Card>
      </div>
    {:else}
      <!-- 正常商户界面 -->
      <!-- 顶部头部 -->
      <header class="seller-header">
        <div class="header-left">
          <h1>🏪 商户管理面板</h1>
          <div class="store-info">
            <Badge variant="success" size="sm">
              {sellerUser.storeInfo.storeName}
            </Badge>
            <span class="store-id">ID: {sellerUser.storeInfo.storeId}</span>
          </div>
          <div class="stats-overview">
            <span class="stat-item">{sellerUser.stats.totalProducts} 商品</span>
            <span class="stat-item">{sellerUser.stats.totalSales} 销量</span>
            <span class="stat-item">¥{sellerUser.stats.monthlyRevenue.toLocaleString()} 月收入</span>
          </div>
        </div>
        
        <div class="header-right">
          <UserProfileDropdown 
            user={sellerUser}
            bind:visible={showDropdown}
            on:menuClick={handleMenuClick}
            on:statusChange={handleStatusChange}
          />
          <Button variant="ghost" on:click={() => showDropdown = !showDropdown}>
            <Avatar src={sellerUser.avatar} size="sm" />
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
      <main class="seller-content">
        {#if activeTab === 'keys'}
          <!-- API密钥管理 -->
          <div class="content-section">
            <Card variant="elevated">
              <div slot="header" class="section-header">
                <h2>🔑 API密钥管理</h2>
                <Badge variant="info" size="sm">商户权限</Badge>
              </div>
              
              <ApiKeyManager
                keys={mockApiKeys}
                canCreate={true}
                canRevoke={true}
                canEdit={false}
                sellerMode={true}
                on:keyCreated={handleKeyCreated}
                on:keyRevoked={handleKeyRevoked}
                on:keyDeleted={handleKeyDeleted}
              />
            </Card>
          </div>
          
        {:else if activeTab === 'info'}
          <!-- 商户信息设置 -->
          <div class="content-section">
            <Card variant="elevated">
              <div slot="header" class="section-header">
                <h2>ℹ️ 商户信息设置</h2>
                <Badge variant="secondary" size="sm">基本信息</Badge>
              </div>
              
              <form class="store-form" on:submit|preventDefault={handleSaveStoreInfo}>
                <div class="form-row">
                  <div class="form-group">
                    <label for="storeName">店铺名称</label>
                    <Input
                      id="storeName"
                      bind:value={storeForm.storeName}
                      placeholder="请输入店铺名称"
                      required
                    />
                  </div>
                  
                  <div class="form-group">
                    <label for="city">所在城市</label>
                    <Select
                      id="city"
                      bind:value={storeForm.city}
                      options={cityOptions}
                      placeholder="请选择城市"
                    />
                  </div>
                </div>
                
                <div class="form-row">
                  <div class="form-group">
                    <label for="email">订单通知邮箱</label>
                    <Input
                      id="email"
                      type="email"
                      bind:value={storeForm.email}
                      placeholder="orders@example.com"
                      required
                    />
                  </div>
                  
                  <div class="form-group">
                    <label for="phone">联系电话</label>
                    <Input
                      id="phone"
                      type="tel"
                      bind:value={storeForm.phone}
                      placeholder="请输入联系电话"
                      required
                    />
                  </div>
                </div>
                
                <div class="form-group">
                  <label for="address">详细地址</label>
                  <Input
                    id="address"
                    bind:value={storeForm.address}
                    placeholder="请输入详细地址"
                    required
                  />
                </div>
                
                <div class="form-actions">
                  <Button type="submit" variant="primary">
                    保存设置
                  </Button>
                  <Button type="button" variant="outline">
                    重置
                  </Button>
                </div>
              </form>
            </Card>
            
            <!-- 商户状态卡片 -->
            <Card variant="outlined">
              <h3 slot="header">📊 商户状态</h3>
              
              <div class="status-grid">
                <div class="status-item">
                  <h4>账户状态</h4>
                  <Badge variant="success">正常运营</Badge>
                </div>
                <div class="status-item">
                  <h4>认证状态</h4>
                  <Badge variant="success">已认证</Badge>
                </div>
                <div class="status-item">
                  <h4>API调用</h4>
                  <span class="api-usage">本月已使用 12,456 / 50,000</span>
                </div>
                <div class="status-item">
                  <h4>加入时间</h4>
                  <span>{sellerUser.joinDate}</span>
                </div>
              </div>
            </Card>
          </div>
          
        {:else if activeTab === 'tutorial'}
          <!-- 教程视频 -->
          <div class="content-section">
            <Card variant="elevated">
              <div slot="header" class="section-header">
                <h2>📺 教程视频中心</h2>
                <Badge variant="info" size="sm">学习资源</Badge>
              </div>
              
              <div class="tutorial-grid">
                {#each tutorialVideos as video}
                  <div class="video-card">
                    <div class="video-thumbnail">
                      <img src={video.thumbnail} alt={video.title} />
                      <button class="play-button" on:click={() => playVideo(video)}>
                        ▶️
                      </button>
                      <span class="video-duration">{video.duration}</span>
                    </div>
                    <div class="video-info">
                      <h3>{video.title}</h3>
                      <p>{video.description}</p>
                    </div>
                  </div>
                {/each}
              </div>
            </Card>
          </div>
        {/if}
      </main>
    {/if}
  </div>

  <!-- 视频播放模态框 -->
  {#if currentVideo}
    <div class="video-modal" on:click={closeVideo}>
      <div class="video-modal-content" on:click|stopPropagation>
        <div class="video-modal-header">
          <h3>{currentVideo.title}</h3>
          <button class="close-button" on:click={closeVideo}>✕</button>
        </div>
        <div class="video-player">
          <iframe
            src={currentVideo.videoUrl}
            title={currentVideo.title}
            frameborder="0"
            allowfullscreen
          ></iframe>
        </div>
      </div>
    </div>
  {/if}

  <!-- Toast消息 -->
  {#if showToast}
    <Toast
      type="success"
      message={toastMessage}
      duration={3000}
      bind:visible={showToast}
    />
  {/if}
{/if}

<style>
  .loading-screen {
    min-height: 100vh;
    display: flex;
    align-items: center;
    justify-content: center;
    background: linear-gradient(135deg, #10b981 0%, #059669 100%);
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

  .seller-container {
    min-height: 100vh;
    background: #f8fafc;
    display: flex;
    flex-direction: column;
  }

  /* 欢迎界面 */
  .welcome-screen {
    min-height: 100vh;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 20px;
  }

  .welcome-content {
    text-align: center;
    max-width: 500px;
  }

  .welcome-content h1 {
    margin: 0 0 16px 0;
    font-size: 28px;
    font-weight: 700;
    color: #111827;
  }

  .welcome-content p {
    margin: 0 0 24px 0;
    color: #6b7280;
    line-height: 1.6;
  }

  .welcome-steps {
    display: flex;
    flex-direction: column;
    gap: 12px;
    margin-bottom: 32px;
  }

  .step {
    display: flex;
    align-items: center;
    gap: 12px;
    text-align: left;
  }

  .step-number {
    width: 24px;
    height: 24px;
    background: #10b981;
    color: white;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 12px;
    font-weight: 600;
  }

  .step-text {
    color: #374151;
    font-weight: 500;
  }

  /* 头部样式 */
  .seller-header {
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
    flex-direction: column;
    gap: 8px;
  }

  .header-left h1 {
    margin: 0;
    font-size: 24px;
    font-weight: 700;
    color: #111827;
  }

  .store-info {
    display: flex;
    align-items: center;
    gap: 12px;
  }

  .store-id {
    font-size: 12px;
    color: #6b7280;
    font-family: monospace;
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
    color: #10b981;
    border-bottom-color: #10b981;
    background: #f8fafc;
  }

  .tab-icon {
    font-size: 18px;
  }

  .tab-label {
    font-size: 14px;
  }

  /* 主要内容 */
  .seller-content {
    flex: 1;
    padding: 24px;
    overflow-y: auto;
  }

  .content-section {
    display: flex;
    flex-direction: column;
    gap: 24px;
    max-width: 1000px;
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

  /* 表单样式 */
  .store-form {
    display: flex;
    flex-direction: column;
    gap: 20px;
  }

  .form-row {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 20px;
  }

  .form-group {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .form-group label {
    font-weight: 500;
    color: #374151;
    font-size: 14px;
  }

  .form-actions {
    display: flex;
    gap: 12px;
    justify-content: flex-end;
    padding-top: 20px;
    border-top: 1px solid #e5e7eb;
  }

  /* 商户状态 */
  .status-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 16px;
  }

  .status-item {
    text-align: center;
    padding: 16px;
    background: #f9fafb;
    border-radius: 8px;
  }

  .status-item h4 {
    margin: 0 0 8px 0;
    font-size: 14px;
    font-weight: 500;
    color: #6b7280;
  }

  .api-usage {
    font-size: 14px;
    color: #374151;
  }

  /* 教程视频 */
  .tutorial-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
    gap: 20px;
  }

  .video-card {
    background: white;
    border-radius: 12px;
    overflow: hidden;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
    transition: transform 0.2s ease;
  }

  .video-card:hover {
    transform: translateY(-2px);
  }

  .video-thumbnail {
    position: relative;
    width: 100%;
    height: 200px;
    overflow: hidden;
  }

  .video-thumbnail img {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }

  .play-button {
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    width: 60px;
    height: 60px;
    background: rgba(0, 0, 0, 0.7);
    border: none;
    border-radius: 50%;
    color: white;
    font-size: 20px;
    cursor: pointer;
    transition: all 0.2s ease;
  }

  .play-button:hover {
    background: rgba(0, 0, 0, 0.9);
    transform: translate(-50%, -50%) scale(1.1);
  }

  .video-duration {
    position: absolute;
    bottom: 8px;
    right: 8px;
    background: rgba(0, 0, 0, 0.7);
    color: white;
    padding: 4px 8px;
    border-radius: 4px;
    font-size: 12px;
  }

  .video-info {
    padding: 16px;
  }

  .video-info h3 {
    margin: 0 0 8px 0;
    font-size: 16px;
    font-weight: 600;
    color: #111827;
  }

  .video-info p {
    margin: 0;
    font-size: 14px;
    color: #6b7280;
    line-height: 1.4;
  }

  /* 视频模态框 */
  .video-modal {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.8);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 1000;
  }

  .video-modal-content {
    width: 90%;
    max-width: 800px;
    background: white;
    border-radius: 12px;
    overflow: hidden;
  }

  .video-modal-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 16px;
    border-bottom: 1px solid #e5e7eb;
  }

  .video-modal-header h3 {
    margin: 0;
    font-size: 18px;
    font-weight: 600;
  }

  .close-button {
    width: 32px;
    height: 32px;
    border: none;
    background: #f3f4f6;
    border-radius: 50%;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .close-button:hover {
    background: #e5e7eb;
  }

  .video-player {
    width: 100%;
    height: 450px;
  }

  .video-player iframe {
    width: 100%;
    height: 100%;
  }

  /* 移动端适配 */
  @media (max-width: 768px) {
    .seller-header {
      flex-direction: column;
      gap: 12px;
      padding: 12px 16px;
    }

    .header-left h1 {
      font-size: 20px;
      text-align: center;
    }

    .store-info {
      justify-content: center;
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

    .seller-content {
      padding: 16px;
    }

    .form-row {
      grid-template-columns: 1fr;
    }

    .form-actions {
      flex-direction: column;
    }

    .status-grid {
      grid-template-columns: repeat(2, 1fr);
    }

    .tutorial-grid {
      grid-template-columns: 1fr;
    }

    .video-modal-content {
      width: 95%;
      margin: 20px;
    }

    .video-player {
      height: 300px;
    }

    .welcome-steps {
      text-align: left;
    }
  }

  /* 深色模式 */
  @media (prefers-color-scheme: dark) {
    .seller-container {
      background: #111827;
    }

    .seller-header {
      background: #1f2937;
      border-bottom-color: #374151;
    }

    .header-left h1 {
      color: #f9fafb;
    }

    .store-id {
      color: #d1d5db;
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

    .section-header h2 {
      color: #f9fafb;
    }

    .form-group label {
      color: #e5e7eb;
    }

    .status-item {
      background: #374151;
    }

    .status-item h4 {
      color: #d1d5db;
    }

    .api-usage {
      color: #e5e7eb;
    }

    .video-card {
      background: #1f2937;
    }

    .video-info h3 {
      color: #f9fafb;
    }

    .video-info p {
      color: #d1d5db;
    }

    .video-modal-content {
      background: #1f2937;
    }

    .video-modal-header {
      border-bottom-color: #374151;
    }

    .video-modal-header h3 {
      color: #f9fafb;
    }

    .close-button {
      background: #374151;
    }

    .close-button:hover {
      background: #4b5563;
    }

    .welcome-content h1 {
      color: #f9fafb;
    }

    .welcome-content p {
      color: #d1d5db;
    }

    .step-text {
      color: #e5e7eb;
    }
  }

  /* 无障碍支持 */
  @media (prefers-reduced-motion: reduce) {
    .loading-spinner {
      animation: none;
    }

    .tab,
    .video-card,
    .play-button {
      transition: none;
    }
  }
</style> 