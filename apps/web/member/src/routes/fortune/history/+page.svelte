<script>
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  
  let applications = [];
  let loading = true;
  let selectedApp = null;
  let showDetail = false;
  let showRefundDialog = false;
  let refundReason = '';
  
  const statusMap = {
    'pending': { text: '排队中', color: 'yellow' },
    'processing': { text: '处理中', color: 'blue' },
    'completed': { text: '已完成', color: 'green' },
    'refunded': { text: '已退款', color: 'gray' }
  };
  
  const currencySymbols = {
    'CNY': '¥',
    'USD': '$',
    'CAD': 'C$',
    'SGD': 'S$',
    'AUD': 'A$'
  };
  
  onMount(async () => {
    await loadApplications();
  });
  
  async function loadApplications() {
    try {
      const response = await fetch('https://fortune.baiduohui.com/applications', {
        headers: {
          'Authorization': `Bearer ${localStorage.getItem('supabase_token')}`
        }
      });
      
      if (response.ok) {
        applications = await response.json();
      }
    } catch (error) {
      console.error('加载申请历史失败:', error);
    } finally {
      loading = false;
    }
  }
  
  function showDetailDialog(app) {
    selectedApp = app;
    showDetail = true;
  }
  
  function closeDetail() {
    showDetail = false;
    selectedApp = null;
  }
  
  function openRefundDialog() {
    showRefundDialog = true;
    refundReason = '';
  }
  
  function closeRefundDialog() {
    showRefundDialog = false;
    refundReason = '';
  }
  
  async function submitRefund() {
    if (!refundReason.trim()) {
      alert('请输入退款原因');
      return;
    }
    
    try {
      const response = await fetch(`https://fortune.baiduohui.com/refund/${selectedApp.id}`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${localStorage.getItem('supabase_token')}`
        },
        body: JSON.stringify({
          reason: refundReason
        })
      });
      
      if (response.ok) {
        alert('退款申请已提交');
        closeRefundDialog();
        closeDetail();
        await loadApplications();
      } else {
        alert('退款申请失败');
      }
    } catch (error) {
      console.error('退款失败:', error);
      alert('退款申请失败');
    }
  }
  
  function formatDate(dateString) {
    return new Date(dateString).toLocaleString('zh-CN');
  }
  
  function getQueuePercentage(app) {
    if (app.status !== 'pending') return null;
    return app.queue_position ? Math.max(0, 100 - (app.queue_position * 10)) : 0;
  }

  function canModifyOrder(app) {
    return app.status === 'pending' || app.status === 'queued' && 
           app.modification_count < (app.max_modifications || 5) &&
           app.status !== 'refunded';
  }

  function getRemainingModifications(app) {
    const maxMods = app.max_modifications || 5;
    const currentMods = app.modification_count || 0;
    return Math.max(0, maxMods - currentMods);
  }
</script>

<div class="min-h-screen bg-gray-50 py-8">
  <div class="max-w-4xl mx-auto px-4">
    <div class="flex justify-between items-center mb-6">
      <h1 class="text-2xl font-bold text-gray-900">算命申请历史</h1>
      <button
        on:click={() => goto('/fortune/new')}
        class="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700"
      >
        新建申请
      </button>
    </div>
    
    {#if loading}
      <div class="text-center py-12">
        <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
        <p class="mt-2 text-gray-600">加载中...</p>
      </div>
    {:else if applications.length === 0}
      <div class="text-center py-12">
        <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
        </svg>
        <h3 class="mt-2 text-sm font-medium text-gray-900">暂无申请记录</h3>
        <p class="mt-1 text-sm text-gray-500">开始您的第一次算命申请吧</p>
        <div class="mt-6">
          <button
            on:click={() => goto('/fortune/new')}
            class="inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700"
          >
            新建申请
          </button>
        </div>
      </div>
    {:else}
      <div class="space-y-4">
        {#each applications as app}
          <div class="bg-white border border-gray-200 rounded-lg p-6 hover:shadow-md transition-shadow duration-200">
            <div class="flex justify-between items-start mb-4">
              <div>
                <h3 class="text-lg font-medium text-gray-900">
                  订单 #{app.order_number || app.id.slice(-8)}
                </h3>
                <p class="text-sm text-gray-500">
                  提交时间: {formatDate(app.created_at)}
                </p>
                {#if app.modification_count > 0}
                  <p class="text-sm text-blue-600">
                    已修改 {app.modification_count} 次，剩余 {getRemainingModifications(app)} 次修改机会
                  </p>
                {/if}
              </div>
              
              <div class="flex flex-col items-end space-y-2">
                <span class="px-3 py-1 text-xs font-medium rounded-full {getStatusColor(app.status)}">
                  {getStatusDisplayName(app.status)}
                </span>
                {#if app.is_child_emergency}
                  <span class="px-2 py-1 text-xs font-medium bg-red-100 text-red-800 rounded-full">
                    小孩危急
                  </span>
                {/if}
              </div>
            </div>
            
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
              <div>
                <p class="text-sm text-gray-600">
                  <span class="font-medium">金额:</span> 
                  {currencySymbols[app.currency]}{app.amount}
                </p>
                <p class="text-sm text-gray-600">
                  <span class="font-medium">描述:</span> 
                  {app.description.length > 50 ? app.description.substring(0, 50) + '...' : app.description}
                </p>
              </div>
              
              {#if app.status === 'pending' && getQueuePercentage(app) !== null}
                <div>
                  <p class="text-sm text-gray-600 mb-1">排队进度</p>
                  <div class="w-full bg-gray-200 rounded-full h-2">
                    <div 
                      class="bg-blue-600 h-2 rounded-full transition-all duration-300" 
                      style="width: {getQueuePercentage(app)}%"
                    ></div>
                  </div>
                  <p class="text-xs text-gray-500 mt-1">您已在前 {getQueuePercentage(app)}%</p>
                </div>
              {/if}
            </div>
            
            <div class="flex justify-end space-x-2">
              <button
                on:click={() => showDetailDialog(app)}
                class="px-4 py-2 text-sm font-medium text-blue-600 bg-blue-50 rounded-md hover:bg-blue-100 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
              >
                查看详情
              </button>
              
              {#if canModifyOrder(app)}
                <button
                  on:click={() => goto(`/fortune/edit/${app.id}`)}
                  class="px-4 py-2 text-sm font-medium text-green-600 bg-green-50 rounded-md hover:bg-green-100 focus:outline-none focus:ring-2 focus:ring-green-500 focus:ring-offset-2"
                >
                  修改申请 ({getRemainingModifications(app)})
                </button>
              {/if}
              
              {#if app.status === 'pending' || app.status === 'queued'}
                <button
                  on:click={() => openRefundDialog(app)}
                  class="px-4 py-2 text-sm font-medium text-red-600 bg-red-50 rounded-md hover:bg-red-100 focus:outline-none focus:ring-2 focus:ring-red-500 focus:ring-offset-2"
                >
                  申请退款
                </button>
              {/if}
            </div>
          </div>
        {/each}
      </div>
    {/if}
  </div>
</div>

<!-- 详情对话框 -->
{#if showDetail && selectedApp}
  <div class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50">
    <div class="relative top-20 mx-auto p-5 border w-11/12 md:w-3/4 lg:w-1/2 shadow-lg rounded-md bg-white">
      <div class="flex justify-between items-center mb-4">
        <h3 class="text-lg font-medium text-gray-900">
          申请详情 #{selectedApp.id.slice(-8)}
        </h3>
        <button
          on:click={closeDetail}
          class="text-gray-400 hover:text-gray-600"
        >
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
          </svg>
        </button>
      </div>
      
      <div class="space-y-4">
        <div>
          <label class="block text-sm font-medium text-gray-700">状态</label>
          <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-{statusMap[selectedApp.status].color}-100 text-{statusMap[selectedApp.status].color}-800">
            {statusMap[selectedApp.status].text}
          </span>
        </div>
        
        <div>
          <label class="block text-sm font-medium text-gray-700">金额</label>
          <p class="mt-1 text-sm text-gray-900">
            {currencySymbols[selectedApp.currency]}{selectedApp.amount}
          </p>
        </div>
        
        <div>
          <label class="block text-sm font-medium text-gray-700">提交时间</label>
          <p class="mt-1 text-sm text-gray-900">
            {formatDate(selectedApp.created_at)}
          </p>
        </div>
        
        {#if selectedApp.description}
          <div>
            <label class="block text-sm font-medium text-gray-700">附言</label>
            <p class="mt-1 text-sm text-gray-900 whitespace-pre-wrap">
              {selectedApp.description}
            </p>
          </div>
        {/if}
        
        {#if selectedApp.images && selectedApp.images.length > 0}
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">上传的图片</label>
            <div class="grid grid-cols-3 gap-4">
              {#each selectedApp.images as image}
                <img src={image} alt="申请图片" class="w-full h-24 object-cover rounded-lg" />
              {/each}
            </div>
          </div>
        {/if}
        
        {#if selectedApp.reply}
          <div>
            <label class="block text-sm font-medium text-gray-700">回复</label>
            <div class="mt-1 p-3 bg-gray-50 rounded-md">
              <p class="text-sm text-gray-900 whitespace-pre-wrap">
                {selectedApp.reply}
              </p>
              {#if selectedApp.reply_images && selectedApp.reply_images.length > 0}
                <div class="mt-3 grid grid-cols-3 gap-2">
                  {#each selectedApp.reply_images as image}
                    <img src={image} alt="回复图片" class="w-full h-20 object-cover rounded" />
                  {/each}
                </div>
              {/if}
            </div>
          </div>
        {/if}
      </div>
      
      <div class="mt-6 flex justify-end space-x-3">
        {#if selectedApp.status === 'pending' || selectedApp.status === 'processing'}
          <button
            on:click={openRefundDialog}
            class="px-4 py-2 border border-red-300 text-red-700 rounded-md hover:bg-red-50"
          >
            申请退款
          </button>
        {/if}
        <button
          on:click={closeDetail}
          class="px-4 py-2 bg-gray-600 text-white rounded-md hover:bg-gray-700"
        >
          关闭
        </button>
      </div>
    </div>
  </div>
{/if}

<!-- 退款对话框 -->
{#if showRefundDialog}
  <div class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-60">
    <div class="relative top-20 mx-auto p-5 border w-11/12 md:w-1/2 shadow-lg rounded-md bg-white">
      <div class="flex justify-between items-center mb-4">
        <h3 class="text-lg font-medium text-gray-900">申请退款</h3>
        <button
          on:click={closeRefundDialog}
          class="text-gray-400 hover:text-gray-600"
        >
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
          </svg>
        </button>
      </div>
      
      <div class="mb-4">
        <label for="refundReason" class="block text-sm font-medium text-gray-700 mb-2">
          退款原因
        </label>
        <textarea
          id="refundReason"
          bind:value={refundReason}
          rows="4"
          class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
          placeholder="请说明退款原因..."
        ></textarea>
      </div>
      
      <div class="flex justify-end space-x-3">
        <button
          on:click={closeRefundDialog}
          class="px-4 py-2 border border-gray-300 rounded-md text-gray-700 hover:bg-gray-50"
        >
          取消
        </button>
        <button
          on:click={submitRefund}
          class="px-4 py-2 bg-red-600 text-white rounded-md hover:bg-red-700"
        >
          提交退款申请
        </button>
      </div>
    </div>
  </div>
{/if} 