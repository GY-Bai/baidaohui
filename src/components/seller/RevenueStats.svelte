<script lang="ts">
  import { onMount } from 'svelte';

  let stats = {
    totalRevenue: 0,
    monthlyRevenue: 0,
    totalOrders: 0,
    monthlyOrders: 0,
    averageOrderValue: 0,
    topProducts: []
  };
  let loading = true;
  let selectedPeriod = 'month';

  const periods = [
    { value: 'week', label: '本周' },
    { value: 'month', label: '本月' },
    { value: 'quarter', label: '本季度' },
    { value: 'year', label: '本年' }
  ];

  onMount(() => {
    loadStats();
  });

  async function loadStats() {
    try {
      loading = true;
      const response = await fetch(`/api/seller/stats?period=${selectedPeriod}`);
      if (response.ok) {
        stats = await response.json();
      }
    } catch (error) {
      console.error('加载统计数据失败:', error);
    } finally {
      loading = false;
    }
  }

  function formatCurrency(amount) {
    return new Intl.NumberFormat('zh-CN', {
      style: 'currency',
      currency: 'CNY'
    }).format(amount);
  }

  $: {
    if (selectedPeriod) {
      loadStats();
    }
  }
</script>

<div class="space-y-6">
  <div class="bg-white rounded-lg shadow p-6">
    <div class="flex justify-between items-center mb-6">
      <h2 class="text-2xl font-semibold text-gray-900">收益统计</h2>
      <select
        bind:value={selectedPeriod}
        class="px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
      >
        {#each periods as period}
          <option value={period.value}>{period.label}</option>
        {/each}
      </select>
    </div>

    {#if loading}
      <div class="text-center py-8">
        <svg class="animate-spin h-8 w-8 text-blue-600 mx-auto mb-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 714 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
        <p class="text-gray-600">加载中...</p>
      </div>
    {:else}
      <!-- 统计卡片 -->
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        <div class="bg-gradient-to-r from-blue-500 to-blue-600 rounded-lg p-6 text-white">
          <div class="flex items-center justify-between">
            <div>
              <p class="text-blue-100 text-sm">总收益</p>
              <p class="text-2xl font-bold">{formatCurrency(stats.totalRevenue)}</p>
            </div>
            <div class="text-blue-200">
              <svg class="w-8 h-8" fill="currentColor" viewBox="0 0 20 20">
                <path d="M4 4a2 2 0 00-2 2v1h16V6a2 2 0 00-2-2H4zM18 9H2v5a2 2 0 002 2h12a2 2 0 002-2V9zM4 13a1 1 0 011-1h1a1 1 0 110 2H5a1 1 0 01-1-1zm5-1a1 1 0 100 2h1a1 1 0 100-2H9z"></path>
              </svg>
            </div>
          </div>
        </div>

        <div class="bg-gradient-to-r from-green-500 to-green-600 rounded-lg p-6 text-white">
          <div class="flex items-center justify-between">
            <div>
              <p class="text-green-100 text-sm">期间收益</p>
              <p class="text-2xl font-bold">{formatCurrency(stats.monthlyRevenue)}</p>
            </div>
            <div class="text-green-200">
              <svg class="w-8 h-8" fill="currentColor" viewBox="0 0 20 20">
                <path fill-rule="evenodd" d="M3 3a1 1 0 000 2v8a2 2 0 002 2h2.586l-1.293 1.293a1 1 0 101.414 1.414L10 15.414l2.293 2.293a1 1 0 001.414-1.414L12.414 15H15a2 2 0 002-2V5a1 1 0 100-2H3zm11.707 4.707a1 1 0 00-1.414-1.414L10 9.586 8.707 8.293a1 1 0 00-1.414 0l-2 2a1 1 0 101.414 1.414L8 10.414l1.293 1.293a1 1 0 001.414 0l4-4z" clip-rule="evenodd"></path>
              </svg>
            </div>
          </div>
        </div>

        <div class="bg-gradient-to-r from-purple-500 to-purple-600 rounded-lg p-6 text-white">
          <div class="flex items-center justify-between">
            <div>
              <p class="text-purple-100 text-sm">总订单</p>
              <p class="text-2xl font-bold">{stats.totalOrders}</p>
            </div>
            <div class="text-purple-200">
              <svg class="w-8 h-8" fill="currentColor" viewBox="0 0 20 20">
                <path fill-rule="evenodd" d="M10 2L3 7v11a1 1 0 001 1h12a1 1 0 001-1V7l-7-5zM6 9a1 1 0 112 0v6a1 1 0 11-2 0V9zm6 0a1 1 0 112 0v6a1 1 0 11-2 0V9z" clip-rule="evenodd"></path>
              </svg>
            </div>
          </div>
        </div>

        <div class="bg-gradient-to-r from-orange-500 to-orange-600 rounded-lg p-6 text-white">
          <div class="flex items-center justify-between">
            <div>
              <p class="text-orange-100 text-sm">平均订单价值</p>
              <p class="text-2xl font-bold">{formatCurrency(stats.averageOrderValue)}</p>
            </div>
            <div class="text-orange-200">
              <svg class="w-8 h-8" fill="currentColor" viewBox="0 0 20 20">
                <path d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"></path>
              </svg>
            </div>
          </div>
        </div>
      </div>

      <!-- 热销商品 -->
      <div class="bg-white rounded-lg border p-6">
        <h3 class="text-lg font-semibold text-gray-900 mb-4">热销商品 TOP 5</h3>
        {#if stats.topProducts && stats.topProducts.length > 0}
          <div class="space-y-4">
            {#each stats.topProducts as product, index}
              <div class="flex items-center justify-between p-4 bg-gray-50 rounded-lg">
                <div class="flex items-center space-x-4">
                  <div class="flex-shrink-0">
                    <span class="inline-flex items-center justify-center w-8 h-8 bg-blue-500 text-white rounded-full text-sm font-medium">
                      {index + 1}
                    </span>
                  </div>
                  <div class="flex items-center space-x-3">
                    <img class="w-12 h-12 rounded object-cover" src={product.image} alt={product.name} />
                    <div>
                      <p class="text-sm font-medium text-gray-900">{product.name}</p>
                      <p class="text-sm text-gray-500">销量: {product.soldCount} 件</p>
                    </div>
                  </div>
                </div>
                <div class="text-right">
                  <p class="text-sm font-medium text-gray-900">{formatCurrency(product.revenue)}</p>
                  <p class="text-sm text-gray-500">收益</p>
                </div>
              </div>
            {/each}
          </div>
        {:else}
          <div class="text-center py-8">
            <svg class="w-12 h-12 text-gray-400 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"></path>
            </svg>
            <p class="text-gray-500">暂无销售数据</p>
          </div>
        {/if}
      </div>
    {/if}
  </div>
</div> 