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
        alert('支付凭证已提交，正在排队处理中');
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

  function showModifyForm(app) {
    if (app.remainingModifications <= 0) {
      alert('修改次数已用完');
      return;
    }
    currentApplication = app;
    formData = {
      images: [],
      message: app.message,
      kidsEmergency: app.kidsEmergency,
      currency: app.currency,
      amount: app.amount
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
        alert('修改已提交');
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
    currentApplication = null;
  }

  function closeModals() {
    showNewApplication = false;
    showUploadModal = false;
    showModifyModal = false;
    showPaymentChoiceModal = false;
    resetForm();
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
</script>

<div class="bg-white rounded-lg shadow p-6">
  <div class="flex justify-between items-center mb-6">
    <h2 class="text-2xl font-semibold text-gray-900">算命</h2>
    <button
      on:click={() => showNewApplication = true}
      class="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500"
    >
      新建申请
    </button>
  </div>

  <!-- 申请列表 -->
  {#if loading}
    <div class="text-center py-8">
      <svg class="animate-spin h-8 w-8 text-blue-600 mx-auto mb-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
      </svg>
      <p class="text-gray-600">加载中...</p>
    </div>
  {:else if applications.length === 0}
    <div class="text-center py-8">
      <svg class="w-16 h-16 text-gray-400 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path>
      </svg>
      <p class="text-gray-600">暂无申请记录</p>
    </div>
  {:else}
    <div class="space-y-4">
      {#each applications as app}
        <div class="border rounded-lg p-4 {app.priority ? 'border-red-300 bg-red-50' : 'border-gray-200'}">
          <div class="flex justify-between items-start mb-2">
            <div class="flex items-center space-x-2">
              <span class="text-sm font-medium text-gray-900">#{app.queueIndex || '待排队'}</span>
              {#if app.kidsEmergency}
                <span class="px-2 py-1 text-xs bg-red-100 text-red-800 rounded-full">紧急</span>
              {/if}
              <span class="px-2 py-1 text-xs rounded-full {getStatusColor(app.status)}">
                {getStatusText(app.status)}
              </span>
            </div>
            <div class="flex items-center space-x-2">
              <span class="text-sm text-gray-500">{new Date(app.createdAt).toLocaleDateString()}</span>
              {#if (app.status === 'Pending' || app.status === 'Queued-payed' || app.status === 'Queued-upload') && app.remainingModifications > 0}
                <button
                  on:click={() => showModifyForm(app)}
                  class="text-xs px-2 py-1 bg-blue-100 text-blue-700 rounded hover:bg-blue-200"
                >
                  修改
                </button>
              {/if}
            </div>
          </div>
          
          <p class="text-gray-700 mb-2">{app.message.substring(0, 100)}{app.message.length > 100 ? '...' : ''}</p>
          
          <div class="flex justify-between items-center text-sm text-gray-600">
            <span>金额: {app.convertedAmountCAD || app.amount} {app.convertedAmountCAD ? 'CAD' : app.currency}</span>
            <span>剩余修改次数: {app.remainingModifications || 5}</span>
          </div>
          
          {#if app.percentile}
            <div class="mt-2 text-sm text-blue-600">
              排队位置: 前 {app.percentile}%
            </div>
          {/if}
        </div>
      {/each}
    </div>
  {/if}
</div>

<!-- 新建申请模态框 -->
{#if showNewApplication}
  <div class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50">
    <div class="relative top-10 mx-auto p-5 border w-full max-w-2xl shadow-lg rounded-md bg-white">
      <div class="mt-3">
        <h3 class="text-lg font-medium text-gray-900 mb-4">新建算命申请</h3>
        
        <!-- 图片上传 -->
        <div class="mb-4">
          <label class="block text-sm font-medium text-gray-700 mb-2">上传图片 (最多3张)</label>
          <input
            type="file"
            multiple
            accept="image/jpeg,image/png"
            on:change={handleImageUpload}
            class="block w-full text-sm text-gray-500 file:mr-4 file:py-2 file:px-4 file:rounded-full file:border-0 file:text-sm file:font-semibold file:bg-blue-50 file:text-blue-700 hover:file:bg-blue-100"
          />
          
          {#if imageFiles.length > 0}
            <div class="mt-2 flex flex-wrap gap-2">
              {#each imageFiles as file, index}
                <div class="relative">
                  <img src={URL.createObjectURL(file)} alt="预览" class="w-20 h-20 object-cover rounded" />
                  <button
                    on:click={() => removeImage(index)}
                    class="absolute -top-2 -right-2 bg-red-500 text-white rounded-full w-6 h-6 flex items-center justify-center text-xs"
                  >
                    ×
                  </button>
                </div>
              {/each}
            </div>
          {/if}
        </div>

        <!-- 附言输入 -->
        <div class="mb-4">
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
        <div class="mb-4">
          <label class="flex items-center">
            <input
              type="checkbox"
              bind:checked={formData.kidsEmergency}
              class="rounded border-gray-300 text-blue-600 focus:ring-blue-500"
            />
            <span class="ml-2 text-sm text-gray-700">紧急订单 (优先处理)</span>
          </label>
        </div>

        <!-- 币种和金额 -->
        <div class="mb-4 flex space-x-4">
          <div class="flex-1">
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
          
          <div class="flex-1">
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
                class="px-4 py-2 bg-gray-100 text-gray-700 border border-l-0 border-gray-300 rounded-r-md hover:bg-gray-200 disabled:opacity-50 disabled:cursor-not-allowed text-sm"
              >
                {testingPosition ? '测试中...' : '测试位置'}
              </button>
            </div>
            {#if testCount >= maxTestsPerHour}
              <p class="text-xs text-red-600 mt-1">测试次数已用完，请稍后再试</p>
            {:else}
              <p class="text-xs text-gray-500 mt-1">剩余测试次数: {maxTestsPerHour - testCount}</p>
            {/if}
          </div>
        </div>

        <!-- 提交按钮 -->
        <div class="flex space-x-3">
          <button
            on:click={submitApplication}
            disabled={loading}
            class="flex-1 px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 disabled:opacity-50"
          >
            提交申请
          </button>
          <button
            on:click={closeModals}
            class="px-4 py-2 bg-gray-300 text-gray-700 rounded-md hover:bg-gray-400 focus:outline-none focus:ring-2 focus:ring-gray-500"
          >
            取消
          </button>
        </div>
      </div>
    </div>
  </div>
{/if}

<!-- 支付方式选择模态框 -->
{#if showPaymentChoiceModal}
  <div class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50">
    <div class="relative top-20 mx-auto p-5 border w-96 shadow-lg rounded-md bg-white">
      <div class="mt-3 text-center">
        <h3 class="text-lg font-medium text-gray-900 mb-4">选择支付方式</h3>
        
        <div class="space-y-3">
          <button
            on:click={handleOnlinePayment}
            class="w-full px-4 py-3 bg-blue-600 text-white rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500"
          >
            在线支付
          </button>
          <button
            on:click={handleUploadPayment}
            class="w-full px-4 py-3 bg-green-600 text-white rounded-md hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-green-500"
          >
            已付款上传凭证
          </button>
          <button
            on:click={closeModals}
            class="w-full px-4 py-3 bg-gray-300 text-gray-700 rounded-md hover:bg-gray-400 focus:outline-none focus:ring-2 focus:ring-gray-500"
          >
            取消
          </button>
        </div>
      </div>
    </div>
  </div>
{/if}

<!-- 上传支付凭证模态框 -->
{#if showUploadModal}
  <div class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50">
    <div class="relative top-20 mx-auto p-5 border w-96 shadow-lg rounded-md bg-white">
      <div class="mt-3">
        <h3 class="text-lg font-medium text-gray-900 mb-4">上传支付凭证</h3>
        
        <div class="mb-4">
          <label class="block text-sm font-medium text-gray-700 mb-2">选择支付截图 (最多3张)</label>
          <input
            type="file"
            multiple
            accept="image/jpeg,image/png"
            on:change={handleUploadFiles}
            class="block w-full text-sm text-gray-500 file:mr-4 file:py-2 file:px-4 file:rounded-full file:border-0 file:text-sm file:font-semibold file:bg-blue-50 file:text-blue-700 hover:file:bg-blue-100"
          />
        </div>
        
        <div class="flex space-x-3">
          <button
            on:click={uploadPaymentProof}
            disabled={loading || uploadFiles.length === 0}
            class="flex-1 px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 disabled:opacity-50"
          >
            {loading ? '上传中...' : '提交凭证'}
          </button>
          <button
            on:click={closeModals}
            class="px-4 py-2 bg-gray-300 text-gray-700 rounded-md hover:bg-gray-400 focus:outline-none focus:ring-2 focus:ring-gray-500"
          >
            取消
          </button>
        </div>
      </div>
    </div>
  </div>
{/if}

<!-- 修改申请模态框 -->
{#if showModifyModal}
  <div class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50">
    <div class="relative top-10 mx-auto p-5 border w-full max-w-2xl shadow-lg rounded-md bg-white">
      <div class="mt-3">
        <h3 class="text-lg font-medium text-gray-900 mb-4">修改申请 (剩余次数: {currentApplication?.remainingModifications || 0})</h3>
        
        <!-- 图片上传 -->
        <div class="mb-4">
          <label class="block text-sm font-medium text-gray-700 mb-2">重新上传图片 (最多3张)</label>
          <input
            type="file"
            multiple
            accept="image/jpeg,image/png"
            on:change={handleImageUpload}
            class="block w-full text-sm text-gray-500 file:mr-4 file:py-2 file:px-4 file:rounded-full file:border-0 file:text-sm file:font-semibold file:bg-blue-50 file:text-blue-700 hover:file:bg-blue-100"
          />
          
          {#if imageFiles.length > 0}
            <div class="mt-2 flex flex-wrap gap-2">
              {#each imageFiles as file, index}
                <div class="relative">
                  <img src={URL.createObjectURL(file)} alt="预览" class="w-20 h-20 object-cover rounded" />
                  <button
                    on:click={() => removeImage(index)}
                    class="absolute -top-2 -right-2 bg-red-500 text-white rounded-full w-6 h-6 flex items-center justify-center text-xs"
                  >
                    ×
                  </button>
                </div>
              {/each}
            </div>
          {/if}
        </div>

        <!-- 附言输入 -->
        <div class="mb-4">
          <label class="block text-sm font-medium text-gray-700 mb-2">
            修改附言 ({charCount}/{maxChars})
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

        <div class="bg-yellow-50 border border-yellow-200 rounded p-3 mb-4">
          <p class="text-sm text-yellow-800">
            注意：金额和币种不可修改。每个申请最多可修改5次。
          </p>
        </div>

        <!-- 提交按钮 -->
        <div class="flex space-x-3">
          <button
            on:click={submitModification}
            disabled={loading}
            class="flex-1 px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 disabled:opacity-50"
          >
            {loading ? '提交中...' : '提交修改'}
          </button>
          <button
            on:click={closeModals}
            class="px-4 py-2 bg-gray-300 text-gray-700 rounded-md hover:bg-gray-400 focus:outline-none focus:ring-2 focus:ring-gray-500"
          >
            取消
          </button>
        </div>
      </div>
    </div>
  </div>
{/if} 