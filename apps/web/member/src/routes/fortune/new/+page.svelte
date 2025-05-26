<script>
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { page } from '$app/stores';
  
  let files = [];
  let paymentScreenshots = [];
  let description = '';
  let amount = '';
  let currency = 'CNY';
  let isChildEmergency = false;
  let isSubmitting = false;
  let uploadProgress = 0;
  
  const currencyOptions = [
    { value: 'CNY', label: '¥ 人民币', symbol: '¥' },
    { value: 'USD', label: '$ 美元', symbol: '$' },
    { value: 'CAD', label: 'C$ 加元', symbol: 'C$' },
    { value: 'SGD', label: 'S$ 新币', symbol: 'S$' },
    { value: 'AUD', label: 'A$ 澳元', symbol: 'A$' }
  ];
  
  let fileInput;
  
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
  
  async function uploadToR2(file) {
    // 这里应该实现实际的R2上传逻辑
    // 暂时返回模拟结果
    return new Promise((resolve) => {
      setTimeout(() => {
        resolve({
          url: `https://r2.example.com/${file.name}`,
          success: true
        });
      }, 1000);
    });
  }
  
  async function submitApplication() {
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
      
      // 提交申请
      const response = await fetch('https://fortune.baiduohui.com/submit', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${localStorage.getItem('supabase_token')}`
        },
        body: formData
      });
      
      uploadProgress = 100;
      
      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.error || '提交失败');
      }
      
      const result = await response.json();
      alert('申请提交成功！');
      goto('/fortune/history');
      
    } catch (error) {
      console.error('提交失败:', error);
      alert('提交失败: ' + error.message);
    } finally {
      isSubmitting = false;
      uploadProgress = 0;
    }
  }
</script>

<div class="min-h-screen bg-gray-50 py-8">
  <div class="max-w-2xl mx-auto px-4">
    <div class="bg-white rounded-lg shadow-md p-6">
      <h1 class="text-2xl font-bold text-gray-900 mb-6">提交算命申请</h1>
      
      <!-- 正文图片上传区域 -->
      <div class="mb-6">
        <label class="block text-sm font-medium text-gray-700 mb-2">
          上传正文图片 (最多3张)
        </label>
        
        <div class="border-2 border-dashed border-gray-300 rounded-lg p-6 text-center">
          <input
            bind:this={fileInput}
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
          上传付款截图 (必须，最多5张)
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
          on:click={submitApplication}
          disabled={isSubmitting || !amount || paymentScreenshots.length === 0}
          class="px-6 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {#if isSubmitting}
            提交中... ({uploadProgress}%)
          {:else}
            提交申请
          {/if}
        </button>
      </div>
    </div>
  </div>
</div> 