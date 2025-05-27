<script lang="ts">
  import { onMount } from 'svelte';

  let orders = [];
  let loading = true;
  let filters = {
    status: '',
    dateFrom: '',
    dateTo: ''
  };

  const statusOptions = [
    { value: '', label: '全部状态' },
    { value: 'pending', label: '待付款' },
    { value: 'paid', label: '已付款' },
    { value: 'shipped', label: '已发货' },
    { value: 'delivered', label: '已送达' },
    { value: 'cancelled', label: '已取消' }
  ];

  onMount(() => {
    loadOrders();
  });

  async function loadOrders() {
    try {
      loading = true;
      const response = await fetch('/api/seller/orders');
      if (response.ok) {
        orders = await response.json();
      }
    } catch (error) {
      console.error('加载订单失败:', error);
    } finally {
      loading = false;
    }
  }

  function getStatusText(status) {
    const statusMap = {
      'pending': '待付款',
      'paid': '已付款',
      'shipped': '已发货',
      'delivered': '已送达',
      'cancelled': '已取消'
    };
    return statusMap[status] || status;
  }

  function getStatusColor(status) {
    const colorMap = {
      'pending': 'bg-yellow-100 text-yellow-800',
      'paid': 'bg-blue-100 text-blue-800',
      'shipped': 'bg-purple-100 text-purple-800',
      'delivered': 'bg-green-100 text-green-800',
      'cancelled': 'bg-red-100 text-red-800'
    };
    return colorMap[status] || 'bg-gray-100 text-gray-800';
  }

  function formatCurrency(amount) {
    return new Intl.NumberFormat('zh-CN', {
      style: 'currency',
      currency: 'CNY'
    }).format(amount);
  }

  $: filteredOrders = orders.filter(order => {
    if (filters.status && order.status !== filters.status) return false;
    if (filters.dateFrom) {
      const orderDate = new Date(order.createdAt);
      const fromDate = new Date(filters.dateFrom);
      if (orderDate < fromDate) return false;
    }
    if (filters.dateTo) {
      const orderDate = new Date(order.createdAt);
      const toDate = new Date(filters.dateTo);
      if (orderDate > toDate) return false;
    }
    return true;
  });
</script>

<div class="space-y-6">
  <div class="bg-white rounded-lg shadow p-6">
    <h2 class="text-2xl font-semibold text-gray-900 mb-6">订单管理</h2>

    <!-- 筛选器 -->
    <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">订单状态</label>
        <select
          bind:value={filters.status}
          class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
        >
          {#each statusOptions as option}
            <option value={option.value}>{option.label}</option>
          {/each}
        </select>
      </div>
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">开始日期</label>
        <input
          type="date"
          bind:value={filters.dateFrom}
          class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
        />
      </div>
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">结束日期</label>
        <input
          type="date"
          bind:value={filters.dateTo}
          class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
        />
      </div>
    </div>

    <!-- 订单列表 -->
    {#if loading}
      <div class="text-center py-8">
        <svg class="animate-spin h-8 w-8 text-blue-600 mx-auto mb-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 714 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
        <p class="text-gray-600">加载中...</p>
      </div>
    {:else if filteredOrders.length === 0}
      <div class="text-center py-8">
        <svg class="w-16 h-16 text-gray-400 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path>
        </svg>
        <p class="text-gray-600">暂无订单</p>
      </div>
    {:else}
      <div class="overflow-x-auto">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">订单号</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">商品</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">买家</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">金额</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">状态</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">下单时间</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">操作</th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            {#each filteredOrders as order}
              <tr class="hover:bg-gray-50">
                <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                  #{order.id}
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <div class="flex items-center">
                    <img class="h-10 w-10 rounded object-cover" src={order.product.image} alt={order.product.name} />
                    <div class="ml-4">
                      <div class="text-sm font-medium text-gray-900">{order.product.name}</div>
                      <div class="text-sm text-gray-500">数量: {order.quantity}</div>
                    </div>
                  </div>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  {order.buyer.email}
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  {formatCurrency(order.totalAmount)}
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <span class="px-2 py-1 text-xs rounded-full {getStatusColor(order.status)}">
                    {getStatusText(order.status)}
                  </span>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  {new Date(order.createdAt).toLocaleString('zh-CN')}
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
                  <button class="text-blue-600 hover:text-blue-900">
                    查看详情
                  </button>
                </td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>
    {/if}
  </div>
</div> 