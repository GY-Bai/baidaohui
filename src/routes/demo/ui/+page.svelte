<script lang="ts">
  import { onMount } from 'svelte';
  import BottomDock from '$lib/components/ui/BottomDock.svelte';
  import TabNavigation from '$lib/components/ui/TabNavigation.svelte';
  import CreateFortuneModal from '$lib/components/ui/CreateFortuneModal.svelte';

  // Dock 栏状态
  let activeDockItem = 'fortune';
  let showCreateModal = false;

  // 二级导航状态
  let activeTab = 'overview';

  // Dock 栏配置（粉丝页面）
  const dockItems = [
    { 
      id: 'fortune', 
      label: '算命申请', 
      icon: '🔮',
      activeIcon: '✨',
      description: '申请专业算命服务',
      badge: 2
    },
    { 
      id: 'chat', 
      label: '悄悄话', 
      icon: '💬',
      activeIcon: '💭',
      description: '教主的独家分享'
    },
    { 
      id: 'shop', 
      label: '好物推荐', 
      icon: '🛍️',
      activeIcon: '🛒',
      description: '发现优质商品'
    },
    { 
      id: 'profile', 
      label: '个人中心', 
      icon: '👤',
      activeIcon: '🎭',
      description: '个人设置和信息'
    }
  ];

  // 二级导航配置
  const tabs = [
    { id: 'overview', label: '概览', icon: '📊' },
    { id: 'history', label: '历史记录', icon: '📋', count: 5 },
    { id: 'favorites', label: '收藏', icon: '⭐' },
    { id: 'settings', label: '设置', icon: '⚙️', disabled: false }
  ];

  // 处理 Dock 栏切换
  function handleDockChange(event) {
    const { id } = event.detail;
    activeDockItem = id;
    
    if (id === 'fortune') {
      // 在算命页面时，显示相关的二级导航
      activeTab = 'overview';
    }
  }

  // 处理创建算命
  function handleCreateFortune() {
    showCreateModal = true;
  }

  // 处理模态框关闭
  function handleModalClose() {
    showCreateModal = false;
  }

  // 处理表单提交
  function handleModalSubmit(event) {
    const { formData, success } = event.detail;
    console.log('算命申请提交:', formData);
    
    if (success) {
      // 显示成功提示
      alert('算命申请提交成功！我们会尽快为您安排。');
    } else {
      alert('提交失败，请稍后重试。');
    }
  }

  // 处理二级导航切换
  function handleTabChange(event) {
    activeTab = event.detail.activeTab;
  }

  onMount(() => {
    console.log('UI演示页面加载完成');
  });
</script>

<svelte:head>
  <title>UI组件演示 - 百道慧</title>
</svelte:head>

<div class="demo-container">
  <!-- 顶部标题栏 -->
  <header class="demo-header">
    <h1 class="demo-title">🎨 UI组件演示</h1>
    <p class="demo-subtitle">Instagram风格的现代化移动端界面组件</p>
  </header>

  <!-- 主要内容区域 -->
  <main class="demo-content">
    
    <!-- 组件介绍 -->
    <section class="demo-section">
      <h2 class="section-title">📱 移动端优先设计</h2>
      <div class="feature-grid">
        <div class="feature-card">
          <div class="feature-icon">🚢</div>
          <h3>底部 Dock 栏</h3>
          <p>类似Instagram的主导航，固定底部，支持徽章和动画效果</p>
        </div>
        <div class="feature-card">
          <div class="feature-icon">📋</div>
          <h3>标签式导航</h3>
          <p>流畅的二级导航，支持滑动指示器和多种样式变体</p>
        </div>
        <div class="feature-card">
          <div class="feature-icon">✨</div>
          <h3>模态框操作</h3>
          <p>沉浸式的创建流程，分步表单和优雅的动画过渡</p>
        </div>
      </div>
    </section>

    <!-- 二级导航演示 -->
    <section class="demo-section">
      <h2 class="section-title">标签导航组件</h2>
      <div class="demo-showcase">
        <div class="showcase-header">
          <h3>Default 样式</h3>
          <button class="create-button" on:click={handleCreateFortune}>
            ✨ 新建算命申请
          </button>
        </div>
        
        <TabNavigation 
          {tabs}
          {activeTab}
          variant="default"
          size="md"
          on:change={handleTabChange}
        />
        
        <div class="tab-content">
          {#if activeTab === 'overview'}
            <div class="content-panel">
              <h4>📊 概览面板</h4>
              <p>这里显示整体的统计信息和快速操作入口。</p>
              <div class="stats-grid">
                <div class="stat-item">
                  <div class="stat-number">12</div>
                  <div class="stat-label">算命申请</div>
                </div>
                <div class="stat-item">
                  <div class="stat-number">5</div>
                  <div class="stat-label">已完成</div>
                </div>
                <div class="stat-item">
                  <div class="stat-number">2</div>
                  <div class="stat-label">进行中</div>
                </div>
              </div>
            </div>
          {:else if activeTab === 'history'}
            <div class="content-panel">
              <h4>📋 历史记录</h4>
              <div class="history-list">
                <div class="history-item">
                  <div class="history-icon">🔮</div>
                  <div class="history-info">
                    <div class="history-title">事业运势咨询</div>
                    <div class="history-date">2024年3月15日</div>
                  </div>
                  <div class="history-status completed">已完成</div>
                </div>
                <div class="history-item">
                  <div class="history-icon">💕</div>
                  <div class="history-info">
                    <div class="history-title">感情姻缘分析</div>
                    <div class="history-date">2024年3月10日</div>
                  </div>
                  <div class="history-status pending">进行中</div>
                </div>
              </div>
            </div>
          {:else if activeTab === 'favorites'}
            <div class="content-panel">
              <h4>⭐ 收藏夹</h4>
              <p>您收藏的重要算命结果和建议。</p>
            </div>
          {:else if activeTab === 'settings'}
            <div class="content-panel">
              <h4>⚙️ 设置</h4>
              <p>个性化设置和偏好配置。</p>
            </div>
          {/if}
        </div>
      </div>
      
      <!-- Pills 样式示例 -->
      <div class="demo-showcase">
        <h3>Pills 样式</h3>
        <TabNavigation 
          tabs={[
            { id: 'all', label: '全部' },
            { id: 'active', label: '进行中', count: 3 },
            { id: 'completed', label: '已完成' }
          ]}
          activeTab="active"
          variant="pills"
          size="sm"
        />
      </div>
    </section>

    <!-- 使用指南 -->
    <section class="demo-section">
      <h2 class="section-title">🛠️ 使用指南</h2>
      <div class="code-examples">
        <div class="code-example">
          <h4>底部 Dock 栏</h4>
          <pre><code>{`<BottomDock 
  items={dockItems}
  activeId={activeDockItem}
  theme="default"
  on:change={handleDockChange}
  on:logout={handleLogout}
/>`}</code></pre>
        </div>
        
        <div class="code-example">
          <h4>标签导航</h4>
          <pre><code>{`<TabNavigation 
  tabs={tabs}
  activeTab={activeTab}
  variant="default"
  size="md"
  on:change={handleTabChange}
/>`}</code></pre>
        </div>
        
        <div class="code-example">
          <h4>创建模态框</h4>
          <pre><code>{`<CreateFortuneModal 
  isOpen={showModal}
  title="新建算命申请"
  on:close={handleClose}
  on:submit={handleSubmit}
/>`}</code></pre>
        </div>
      </div>
    </section>

  </main>

  <!-- 底部 Dock 栏 -->
  <BottomDock 
    items={dockItems}
    activeId={activeDockItem}
    theme="default"
    on:change={handleDockChange}
  />

  <!-- 创建算命模态框 -->
  <CreateFortuneModal 
    isOpen={showCreateModal}
    title="新建算命申请"
    subtitle="填写您的需求，获得专业算命服务"
    on:close={handleModalClose}
    on:submit={handleModalSubmit}
  />
</div>

<style>
  .demo-container {
    min-height: 100vh;
    background: #fafafa;
    padding-bottom: 80px; /* 为底部dock栏留空间 */
  }

  .demo-header {
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    color: white;
    padding: 32px 20px;
    text-align: center;
  }

  .demo-title {
    margin: 0 0 8px 0;
    font-size: 28px;
    font-weight: 700;
  }

  .demo-subtitle {
    margin: 0;
    font-size: 16px;
    opacity: 0.9;
  }

  .demo-content {
    max-width: 800px;
    margin: 0 auto;
    padding: 24px 20px;
  }

  .demo-section {
    margin-bottom: 40px;
  }

  .section-title {
    margin: 0 0 20px 0;
    font-size: 24px;
    font-weight: 600;
    color: #374151;
  }

  .feature-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
    gap: 20px;
    margin-bottom: 32px;
  }

  .feature-card {
    background: white;
    padding: 24px;
    border-radius: 12px;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
    text-align: center;
    transition: transform 0.2s;
  }

  .feature-card:hover {
    transform: translateY(-4px);
  }

  .feature-icon {
    font-size: 32px;
    margin-bottom: 12px;
  }

  .feature-card h3 {
    margin: 0 0 8px 0;
    font-size: 18px;
    font-weight: 600;
    color: #374151;
  }

  .feature-card p {
    margin: 0;
    font-size: 14px;
    color: #6b7280;
    line-height: 1.5;
  }

  .demo-showcase {
    background: white;
    border-radius: 12px;
    padding: 24px;
    margin-bottom: 24px;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  }

  .showcase-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 20px;
  }

  .showcase-header h3 {
    margin: 0;
    font-size: 18px;
    font-weight: 600;
    color: #374151;
  }

  .create-button {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 8px 16px;
    background: #667eea;
    color: white;
    border: none;
    border-radius: 8px;
    font-weight: 600;
    font-size: 14px;
    cursor: pointer;
    transition: all 0.2s;
  }

  .create-button:hover {
    background: #5a67d8;
    transform: translateY(-1px);
  }

  .tab-content {
    margin-top: 20px;
  }

  .content-panel {
    padding: 20px;
    background: #f9fafb;
    border-radius: 8px;
    border: 1px solid #e5e7eb;
  }

  .content-panel h4 {
    margin: 0 0 12px 0;
    font-size: 16px;
    font-weight: 600;
    color: #374151;
  }

  .content-panel p {
    margin: 0 0 16px 0;
    color: #6b7280;
    line-height: 1.5;
  }

  .stats-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(100px, 1fr));
    gap: 16px;
  }

  .stat-item {
    text-align: center;
    padding: 16px;
    background: white;
    border-radius: 8px;
    border: 1px solid #e5e7eb;
  }

  .stat-number {
    font-size: 24px;
    font-weight: 700;
    color: #667eea;
    margin-bottom: 4px;
  }

  .stat-label {
    font-size: 12px;
    color: #6b7280;
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }

  .history-list {
    display: flex;
    flex-direction: column;
    gap: 12px;
  }

  .history-item {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 16px;
    background: white;
    border-radius: 8px;
    border: 1px solid #e5e7eb;
  }

  .history-icon {
    font-size: 24px;
    flex-shrink: 0;
  }

  .history-info {
    flex: 1;
  }

  .history-title {
    font-size: 14px;
    font-weight: 600;
    color: #374151;
    margin-bottom: 2px;
  }

  .history-date {
    font-size: 12px;
    color: #9ca3af;
  }

  .history-status {
    padding: 4px 8px;
    border-radius: 4px;
    font-size: 12px;
    font-weight: 600;
    text-transform: uppercase;
  }

  .history-status.completed {
    background: #d1fae5;
    color: #065f46;
  }

  .history-status.pending {
    background: #fef3c7;
    color: #92400e;
  }

  .code-examples {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
    gap: 20px;
  }

  .code-example {
    background: white;
    border-radius: 8px;
    overflow: hidden;
    border: 1px solid #e5e7eb;
  }

  .code-example h4 {
    margin: 0;
    padding: 16px 20px;
    background: #f9fafb;
    border-bottom: 1px solid #e5e7eb;
    font-size: 14px;
    font-weight: 600;
    color: #374151;
  }

  .code-example pre {
    margin: 0;
    padding: 20px;
    overflow-x: auto;
  }

  .code-example code {
    font-family: 'Monaco', 'Consolas', monospace;
    font-size: 12px;
    line-height: 1.5;
    color: #1f2937;
  }

  /* 响应式优化 */
  @media (max-width: 768px) {
    .demo-header {
      padding: 24px 16px;
    }

    .demo-title {
      font-size: 24px;
    }

    .demo-content {
      padding: 20px 16px;
    }

    .feature-grid {
      grid-template-columns: 1fr;
    }

    .demo-showcase {
      padding: 20px 16px;
    }

    .showcase-header {
      flex-direction: column;
      align-items: flex-start;
      gap: 12px;
    }

    .stats-grid {
      grid-template-columns: repeat(3, 1fr);
    }

    .code-examples {
      grid-template-columns: 1fr;
    }

    .history-item {
      padding: 12px;
    }
  }
</style> 