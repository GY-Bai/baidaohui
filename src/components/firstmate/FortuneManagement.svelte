<!-- Firstmate的算命管理组件，与Master相同但有助理标识和权限限制 -->
<script>
  import { onMount } from 'svelte';

  let orders = [];
  let loading = true;
  let selectedOrder = null;
  let showDetailSidebar = false;
  let replyContent = '';
  let savingReply = false;

  // 筛选和搜索
  let filters = {
    status: '',
    searchTerm: ''
  };

  const statusOptions = [
    { value: '', label: '全部状态' },
    { value: 'Queued-payed', label: '已付款排队中' },
    { value: 'Queued-upload', label: '凭证已上传' }
  ];

  onMount(() => {
    loadOrders();
  });

  async function loadOrders() {
    try {
      loading = true;
      const response = await fetch('/api/fortune/orders?role=firstmate');
      if (response.ok) {
        orders = await response.json();
      }
    } catch (error) {
      console.error('加载订单失败:', error);
    } finally {
      loading = false;
    }
  }

  function openOrderDetail(order) {
    selectedOrder = order;
    replyContent = order.reply || '';
    showDetailSidebar = true;
  }

  function closeDetailSidebar() {
    showDetailSidebar = false;
    selectedOrder = null;
    replyContent = '';
  }

  async function saveReply() {
    if (!selectedOrder || !replyContent.trim()) {
      alert('请输入回复内容');
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
          reply: replyContent.trim(),
          repliedBy: 'firstmate'
        })
      });

      if (response.ok) {
        alert('回复保存成功');
        closeDetailSidebar();
        loadOrders();
        
        // 记录操作日志
        logOperation('fortune_reply', `回复算命订单 #${selectedOrder.id}`);
      } else {
        const error = await response.json();
        alert(error.message || '保存失败');
      }
    } catch (error) {
      console.error('保存回复失败:', error);
      alert('保存失败，请重试');
    } finally {
      savingReply = false;
    }
  }

  async function logOperation(type, description) {
    try {
      await fetch('/api/firstmate/operation-logs', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          type,
          description,
          timestamp: new Date().toISOString()
        })
      });
    } catch (error) {
      console.error('记录操作日志失败:', error);
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
      'Pending': 'bg-yellow-100 text-yellow-800',
      'Queued-payed': 'bg-blue-100 text-blue-800',
      'Queued-upload': 'bg-purple-100 text-purple-800',
      'Completed': 'bg-green-100 text-green-800',
      'Refunded': 'bg-red-100 text-red-800'
    };
    return colorMap[status] || 'bg-gray-100 text-gray-800';
  }

  $: filteredOrders = orders.filter(order => {
    if (filters.status && order.status !== filters.status) return false;
    if (filters.searchTerm) {
      const term = filters.searchTerm.toLowerCase();
      return order.id.toString().includes(term) || 
             order.userEmail.toLowerCase().includes(term) ||
             (order.note && order.note.toLowerCase().includes(term));
    }
    return true;
  });
</script>

<div class="space-y-6">
  <div class="bg-white rounded-lg shadow p-6">
    <div class="flex items-center justify-between mb-6">
      <h2 class="text-2xl font-semibold text-gray-900">算命管理</h2>
      <div class="flex items-center space-x-2">
        <span class="px-2 py-1 text-xs bg-orange-100 text-orange-800 rounded-full">助理权限</span>
        <button
          on:click={loadOrders}
          class="px-4 py-2 bg-orange-600 text-white rounded-md hover:bg-orange-700 focus:outline-none focus:ring-2 focus:ring-orange-500"
        >
          🔄 刷新
        </button>
      </div>
    </div>

    <!-- 筛选器 -->
    <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-6">
      <div>
        <label for="status-filter" class="block text-sm font-medium text-gray-700 mb-2">状态筛选</label>
        <select
          id="status-filter"
          bind:value={filters.status}
          class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-orange-500"
        >
          {#each statusOptions as option}
            <option value={option.value}>{option.label}</option>
          {/each}
        </select>
      </div>
      <div>
        <label for="search-input" class="block text-sm font-medium text-gray-700 mb-2">搜索</label>
        <input
          id="search-input"
          type="text"
          bind:value={filters.searchTerm}
          placeholder="搜索订单ID、用户邮箱或备注..."
          class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-orange-500"
        />
      </div>
    </div>

    <!-- 订单列表 -->
    {#if loading}
      <div class="text-center py-8">
        <svg class="animate-spin h-8 w-8 text-orange-600 mx-auto mb-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
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
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">订单ID</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">用户</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">金额</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">状态</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">创建时间</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">操作</th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            {#each filteredOrders as order}
              <tr class="hover:bg-gray-50">
                <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                  #{order.id}
                  {#if order.isEmergency}
                    <span class="ml-2 px-2 py-1 text-xs bg-red-100 text-red-800 rounded-full">紧急</span>
                  {/if}
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  {order.userEmail}
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  {order.amount} {order.currency}
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
                  <button
                    on:click={() => openOrderDetail(order)}
                    class="text-orange-600 hover:text-orange-900"
                  >
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

<!-- 订单详情侧栏 -->
{#if showDetailSidebar && selectedOrder}
  <div class="fixed inset-0 overflow-hidden z-50">
    <div class="absolute inset-0 overflow-hidden">
      <div class="absolute inset-0 bg-gray-500 bg-opacity-75 transition-opacity" 
           role="button"
           tabindex="0"
           on:click={closeDetailSidebar}
           on:keydown={(e) => e.key === 'Escape' && closeDetailSidebar()}
           aria-label="关闭订单详情"></div>
      
      <section class="absolute inset-y-0 right-0 pl-10 max-w-full flex">
        <div class="w-screen max-w-md">
          <div class="h-full flex flex-col bg-white shadow-xl overflow-y-scroll">
            <div class="flex-1 py-6 overflow-y-auto px-4 sm:px-6">
              <div class="flex items-start justify-between">
                <h2 class="text-lg font-medium text-gray-900">订单详情 #{selectedOrder.id}</h2>
                <div class="ml-3 h-7 flex items-center">
                  <button
                    on:click={closeDetailSidebar}
                    class="bg-white rounded-md text-gray-400 hover:text-gray-500"
                  >
                    <svg class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                    </svg>
                  </button>
                </div>
              </div>

              <div class="mt-8">
                <div class="space-y-6">
                  <!-- 基本信息 -->
                  <div>
                    <h3 class="text-sm font-medium text-gray-900 mb-3">基本信息</h3>
                    <div class="bg-gray-50 rounded-lg p-4 space-y-2">
                      <div class="flex justify-between">
                        <span class="text-sm text-gray-600">用户邮箱:</span>
                        <span class="text-sm text-gray-900">{selectedOrder.userEmail}</span>
                      </div>
                      <div class="flex justify-between">
                        <span class="text-sm text-gray-600">金额:</span>
                        <span class="text-sm text-gray-900">{selectedOrder.amount} {selectedOrder.currency}</span>
                      </div>
                      <div class="flex justify-between">
                        <span class="text-sm text-gray-600">状态:</span>
                        <span class="px-2 py-1 text-xs rounded-full {getStatusColor(selectedOrder.status)}">
                          {getStatusText(selectedOrder.status)}
                        </span>
                      </div>
                      <div class="flex justify-between">
                        <span class="text-sm text-gray-600">创建时间:</span>
                        <span class="text-sm text-gray-900">{new Date(selectedOrder.createdAt).toLocaleString('zh-CN')}</span>
                      </div>
                    </div>
                  </div>

                  <!-- 用户附言 -->
                  {#if selectedOrder.note}
                    <div>
                      <h3 class="text-sm font-medium text-gray-900 mb-3">用户附言</h3>
                      <div class="bg-blue-50 rounded-lg p-4">
                        <p class="text-sm text-gray-700">{selectedOrder.note}</p>
                      </div>
                    </div>
                  {/if}

                  <!-- 上传的图片 -->
                  {#if selectedOrder.images && selectedOrder.images.length > 0}
                    <div>
                      <h3 class="text-sm font-medium text-gray-900 mb-3">上传图片</h3>
                      <div class="grid grid-cols-2 gap-2">
                        {#each selectedOrder.images as image}
                          <img src={image} alt="用户上传" class="w-full h-24 object-cover rounded-lg" />
                        {/each}
                      </div>
                    </div>
                  {/if}

                  <!-- 回复编辑器 -->
                  <div>
                    <h3 class="text-sm font-medium text-gray-900 mb-3">助理回复</h3>
                    <textarea
                      bind:value={replyContent}
                      rows="8"
                      placeholder="请输入您的回复..."
                      class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-orange-500"
                    ></textarea>
                    <div class="mt-2 text-xs text-gray-500">
                      作为助理，您的回复将标记为助理回复
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <div class="flex-shrink-0 px-4 py-4 flex justify-end space-x-3 border-t border-gray-200">
              <button
                on:click={closeDetailSidebar}
                class="px-4 py-2 bg-gray-300 text-gray-700 rounded-md hover:bg-gray-400"
              >
                取消
              </button>
              <button
                on:click={saveReply}
                disabled={savingReply || !replyContent.trim()}
                class="px-4 py-2 bg-orange-600 text-white rounded-md hover:bg-orange-700 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {savingReply ? '保存中...' : '保存回复'}
              </button>
            </div>
          </div>
        </div>
      </section>
    </div>
  </div>
{/if} 