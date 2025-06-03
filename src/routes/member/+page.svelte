<script lang="ts">
  import { onMount } from 'svelte';
  import { clientSideRouteGuard, signOut } from '$lib/auth';
  import Chat from '$components/member/Chat.svelte';
  import Fortune from '$components/member/Fortune.svelte';
  import Ecommerce from '$components/member/Ecommerce.svelte';
  import Profile from '$components/member/Profile.svelte';

  let loading = true;
  let authenticated = false;
  let activeTab = 'chat'; // 默认显示悄悄话

  onMount(async () => {
    // 使用客户端路由守卫
    authenticated = await clientSideRouteGuard('Member');
    loading = false;
  });

  async function handleSignOut() {
    await signOut();
  }

  const tabs = [
    { 
      id: 'chat', 
      name: '悄悄话', 
      icon: '💬',
      description: '教主的独家分享和内幕消息'
    },
    { 
      id: 'fortune', 
      name: '算命申请', 
      icon: '🔮',
      description: '申请教主为您进行专业算命服务'
    },
    { 
      id: 'ecommerce', 
      name: '好物推荐', 
      icon: '🛍️',
      description: '发现教主推荐的优质商品'
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
    return tab ? tab.name : '会员专区';
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
        <h1 class="app-title">百刀会 - 会员专区</h1>
        <div class="user-badge member">Member</div>
      </div>
    </header>

    <!-- 主内容区域 -->
    <main class="main-content">
      <div class="content-wrapper">
        {#if activeTab === 'chat'}
          <div class="content-section">
            <div class="section-header member">
              <h2>💬 教主悄悄话</h2>
              <p>获取教主的独家分享和内幕消息</p>
            </div>
            <Chat />
          </div>
        {:else if activeTab === 'fortune'}
          <div class="content-section">
            <div class="section-header member">
              <h2>🔮 算命申请</h2>
              <p>申请教主为您进行专业算命服务</p>
            </div>
            <Fortune />
          </div>
        {:else if activeTab === 'ecommerce'}
          <div class="content-section">
            <div class="section-header member">
              <h2>🛍️ 好物推荐</h2>
              <p>发现教主推荐的优质商品</p>
            </div>
            <Ecommerce />
          </div>
        {/if}
      </div>
    </main>

    <!-- 底部Dock栏 -->
    <nav class="dock-bar">
      <div class="dock-container">
        {#each tabs as tab}
          <button
            class="dock-item {activeTab === tab.id ? 'active' : ''} member"
            on:click={() => setActiveTab(tab.id)}
            title={tab.description}
          >
            <div class="dock-icon">{tab.icon}</div>
            <span class="dock-label">{tab.name}</span>
          </button>
        {/each}
      </div>
    </nav>

    <!-- 会员特权提示 -->
    {#if activeTab === 'chat'}
      <div class="privilege-banner member">
        <p><strong>会员特权：</strong>享受高级内容访问权限，优先算命服务，专属会员优惠</p>
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
    background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%);
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

  .user-badge.member {
    background: linear-gradient(45deg, #4facfe 0%, #00f2fe 100%);
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

  .section-header.member {
    background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%);
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

  .dock-item.active.member {
    background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%);
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

  .privilege-banner.member {
    background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%);
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