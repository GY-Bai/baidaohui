<script>
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { page } from '$app/stores';
  
  let orderId = '';
  let orderData = null;
  let files = [];
  let paymentScreenshots = [];
  let description = '';
  let amount = '';
  let currency = 'CNY';
  let isChildEmergency = false;
  let isSubmitting = false;
  let uploadProgress = 0;
  let loading = true;
  
  const currencyOptions = [
    { value: 'CNY', label: '¥ 人民币', symbol: '¥' },
    { value: 'USD', label: '$ 美元', symbol: '$' },
    { value: 'CAD', label: 'C$ 加元', symbol: 'C$' },
    { value: 'SGD', label: 'S$ 新币', symbol: 'S$' },
    { value: 'AUD', label: 'A$ 澳元', symbol: 'A$' }
  ];
  
  onMount(async () => {
    orderId = $page.params.id;
    await loadOrderData();
  });
  
  async function loadOrderData() {
    try {
      const response = await fetch(`https://fortune.baiduohui.com/orders/${orderId}`, {
        headers: {
          'Authorization': `Bearer ${localStorage.getItem('supabase_token')}`
        }
      });
      
      if (!response.ok) {
        throw new Error('获取订单信息失败');
      }
      
      orderData = await response.json();
      
      // 检查是否可以修改
      if (!orderData.can_be_modified) {
        alert('此订单无法修改');
        goto('/fortune/history');
        return;
      }
      
      // 填充表单数据
      description = orderData.description;
      amount = orderData.amount.toString();
      currency = orderData.currency;
      isChildEmergency = orderData.is_child_urgent;
      
    } catch (error) {
      console.error('加载订单数据失败:', error);
      alert('加载订单数据失败: ' + error.message);
      goto('/fortune/history');
    } finally {
      loading = false;
    }
  }
  
  function handleFileSelect(event) {
    const selectedFiles = Array.from(event.target.files);
    if (files.length + selectedFiles.length > 3) {
      alert('最多只能上传3张图片');
      return;
    }
    files = [...files, ...selectedFiles];
  }
  
  function handlePaymentScreenshotSelect(event) {
    const selectedFiles = Array.from(event.target.files);
    if (paymentScreenshots.length + selectedFiles.length > 5) {
      alert('最多只能上传5张付款截图');
      return;
    }
    paymentScreenshots = [...paymentScreenshots, ...selectedFiles];
  }
  
  function removeFile(index) {
    files = files.filter((_, i) => i !== index);
  }
  
  function removePaymentScreenshot(index) {
    paymentScreenshots = paymentScreenshots.filter((_, i) => i !== index);
  }
  
  async function submitModification() {
    if (!amount || parseFloat(amount) <= 0) {
      alert('请输入有效金额');
      return;
    }
    
    if (description.length > 800) {
      alert('附言不能超过800字');
      return;
    }
    
    if (paymentScreenshots.length === 0) {
      alert('请上传至少一张付款截图');
      return;
    }
    
    isSubmitting = true;
    uploadProgress = 0;
    
    try {
      const formData = new FormData();
      
      // 添加正文图片
      for (let i = 0; i < files.length; i++) {
        formData.append(`image_${i}`, files[i]);
        uploadProgress = ((i + 1) / (files.length + paymentScreenshots.length)) * 50;
      }
      
      // 添加付款截图
      for (let i = 0; i < paymentScreenshots.length; i++) {
        formData.append(`payment_screenshot_${i}`, paymentScreenshots[i]);
        uploadProgress = ((files.length + i + 1) / (files.length + paymentScreenshots.length)) * 50;
      }
      
      // 添加其他数据
      formData.append('description', description);
      formData.append('amount', amount);
      formData.append('currency', currency);
      formData.append('is_child_urgent', isChildEmergency);
      
      uploadProgress = 75;
      
      // 提交修改
      const response = await fetch(`https://fortune.baiduohui.com/modify/${orderId}`, {
        method: 'PUT',
        headers: {
          'Authorization': `Bearer ${localStorage.getItem('supabase_token')}`
        },
        body: formData
      });
      
      uploadProgress = 100;
      
      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.error || '修改失败');
      }
      
      const result = await response.json();
      alert(result.message);
      goto('/fortune/history');
      
    } catch (error) {
      console.error('修改失败:', error);
      alert('修改失败: ' + error.message);
    } finally {
      isSubmitting = false;
      uploadProgress = 0;
    }
  }
</script>

<svelte:head>
  <title>修改算命申请 - 百刀会</title>
</svelte:head>

<div class="min-h-screen bg-gray-50 py-8">
  <div class="max-w-2xl mx-auto px-4">
    {#if loading}
      <div class="text-center py-12">
        <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
        <p class="mt-2 text-gray-600">加载中...</p>
      </div>
    {:else if orderData}
      <div class="bg-white rounded-lg shadow-md p-6">
        <div class="mb-6">
          <h1 class="text-2xl font-bold text-gray-900 mb-2">修改算命申请</h1>
          <div class="bg-yellow-50 border border-yellow-200 rounded-md p-4">
            <div class="flex">
              <div class="flex-shrink-0">
                <svg class="h-5 w-5 text-yellow-400" viewBox="0 0 20 20" fill="currentColor">
                  <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
                </svg>
              </div>
              <div class="ml-3">
                <h3 class="text-sm font-medium text-yellow-800">修改提醒</h3>
                <div class="mt-2 text-sm text-yellow-700">
                  <p>订单号：{orderData.order_number}</p>
                  <p>已修改次数：{orderData.modification_count}/{orderData.max_modifications}</p>
                  <p>剩余修改次数：{orderData.remaining_modifications}</p>
                  <p class="mt-1 font-medium">注意：一旦订单进入退款状态，将无法再次修改。</p>
                </div>
              </div>
            </div>
          </div>
        </div>
        
        <!-- 正文图片上传区域 -->
        <div class="mb-6">
          <label class="block text-sm font-medium text-gray-700 mb-2">
            上传新的正文图片 (最多3张，将替换原有图片)
          </label>
          
          <div class="border-2 border-dashed border-gray-300 rounded-lg p-6 text-center">
            <input
              type="file"
              multiple
              accept="image/*"
              on:change={handleFileSelect}
              class="hidden"
              id="file-upload"
            />
            <label
              for="file-upload"
              class="cursor-pointer inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700"
            >
              选择图片
            </label>
            
            <p class="mt-2 text-sm text-gray-500">
              支持 JPG、PNG 格式，单张图片不超过 5MB
            </p>
          </div>
          
          {#if files.length > 0}
            <div class="mt-4 grid grid-cols-2 md:grid-cols-3 gap-4">
              {#each files as file, index}
                <div class="relative">
                  <img
                    src={URL.createObjectURL(file)}
                    alt="预览"
                    class="w-full h-24 object-cover rounded-lg"
                  />
                  <button
                    type="button"
                    on:click={() => removeFile(index)}
                    class="absolute -top-2 -right-2 bg-red-500 text-white rounded-full w-6 h-6 flex items-center justify-center text-xs hover:bg-red-600"
                  >
                    ×
                  </button>
                </div>
              {/each}
            </div>
          {/if}
        </div>
        
        <!-- 付款截图上传区域 -->
        <div class="mb-6">
          <label class="block text-sm font-medium text-gray-700 mb-2">
            上传新的付款截图 (必须，最多5张，将保留所有历史截图)
          </label>
          
          <div class="border-2 border-dashed border-orange-300 rounded-lg p-6 text-center bg-orange-50">
            <input
              type="file"
              multiple
              accept="image/*"
              on:change={handlePaymentScreenshotSelect}
              class="hidden"
              id="payment-upload"
            />
            <label
              for="payment-upload"
              class="cursor-pointer inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-orange-600 hover:bg-orange-700"
            >
              选择付款截图
            </label>
            
            <p class="mt-2 text-sm text-orange-600">
              请上传支付成功的截图作为付款凭证
            </p>
          </div>
          
          {#if paymentScreenshots.length > 0}
            <div class="mt-4 grid grid-cols-2 md:grid-cols-3 gap-4">
              {#each paymentScreenshots as file, index}
                <div class="relative">
                  <img
                    src={URL.createObjectURL(file)}
                    alt="付款截图"
                    class="w-full h-24 object-cover rounded-lg border-2 border-orange-200"
                  />
                  <button
                    type="button"
                    on:click={() => removePaymentScreenshot(index)}
                    class="absolute -top-2 -right-2 bg-red-500 text-white rounded-full w-6 h-6 flex items-center justify-center text-xs hover:bg-red-600"
                  >
                    ×
                  </button>
                </div>
              {/each}
            </div>
          {/if}
        </div>
        
        <!-- 附言输入 -->
        <div class="mb-6">
          <label for="description" class="block text-sm font-medium text-gray-700 mb-2">
            附言 ({description.length}/800字)
          </label>
          <textarea
            id="description"
            bind:value={description}
            rows="6"
            maxlength="800"
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            placeholder="请详细描述您的问题..."
          ></textarea>
        </div>
        
        <!-- 金额和币种 -->
        <div class="mb-6">
          <label class="block text-sm font-medium text-gray-700 mb-2">
            金额
          </label>
          <div class="flex space-x-4">
            <div class="flex-1">
              <input
                type="number"
                bind:value={amount}
                min="0"
                step="0.01"
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                placeholder="请输入金额"
              />
            </div>
            <div class="w-32">
              <select
                bind:value={currency}
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              >
                {#each currencyOptions as option}
                  <option value={option.value}>{option.label}</option>
                {/each}
              </select>
            </div>
          </div>
        </div>
        
        <!-- 小孩危急选项 -->
        <div class="mb-6">
          <label class="flex items-center">
            <input
              type="checkbox"
              bind:checked={isChildEmergency}
              class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
            />
            <span class="ml-2 text-sm text-gray-700">小孩危急情况（优先处理）</span>
          </label>
        </div>
        
        <!-- 提交按钮 -->
        <div class="flex justify-end space-x-4">
          <button
            type="button"
            on:click={() => goto('/fortune/history')}
            class="px-4 py-2 border border-gray-300 rounded-md text-gray-700 hover:bg-gray-50"
          >
            取消
          </button>
          <button
            type="button"
            on:click={submitModification}
            disabled={isSubmitting || !amount || paymentScreenshots.length === 0}
            class="px-6 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {#if isSubmitting}
              修改中... ({uploadProgress}%)
            {:else}
              提交修改
            {/if}
          </button>
        </div>
      </div>
    {/if}
  </div>
</div> 