<script lang="ts">
  import { onMount } from 'svelte';

  let orders = [];
  let loading = true;
  let selectedOrder = null;
  let showDetailSidebar = false;
  let replyContent = '';
  let isDraft = false;
  let savingReply = false;

  // 筛选和搜索
  let filters = {
    status: '',
    dateFrom: '',
    dateTo: '',
    minAmount: '',
    maxAmount: '',
    emergency: '',
    searchTerm: ''
  };

  // 分页
  let currentPage = 1;
  let totalPages = 1;
  let pageSize = 20;

  const statusOptions = [
    { value: '', label: '全部状态' },
    { value: 'Pending', label: '待付款' },
    { value: 'Queued-payed', label: '已付款排队中' },
    { value: 'Queued-upload', label: '凭证已上传' },
    { value: 'Completed', label: '已完成' },
    { value: 'Refunded', label: '已退款' }
  ];

  onMount(() => {
    loadOrders();
  });

  async function loadOrders() {
    try {
      loading = true;
      const params = new URLSearchParams({
        page: currentPage.toString(),
        limit: pageSize.toString(),
        ...Object.fromEntries(Object.entries(filters).filter(([_, v]) => v !== ''))
      });

      const response = await fetch(`/api/fortune/admin/list?${params}`);
      if (response.ok) {
        const data = await response.json();
        orders = data.orders;
        totalPages = data.totalPages;
      }
    } catch (error) {
      console.error('加载订单失败:', error);
    } finally {
      loading = false;
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
      searchTerm: ''
    };
    applyFilters();
  }

  function openOrderDetail(order) {
    selectedOrder = order;
    showDetailSidebar = true;
    loadDraft(order.id);
  }

  function closeDetailSidebar() {
    showDetailSidebar = false;
    selectedOrder = null;
    replyContent = '';
  }

  async function loadDraft(orderId) {
    try {
      const response = await fetch(`/api/fortune/draft/${orderId}`);
      if (response.ok) {
        const data = await response.json();
        replyContent = data.content || '';
      }
    } catch (error) {
      console.error('加载草稿失败:', error);
    }
  }

  async function saveDraft() {
    if (!selectedOrder || !replyContent.trim()) return;

    try {
      savingReply = true;
      const response = await fetch('/api/fortune/reply', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          orderId: selectedOrder.id,
          replyContent: replyContent.trim(),
          draft: true
        })
      });

      if (response.ok) {
        alert('草稿已保存');
      } else {
        alert('保存草稿失败');
      }
    } catch (error) {
      console.error('保存草稿失败:', error);
      alert('保存草稿失败');
    } finally {
      savingReply = false;
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
      savingReply = true;
      const response = await fetch('/api/fortune/reply', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          orderId: selectedOrder.id,
          replyContent: replyContent.trim(),
          draft: false
        })
      });

      if (response.ok) {
        alert('回复已发布');
        closeDetailSidebar();
        loadOrders(); // 刷新列表
      } else {
        const error = await response.json();
        alert(error.message || '发布失败');
      }
    } catch (error) {
      console.error('发布回复失败:', error);
      alert('发布失败');
    } finally {
      savingReply = false;
    }
  }

  function getStatusText(status) {
    const statusMap = {
      'Pending': '待付款',
      'Queued-payed': '已付款排队中',
      'Queued-upload': '凭证已上传',
      'Completed': '已完成',
      'Refunded': '已退款'
    };
    return statusMap[status] || status;
  }

  function getStatusColor(status) {
    const colorMap = {
      'Pending': 'text-yellow-600 bg-yellow-100',
      'Queued-payed': 'text-blue-600 bg-blue-100',
      'Queued-upload': 'text-purple-600 bg-purple-100',
      'Completed': 'text-green-600 bg-green-100',
      'Refunded': 'text-red-600 bg-red-100'
    };
    return colorMap[status] || 'text-gray-600 bg-gray-100';
  }

  function formatDate(dateString) {
    return new Date(dateString).toLocaleString('zh-CN');
  }

  function formatAmount(amount, currency) {
    return `${amount} ${currency}`;
  }

  function goToPage(page) {
    if (page >= 1 && page <= totalPages) {
      currentPage = page;
      loadOrders();
    }
  }
</script>

<div class="space-y-6">
  <div class="bg-white rounded-lg shadow p-6">
    <div class="flex justify-between items-center mb-6">
      <h2 class="text-2xl font-semibold text-gray-900">算命管理</h2>
      <button
        on:click={loadOrders}
        class="px-4 py-2 bg-purple-600 text-white rounded-md hover:bg-purple-700 focus:outline-none focus:ring-2 focus:ring-purple-500"
      >
        🔄 刷新
      </button>
    </div>

    <!-- 筛选和搜索 -->
    <div class="bg-gray-50 rounded-lg p-4 mb-6">
      <h3 class="text-lg font-medium text-gray-900 mb-4">筛选与搜索</h3>
      
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-4">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">状态</label>
          <select
            bind:value={filters.status}
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-purple-500"
          >
            {#each statusOptions as option}
              <option value={option.value}>{option.label}</option>
            {/each}
          </select>
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">开始日期</label>
          <input
            type="date"
            bind:value={filters.dateFrom}
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-purple-500"
          />
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">结束日期</label>
          <input
            type="date"
            bind:value={filters.dateTo}
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-purple-500"
          />
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">紧急订单</label>
          <select
            bind:value={filters.emergency}
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-purple-500"
          >
            <option value="">全部</option>
            <option value="true">仅紧急</option>
            <option value="false">非紧急</option>
          </select>
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">最小金额 (CAD)</label>
          <input
            type="number"
            bind:value={filters.minAmount}
            placeholder="0"
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-purple-500"
          />
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">最大金额 (CAD)</label>
          <input
            type="number"
            bind:value={filters.maxAmount}
            placeholder="1000"
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-purple-500"
          />
        </div>

        <div class="md:col-span-2">
          <label class="block text-sm font-medium text-gray-700 mb-1">搜索用户</label>
          <input
            type="text"
            bind:value={filters.searchTerm}
            placeholder="用户昵称或ID"
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-purple-500"
          />
        </div>
      </div>

      <div class="flex space-x-3">
        <button
          on:click={applyFilters}
          class="px-4 py-2 bg-purple-600 text-white rounded-md hover:bg-purple-700 focus:outline-none focus:ring-2 focus:ring-purple-500"
        >
          应用筛选
        </button>
        <button
          on:click={resetFilters}
          class="px-4 py-2 bg-gray-300 text-gray-700 rounded-md hover:bg-gray-400 focus:outline-none focus:ring-2 focus:ring-gray-500"
        >
          重置
        </button>
      </div>
    </div>

    <!-- 订单列表 -->
    {#if loading}
      <div class="text-center py-8">
        <svg class="animate-spin h-8 w-8 text-purple-600 mx-auto mb-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
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
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">用户</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">提交时间</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">金额</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">状态</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">紧急</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">操作</th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            {#each orders as order}
              <tr class="hover:bg-gray-50">
                <td class="px-6 py-4 whitespace-nowrap">
                  <div>
                    <div class="text-sm font-medium text-gray-900">{order.userNickname || order.userId}</div>
                    <div class="text-sm text-gray-500">{order.userId}</div>
                  </div>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  {formatDate(order.createdAt)}
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <div class="text-sm font-bold text-gray-900">
                    {formatAmount(order.convertedAmountCAD, 'CAD')}
                  </div>
                  <div class="text-xs text-gray-500">
                    原价: {formatAmount(order.amount, order.currency)}
                  </div>
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <span class="px-2 py-1 text-xs rounded-full {getStatusColor(order.status)}">
                    {getStatusText(order.status)}
                  </span>
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  {#if order.kidsEmergency}
                    <span class="px-2 py-1 text-xs bg-red-100 text-red-800 rounded-full">紧急</span>
                  {:else}
                    <span class="text-gray-400">-</span>
                  {/if}
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
                  <button
                    on:click={() => openOrderDetail(order)}
                    class="text-purple-600 hover:text-purple-900"
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
              on:click={() => goToPage(currentPage - 1)}
              disabled={currentPage === 1}
              class="px-3 py-2 text-sm bg-gray-300 text-gray-700 rounded-md hover:bg-gray-400 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              上一页
            </button>
            <button
              on:click={() => goToPage(currentPage + 1)}
              disabled={currentPage === totalPages}
              class="px-3 py-2 text-sm bg-gray-300 text-gray-700 rounded-md hover:bg-gray-400 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              下一页
            </button>
          </div>
        </div>
      {/if}
    {/if}
  </div>
</div>

<!-- 订单详情侧栏 -->
{#if showDetailSidebar && selectedOrder}
  <div class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-hidden z-50">
    <div class="absolute inset-y-0 right-0 max-w-2xl w-full bg-white shadow-xl">
      <div class="h-full flex flex-col">
        <!-- 头部 -->
        <div class="px-6 py-4 bg-gray-50 border-b">
          <div class="flex items-center justify-between">
            <h3 class="text-lg font-medium text-gray-900">订单详情</h3>
            <button
              on:click={closeDetailSidebar}
              class="text-gray-400 hover:text-gray-600"
            >
              <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
              </svg>
            </button>
          </div>
        </div>

        <!-- 内容 -->
        <div class="flex-1 overflow-y-auto p-6">
          <div class="space-y-6">
            <!-- 基本信息 -->
            <div>
              <h4 class="font-medium text-gray-900 mb-3">基本信息</h4>
              <div class="bg-gray-50 rounded-lg p-4 space-y-2">
                <div class="flex justify-between">
                  <span class="text-gray-600">订单ID:</span>
                  <span class="font-medium">{selectedOrder.id}</span>
                </div>
                <div class="flex justify-between">
                  <span class="text-gray-600">用户:</span>
                  <span class="font-medium">{selectedOrder.userNickname || selectedOrder.userId}</span>
                </div>
                <div class="flex justify-between">
                  <span class="text-gray-600">提交时间:</span>
                  <span class="font-medium">{formatDate(selectedOrder.createdAt)}</span>
                </div>
                <div class="flex justify-between">
                  <span class="text-gray-600">金额:</span>
                  <span class="font-bold">{formatAmount(selectedOrder.convertedAmountCAD, 'CAD')}</span>
                </div>
                <div class="flex justify-between">
                  <span class="text-gray-600">剩余修改次数:</span>
                  <span class="font-medium">{selectedOrder.remainingModifications}</span>
                </div>
              </div>
            </div>

            <!-- 用户附言 -->
            <div>
              <h4 class="font-medium text-gray-900 mb-3">用户附言</h4>
              <div class="bg-gray-50 rounded-lg p-4">
                <p class="text-gray-700 whitespace-pre-wrap">{selectedOrder.message}</p>
              </div>
            </div>

            <!-- 上传图片 -->
            {#if selectedOrder.images && selectedOrder.images.length > 0}
              <div>
                <h4 class="font-medium text-gray-900 mb-3">上传图片</h4>
                <div class="grid grid-cols-2 gap-2">
                  {#each selectedOrder.images as image}
                    <img src={image} alt="用户上传" class="w-full h-32 object-cover rounded border" />
                  {/each}
                </div>
              </div>
            {/if}

            <!-- 回复编辑器 -->
            <div>
              <h4 class="font-medium text-gray-900 mb-3">回复内容</h4>
              <textarea
                bind:value={replyContent}
                rows="8"
                placeholder="请输入回复内容..."
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-purple-500"
              ></textarea>
              
              <div class="flex space-x-3 mt-4">
                <button
                  on:click={saveDraft}
                  disabled={savingReply}
                  class="px-4 py-2 bg-gray-600 text-white rounded-md hover:bg-gray-700 focus:outline-none focus:ring-2 focus:ring-gray-500 disabled:opacity-50"
                >
                  {savingReply ? '保存中...' : '保存草稿'}
                </button>
                <button
                  on:click={publishReply}
                  disabled={savingReply || !replyContent.trim()}
                  class="px-4 py-2 bg-purple-600 text-white rounded-md hover:bg-purple-700 focus:outline-none focus:ring-2 focus:ring-purple-500 disabled:opacity-50"
                >
                  {savingReply ? '发布中...' : '发布回复'}
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
{/if} 