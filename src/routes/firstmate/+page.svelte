<script lang="ts">
  import { onMount } from 'svelte';
  import { clientSideRouteGuard, signOut } from '$lib/auth';
  import FortuneManagement from '$components/firstmate/FortuneManagement.svelte';
  import ChatManagement from '$components/firstmate/ChatManagement.svelte';
  import Profile from '$components/firstmate/Profile.svelte';

  let loading = true;
  let authenticated = false;
  let activeTab = 'fortune'; // 默认显示算命管理

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
      id: 'fortune', 
      name: '算命助理', 
      icon: '🔮',
      description: '协助处理算命申请和订单'
    },
    { 
      id: 'chat', 
      name: '聊天助理', 
      icon: '💬',
      description: '协助管理聊天室和用户交流'
    },
    { 
      id: 'profile', 
      name: '个人资料', 
      icon: '👤',
      description: '管理个人信息和设置'
    },
    { 
      id: 'logout', 
      name: '退出登录', 
      icon: '🚪',
      description: '安全退出当前账户'
    }
  ];

  function setActiveTab(tabId) {
    if (tabId === 'logout') {
      handleSignOut();
      return;
    }
    activeTab = tabId;
  }

  function getTabTitle() {
    const tab = tabs.find(t => t.id === activeTab);
    return tab ? tab.name : '大副控制台';
  }
</script>

<svelte:head>
  <title>{getTabTitle()} - 百刀会</title>
</svelte:head>

{#if loading}
  <div class="loading-screen">
    <div class="loading-content">
      <div class="loading-spinner"></div>
      <p>正在验证身份...</p>
    </div>
  </div>
{:else if authenticated}
  <div class="app-container">
    <!-- 顶部标题栏 -->
    <header class="app-header">
      <div class="header-content">
        <h1 class="app-title">百刀会 - 大副控制台</h1>
        <div class="user-badge firstmate">Firstmate</div>
      </div>
    </header>

    <!-- 主内容区域 -->
    <main class="main-content">
      <div class="content-wrapper">
        {#if activeTab === 'fortune'}
          <div class="content-section">
            <div class="section-header firstmate">
              <h2>🔮 算命助理</h2>
              <p>协助处理算命申请和订单</p>
            </div>
            <FortuneManagement />
          </div>
        {:else if activeTab === 'chat'}
          <div class="content-section">
            <div class="section-header firstmate">
              <h2>💬 聊天助理</h2>
              <p>协助管理聊天室和用户交流</p>
            </div>
            <ChatManagement />
          </div>
        {:else if activeTab === 'profile'}
          <div class="content-section">
            <div class="section-header firstmate">
              <h2>👤 个人资料</h2>
              <p>管理个人信息和设置</p>
            </div>
            <Profile />
          </div>
        {/if}
      </div>
    </main>

    <!-- 底部Dock栏 -->
    <nav class="dock-bar">
      <div class="dock-container">
        {#each tabs as tab}
          <button
            class="dock-item {activeTab === tab.id ? 'active' : ''} firstmate"
            on:click={() => setActiveTab(tab.id)}
            title={tab.description}
          >
            <div class="dock-icon">{tab.icon}</div>
            <span class="dock-label">{tab.name}</span>
          </button>
        {/each}
      </div>
    </nav>

    <!-- 大副特权提示 -->
    {#if activeTab === 'fortune'}
      <div class="privilege-banner firstmate">
        <p><strong>大副特权：</strong>协助教主管理系统，拥有高级管理权限</p>
      </div>
    {/if}
  </div>
{/if}

<style>
  .loading-screen {
    min-height: 100vh;
    display: flex;
    align-items: center;
    justify-content: center;
    background: linear-gradient(135deg, #ff8a00 0%, #e52e71 100%);
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

  .app-container {
    min-height: 100vh;
    background: #fafafa;
    display: flex;
    flex-direction: column;
  }

  .app-header {
    background: white;
    border-bottom: 1px solid #dbdbdb;
    padding: 12px 16px;
    position: sticky;
    top: 0;
    z-index: 100;
  }

  .header-content {
    max-width: 935px;
    margin: 0 auto;
    display: flex;
    align-items: center;
    justify-content: space-between;
  }

  .app-title {
    font-size: 24px;
    font-weight: 600;
    color: #262626;
    margin: 0;
  }

  .user-badge {
    color: white;
    padding: 6px 16px;
    border-radius: 20px;
    font-size: 14px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }

  .user-badge.firstmate {
    background: linear-gradient(45deg, #ff8a00 0%, #e52e71 100%);
  }

  .main-content {
    flex: 1;
    padding: 20px 16px 80px 16px;
    overflow-y: auto;
  }

  .content-wrapper {
    max-width: 614px;
    margin: 0 auto;
  }

  .content-section {
    background: white;
    border: 1px solid #dbdbdb;
    border-radius: 8px;
    overflow: hidden;
    margin-bottom: 20px;
  }

  .section-header {
    padding: 20px;
    border-bottom: 1px solid #efefef;
    color: white;
    text-align: center;
  }

  .section-header.firstmate {
    background: linear-gradient(135deg, #ff8a00 0%, #e52e71 100%);
  }

  .section-header h2 {
    margin: 0 0 8px 0;
    font-size: 28px;
    font-weight: 700;
  }

  .section-header p {
    margin: 0;
    font-size: 16px;
    opacity: 0.9;
  }

  .dock-bar {
    position: fixed;
    bottom: 0;
    left: 0;
    right: 0;
    background: white;
    border-top: 1px solid #dbdbdb;
    padding: 8px 0;
    z-index: 1000;
  }

  .dock-container {
    display: flex;
    justify-content: space-around;
    align-items: center;
    max-width: 614px;
    margin: 0 auto;
  }

  .dock-item {
    display: flex;
    flex-direction: column;
    align-items: center;
    padding: 8px 12px;
    background: none;
    border: none;
    cursor: pointer;
    transition: all 0.2s ease;
    border-radius: 8px;
    min-width: 70px;
  }

  .dock-item:hover {
    background: #f5f5f5;
    transform: translateY(-2px);
  }

  .dock-item.active.firstmate {
    background: linear-gradient(135deg, #ff8a00 0%, #e52e71 100%);
    color: white;
  }

  .dock-item.active .dock-icon {
    transform: scale(1.2);
  }

  .dock-icon {
    font-size: 24px;
    margin-bottom: 4px;
    transition: transform 0.2s ease;
  }

  .dock-label {
    font-size: 12px;
    font-weight: 600;
    text-align: center;
    line-height: 1.2;
  }

  .privilege-banner {
    position: fixed;
    top: 70px;
    left: 16px;
    right: 16px;
    color: white;
    padding: 12px 16px;
    border-radius: 8px;
    text-align: center;
    font-size: 14px;
    z-index: 90;
    animation: slideDown 0.3s ease;
  }

  .privilege-banner.firstmate {
    background: linear-gradient(135deg, #ff8a00 0%, #e52e71 100%);
  }

  @keyframes slideDown {
    from {
      transform: translateY(-100%);
      opacity: 0;
    }
    to {
      transform: translateY(0);
      opacity: 1;
    }
  }

  /* 移动端优化 */
  @media (max-width: 768px) {
    .app-title {
      font-size: 20px;
    }

    .dock-item {
      min-width: 60px;
      padding: 6px 8px;
    }

    .dock-icon {
      font-size: 20px;
    }

    .dock-label {
      font-size: 10px;
    }

    .section-header h2 {
      font-size: 24px;
    }

    .section-header p {
      font-size: 14px;
    }
  }
</style> 