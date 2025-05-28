<!-- Member的算命功能与Fan完全一致 -->
<script>
  import { onMount } from 'svelte';
  

  export let session;

  let showNewApplication = false;
  let showUploadModal = false;
  let showModifyModal = false;
  let showPaymentChoiceModal = false;
  let applications = [];
  let loading = false;
  let testingPosition = false;
  let testCount = 0;
  let currentOrderId = '';
  let currentApplication = null;
  let uploadFiles = [];
  const maxTestsPerHour = 15;

  // 表单数据
  let formData = {
    images: [],
    message: '',
    kidsEmergency: false,
    currency: 'CNY',
    amount: 0
  };

  let imageFiles = [];
  let charCount = 0;
  const maxChars = 800;

  const currencies = [
    { code: 'CNY', symbol: '¥', name: '人民币' },
    { code: 'USD', symbol: '$', name: '美元' },
    { code: 'CAD', symbol: 'C$', name: '加拿大元' },
    { code: 'SGD', symbol: 'S$', name: '新加坡元' },
    { code: 'AUD', symbol: 'A$', name: '澳元' }
  ];

  onMount(() => {
    loadApplications();
    // 从localStorage获取测试次数
    const stored = localStorage.getItem('fortuneTestCount');
    if (stored) {
      const data = JSON.parse(stored);
      const now = Date.now();
      if (now - data.timestamp < 3600000) { // 1小时内
        testCount = data.count;
      } else {
        localStorage.removeItem('fortuneTestCount');
      }
    }

    // Member可以实时看到状态更新，设置轮询
    const interval = setInterval(loadApplications, 30000); // 每30秒刷新一次
    return () => clearInterval(interval);
  });

  async function loadApplications() {
    try {
      loading = true;
      const response = await fetch(`/api/fortune/list?userId=${session.user.id}`);
      if (response.ok) {
        applications = await response.json();
      }
    } catch (error) {
      console.error('加载申请列表失败:', error);
    } finally {
      loading = false;
    }
  }

  function handleImageUpload(event) {
    const files = Array.from(event.target.files);
    if (files.length + imageFiles.length > 3) {
      alert('最多只能上传3张图片');
      return;
    }

    files.forEach(file => {
      if (file.size > 5 * 1024 * 1024) {
        alert('图片大小不能超过5MB');
        return;
      }
      if (!['image/jpeg', 'image/png'].includes(file.type)) {
        alert('只支持JPG和PNG格式');
        return;
      }
      imageFiles = [...imageFiles, file];
    });
  }

  function removeImage(index) {
    imageFiles = imageFiles.filter((_, i) => i !== index);
  }

  function updateCharCount() {
    charCount = formData.message.length;
  }

  async function testPosition() {
    if (testCount >= maxTestsPerHour) {
      alert('测试次数已用完，请稍后再试');
      return;
    }

    if (!formData.amount || formData.amount <= 0) {
      alert('请输入有效金额');
      return;
    }

    try {
      testingPosition = true;
      const response = await fetch(`/api/fortune/percentile?amount=${formData.amount}&currency=${formData.currency}`);
      
      if (response.ok) {
        const data = await response.json();
        alert(`您当前排队在前 ${data.percentile}%`);
        
        // 更新测试次数
        testCount++;
        const testData = {
          count: testCount,
          timestamp: Date.now()
        };
        localStorage.setItem('fortuneTestCount', JSON.stringify(testData));
      } else {
        alert('测试失败，请重试');
      }
    } catch (error) {
      console.error('测试位置失败:', error);
      alert('测试失败，请重试');
    } finally {
      testingPosition = false;
    }
  }

  async function submitApplication() {
    try {
      loading = true;
      
      const formDataToSend = new FormData();
      formDataToSend.append('message', formData.message);
      formDataToSend.append('kidsEmergency', formData.kidsEmergency.toString());
      formDataToSend.append('currency', formData.currency);
      formDataToSend.append('amount', formData.amount.toString());
      formDataToSend.append('userId', session.user.id);
      
      imageFiles.forEach((file, index) => {
        formDataToSend.append(`image${index}`, file);
      });

      const response = await fetch('/api/fortune/apply', {
        method: 'POST',
        body: formDataToSend
      });

      if (response.ok) {
        const result = await response.json();
        currentOrderId = result.orderId;
        showNewApplication = false;
        showPaymentChoiceModal = true;
        resetForm();
      } else {
        const error = await response.json();
        alert(error.message || '提交失败，请重试');
      }
    } catch (error) {
      console.error('提交申请失败:', error);
      alert('提交失败，请重试');
    } finally {
      loading = false;
    }
  }

  async function handleOnlinePayment() {
    try {
      const response = await fetch('/api/payment/session', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          orderId: currentOrderId,
          amount: formData.amount * 100, // 转换为分
          currency: formData.currency,
          description: '算命服务'
        })
      });

      if (response.ok) {
        const data = await response.json();
        window.location.href = data.url;
      } else {
        alert('创建支付会话失败');
      }
    } catch (error) {
      console.error('支付失败:', error);
      alert('支付失败，请重试');
    }
    showPaymentChoiceModal = false;
  }

  function handleUploadPayment() {
    showPaymentChoiceModal = false;
    showUploadModal = true;
  }

  async function uploadPaymentProof() {
    if (uploadFiles.length === 0) {
      alert('请选择支付凭证');
      return;
    }

    try {
      loading = true;
      const formData = new FormData();
      formData.append('orderId', currentOrderId);
      
      uploadFiles.forEach((file, index) => {
        formData.append(`screenshot${index}`, file);
      });

      const response = await fetch('/api/fortune/upload', {
        method: 'POST',
        body: formData
      });

      if (response.ok) {
        alert('支付凭证上传成功，正在排队处理中');
        showUploadModal = false;
        uploadFiles = [];
        loadApplications();
      } else {
        alert('上传失败，请重试');
      }
    } catch (error) {
      console.error('上传失败:', error);
      alert('上传失败，请重试');
    } finally {
      loading = false;
    }
  }

  function handleUploadFiles(event) {
    const files = Array.from(event.target.files);
    if (files.length > 3) {
      alert('最多只能上传3张截图');
      return;
    }
    uploadFiles = files;
  }

  function resetForm() {
    formData = {
      images: [],
      message: '',
      kidsEmergency: false,
      currency: 'CNY',
      amount: 0
    };
    imageFiles = [];
    charCount = 0;
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
      'Pending': 'text-yellow-600',
      'Queued-payed': 'text-blue-600',
      'Queued-upload': 'text-purple-600',
      'Completed': 'text-green-600',
      'Refunded': 'text-red-600'
    };
    return colorMap[status] || 'text-gray-600';
  }

  function canModify(application) {
    return ['Pending', 'Queued-payed', 'Queued-upload'].includes(application.status) && 
           application.remainingModifications > 0;
  }

  function openModifyModal(application) {
    currentApplication = application;
    formData = {
      images: [],
      message: application.message,
      kidsEmergency: application.kidsEmergency,
      currency: application.currency,
      amount: application.amount
    };
    charCount = formData.message.length;
    showModifyModal = true;
  }

  async function submitModification() {
    try {
      loading = true;
      
      const formDataToSend = new FormData();
      formDataToSend.append('orderId', currentApplication._id);
      formDataToSend.append('message', formData.message);
      
      imageFiles.forEach((file, index) => {
        formDataToSend.append(`image${index}`, file);
      });

      const response = await fetch('/api/fortune/modify', {
        method: 'POST',
        body: formDataToSend
      });

      if (response.ok) {
        alert('修改成功');
        showModifyModal = false;
        resetForm();
        loadApplications();
      } else {
        const error = await response.json();
        alert(error.message || '修改失败，请重试');
      }
    } catch (error) {
      console.error('修改失败:', error);
      alert('修改失败，请重试');
    } finally {
      loading = false;
    }
  }

  function formatDateTime(dateString) {
    return new Date(dateString).toLocaleString('zh-CN');
  }

  function formatCurrency(amount, currency) {
    const symbols = {
      'CNY': '¥',
      'USD': '$',
      'CAD': 'C$',
      'SGD': 'S$',
      'AUD': 'A$'
    };
    return `${symbols[currency] || ''}${amount}`;
  }
</script>

<div class="bg-white rounded-lg shadow p-6">
  <div class="flex items-center justify-between mb-6">
    <h2 class="text-2xl font-semibold text-gray-900">算命</h2>
    <button
      on:click={() => showNewApplication = true}
      class="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 transition-colors"
    >
      新建申请
    </button>
  </div>

  <!-- 申请列表 -->
  <div class="space-y-4">
    {#if loading}
      <div class="text-center py-8">
        <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600 mx-auto"></div>
        <p class="mt-2 text-gray-600">加载中...</p>
      </div>
    {:else if applications.length === 0}
      <div class="text-center py-8">
        <svg class="w-12 h-12 text-gray-400 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path>
        </svg>
        <p class="text-gray-600">暂无申请记录</p>
      </div>
    {:else}
      {#each applications as application}
        <div class="border rounded-lg p-4">
          <div class="flex items-center justify-between mb-3">
            <div class="flex items-center space-x-3">
              <span class="text-sm font-medium {getStatusColor(application.status)}">
                {getStatusText(application.status)}
              </span>
              {#if application.priority}
                <span class="px-2 py-1 text-xs bg-red-100 text-red-800 rounded-full">
                  紧急
                </span>
              {/if}
              <span class="text-sm text-gray-500">
                排队位置: #{application.queueIndex || '-'}
              </span>
            </div>
            <span class="text-sm text-gray-500">
              {formatDateTime(application.createdAt)}
            </span>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-3">
            <div>
              <span class="text-sm font-medium text-gray-700">金额:</span>
              <span class="ml-2 text-sm text-gray-900">
                {formatCurrency(application.amount, application.currency)}
                {#if application.convertedAmountCAD}
                  (≈ C${application.convertedAmountCAD})
                {/if}
              </span>
            </div>
            <div>
              <span class="text-sm font-medium text-gray-700">剩余修改次数:</span>
              <span class="ml-2 text-sm text-gray-900">
                {application.remainingModifications || 0}
              </span>
            </div>
          </div>

          <div class="mb-3">
            <span class="text-sm font-medium text-gray-700">附言:</span>
            <p class="mt-1 text-sm text-gray-900 bg-gray-50 rounded p-2">
              {application.message || '无'}
            </p>
          </div>

          {#if application.images && application.images.length > 0}
            <div class="mb-3">
              <span class="text-sm font-medium text-gray-700">图片:</span>
              <div class="mt-1 flex space-x-2">
                {#each application.images as image}
                  <img src={image.url} alt="申请图片" class="w-16 h-16 object-cover rounded border" />
                {/each}
              </div>
            </div>
          {/if}

          {#if canModify(application)}
            <div class="flex space-x-2">
              <button
                on:click={() => openModifyModal(application)}
                class="px-3 py-1 text-sm bg-yellow-100 text-yellow-800 rounded hover:bg-yellow-200 transition-colors"
              >
                修改申请
              </button>
            </div>
          {/if}
        </div>
      {/each}
    {/if}
  </div>
</div>

<!-- 新建申请模态框 -->
{#if showNewApplication}
  <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
    <div class="bg-white rounded-lg max-w-2xl w-full max-h-[90vh] overflow-y-auto">
      <div class="p-6">
        <div class="flex items-center justify-between mb-6">
          <h3 class="text-lg font-semibold text-gray-900">新建算命申请</h3>
          <button
            on:click={() => showNewApplication = false}
            class="text-gray-400 hover:text-gray-600"
          >
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
            </svg>
          </button>
        </div>

        <div class="space-y-6">
          <!-- 图片上传 -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">
              图片上传 (最多3张)
            </label>
            <input
              type="file"
              multiple
              accept="image/jpeg,image/png"
              on:change={handleImageUpload}
              class="block w-full text-sm text-gray-500 file:mr-4 file:py-2 file:px-4 file:rounded-full file:border-0 file:text-sm file:font-semibold file:bg-blue-50 file:text-blue-700 hover:file:bg-blue-100"
            />
            <p class="mt-1 text-xs text-gray-500">支持JPG、PNG格式，每张图片不超过5MB</p>
            
            {#if imageFiles.length > 0}
              <div class="mt-3 grid grid-cols-3 gap-2">
                {#each imageFiles as file, index}
                  <div class="relative">
                    <img
                      src={URL.createObjectURL(file)}
                      alt="预览"
                      class="w-full h-20 object-cover rounded border"
                    />
                    <button
                      on:click={() => removeImage(index)}
                      class="absolute -top-1 -right-1 w-5 h-5 bg-red-500 text-white rounded-full text-xs hover:bg-red-600"
                    >
                      ×
                    </button>
                  </div>
                {/each}
              </div>
            {/if}
          </div>

          <!-- 附言 -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">
              附言 ({charCount}/{maxChars})
            </label>
            <textarea
              bind:value={formData.message}
              on:input={updateCharCount}
              maxlength={maxChars}
              rows="4"
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              placeholder="请描述您的问题..."
            ></textarea>
          </div>

          <!-- 紧急订单 -->
          <div class="flex items-center">
            <input
              type="checkbox"
              bind:checked={formData.kidsEmergency}
              id="emergency"
              class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
            />
            <label for="emergency" class="ml-2 block text-sm text-gray-900">
              紧急订单 (优先处理)
            </label>
          </div>

          <!-- 币种和金额 -->
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">币种</label>
              <select
                bind:value={formData.currency}
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              >
                {#each currencies as currency}
                  <option value={currency.code}>{currency.symbol} {currency.name}</option>
                {/each}
              </select>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">金额</label>
              <div class="flex">
                <input
                  type="number"
                  bind:value={formData.amount}
                  min="0"
                  step="0.01"
                  class="flex-1 px-3 py-2 border border-gray-300 rounded-l-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                  placeholder="0.00"
                />
                <button
                  on:click={testPosition}
                  disabled={testingPosition || testCount >= maxTestsPerHour}
                  class="px-3 py-2 bg-gray-100 text-gray-700 border border-l-0 border-gray-300 rounded-r-md hover:bg-gray-200 disabled:opacity-50 disabled:cursor-not-allowed text-sm"
                >
                  {testingPosition ? '测试中...' : '测试位置'}
                </button>
              </div>
              {#if testCount >= maxTestsPerHour}
                <p class="mt-1 text-xs text-red-500">测试次数已用完，请稍后再试</p>
              {:else}
                <p class="mt-1 text-xs text-gray-500">剩余测试次数: {maxTestsPerHour - testCount}</p>
              {/if}
            </div>
          </div>

          <!-- 提交按钮 -->
          <div class="flex space-x-3">
            <button
              on:click={() => showNewApplication = false}
              class="flex-1 px-4 py-2 border border-gray-300 text-gray-700 rounded-md hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-gray-500"
            >
              取消
            </button>
            <button
              on:click={submitApplication}
              disabled={loading || !formData.message.trim() || !formData.amount}
              class="flex-1 px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {loading ? '提交中...' : '提交申请'}
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
{/if}

<!-- 支付方式选择模态框 -->
{#if showPaymentChoiceModal}
  <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
    <div class="bg-white rounded-lg max-w-md w-full">
      <div class="p-6">
        <h3 class="text-lg font-semibold text-gray-900 mb-4">选择支付方式</h3>
        <p class="text-gray-600 mb-6">请选择您的支付方式：</p>
        
        <div class="space-y-3">
          <button
            on:click={handleOnlinePayment}
            class="w-full p-4 border border-gray-300 rounded-lg hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-blue-500 text-left"
          >
            <div class="flex items-center">
              <svg class="w-6 h-6 text-blue-600 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 10h18M7 15h1m4 0h1m-7 4h12a3 3 0 003-3V8a3 3 0 00-3-3H6a3 3 0 00-3 3v8a3 3 0 003 3z"></path>
              </svg>
              <div>
                <div class="font-medium text-gray-900">在线支付</div>
                <div class="text-sm text-gray-500">使用信用卡或借记卡支付</div>
              </div>
            </div>
          </button>
          
          <button
            on:click={handleUploadPayment}
            class="w-full p-4 border border-gray-300 rounded-lg hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-blue-500 text-left"
          >
            <div class="flex items-center">
              <svg class="w-6 h-6 text-green-600 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"></path>
              </svg>
              <div>
                <div class="font-medium text-gray-900">已付款</div>
                <div class="text-sm text-gray-500">上传银行转账或其他支付凭证</div>
              </div>
            </div>
          </button>
        </div>
        
        <button
          on:click={() => showPaymentChoiceModal = false}
          class="w-full mt-4 px-4 py-2 border border-gray-300 text-gray-700 rounded-md hover:bg-gray-50"
        >
          取消
        </button>
      </div>
    </div>
  </div>
{/if}

<!-- 上传支付凭证模态框 -->
{#if showUploadModal}
  <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
    <div class="bg-white rounded-lg max-w-md w-full">
      <div class="p-6">
        <h3 class="text-lg font-semibold text-gray-900 mb-4">上传支付凭证</h3>
        
        <div class="mb-4">
          <label class="block text-sm font-medium text-gray-700 mb-2">
            支付截图 (最多3张)
          </label>
          <input
            type="file"
            multiple
            accept="image/*"
            on:change={handleUploadFiles}
            class="block w-full text-sm text-gray-500 file:mr-4 file:py-2 file:px-4 file:rounded-full file:border-0 file:text-sm file:font-semibold file:bg-blue-50 file:text-blue-700 hover:file:bg-blue-100"
          />
          <p class="mt-1 text-xs text-gray-500">请上传银行转账、微信、支付宝等支付凭证</p>
        </div>
        
        <div class="flex space-x-3">
          <button
            on:click={() => showUploadModal = false}
            class="flex-1 px-4 py-2 border border-gray-300 text-gray-700 rounded-md hover:bg-gray-50"
          >
            取消
          </button>
          <button
            on:click={uploadPaymentProof}
            disabled={loading || uploadFiles.length === 0}
            class="flex-1 px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {loading ? '上传中...' : '提交凭证'}
          </button>
        </div>
      </div>
    </div>
  </div>
{/if}

<!-- 修改申请模态框 -->
{#if showModifyModal && currentApplication}
  <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
    <div class="bg-white rounded-lg max-w-2xl w-full max-h-[90vh] overflow-y-auto">
      <div class="p-6">
        <div class="flex items-center justify-between mb-6">
          <h3 class="text-lg font-semibold text-gray-900">修改申请</h3>
          <button
            on:click={() => showModifyModal = false}
            class="text-gray-400 hover:text-gray-600"
          >
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
            </svg>
          </button>
        </div>

        <div class="mb-4 p-3 bg-yellow-50 border border-yellow-200 rounded">
          <p class="text-sm text-yellow-800">
            剩余修改次数: {currentApplication.remainingModifications}
            <br />
            注意: 金额和币种不可修改
          </p>
        </div>

        <div class="space-y-6">
          <!-- 图片上传 -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">
              重新上传图片 (最多3张)
            </label>
            <input
              type="file"
              multiple
              accept="image/jpeg,image/png"
              on:change={handleImageUpload}
              class="block w-full text-sm text-gray-500 file:mr-4 file:py-2 file:px-4 file:rounded-full file:border-0 file:text-sm file:font-semibold file:bg-blue-50 file:text-blue-700 hover:file:bg-blue-100"
            />
            
            {#if imageFiles.length > 0}
              <div class="mt-3 grid grid-cols-3 gap-2">
                {#each imageFiles as file, index}
                  <div class="relative">
                    <img
                      src={URL.createObjectURL(file)}
                      alt="预览"
                      class="w-full h-20 object-cover rounded border"
                    />
                    <button
                      on:click={() => removeImage(index)}
                      class="absolute -top-1 -right-1 w-5 h-5 bg-red-500 text-white rounded-full text-xs hover:bg-red-600"
                    >
                      ×
                    </button>
                  </div>
                {/each}
              </div>
            {/if}
          </div>

          <!-- 附言 -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">
              附言 ({charCount}/{maxChars})
            </label>
            <textarea
              bind:value={formData.message}
              on:input={updateCharCount}
              maxlength={maxChars}
              rows="4"
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              placeholder="请描述您的问题..."
            ></textarea>
          </div>

          <!-- 提交按钮 -->
          <div class="flex space-x-3">
            <button
              on:click={() => showModifyModal = false}
              class="flex-1 px-4 py-2 border border-gray-300 text-gray-700 rounded-md hover:bg-gray-50"
            >
              取消
            </button>
            <button
              on:click={submitModification}
              disabled={loading}
              class="flex-1 px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {loading ? '提交中...' : '提交修改'}
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
{/if} 