<script lang="ts">
  import { onMount } from 'svelte';
  import { validateRoleAndRedirect, signOut, getSession } from '$lib/auth';
  import ProductManagement from '$components/seller/ProductManagement.svelte';
  import OrderManagement from '$components/seller/OrderManagement.svelte';
  import RevenueStats from '$components/seller/RevenueStats.svelte';
  import StoreSettings from '$components/seller/StoreSettings.svelte';
  import type { UserSession } from '$lib/auth';

  let activeTab = 'products';
  let loading = true;
  let user: UserSession | null = null;
  let storeInfo = {
    name: '',
    isActive: true,
    totalProducts: 0,
    totalOrders: 0,
    totalRevenue: 0
  };

  onMount(async () => {
    const isValid = await validateRoleAndRedirect('Seller');
    if (isValid) {
      user = await getSession();
      loadStoreInfo();
      loading = false;
    }
  });

  const tabs = [
    { id: 'products', name: '商品管理', icon: '📦' },
    { id: 'orders', name: '订单管理', icon: '📋' },
    { id: 'revenue', name: '收益统计', icon: '💰' },
    { id: 'settings', name: '店铺设置', icon: '⚙️' }
  ];

  function setActiveTab(tabId: string) {
    activeTab = tabId;
  }

  async function handleSignOut() {
    if (confirm('确定要退出登录吗？')) {
      try {
        await signOut();
      } catch (error) {
        console.error('退出登录失败:', error);
        alert('退出登录失败，请重试');
      }
    }
  }

  async function loadStoreInfo() {
    try {
      const response = await fetch('/api/seller/store-info');
      if (response.ok) {
        storeInfo = await response.json();
      }
    } catch (error) {
      console.error('加载店铺信息失败:', error);
    }
  }

  function formatCurrency(amount) {
    return new Intl.NumberFormat('zh-CN', {
      style: 'currency',
      currency: 'CNY'
    }).format(amount);
  }
</script>

<svelte:head>
  <title>百道会 - Seller 商户后台</title>
</svelte:head>

{#if loading}
  <div class="min-h-screen flex items-center justify-center">
    <div class="text-center">
      <svg class="animate-spin h-8 w-8 text-blue-600 mx-auto mb-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 714 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
      </svg>
      <p class="text-gray-600">加载中...</p>
    </div>
  </div>
{:else}
  <div class="min-h-screen bg-gray-50">
    <!-- 顶部导航栏 -->
    <nav class="bg-white shadow-sm border-b">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex justify-between h-16">
          <div class="flex items-center">
            <h1 class="text-xl font-semibold text-gray-900">百道会 - 商户后台</h1>
            <div class="ml-3 flex items-center space-x-2">
              <span class="px-2 py-1 text-xs bg-blue-100 text-blue-800 rounded-full">Seller</span>
              {#if storeInfo.name}
                <span class="px-2 py-1 text-xs bg-green-100 text-green-800 rounded-full">{storeInfo.name}</span>
              {/if}
              <div class="px-2 py-1 text-xs {storeInfo.isActive ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'} rounded-full">
                {storeInfo.isActive ? '营业中' : '已暂停'}
              </div>
            </div>
          </div>
          
          <!-- 用户信息 -->
          <div class="flex items-center space-x-4">
            <!-- 快速统计 -->
            <div class="hidden md:flex items-center space-x-4 text-sm text-gray-600">
              <div class="flex items-center">
                <span class="mr-1">📦</span>
                <span>{storeInfo.totalProducts} 商品</span>
              </div>
              <div class="flex items-center">
                <span class="mr-1">📋</span>
                <span>{storeInfo.totalOrders} 订单</span>
              </div>
              <div class="flex items-center">
                <span class="mr-1">💰</span>
                <span>{formatCurrency(storeInfo.totalRevenue)}</span>
              </div>
            </div>

            <!-- 用户头像和菜单 -->
            {#if user}
              <div class="relative group">
                <button class="flex items-center space-x-2 p-2 rounded-md hover:bg-gray-100">
                  <div class="w-8 h-8 bg-blue-500 rounded-full flex items-center justify-center text-white text-sm font-semibold">
                    {user.user.email.charAt(0).toUpperCase()}
                  </div>
                  <span class="text-sm text-gray-700">{user.user.email}</span>
                  <svg class="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"></path>
                  </svg>
                </button>
                
                <!-- 下拉菜单 -->
                <div class="absolute right-0 mt-2 w-48 bg-white rounded-md shadow-lg py-1 z-50 opacity-0 invisible group-hover:opacity-100 group-hover:visible transition-all">
                  <button class="block w-full text-left px-4 py-2 text-sm text-gray-700 hover:bg-gray-100">
                    个人设置
                  </button>
                  <button class="block w-full text-left px-4 py-2 text-sm text-gray-700 hover:bg-gray-100">
                    商户帮助
                  </button>
                  <hr class="my-1">
                  <button 
                    on:click={handleSignOut}
                    class="block w-full text-left px-4 py-2 text-sm text-red-600 hover:bg-gray-100"
                  >
                    退出登录
                  </button>
                </div>
              </div>
            {/if}
          </div>
        </div>
      </div>
    </nav>

    <!-- 欢迎横幅 -->
    <div class="bg-gradient-to-r from-blue-500 to-purple-600 text-white">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
        <div class="flex items-center justify-between">
          <div>
            <h2 class="text-lg font-semibold">
              欢迎回来，{storeInfo.name || '商户'}！
            </h2>
            <p class="text-blue-100 text-sm">
              管理您的商品，处理订单，查看收益统计
            </p>
          </div>
          <div class="hidden md:flex items-center space-x-6">
            <div class="text-center">
              <div class="text-2xl font-bold">{storeInfo.totalProducts}</div>
              <div class="text-xs text-blue-100">商品总数</div>
            </div>
            <div class="text-center">
              <div class="text-2xl font-bold">{storeInfo.totalOrders}</div>
              <div class="text-xs text-blue-100">订单总数</div>
            </div>
            <div class="text-center">
              <div class="text-2xl font-bold">{formatCurrency(storeInfo.totalRevenue)}</div>
              <div class="text-xs text-blue-100">总收益</div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- 标签导航 -->
    <div class="bg-white border-b">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex space-x-8">
          {#each tabs as tab}
            <button
              on:click={() => setActiveTab(tab.id)}
              class="flex items-center px-3 py-4 text-sm font-medium border-b-2 transition-colors {
                activeTab === tab.id 
                  ? 'text-blue-600 border-blue-600' 
                  : 'text-gray-500 border-transparent hover:text-gray-700 hover:border-gray-300'
              }"
            >
              <span class="mr-2">{tab.icon}</span>
              {tab.name}
            </button>
          {/each}
        </div>
      </div>
    </div>

    <!-- 主要内容区域 -->
    <main class="max-w-7xl mx-auto py-6 px-4 sm:px-6 lg:px-8">
      {#if activeTab === 'products'}
        <ProductManagement />
      {:else if activeTab === 'orders'}
        <OrderManagement />
      {:else if activeTab === 'revenue'}
        <RevenueStats />
      {:else if activeTab === 'settings'}
        <StoreSettings on:storeUpdated={loadStoreInfo} />
      {/if}
    </main>
  </div>
{/if} 