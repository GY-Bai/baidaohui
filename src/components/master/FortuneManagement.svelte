<script>
  import { onMount } from 'svelte';
  import { apiCall, formatDate, formatTime, formatCurrency } from '$lib/auth';
  

  export const session = undefined;

  let orders = [];
  let loading = true;
  let currentPage = 1;
  let totalPages = 1;
  let pageSize = 20;
  let totalOrders = 0;

  // 筛选条件
  let filters = {
    status: '',
    dateFrom: '',
    dateTo: '',
    minAmount: '',
    maxAmount: '',
    emergency: '',
    search: ''
  };

  // 排序条件
  let sortBy = 'priority'; // priority, createdAt, amount
  let sortOrder = 'desc';

  // 详情侧栏
  let showDetails = false;
  let selectedOrder = null;
  let replyContent = '';
  let replyImages = [];
  let isDraft = false;
  let uploadingReply = false;

  // 系统设置
  let fortuneEnabled = true;
  let minAmount = 50;
  let minCurrency = 'CAD';

  onMount(() => {
    loadOrders();
    loadSettings();
  });

  async function loadOrders() {
    try {
      loading = true;
      const params = new URLSearchParams({
        page: currentPage.toString(),
        limit: pageSize.toString(),
        sortBy,
        sortOrder,
        ...Object.fromEntries(Object.entries(filters).filter(([_, v]) => v))
      });

      const response = await apiCall(`/fortune/list?${params}`);
      orders = response.orders;
      totalPages = response.totalPages;
      totalOrders = response.total;
    } catch (error) {
      console.error('加载订单失败:', error);
      alert('加载订单失败，请重试');
    } finally {
      loading = false;
    }
  }

  async function loadSettings() {
    try {
      const settings = await apiCall('/fortune/settings');
      fortuneEnabled = settings.enabled;
      minAmount = settings.minAmount;
      minCurrency = settings.minCurrency;
    } catch (error) {
      console.error('加载设置失败:', error);
    }
  }

  async function updateSettings() {
    try {
      await apiCall('/fortune/settings', {
        method: 'PUT',
        body: JSON.stringify({
          enabled: fortuneEnabled,
          minAmount,
          minCurrency
        })
      });
      alert('设置已保存');
    } catch (error) {
      console.error('保存设置失败:', error);
      alert('保存设置失败，请重试');
    }
  }

  function applyFilters() {
    currentPage = 1;
    loadOrders();
  }

  function resetFilters() {
    filters = {
      status: '',
      dateFrom: '',
      dateTo: '',
      minAmount: '',
      maxAmount: '',
      emergency: '',
      search: ''
    };
    currentPage = 1;
    loadOrders();
  }

  function changePage(page) {
    currentPage = page;
    loadOrders();
  }

  function changeSort(field) {
    if (sortBy === field) {
      sortOrder = sortOrder === 'asc' ? 'desc' : 'asc';
    } else {
      sortBy = field;
      sortOrder = 'desc';
    }
    loadOrders();
  }

  function openDetails(order) {
    selectedOrder = order;
    showDetails = true;
    loadDraft(order._id);
  }

  function closeDetails() {
    showDetails = false;
    selectedOrder = null;
    replyContent = '';
    replyImages = [];
    isDraft = false;
  }

  async function loadDraft(orderId) {
    try {
      const draft = await apiCall(`/fortune/draft/${orderId}`);
      if (draft.content) {
        replyContent = draft.content;
        isDraft = true;
      }
    } catch (error) {
      // 没有草稿是正常的
    }
  }

  async function saveDraft() {
    if (!selectedOrder || !replyContent.trim()) return;

    try {
      await apiCall('/fortune/reply', {
        method: 'POST',
        body: JSON.stringify({
          orderId: selectedOrder._id,
          replyContent: replyContent.trim(),
          draft: true
        })
      });
      isDraft = true;
      alert('草稿已保存');
    } catch (error) {
      console.error('保存草稿失败:', error);
      alert('保存草稿失败，请重试');
    }
  }

  async function publishReply() {
    if (!selectedOrder || !replyContent.trim()) {
      alert('请输入回复内容');
      return;
    }

    if (!confirm('确定要发布回复吗？发布后将无法修改。')) {
      return;
    }

    try {
      uploadingReply = true;
      
      // 上传图片
      const imageUrls = [];
      for (const file of replyImages) {
        const formData = new FormData();
        formData.append('file', file);
        const response = await apiCall('/fortune/upload-reply-image', {
          method: 'POST',
          body: formData
        });
        imageUrls.push(response.url);
      }

      await apiCall('/fortune/reply', {
        method: 'POST',
        body: JSON.stringify({
          orderId: selectedOrder._id,
          replyContent: replyContent.trim(),
          replyImages: imageUrls,
          draft: false
        })
      });

      alert('回复已发布');
      closeDetails();
      loadOrders();
    } catch (error) {
      console.error('发布回复失败:', error);
      alert('发布回复失败，请重试');
    } finally {
      uploadingReply = false;
    }
  }

  function handleImageUpload(event) {
    const target = event.target;
    const files = Array.from(target.files || []);
    
    for (const file of files) {
      if (file.size > 5 * 1024 * 1024) {
        alert('图片大小不能超过5MB');
        continue;
      }
      if (!file.type.startsWith('image/')) {
        alert('只能上传图片文件');
        continue;
      }
      replyImages = [...replyImages, file];
    }
    
    target.value = '';
  }

  function removeImage(index) {
    replyImages = replyImages.filter((_, i) => i !== index);
  }

  function getStatusColor(status) {
    switch (status) {
      case 'Pending': return 'text-yellow-600 bg-yellow-100';
      case 'Queued-payed': return 'text-blue-600 bg-blue-100';
      case 'Queued-upload': return 'text-purple-600 bg-purple-100';
      case 'Completed': return 'text-green-600 bg-green-100';
      case 'Refunded': return 'text-red-600 bg-red-100';
      default: return 'text-gray-600 bg-gray-100';
    }
  }

  function getStatusText(status) {
    switch (status) {
      case 'Pending': return '待付款';
      case 'Queued-payed': return '已付款';
      case 'Queued-upload': return '凭证上传';
      case 'Completed': return '已完成';
      case 'Refunded': return '已退款';
      default: return status;
    }
  }
</script>

<div class="space-y-6">
  <!-- 系统设置 -->
  <div class="bg-white rounded-lg shadow p-6">
    <h2 class="text-lg font-semibold text-gray-900 mb-4">算命服务设置</h2>
    
    <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
      <div class="flex items-center space-x-3">
        <label class="flex items-center">
          <input
            type="checkbox"
            bind:checked={fortuneEnabled}
            class="rounded border-gray-300 text-blue-600 focus:ring-blue-500"
          />
          <span class="ml-2 text-sm font-medium text-gray-700">启用算命服务</span>
        </label>
      </div>
      
      <div>
        <label for="min-amount" class="block text-sm font-medium text-gray-700 mb-1">最低金额</label>
        <div class="flex space-x-2">
          <input
            id="min-amount"
            type="number"
            bind:value={minAmount}
            min="0"
            class="flex-1 px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
          <select
            bind:value={minCurrency}
            class="px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          >
            <option value="CAD">CAD</option>
            <option value="USD">USD</option>
            <option value="CNY">CNY</option>
            <option value="SGD">SGD</option>
            <option value="AUD">AUD</option>
          </select>
        </div>
      </div>
      
      <div class="flex items-end">
        <button
          on:click={updateSettings}
          class="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 transition-colors"
        >
          保存设置
        </button>
      </div>
    </div>
  </div>

  <!-- 筛选和搜索 -->
  <div class="bg-white rounded-lg shadow p-6">
    <h3 class="text-lg font-semibold text-gray-900 mb-4">筛选条件</h3>
    
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-4">
      <div>
        <label for="filter-status" class="block text-sm font-medium text-gray-700 mb-1">状态</label>
        <select
          id="filter-status"
          bind:value={filters.status}
          class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
        >
          <option value="">全部状态</option>
          <option value="Pending">待付款</option>
          <option value="Queued-payed">已付款</option>
          <option value="Queued-upload">凭证上传</option>
          <option value="Completed">已完成</option>
          <option value="Refunded">已退款</option>
        </select>
      </div>
      
      <div>
        <label for="filter-emergency" class="block text-sm font-medium text-gray-700 mb-1">紧急订单</label>
        <select
          id="filter-emergency"
          bind:value={filters.emergency}
          class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
        >
          <option value="">全部</option>
          <option value="true">仅紧急</option>
          <option value="false">非紧急</option>
        </select>
      </div>
      
      <div>
        <label for="filter-date-from" class="block text-sm font-medium text-gray-700 mb-1">开始日期</label>
        <input
          id="filter-date-from"
          type="date"
          bind:value={filters.dateFrom}
          class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
        />
      </div>
      
      <div>
        <label for="filter-date-to" class="block text-sm font-medium text-gray-700 mb-1">结束日期</label>
        <input
          id="filter-date-to"
          type="date"
          bind:value={filters.dateTo}
          class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
        />
      </div>
    </div>
    
    <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-4">
      <div>
        <label for="filter-min-amount" class="block text-sm font-medium text-gray-700 mb-1">最低金额 (CAD)</label>
        <input
          id="filter-min-amount"
          type="number"
          bind:value={filters.minAmount}
          placeholder="最低金额"
          class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
        />
      </div>
      
      <div>
        <label for="filter-max-amount" class="block text-sm font-medium text-gray-700 mb-1">最高金额 (CAD)</label>
        <input
          id="filter-max-amount"
          type="number"
          bind:value={filters.maxAmount}
          placeholder="最高金额"
          class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
        />
      </div>
      
      <div>
        <label for="filter-search" class="block text-sm font-medium text-gray-700 mb-1">搜索用户</label>
        <input
          id="filter-search"
          type="text"
          bind:value={filters.search}
          placeholder="用户昵称或ID"
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
        on:click={resetFilters}
        class="px-4 py-2 bg-gray-300 text-gray-700 rounded-md hover:bg-gray-400 transition-colors"
      >
        重置
      </button>
    </div>
  </div>

  <!-- 订单列表 -->
  <div class="bg-white rounded-lg shadow">
    <div class="px-6 py-4 border-b border-gray-200">
      <div class="flex items-center justify-between">
        <h3 class="text-lg font-semibold text-gray-900">算命订单列表</h3>
        <span class="text-sm text-gray-500">共 {totalOrders} 条记录</span>
      </div>
    </div>
    
    {#if loading}
      <div class="p-8 text-center">
        <svg class="animate-spin h-8 w-8 text-blue-600 mx-auto mb-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
        <p class="text-gray-600">加载中...</p>
      </div>
    {:else if orders.length === 0}
      <div class="p-8 text-center">
        <svg class="w-12 h-12 text-gray-400 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path>
        </svg>
        <p class="text-gray-600">暂无订单数据</p>
      </div>
    {:else}
      <div class="overflow-x-auto">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                <button on:click={() => changeSort('queueIndex')} 
                        class="flex items-center space-x-1 hover:text-gray-700"
                        aria-label="按排队序号排序">
                  <span>排队序号</span>
                  {#if sortBy === 'queueIndex'}
                    <span aria-hidden="true">{sortOrder === 'asc' ? '↑' : '↓'}</span>
                  {/if}
                </button>
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">用户信息</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                <button on:click={() => changeSort('amount')} 
                        class="flex items-center space-x-1 hover:text-gray-700"
                        aria-label="按金额排序">
                  <span>金额</span>
                  {#if sortBy === 'amount'}
                    <span aria-hidden="true">{sortOrder === 'asc' ? '↑' : '↓'}</span>
                  {/if}
                </button>
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">状态</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                <button on:click={() => changeSort('createdAt')} 
                        class="flex items-center space-x-1 hover:text-gray-700"
                        aria-label="按提交时间排序">
                  <span>提交时间</span>
                  {#if sortBy === 'createdAt'}
                    <span aria-hidden="true">{sortOrder === 'asc' ? '↑' : '↓'}</span>
                  {/if}
                </button>
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">操作</th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            {#each orders as order}
              <tr class="hover:bg-gray-50 {order.kidsEmergency ? 'bg-red-50' : ''}">
                <td class="px-6 py-4 whitespace-nowrap">
                  <div class="flex items-center">
                    {#if order.kidsEmergency}
                      <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-red-100 text-red-800 mr-2">
                        紧急
                      </span>
                    {/if}
                    <span class="text-sm font-medium text-gray-900">#{order.queueIndex}</span>
                  </div>
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <div>
                    <div class="text-sm font-medium text-gray-900">{order.userNickname}</div>
                    <div class="text-sm text-gray-500">{order.userId}</div>
                  </div>
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <div>
                    <div class="text-sm font-medium text-gray-900">
                      {formatCurrency(order.convertedAmountCAD, 'CAD')}
                    </div>
                    <div class="text-sm text-gray-500">
                      原价: {formatCurrency(order.amount, order.currency)}
                    </div>
                  </div>
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium {getStatusColor(order.status)}">
                    {getStatusText(order.status)}
                  </span>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  <div>
                    <div>{formatDate(order.createdAt)}</div>
                    <div>{formatTime(order.createdAt)}</div>
                  </div>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
                  <button
                    on:click={() => openDetails(order)}
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
        <div class="px-6 py-4 border-t border-gray-200">
          <div class="flex items-center justify-between">
            <div class="text-sm text-gray-700">
              显示第 {(currentPage - 1) * pageSize + 1} - {Math.min(currentPage * pageSize, totalOrders)} 条，共 {totalOrders} 条
            </div>
            <div class="flex space-x-2">
              <button
                on:click={() => changePage(currentPage - 1)}
                disabled={currentPage === 1}
                class="px-3 py-2 text-sm bg-white border border-gray-300 rounded-md hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                上一页
              </button>
              
              {#each Array.from({length: Math.min(5, totalPages)}, (_, i) => {
                const start = Math.max(1, currentPage - 2);
                return start + i;
              }) as page}
                {#if page <= totalPages}
                  <button
                    on:click={() => changePage(page)}
                    class="px-3 py-2 text-sm border rounded-md {
                      page === currentPage 
                        ? 'bg-blue-600 text-white border-blue-600' 
                        : 'bg-white text-gray-700 border-gray-300 hover:bg-gray-50'
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
        </div>
      {/if}
    {/if}
  </div>
</div>

<!-- 订单详情侧栏 -->
{#if showDetails && selectedOrder}
  <div class="fixed inset-0 bg-black bg-opacity-50 z-50">
    <div class="fixed right-0 top-0 h-full w-full max-w-2xl bg-white shadow-xl overflow-y-auto">
      <div class="p-6">
        <div class="flex items-center justify-between mb-6">
          <h2 class="text-xl font-semibold text-gray-900">订单详情</h2>
          <button
            on:click={closeDetails}
            class="text-gray-400 hover:text-gray-600"
          >
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
            </svg>
          </button>
        </div>
        
        <!-- 订单基本信息 -->
        <div class="bg-gray-50 rounded-lg p-4 mb-6">
          <div class="grid grid-cols-2 gap-4">
            <div>
              <span class="text-sm font-medium text-gray-500">订单号</span>
              <p class="text-sm text-gray-900">#{selectedOrder.queueIndex}</p>
            </div>
            <div>
              <span class="text-sm font-medium text-gray-500">用户</span>
              <p class="text-sm text-gray-900">{selectedOrder.userNickname}</p>
            </div>
            <div>
              <span class="text-sm font-medium text-gray-500">金额</span>
              <p class="text-sm text-gray-900">
                {formatCurrency(selectedOrder.convertedAmountCAD, 'CAD')}
                <span class="text-gray-500">
                  (原价: {formatCurrency(selectedOrder.amount, selectedOrder.currency)})
                </span>
              </p>
            </div>
            <div>
              <span class="text-sm font-medium text-gray-500">状态</span>
              <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium {getStatusColor(selectedOrder.status)}">
                {getStatusText(selectedOrder.status)}
              </span>
            </div>
            <div>
              <span class="text-sm font-medium text-gray-500">提交时间</span>
              <p class="text-sm text-gray-900">{formatDate(selectedOrder.createdAt)} {formatTime(selectedOrder.createdAt)}</p>
            </div>
            <div>
              <span class="text-sm font-medium text-gray-500">剩余修改次数</span>
              <p class="text-sm text-gray-900">{selectedOrder.remainingModifications}</p>
            </div>
          </div>
        </div>
        
        <!-- 用户附言 -->
        <div class="mb-6">
          <h3 class="text-lg font-medium text-gray-900 mb-3">用户附言</h3>
          <div class="bg-gray-50 rounded-lg p-4">
            <p class="text-sm text-gray-900 whitespace-pre-wrap">{selectedOrder.message}</p>
          </div>
        </div>
        
        <!-- 上传图片 -->
        {#if selectedOrder.images.length > 0}
          <div class="mb-6">
            <h3 class="text-lg font-medium text-gray-900 mb-3">上传图片</h3>
            <div class="grid grid-cols-3 gap-3">
              {#each selectedOrder.images as image}
                <button
                  on:click={() => window.open(image, '_blank')}
                  class="block w-full h-24 rounded-lg overflow-hidden hover:opacity-90 focus:outline-none focus:ring-2 focus:ring-blue-500"
                  aria-label="在新窗口中查看用户上传图片"
                >
                  <img
                    src={image}
                    alt="用户上传图片"
                    class="w-full h-full object-cover"
                  />
                </button>
              {/each}
            </div>
          </div>
        {/if}
        
        <!-- 付款凭证 -->
        {#if selectedOrder.paymentScreenshots && selectedOrder.paymentScreenshots.length > 0}
          <div class="mb-6">
            <h3 class="text-lg font-medium text-gray-900 mb-3">付款凭证</h3>
            <div class="grid grid-cols-3 gap-3">
              {#each selectedOrder.paymentScreenshots as screenshot}
                <button
                  on:click={() => window.open(screenshot, '_blank')}
                  class="block w-full h-24 rounded-lg overflow-hidden hover:opacity-90 focus:outline-none focus:ring-2 focus:ring-blue-500"
                  aria-label="在新窗口中查看付款凭证"
                >
                  <img
                    src={screenshot}
                    alt="付款凭证"
                    class="w-full h-full object-cover"
                  />
                </button>
              {/each}
            </div>
          </div>
        {/if}
        
        <!-- 修改历史 -->
        {#if selectedOrder.modifications.length > 0}
          <div class="mb-6">
            <h3 class="text-lg font-medium text-gray-900 mb-3">修改历史</h3>
            <div class="space-y-3">
              {#each selectedOrder.modifications as modification}
                <div class="bg-gray-50 rounded-lg p-3">
                  <div class="text-xs text-gray-500 mb-2">
                    {formatDate(modification.modifiedAt)} {formatTime(modification.modifiedAt)}
                  </div>
                  <p class="text-sm text-gray-900">{modification.message}</p>
                </div>
              {/each}
            </div>
          </div>
        {/if}
        
        <!-- 回复区域 -->
        <div class="border-t pt-6">
          <h3 class="text-lg font-medium text-gray-900 mb-3">
            回复内容
            {#if isDraft}
              <span class="text-sm text-yellow-600">(有草稿)</span>
            {/if}
          </h3>
          
          {#if selectedOrder.reply}
            <!-- 已发布的回复 -->
            <div class="bg-blue-50 rounded-lg p-4 mb-4">
              <div class="text-xs text-blue-600 mb-2">
                已回复 - {formatDate(selectedOrder.reply.repliedAt)} {formatTime(selectedOrder.reply.repliedAt)}
              </div>
              <p class="text-sm text-gray-900 whitespace-pre-wrap">{selectedOrder.reply.content}</p>
              {#if selectedOrder.reply.images.length > 0}
                <div class="grid grid-cols-3 gap-2 mt-3">
                  {#each selectedOrder.reply.images as image}
                    <button
                      on:click={() => window.open(image, '_blank')}
                      class="block w-full h-16 rounded overflow-hidden hover:opacity-90 focus:outline-none focus:ring-2 focus:ring-blue-500"
                      aria-label="在新窗口中查看回复图片"
                    >
                      <img
                        src={image}
                        alt="回复图片"
                        class="w-full h-full object-cover"
                      />
                    </button>
                  {/each}
                </div>
              {/if}
            </div>
          {:else}
            <!-- 回复编辑器 -->
            <div class="space-y-4">
              <textarea
                id="reply-content"
                bind:value={replyContent}
                placeholder="输入回复内容..."
                rows="6"
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              ></textarea>
              
              <!-- 图片上传 -->
              <div>
                <label for="reply-image-upload" class="block text-sm font-medium text-gray-700 mb-2">上传图片</label>
                <input
                  id="reply-image-upload"
                  type="file"
                  multiple
                  accept="image/*"
                  on:change={handleImageUpload}
                  class="block w-full text-sm text-gray-500 file:mr-4 file:py-2 file:px-4 file:rounded-full file:border-0 file:text-sm file:font-semibold file:bg-blue-50 file:text-blue-700 hover:file:bg-blue-100"
                />
                
                {#if replyImages.length > 0}
                  <div class="grid grid-cols-4 gap-2 mt-3">
                    {#each replyImages as image, index}
                      <div class="relative">
                        <img
                          src={URL.createObjectURL(image)}
                          alt="预览图片"
                          class="w-full h-16 object-cover rounded"
                        />
                        <button
                          on:click={() => removeImage(index)}
                          class="absolute -top-2 -right-2 w-5 h-5 bg-red-500 text-white rounded-full text-xs hover:bg-red-600"
                        >
                          ×
                        </button>
                      </div>
                    {/each}
                  </div>
                {/if}
              </div>
              
              <!-- 操作按钮 -->
              <div class="flex space-x-3">
                <button
                  on:click={saveDraft}
                  disabled={!replyContent.trim()}
                  class="px-4 py-2 bg-gray-300 text-gray-700 rounded-md hover:bg-gray-400 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                >
                  保存草稿
                </button>
                <button
                  on:click={publishReply}
                  disabled={!replyContent.trim() || uploadingReply}
                  class="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                >
                  {uploadingReply ? '发布中...' : '发布回复'}
                </button>
              </div>
            </div>
          {/if}
        </div>
      </div>
    </div>
  </div>
{/if} 