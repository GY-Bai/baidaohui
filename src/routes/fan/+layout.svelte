<script lang="ts">
  import { page } from '$app/stores';
  import { goto } from '$app/navigation';
  import BottomDock from '$lib/components/ui/BottomDock.svelte';
  
  $: currentPath = $page.url.pathname;
  
  const dockItems = [
    {
      id: 'private-chat',
      label: '私信',
      icon: '💬',
      activeIcon: '💬',
      description: '与主播私聊',
      href: '/fan/chat'
    },
    {
      id: 'fortune',
      label: '算命',
      icon: '🔮',
      activeIcon: '✨',
      description: '算命服务',
      href: '/fan/fortune'
    },
    {
      id: 'shopping',
      label: '带货',
      icon: '🛍️',
      activeIcon: '🛒',
      description: '购买商品',
      href: '/fan/shopping'
    },
    {
      id: 'profile',
      label: '个人',
      icon: '👤',
      activeIcon: '👤',
      description: '个人中心',
      href: '/fan/profile'
    }
  ];
  
  $: activeId = getActiveId(currentPath);
  
  function getActiveId(path: string) {
    if (path.startsWith('/fan/chat')) return 'private-chat';
    if (path.startsWith('/fan/fortune')) return 'fortune';
    if (path.startsWith('/fan/shopping')) return 'shopping';
    if (path.startsWith('/fan/profile')) return 'profile';
    return 'fortune'; // 默认
  }
  
  function handleDockChange(event: CustomEvent) {
    const item = dockItems.find(item => item.id === event.detail.id);
    if (item?.href) {
      goto(item.href);
    }
  }
</script>

<svelte:head>
  <title>百道慧 - Fan用户</title>
</svelte:head>

<div class="fan-layout">
  <!-- 主要内容区域 -->
  <main class="content-area">
    <slot />
  </main>
  
  <!-- 底部导航 -->
  <BottomDock 
    items={dockItems}
    {activeId}
    theme="default"
    on:change={handleDockChange}
  />
</div>

<style>
  .fan-layout {
    min-height: 100vh;
    background: #fafafa;
    display: flex;
    flex-direction: column;
    padding-bottom: 80px; /* 为底部导航留空间 */
  }
  
  .content-area {
    flex: 1;
    width: 100%;
    max-width: 768px;
    margin: 0 auto;
    background: white;
    box-shadow: 0 0 20px rgba(0, 0, 0, 0.1);
    min-height: calc(100vh - 80px);
  }
  
  /* 移动端优化 */
  @media (max-width: 768px) {
    .content-area {
      max-width: 100%;
      box-shadow: none;
    }
  }
  
  /* 深色模式 */
  @media (prefers-color-scheme: dark) {
    .fan-layout {
      background: #111827;
    }
    
    .content-area {
      background: #1f2937;
    }
  }
</style> 