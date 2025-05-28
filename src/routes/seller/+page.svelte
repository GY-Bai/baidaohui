<script>
  import { signOut } from '$lib/auth';
  import StoreSettings from '$components/seller/StoreSettings.svelte';
  import ProductManagement from '$components/seller/ProductManagement.svelte';
  import OrderManagement from '$components/seller/OrderManagement.svelte';
  import RevenueStats from '$components/seller/RevenueStats.svelte';

  export let data;
  
  let activeTab = 'store';

  const tabs = [
    { id: 'store', name: '店铺设置', icon: '🏪' },
    { id: 'products', name: '商品管理', icon: '📦' },
    { id: 'orders', name: '订单管理', icon: '📋' },
    { id: 'revenue', name: '收益统计', icon: '💰' }
  ];

  function setActiveTab(tabId) {
    activeTab = tabId;
  }

  async function handleSignOut() {
    if (confirm('确定要退出登录吗？')) {
      await signOut();
    }
  }
</script>

<svelte:head>
  <title>百刀会 - Seller 商户中心</title>
</svelte:head>

<div class="min-h-screen bg-gray-50">
  <!-- 顶部导航栏 -->
  <nav class="bg-white shadow-sm border-b">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <div class="flex justify-between h-16">
        <div class="flex items-center">
          <h1 class="text-xl font-semibold text-gray-900">百刀会商户中心</h1>
          <span class="ml-2 px-2 py-1 text-xs bg-green-100 text-green-800 rounded-full">Seller</span>
        </div>
        
        <!-- 用户信息和导航 -->
        <div class="flex items-center space-x-4">
          <!-- 在线状态 -->
          <div class="flex items-center space-x-2">
            <span class="inline-block w-2 h-2 bg-green-500 rounded-full"></span>
            <span class="text-sm text-gray-600">在线</span>
          </div>
          
          <!-- 用户头像和信息 -->
          <div class="flex items-center space-x-3">
            <div class="w-8 h-8 bg-green-500 rounded-full flex items-center justify-center text-white font-semibold text-sm">
              {data.session.user.nickname?.charAt(0) || data.session.user.email.charAt(0).toUpperCase()}
            </div>
            <div class="hidden md:block">
              <p class="text-sm font-medium text-gray-900">{data.session.user.nickname || '商户'}</p>
              <p class="text-xs text-gray-500">{data.session.user.email}</p>
            </div>
          </div>
          
          <!-- 退出按钮 -->
          <button
            on:click={handleSignOut}
            class="text-gray-400 hover:text-gray-600 text-sm transition-colors"
          >
            退出
          </button>
        </div>
      </div>
      
      <!-- 标签导航 -->
      <div class="border-t border-gray-200">
        <div class="flex space-x-8">
          {#each tabs as tab}
            <button
              on:click={() => setActiveTab(tab.id)}
              class="flex items-center px-3 py-4 text-sm font-medium border-b-2 transition-colors {
                activeTab === tab.id 
                  ? 'text-green-600 border-green-600' 
                  : 'text-gray-500 border-transparent hover:text-gray-700 hover:border-gray-300'
              }"
              aria-label="切换到{tab.name}标签"
              aria-current={activeTab === tab.id ? 'page' : undefined}
            >
              <span class="mr-2">{tab.icon}</span>
              {tab.name}
            </button>
          {/each}
        </div>
      </div>
    </div>
  </nav>

  <!-- 主要内容区域 -->
  <main class="max-w-7xl mx-auto py-6 px-4 sm:px-6 lg:px-8">
    {#if activeTab === 'store'}
      <StoreSettings session={data.session} />
    {:else if activeTab === 'orders'}
      <OrderManagement session={data.session} />
    {:else if activeTab === 'revenue'}
      <RevenueStats session={data.session} />
    {:else if activeTab === 'products'}
      <ProductManagement session={data.session} />
    {/if}
  </main>
</div> 