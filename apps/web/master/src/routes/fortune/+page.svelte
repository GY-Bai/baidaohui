<script>
  import { onMount } from 'svelte';
  
  let pendingApplications = [];
  let refundRequests = [];
  let loading = true;
  let fortuneEnabled = true;
  let minimumAmount = 100;
  let selectedApp = null;
  let showReplyDialog = false;
  let replyText = '';
  let replyImages = [];
  let isDraft = false;
  let uploadingReply = false;
  
  const currencySymbols = {
    'CNY': '¥',
    'USD': '$',
    'CAD': 'C$',
    'SGD': 'S$',
    'AUD': 'A$'
  };
  
  onMount(async () => {
    await loadData();
  });
  
  async function loadData() {
    loading = true;
    try {
      // 加载排队中的申请
      const pendingResponse = await fetch('https://fortune.baiduohui.com/admin/pending', {
        headers: {
          'Authorization': `Bearer ${localStorage.getItem('supabase_token')}`
        }
      });
      if (pendingResponse.ok) {
        pendingApplications = await pendingResponse.json();
      }
      
      // 加载退款请求
      const refundResponse = await fetch('https://fortune.baiduohui.com/admin/refunds', {
        headers: {
          'Authorization': `Bearer ${localStorage.getItem('supabase_token')}`
        }
      });
      if (refundResponse.ok) {
        refundRequests = await refundResponse.json();
      }
      
      // 加载设置
      const settingsResponse = await fetch('https://fortune.baiduohui.com/admin/settings', {
        headers: {
          'Authorization': `Bearer ${localStorage.getItem('supabase_token')}`
        }
      });
      if (settingsResponse.ok) {
        const settings = await settingsResponse.json();
        fortuneEnabled = settings.enabled;
        minimumAmount = settings.minimum_amount;
      }
      
    } catch (error) {
      console.error('加载数据失败:', error);
    } finally {
      loading = false;
    }
  }
  
  async function updateSettings() {
    try {
      const response = await fetch('https://fortune.baiduohui.com/admin/settings', {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${localStorage.getItem('supabase_token')}`
        },
        body: JSON.stringify({
          enabled: fortuneEnabled,
          minimum_amount: minimumAmount
        })
      });
      
      if (response.ok) {
        alert('设置已更新');
      } else {
        alert('设置更新失败');
      }
    } catch (error) {
      console.error('更新设置失败:', error);
      alert('设置更新失败');
    }
  }
  
  function openReplyDialog(app) {
    selectedApp = app;
    replyText = app.draft_reply || '';
    replyImages = [];
    isDraft = false;
    showReplyDialog = true;
  }
  
  function closeReplyDialog() {
    showReplyDialog = false;
    selectedApp = null;
    replyText = '';
    replyImages = [];
  }
  
  async function handleReplyImageUpload(event) {
    const files = Array.from(event.target.files);
    if (replyImages.length + files.length > 3) {
      alert('最多只能上传3张图片');
      return;
    }
    
    for (const file of files) {
      try {
        const formData = new FormData();
        formData.append('file', file);
        
        const response = await fetch('/api/upload', {
          method: 'POST',
          body: formData
        });
        
        if (response.ok) {
          const result = await response.json();
          replyImages = [...replyImages, result.url];
        }
      } catch (error) {
        console.error('图片上传失败:', error);
      }
    }
  }
  
  function removeReplyImage(index) {
    replyImages = replyImages.filter((_, i) => i !== index);
  }
  
  async function saveReply(asDraft = false) {
    if (!replyText.trim() && replyImages.length === 0) {
      alert('请输入回复内容或上传图片');
      return;
    }
    
    uploadingReply = true;
    isDraft = asDraft;
    
    try {
      const response = await fetch(`https://fortune.baiduohui.com/admin/reply/${selectedApp.id}`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${localStorage.getItem('supabase_token')}`
        },
        body: JSON.stringify({
          reply: replyText,
          images: replyImages,
          is_draft: asDraft
        })
      });
      
      if (response.ok) {
        alert(asDraft ? '草稿已保存' : '回复已发送');
        closeReplyDialog();
        await loadData();
      } else {
        alert('操作失败');
      }
    } catch (error) {
      console.error('回复失败:', error);
      alert('操作失败');
    } finally {
      uploadingReply = false;
    }
  }
  
  async function approveRefund(refundId) {
    if (!confirm('确认批准此退款申请？')) return;
    
    try {
      const response = await fetch(`https://fortune.baiduohui.com/admin/refund/${refundId}/approve`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${localStorage.getItem('supabase_token')}`
        }
      });
      
      if (response.ok) {
        alert('退款已批准');
        await loadData();
      } else {
        alert('操作失败');
      }
    } catch (error) {
      console.error('批准退款失败:', error);
      alert('操作失败');
    }
  }
  
  async function rejectRefund(refundId) {
    const reason = prompt('请输入拒绝原因：');
    if (!reason) return;
    
    try {
      const response = await fetch(`https://fortune.baiduohui.com/admin/refund/${refundId}/reject`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${localStorage.getItem('supabase_token')}`
        },
        body: JSON.stringify({ reason })
      });
      
      if (response.ok) {
        alert('退款已拒绝');
        await loadData();
      } else {
        alert('操作失败');
      }
    } catch (error) {
      console.error('拒绝退款失败:', error);
      alert('操作失败');
    }
  }
  
  function formatDate(dateString) {
    return new Date(dateString).toLocaleString('zh-CN');
  }
  
  function getPriorityScore(app) {
    let score = app.amount;
    if (app.is_child_emergency) score += 1000;
    return score;
  }
  
  $: sortedPendingApplications = pendingApplications.sort((a, b) => {
    const scoreA = getPriorityScore(a);
    const scoreB = getPriorityScore(b);
    if (scoreB !== scoreA) return scoreB - scoreA;
    return new Date(a.created_at) - new Date(b.created_at);
  });
</script>

<div class="min-h-screen bg-gray-50 py-8">
  <div class="max-w-7xl mx-auto px-4">
    <!-- 设置面板 -->
    <div class="bg-white rounded-lg shadow-md p-6 mb-6">
      <h2 class="text-lg font-medium text-gray-900 mb-4">算命服务设置</h2>
      
      <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div>
          <label class="flex items-center">
            <input
              type="checkbox"
              bind:checked={fortuneEnabled}
              on:change={updateSettings}
              class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
            />
            <span class="ml-2 text-sm text-gray-700">启用算命服务</span>
          </label>
        </div>
        
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">
            最低金额 (CNY)
          </label>
          <input
            type="number"
            bind:value={minimumAmount}
            on:blur={updateSettings}
            min="0"
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
          />
        </div>
        
        <div class="flex items-end">
          <div class="text-sm text-gray-600">
            <p>排队中: {pendingApplications.length} 个申请</p>
            <p>待处理退款: {refundRequests.length} 个</p>
          </div>
        </div>
      </div>
    </div>
    
    {#if loading}
      <div class="text-center py-12">
        <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
        <p class="mt-2 text-gray-600">加载中...</p>
      </div>
    {:else}
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <!-- 排队中的申请 -->
        <div class="bg-white rounded-lg shadow-md">
          <div class="px-6 py-4 border-b border-gray-200">
            <h3 class="text-lg font-medium text-gray-900">
              排队中的申请 ({pendingApplications.length})
            </h3>
          </div>
          
          <div class="max-h-96 overflow-y-auto">
            {#if sortedPendingApplications.length === 0}
              <div class="p-6 text-center text-gray-500">
                暂无排队申请
              </div>
            {:else}
              <div class="divide-y divide-gray-200">
                {#each sortedPendingApplications as app, index}
                  <div class="p-4 hover:bg-gray-50">
                    <div class="flex items-center justify-between">
                      <div class="flex-1">
                        <div class="flex items-center space-x-2">
                          <span class="text-sm font-medium text-gray-900">
                            #{app.id.slice(-8)}
                          </span>
                          <span class="text-xs bg-blue-100 text-blue-800 px-2 py-1 rounded">
                            排队 #{index + 1}
                          </span>
                          {#if app.is_child_emergency}
                            <span class="text-xs bg-red-100 text-red-800 px-2 py-1 rounded">
                              小孩危急
                            </span>
                          {/if}
                          {#if app.draft_reply}
                            <span class="text-xs bg-yellow-100 text-yellow-800 px-2 py-1 rounded">
                              有草稿
                            </span>
                          {/if}
                        </div>
                        
                        <div class="mt-1 text-sm text-gray-600">
                          金额: {currencySymbols[app.currency]}{app.amount} | 
                          提交: {formatDate(app.created_at)}
                        </div>
                        
                        {#if app.description}
                          <p class="mt-1 text-sm text-gray-700 line-clamp-2">
                            {app.description}
                          </p>
                        {/if}
                      </div>
                      
                      <button
                        on:click={() => openReplyDialog(app)}
                        class="ml-4 px-3 py-1 text-sm bg-blue-600 text-white rounded-md hover:bg-blue-700"
                      >
                        回复
                      </button>
                    </div>
                  </div>
                {/each}
              </div>
            {/if}
          </div>
        </div>
        
        <!-- 待处理退款 -->
        <div class="bg-white rounded-lg shadow-md">
          <div class="px-6 py-4 border-b border-gray-200">
            <h3 class="text-lg font-medium text-gray-900">
              待处理退款 ({refundRequests.length})
            </h3>
          </div>
          
          <div class="max-h-96 overflow-y-auto">
            {#if refundRequests.length === 0}
              <div class="p-6 text-center text-gray-500">
                暂无退款申请
              </div>
            {:else}
              <div class="divide-y divide-gray-200">
                {#each refundRequests as refund}
                  <div class="p-4">
                    <div class="flex items-center justify-between">
                      <div class="flex-1">
                        <div class="flex items-center space-x-2">
                          <span class="text-sm font-medium text-gray-900">
                            #{refund.application_id.slice(-8)}
                          </span>
                          <span class="text-xs bg-orange-100 text-orange-800 px-2 py-1 rounded">
                            退款申请
                          </span>
                        </div>
                        
                        <div class="mt-1 text-sm text-gray-600">
                          金额: {currencySymbols[refund.currency]}{refund.amount} | 
                          申请时间: {formatDate(refund.created_at)}
                        </div>
                        
                        {#if refund.reason}
                          <p class="mt-1 text-sm text-gray-700">
                            原因: {refund.reason}
                          </p>
                        {/if}
                      </div>
                      
                      <div class="ml-4 flex space-x-2">
                        <button
                          on:click={() => approveRefund(refund.id)}
                          class="px-3 py-1 text-sm bg-green-600 text-white rounded-md hover:bg-green-700"
                        >
                          批准
                        </button>
                        <button
                          on:click={() => rejectRefund(refund.id)}
                          class="px-3 py-1 text-sm bg-red-600 text-white rounded-md hover:bg-red-700"
                        >
                          拒绝
                        </button>
                      </div>
                    </div>
                  </div>
                {/each}
              </div>
            {/if}
          </div>
        </div>
      </div>
    {/if}
  </div>
</div>

<!-- 回复对话框 -->
{#if showReplyDialog && selectedApp}
  <div class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50">
    <div class="relative top-10 mx-auto p-5 border w-11/12 md:w-3/4 lg:w-2/3 shadow-lg rounded-md bg-white">
      <div class="flex justify-between items-center mb-4">
        <h3 class="text-lg font-medium text-gray-900">
          回复申请 #{selectedApp.id.slice(-8)}
        </h3>
        <button
          on:click={closeReplyDialog}
          class="text-gray-400 hover:text-gray-600"
        >
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
          </svg>
        </button>
      </div>
      
      <!-- 申请信息 -->
      <div class="bg-gray-50 rounded-lg p-4 mb-4">
        <div class="grid grid-cols-2 gap-4 text-sm mb-3">
          <div>
            <span class="font-medium">金额:</span> {currencySymbols[selectedApp.currency]}{selectedApp.amount}
          </div>
          <div>
            <span class="font-medium">提交时间:</span> {formatDate(selectedApp.created_at)}
          </div>
          <div>
            <span class="font-medium">修改次数:</span> {selectedApp.modification_count || 0}/{selectedApp.max_modifications || 5}
          </div>
          <div>
            <span class="font-medium">订单号:</span> {selectedApp.order_number || selectedApp.id.slice(-8)}
          </div>
        </div>
        
        {#if selectedApp.is_child_urgent}
          <div class="mb-3">
            <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800">
              小孩危急
            </span>
          </div>
        {/if}
        
        {#if selectedApp.description}
          <div class="mb-3">
            <span class="font-medium text-sm">当前附言:</span>
            <p class="mt-1 text-sm text-gray-700 whitespace-pre-wrap">
              {selectedApp.description}
            </p>
          </div>
        {/if}
        
        {#if selectedApp.images && selectedApp.images.length > 0}
          <div class="mb-3">
            <span class="font-medium text-sm">当前正文图片:</span>
            <div class="mt-1 grid grid-cols-3 gap-2">
              {#each selectedApp.images as image}
                <img src={image} alt="申请图片" class="w-full h-20 object-cover rounded" />
              {/each}
            </div>
          </div>
        {/if}
        
        <!-- 所有付款截图历史 -->
        {#if selectedApp.all_payment_screenshots && selectedApp.all_payment_screenshots.length > 0}
          <div class="mb-3">
            <span class="font-medium text-sm">所有付款截图历史:</span>
            <div class="mt-1 grid grid-cols-4 gap-2">
              {#each selectedApp.all_payment_screenshots as screenshot}
                <div class="relative">
                  <img src={screenshot.url} alt="付款截图" class="w-full h-16 object-cover rounded border-2 border-orange-200" />
                  <div class="absolute bottom-0 left-0 right-0 bg-black bg-opacity-75 text-white text-xs p-1 rounded-b">
                    第{screenshot.modification_number}次修改
                  </div>
                </div>
              {/each}
            </div>
          </div>
        {/if}
        
        <!-- 修改历史 -->
        {#if selectedApp.modification_history && selectedApp.modification_history.length > 0}
          <div class="mb-3">
            <span class="font-medium text-sm">修改历史:</span>
            <div class="mt-2 space-y-3">
              {#each selectedApp.modification_history as modification}
                <div class="border border-gray-200 rounded-lg p-3 bg-white">
                  <div class="flex justify-between items-start mb-2">
                    <span class="text-xs font-medium text-blue-600">第{modification.modification_number}次修改</span>
                    <span class="text-xs text-gray-500">{formatDate(modification.modified_at)}</span>
                  </div>
                  
                  <div class="grid grid-cols-2 gap-2 text-xs text-gray-600 mb-2">
                    <div>金额: {currencySymbols[modification.currency]}{modification.amount}</div>
                    <div>小孩危急: {modification.is_child_urgent ? '是' : '否'}</div>
                  </div>
                  
                  {#if modification.description}
                    <p class="text-xs text-gray-700 mb-2">
                      <span class="font-medium">附言:</span> {modification.description.substring(0, 100)}{modification.description.length > 100 ? '...' : ''}
                    </p>
                  {/if}
                  
                  {#if modification.images && modification.images.length > 0}
                    <div class="mb-2">
                      <span class="text-xs font-medium text-gray-600">正文图片:</span>
                      <div class="mt-1 flex space-x-1">
                        {#each modification.images as image}
                          <img src={image} alt="修改图片" class="w-8 h-8 object-cover rounded" />
                        {/each}
                      </div>
                    </div>
                  {/if}
                  
                  {#if modification.payment_screenshots && modification.payment_screenshots.length > 0}
                    <div>
                      <span class="text-xs font-medium text-gray-600">付款截图:</span>
                      <div class="mt-1 flex space-x-1">
                        {#each modification.payment_screenshots as screenshot}
                          <img src={screenshot} alt="付款截图" class="w-8 h-8 object-cover rounded border border-orange-200" />
                        {/each}
                      </div>
                    </div>
                  {/if}
                </div>
              {/each}
            </div>
          </div>
        {/if}
        
        {#if selectedApp.ai_keywords}
          <div class="mb-3">
            <span class="font-medium text-sm">AI关键词:</span>
            <p class="mt-1 text-sm text-purple-700 bg-purple-50 p-2 rounded">
              {selectedApp.ai_keywords}
            </p>
          </div>
        {/if}
      </div>
      
      <!-- 回复内容 -->
      <div class="mb-4">
        <label class="block text-sm font-medium text-gray-700 mb-2">
          回复内容
        </label>
        <textarea
          bind:value={replyText}
          rows="6"
          class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
          placeholder="请输入回复内容..."
        ></textarea>
      </div>
      
      <!-- 回复图片 -->
      <div class="mb-4">
        <label class="block text-sm font-medium text-gray-700 mb-2">
          回复图片 (最多3张)
        </label>
        
        <input
          type="file"
          multiple
          accept="image/*"
          on:change={handleReplyImageUpload}
          class="hidden"
          id="replyImageInput"
        />
        
        {#if replyImages.length < 3}
          <button
            type="button"
            on:click={() => document.getElementById('replyImageInput').click()}
            class="inline-flex items-center px-4 py-2 border border-gray-300 rounded-md text-sm font-medium text-gray-700 bg-white hover:bg-gray-50"
          >
            选择图片
          </button>
        {/if}
        
        {#if replyImages.length > 0}
          <div class="mt-2 grid grid-cols-3 gap-2">
            {#each replyImages as image, index}
              <div class="relative">
                <img src={image} alt="回复图片" class="w-full h-20 object-cover rounded" />
                <button
                  type="button"
                  on:click={() => removeReplyImage(index)}
                  class="absolute -top-1 -right-1 bg-red-500 text-white rounded-full w-5 h-5 flex items-center justify-center text-xs hover:bg-red-600"
                >
                  ×
                </button>
              </div>
            {/each}
          </div>
        {/if}
      </div>
      
      <!-- 操作按钮 -->
      <div class="flex justify-end space-x-3">
        <button
          on:click={closeReplyDialog}
          class="px-4 py-2 border border-gray-300 rounded-md text-gray-700 hover:bg-gray-50"
        >
          取消
        </button>
        <button
          on:click={() => saveReply(true)}
          disabled={uploadingReply}
          class="px-4 py-2 border border-yellow-300 text-yellow-700 rounded-md hover:bg-yellow-50 disabled:opacity-50"
        >
          {uploadingReply && isDraft ? '保存中...' : '保存草稿'}
        </button>
        <button
          on:click={() => saveReply(false)}
          disabled={uploadingReply}
          class="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:opacity-50"
        >
          {uploadingReply && !isDraft ? '发送中...' : '发送回复'}
        </button>
      </div>
    </div>
  </div>
{/if} 