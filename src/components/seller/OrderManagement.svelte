<script>
  import { onMount } from 'svelte';
  import { apiCall } from '$lib/auth';
  

  export const session = undefined;


  let orders = [];
  let loading = true;
  let error = '';
  let selectedOrder = null;
  let showOrderDetail = false;
  let currentPage = 1;
  let totalPages = 1;
  let totalOrders = 0;

  let filters = {
    status: '',
    dateFrom: '',
    dateTo: '',
    search: ''
  };

  const statusOptions = [
    { value: '', label: '全部状态' },
    { value: 'pending', label: '待付款' },
    { value: 'queued-payed', label: '已付款排队中' },
    { value: 'queued-processing', label: '处理中' },
    { value: 'queued-shipped', label: '已发货' },
    { value: 'completed', label: '已完成' },
    { value: 'cancelled', label: '已取消' },
    { value: 'refunded', label: '已退款' }
  ];

  onMount(() => {
    loadOrders();
  });

  async function loadOrders() {
    try {
      loading = true;
      error = '';
      
      const params = new URLSearchParams({
        page: currentPage.toString(),
        limit: '20',
        ...filters
      });

      const response = await apiCall(`/seller/orders?${params}`);
      
      orders = response.orders || [];
      totalPages = response.totalPages || 1;
      totalOrders = response.total || 0;
    } catch (err) {
      console.error('加载订单失败:', err);
      error = '加载订单失败，请重试';
      orders = [];
    } finally {
      loading = false;
    }
  }

  async function updateOrderStatus(orderId, newStatus) {
    try {
      await apiCall(`/seller/orders/${orderId}/status`, {
        method: 'PUT',
        body: JSON.stringify({ status: newStatus })
      });
      
      // 更新本地订单状态
      orders = orders.map(order => 
        order.id === orderId ? { ...order, status: newStatus } : order
      );
      
      if (selectedOrder && selectedOrder.id === orderId) {
        selectedOrder = { ...selectedOrder, status: newStatus };
      }
    } catch (err) {
      console.error('更新订单状态失败:', err);
      alert('更新订单状态失败，请重试');
    }
  }

  function getStatusText(status) {
    const statusMap = {
      'pending': '待付款',
      'queued-payed': '已付款排队中',
      'queued-processing': '处理中',
      'queued-shipped': '已发货',
      'completed': '已完成',
      'cancelled': '已取消',
      'refunded': '已退款'
    };
    return statusMap[status] || status;
  }

  function getStatusColor(status) {
    const colorMap = {
      'pending': 'bg-yellow-100 text-yellow-800',
      'queued-payed': 'bg-blue-100 text-blue-800',
      'queued-processing': 'bg-purple-100 text-purple-800',
      'queued-shipped': 'bg-indigo-100 text-indigo-800',
      'completed': 'bg-green-100 text-green-800',
      'cancelled': 'bg-red-100 text-red-800',
      'refunded': 'bg-gray-100 text-gray-800'
    };
    return colorMap[status] || 'bg-gray-100 text-gray-800';
  }

  function formatCurrency(amount, currency) {
    return new Intl.NumberFormat('zh-CN', {
      style: 'currency',
      currency: currency
    }).format(amount);
  }

  function formatDate(dateString) {
    return new Date(dateString).toLocaleString('zh-CN');
  }

  function viewOrderDetail(order) {
    selectedOrder = order;
    showOrderDetail = true;
  }

  function closeOrderDetail() {
    selectedOrder = null;
    showOrderDetail = false;
  }

  function applyFilters() {
    currentPage = 1;
    loadOrders();
  }

  function clearFilters() {
    filters = {
      status: '',
      dateFrom: '',
      dateTo: '',
      search: ''
    };
    currentPage = 1;
    loadOrders();
  }

  function changePage(page) {
    currentPage = page;
    loadOrders();
  }

  function getAvailableStatusTransitions(currentStatus) {
    const transitions = {
      'pending': [],
      'queued-payed': ['queued-processing', 'cancelled'],
      'queued-processing': ['queued-shipped', 'cancelled'],
      'queued-shipped': ['completed'],
      'completed': ['refunded'],
      'cancelled': [],
      'refunded': []
    };
    return transitions[currentStatus] || [];
  }
</script>

<div class="space-y-6">
  <div class="bg-white rounded-lg shadow p-6">
    <div class="flex items-center justify-between mb-6">
      <h2 class="text-2xl font-semibold text-gray-900">订单管理</h2>
      <div class="text-sm text-gray-600">
        共 {totalOrders} 个订单
      </div>
    </div>

    <!-- 筛选器 -->
    <div class="bg-gray-50 rounded-lg p-4 mb-6">
      <div class="grid grid-cols-1 md:grid-cols-4 gap-4 mb-4">
        <div>
          <label for="order-search" class="block text-sm font-medium text-gray-700 mb-2">搜索</label>
          <input
            id="order-search"
            type="text"
            bind:value={filters.search}
            placeholder="订单号、商品名称、买家邮箱"
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>
        <div>
          <label for="order-status" class="block text-sm font-medium text-gray-700 mb-2">订单状态</label>
          <select
            id="order-status"
            bind:value={filters.status}
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          >
            {#each statusOptions as option}
              <option value={option.value}>{option.label}</option>
            {/each}
          </select>
        </div>
        <div>
          <label for="date-from" class="block text-sm font-medium text-gray-700 mb-2">开始日期</label>
          <input
            id="date-from"
            type="date"
            bind:value={filters.dateFrom}
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>
        <div>
          <label for="date-to" class="block text-sm font-medium text-gray-700 mb-2">结束日期</label>
          <input
            id="date-to"
            type="date"
            bind:value={filters.dateTo}
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>
      </div>
      <div class="flex space-x-3">
        <button
          on:click={applyFilters}
          class="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 transition-colors"
        >
          应用筛选
        </button>
        <button
          on:click={clearFilters}
          class="px-4 py-2 bg-gray-300 text-gray-700 rounded-md hover:bg-gray-400 transition-colors"
        >
          清除筛选
        </button>
      </div>
    </div>

    <!-- 错误提示 -->
    {#if error}
      <div class="bg-red-50 border border-red-200 rounded-lg p-4 mb-6">
        <div class="flex">
          <svg class="w-5 h-5 text-red-400 mr-2" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clip-rule="evenodd"></path>
          </svg>
          <span class="text-red-800">{error}</span>
        </div>
      </div>
    {/if}

    <!-- 订单列表 -->
    {#if loading}
      <div class="text-center py-8">
        <svg class="animate-spin h-8 w-8 text-blue-600 mx-auto mb-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 714 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
        <p class="text-gray-600">加载中...</p>
      </div>
    {:else if orders.length === 0}
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
            {#each orders as order}
              <tr class="hover:bg-gray-50">
                <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                  #{order.orderId}
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <div class="flex items-center">
                    <img class="h-10 w-10 rounded object-cover" src={order.productImage} alt={order.productName} />
                    <div class="ml-4">
                      <div class="text-sm font-medium text-gray-900">{order.productName}</div>
                      <div class="text-sm text-gray-500">数量: {order.quantity}</div>
                    </div>
                  </div>
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <div class="text-sm text-gray-900">{order.buyerName || order.buyerEmail}</div>
                  <div class="text-sm text-gray-500">{order.buyerEmail}</div>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  {formatCurrency(order.totalAmount, order.currency)}
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <span class="px-2 py-1 text-xs rounded-full {getStatusColor(order.status)}">
                    {getStatusText(order.status)}
                  </span>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  {formatDate(order.createdAt)}
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm font-medium space-x-2">
                  <button 
                    on:click={() => viewOrderDetail(order)}
                    class="text-blue-600 hover:text-blue-900"
                  >
                    查看详情
                  </button>
                </td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>

      <!-- 分页 -->
      {#if totalPages > 1}
        <div class="flex items-center justify-between mt-6">
          <div class="text-sm text-gray-700">
            第 {currentPage} 页，共 {totalPages} 页
          </div>
          <div class="flex space-x-2">
            <button
              on:click={() => changePage(currentPage - 1)}
              disabled={currentPage === 1}
              class="px-3 py-2 text-sm bg-white border border-gray-300 rounded-md hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              上一页
            </button>
            {#each Array.from({length: Math.min(5, totalPages)}, (_, i) => i + Math.max(1, currentPage - 2)) as page}
              {#if page <= totalPages}
                <button
                  on:click={() => changePage(page)}
                  class="px-3 py-2 text-sm rounded-md {
                    page === currentPage 
                      ? 'bg-blue-600 text-white' 
                      : 'bg-white border border-gray-300 hover:bg-gray-50'
                  }"
                >
                  {page}
                </button>
              {/if}
            {/each}
            <button
              on:click={() => changePage(currentPage + 1)}
              disabled={currentPage === totalPages}
              class="px-3 py-2 text-sm bg-white border border-gray-300 rounded-md hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              下一页
            </button>
          </div>
        </div>
      {/if}
    {/if}
  </div>
</div>

<!-- 订单详情弹窗 -->
{#if showOrderDetail && selectedOrder}
  <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
    <div class="bg-white rounded-lg p-6 max-w-2xl w-full mx-4 max-h-[90vh] overflow-y-auto">
      <div class="flex items-center justify-between mb-6">
        <h3 class="text-lg font-semibold text-gray-900">订单详情</h3>
        <button
          on:click={closeOrderDetail}
          class="text-gray-400 hover:text-gray-600"
        >
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
          </svg>
        </button>
      </div>

      <div class="space-y-6">
        <!-- 基本信息 -->
        <div class="grid grid-cols-2 gap-4">
          <div>
            <span class="block text-sm font-medium text-gray-700">订单号</span>
            <p class="text-sm text-gray-900">#{selectedOrder.orderId}</p>
          </div>
          <div>
            <span class="block text-sm font-medium text-gray-700">下单时间</span>
            <p class="text-sm text-gray-900">{formatDate(selectedOrder.createdAt)}</p>
          </div>
          <div>
            <span class="block text-sm font-medium text-gray-700">支付方式</span>
            <p class="text-sm text-gray-900">{selectedOrder.paymentMethod}</p>
          </div>
          <div>
            <span class="block text-sm font-medium text-gray-700">当前状态</span>
            <span class="px-2 py-1 text-xs rounded-full {getStatusColor(selectedOrder.status)}">
              {getStatusText(selectedOrder.status)}
            </span>
          </div>
        </div>

        <!-- 商品信息 -->
        <div>
          <h4 class="font-medium text-gray-900 mb-3">商品信息</h4>
          <div class="flex items-center p-4 bg-gray-50 rounded-lg">
            <img class="h-16 w-16 rounded object-cover" src={selectedOrder.productImage} alt={selectedOrder.productName} />
            <div class="ml-4 flex-1">
              <h5 class="font-medium text-gray-900">{selectedOrder.productName}</h5>
              <p class="text-sm text-gray-600">数量: {selectedOrder.quantity}</p>
              <p class="text-sm text-gray-600">单价: {formatCurrency(selectedOrder.unitPrice, selectedOrder.currency)}</p>
            </div>
            <div class="text-right">
              <p class="font-medium text-gray-900">{formatCurrency(selectedOrder.totalAmount, selectedOrder.currency)}</p>
            </div>
          </div>
        </div>

        <!-- 买家信息 -->
        <div>
          <h4 class="font-medium text-gray-900 mb-3">买家信息</h4>
          <div class="bg-gray-50 rounded-lg p-4">
            <p class="text-sm"><span class="font-medium">姓名:</span> {selectedOrder.buyerName || '未提供'}</p>
            <p class="text-sm"><span class="font-medium">邮箱:</span> {selectedOrder.buyerEmail}</p>
            {#if selectedOrder.shippingAddress}
              <p class="text-sm"><span class="font-medium">收货地址:</span> {JSON.stringify(selectedOrder.shippingAddress)}</p>
            {/if}
          </div>
        </div>

        <!-- 状态操作 -->
        {#if getAvailableStatusTransitions(selectedOrder.status).length > 0}
          <div>
            <h4 class="font-medium text-gray-900 mb-3">状态操作</h4>
            <div class="flex space-x-2">
              {#each getAvailableStatusTransitions(selectedOrder.status) as status}
                <button
                  on:click={() => updateOrderStatus(selectedOrder.id, status)}
                  class="px-3 py-2 text-sm bg-blue-600 text-white rounded-md hover:bg-blue-700 transition-colors"
                >
                  更新为{getStatusText(status)}
                </button>
              {/each}
            </div>
          </div>
        {/if}
      </div>
    </div>
  </div>
{/if} 