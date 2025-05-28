<script>
  import { onMount, createEventDispatcher } from 'svelte';
  import { apiCall } from '$lib/auth';
  

  const dispatch = createEventDispatcher();

  export let session;


  let settings = {
    storeId: '',
    storeName: '',
    city: '',
    notificationEmail: '',
    secretKey: '',
    publishableKey: '',
    isActive: true,
    createdAt: '',
    updatedAt: ''
  };

  let loading = true;
  let saving = false;
  let showKeyForm = false;
  let showSecretKey = false;
  let testingConnection = false;
  let showDeleteConfirm = false;
  let showSuccessMessage = '';
  let showErrorMessage = '';

  // 新密钥表单
  let newKeys = {
    secretKey: '',
    publishableKey: ''
  };

  // 中国城市列表（简化版）
  const cities = [
    '北京', '上海', '广州', '深圳', '杭州', '南京', '苏州', '成都', '重庆', '武汉',
    '西安', '天津', '青岛', '大连', '厦门', '宁波', '无锡', '佛山', '温州', '泉州',
    '东莞', '长沙', '郑州', '济南', '哈尔滨', '福州', '石家庄', '合肥', '昆明', '沈阳'
  ];

  let filteredCities = [];
  let showCityDropdown = false;

  onMount(() => {
    loadSettings();
  });

  async function loadSettings() {
    try {
      loading = true;
      const response = await apiCall('/seller/settings');
      settings = response.settings;
    } catch (error) {
      console.error('加载设置失败:', error);
      // 如果是首次访问，显示添加密钥的提示
      if (error.message?.includes('not found')) {
        showKeyForm = true;
      }
    } finally {
      loading = false;
    }
  }

  async function saveBasicSettings() {
    try {
      saving = true;
      showErrorMessage = '';
      
      await apiCall('/seller/settings', {
        method: 'PUT',
        body: JSON.stringify({
          storeName: settings.storeName,
          city: settings.city,
          notificationEmail: settings.notificationEmail
        })
      });
      
      showSuccessMessage = '基本设置已保存';
      setTimeout(() => {
        showSuccessMessage = '';
      }, 3000);
    } catch (error) {
      console.error('保存设置失败:', error);
      showErrorMessage = '保存设置失败，请重试';
      setTimeout(() => {
        showErrorMessage = '';
      }, 5000);
    } finally {
      saving = false;
    }
  }

  async function testConnection() {
    if (!newKeys.secretKey || !newKeys.publishableKey) {
      showErrorMessage = '请输入完整的密钥信息';
      setTimeout(() => {
        showErrorMessage = '';
      }, 3000);
      return;
    }

    try {
      testingConnection = true;
      showErrorMessage = '';
      
      await apiCall('/keys/test', {
        method: 'POST',
        body: JSON.stringify({
          secretKey: newKeys.secretKey,
          publishableKey: newKeys.publishableKey
        })
      });
      
      showSuccessMessage = '连接测试成功！密钥有效';
      setTimeout(() => {
        showSuccessMessage = '';
      }, 3000);
    } catch (error) {
      console.error('连接测试失败:', error);
      showErrorMessage = '连接测试失败，请检查密钥是否正确';
      setTimeout(() => {
        showErrorMessage = '';
      }, 5000);
    } finally {
      testingConnection = false;
    }
  }

  async function saveKeys() {
    if (!newKeys.secretKey || !newKeys.publishableKey) {
      showErrorMessage = '请输入完整的密钥信息';
      setTimeout(() => {
        showErrorMessage = '';
      }, 3000);
      return;
    }

    // 二次确认
    const confirmMessage = settings.secretKey 
      ? '确定要更新这些密钥吗？更新后将覆盖现有密钥。' 
      : '确定要保存这些密钥吗？';
      
    if (!confirm(confirmMessage)) {
      return;
    }

    try {
      saving = true;
      showErrorMessage = '';
      
      await apiCall('/seller/keys', {
        method: 'POST',
        body: JSON.stringify({
          secretKey: newKeys.secretKey,
          publishableKey: newKeys.publishableKey
        })
      });

      showSuccessMessage = '密钥保存成功';
      showKeyForm = false;
      newKeys = { secretKey: '', publishableKey: '' };
      await loadSettings();
      
      setTimeout(() => {
        showSuccessMessage = '';
      }, 3000);
    } catch (error) {
      console.error('保存密钥失败:', error);
      showErrorMessage = '保存密钥失败，请重试';
      setTimeout(() => {
        showErrorMessage = '';
      }, 5000);
    } finally {
      saving = false;
    }
  }

  async function deleteKeys() {
    showDeleteConfirm = false;
    
    try {
      await apiCall('/seller/keys', {
        method: 'DELETE'
      });

      showSuccessMessage = '密钥删除成功';
      settings.secretKey = '';
      settings.publishableKey = '';
      
      setTimeout(() => {
        showSuccessMessage = '';
      }, 3000);
    } catch (error) {
      console.error('删除密钥失败:', error);
      showErrorMessage = '删除密钥失败，请重试';
      setTimeout(() => {
        showErrorMessage = '';
      }, 5000);
    }
  }

  function toggleSecretKeyVisibility() {
    showSecretKey = !showSecretKey;
    if (showSecretKey) {
      // 3秒后自动隐藏
      setTimeout(() => {
        showSecretKey = false;
      }, 3000);
    }
  }

  function maskSecretKey(key) {
    if (!key) return '';
    return `****${key.slice(-6)}`;
  }

  function filterCities(query) {
    if (!query) {
      filteredCities = [];
      showCityDropdown = false;
      return;
    }
    
    filteredCities = cities.filter(city => 
      city.toLowerCase().includes(query.toLowerCase())
    ).slice(0, 10);
    showCityDropdown = filteredCities.length > 0;
  }

  function selectCity(city) {
    settings.city = city;
    showCityDropdown = false;
    filteredCities = [];
  }

  function handleCityInput(event) {
    const target = event.target;
    filterCities(target.value);
  }

  function handleCityBlur() {
    // 延迟隐藏下拉框，以便点击选项
    setTimeout(() => {
      showCityDropdown = false;
    }, 200);
  }

  function closeKeyForm() {
    showKeyForm = false;
    newKeys = { secretKey: '', publishableKey: '' };
    showErrorMessage = '';
  }
</script>

<!-- 成功/错误消息提示 -->
{#if showSuccessMessage}
  <div class="fixed top-4 right-4 bg-green-100 border border-green-400 text-green-700 px-4 py-3 rounded z-50">
    <div class="flex items-center">
      <svg class="w-5 h-5 mr-2" fill="currentColor" viewBox="0 0 20 20">
        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"></path>
      </svg>
      {showSuccessMessage}
    </div>
  </div>
{/if}

{#if showErrorMessage}
  <div class="fixed top-4 right-4 bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded z-50">
    <div class="flex items-center">
      <svg class="w-5 h-5 mr-2" fill="currentColor" viewBox="0 0 20 20">
        <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clip-rule="evenodd"></path>
      </svg>
      {showErrorMessage}
    </div>
  </div>
{/if}

<div class="space-y-6">
  {#if loading}
    <div class="text-center py-8">
      <svg class="animate-spin h-8 w-8 text-blue-600 mx-auto mb-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 714 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
      </svg>
      <p class="text-gray-600">加载设置中...</p>
    </div>
  {:else}
    <!-- Stripe 密钥设置 -->
    <div class="bg-white rounded-lg shadow p-6">
      <h2 class="text-lg font-semibold text-gray-900 mb-4">Stripe 密钥设置</h2>
      
      {#if settings.secretKey}
        <!-- 已配置密钥 -->
        <div class="space-y-4">
          <div class="bg-green-50 border border-green-200 rounded-lg p-4">
            <div class="flex items-center">
              <svg class="w-5 h-5 text-green-500 mr-2" fill="currentColor" viewBox="0 0 20 20">
                <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"></path>
              </svg>
              <span class="text-green-800 font-medium">密钥已配置</span>
            </div>
          </div>
          
          <div class="space-y-3">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Secret Key</label>
              <div class="flex items-center space-x-2">
                <span class="font-mono text-sm text-gray-900 bg-gray-50 px-3 py-2 rounded border flex-1">
                  {showSecretKey ? settings.secretKey : maskSecretKey(settings.secretKey)}
                </span>
                <button
                  on:click={toggleSecretKeyVisibility}
                  class="px-3 py-2 text-sm bg-blue-100 text-blue-700 rounded hover:bg-blue-200 transition-colors"
                >
                  {showSecretKey ? '隐藏' : '查看'}
                </button>
              </div>
            </div>
            
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Publishable Key</label>
              <span class="font-mono text-sm text-gray-900 bg-gray-50 px-3 py-2 rounded border block">
                {settings.publishableKey}
              </span>
            </div>
          </div>
          
          <div class="flex space-x-3">
            <button
              on:click={() => showKeyForm = true}
              class="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 transition-colors"
            >
              更新密钥
            </button>
            <button
              on:click={() => showDeleteConfirm = true}
              class="px-4 py-2 bg-red-600 text-white rounded-md hover:bg-red-700 transition-colors"
            >
              删除密钥
            </button>
          </div>
        </div>
      {:else}
        <!-- 未配置密钥 -->
        <div class="text-center py-8">
          <svg class="w-12 h-12 text-gray-400 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"></path>
          </svg>
          <h3 class="text-lg font-medium text-gray-900 mb-2">开始添加密钥</h3>
          <p class="text-gray-600 mb-4">添加您的 Stripe 密钥以开始销售商品</p>
          <button
            on:click={() => showKeyForm = true}
            class="px-6 py-3 bg-blue-600 text-white rounded-md hover:bg-blue-700 transition-colors"
          >
            添加 Stripe 密钥
          </button>
        </div>
      {/if}
    </div>

    <!-- 基本信息设置 -->
    <div class="bg-white rounded-lg shadow p-6">
      <h2 class="text-lg font-semibold text-gray-900 mb-4">基本信息</h2>
      
      <div class="space-y-4">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">店铺名称</label>
          <input
            type="text"
            bind:value={settings.storeName}
            placeholder="输入您的店铺名称"
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>
        
        <div class="relative">
          <label class="block text-sm font-medium text-gray-700 mb-1">所在城市</label>
          <input
            type="text"
            bind:value={settings.city}
            on:input={handleCityInput}
            on:blur={handleCityBlur}
            placeholder="输入城市名称"
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
          
          {#if showCityDropdown && filteredCities.length > 0}
            <div class="absolute z-10 w-full mt-1 bg-white border border-gray-300 rounded-md shadow-lg max-h-60 overflow-y-auto">
              {#each filteredCities as city}
                <button
                  on:click={() => selectCity(city)}
                  class="w-full text-left px-3 py-2 hover:bg-gray-100 transition-colors"
                >
                  {city}
                </button>
              {/each}
            </div>
          {/if}
        </div>
        
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">通知邮箱</label>
          <input
            type="email"
            bind:value={settings.notificationEmail}
            placeholder="接收订单通知的邮箱"
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
          <p class="text-xs text-gray-500 mt-1">用于接收订单通知和重要消息</p>
        </div>
        
        <button
          on:click={saveBasicSettings}
          disabled={saving}
          class="px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
        >
          {saving ? '保存中...' : '保存设置'}
        </button>
      </div>
    </div>

    <!-- 账户状态 -->
    <div class="bg-white rounded-lg shadow p-6">
      <h2 class="text-lg font-semibold text-gray-900 mb-4">账户状态</h2>
      
      <div class="space-y-4">
        <div class="flex items-center justify-between p-4 bg-gray-50 rounded-lg">
          <div>
            <h3 class="font-medium text-gray-900">店铺状态</h3>
            <p class="text-sm text-gray-600">控制您的店铺是否对外展示</p>
          </div>
          <div class="flex items-center">
            <span class="mr-3 text-sm {settings.isActive ? 'text-green-600' : 'text-red-600'}">
              {settings.isActive ? '营业中' : '已暂停'}
            </span>
            <button
              class="relative inline-flex h-6 w-11 items-center rounded-full transition-colors {
                settings.isActive ? 'bg-green-600' : 'bg-gray-200'
              }"
              on:click={() => settings.isActive = !settings.isActive}
            >
              <span class="inline-block h-4 w-4 transform rounded-full bg-white transition-transform {
                settings.isActive ? 'translate-x-6' : 'translate-x-1'
              }"></span>
            </button>
          </div>
        </div>
        
        {#if settings.createdAt}
          <div class="text-sm text-gray-600">
            <p>注册时间：{new Date(settings.createdAt).toLocaleString('zh-CN')}</p>
            {#if settings.updatedAt}
              <p>最后更新：{new Date(settings.updatedAt).toLocaleString('zh-CN')}</p>
            {/if}
          </div>
        {/if}
      </div>
    </div>
  {/if}
</div>

<!-- 密钥设置弹窗 -->
{#if showKeyForm}
  <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
    <div class="bg-white rounded-lg p-6 max-w-md w-full mx-4">
      <div class="flex items-center justify-between mb-4">
        <h3 class="text-lg font-semibold text-gray-900">
          {settings.secretKey ? '更新' : '添加'} Stripe 密钥
        </h3>
        <button
          on:click={closeKeyForm}
          class="text-gray-400 hover:text-gray-600"
        >
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
          </svg>
        </button>
      </div>
      
      <div class="space-y-4">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Secret Key</label>
          <input
            type="password"
            bind:value={newKeys.secretKey}
            placeholder="sk_test_... 或 sk_live_..."
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>
        
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Publishable Key</label>
          <input
            type="text"
            bind:value={newKeys.publishableKey}
            placeholder="pk_test_... 或 pk_live_..."
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>
        
        <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-3">
          <div class="flex">
            <svg class="w-5 h-5 text-yellow-400 mr-2" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd"></path>
            </svg>
            <div class="text-sm text-yellow-800">
              <p class="font-medium">注意事项：</p>
              <ul class="mt-1 list-disc list-inside">
                <li>请确保密钥来自您的 Stripe 账户</li>
                <li>测试环境使用 test 密钥</li>
                <li>生产环境使用 live 密钥</li>
              </ul>
            </div>
          </div>
        </div>
        
        <div class="flex space-x-3">
          <button
            on:click={testConnection}
            disabled={testingConnection || !newKeys.secretKey || !newKeys.publishableKey}
            class="flex-1 px-4 py-2 bg-yellow-600 text-white rounded-md hover:bg-yellow-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
          >
            {testingConnection ? '测试中...' : '测试连接'}
          </button>
          <button
            on:click={saveKeys}
            disabled={saving || !newKeys.secretKey || !newKeys.publishableKey}
            class="flex-1 px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
          >
            {saving ? '保存中...' : '保存密钥'}
          </button>
        </div>
      </div>
    </div>
  </div>
{/if}

<!-- 删除确认弹窗 -->
{#if showDeleteConfirm}
  <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
    <div class="bg-white rounded-lg p-6 max-w-md w-full mx-4">
      <div class="flex items-center mb-4">
        <svg class="w-6 h-6 text-red-500 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L4.082 16.5c-.77.833.192 2.5 1.732 2.5z"></path>
        </svg>
        <h3 class="text-lg font-semibold text-gray-900">确认删除密钥</h3>
      </div>
      
      <p class="text-gray-600 mb-6">
        您确定要删除该商户的 Key 吗？删除后相关商品将无法被轮询同步。
      </p>
      
      <div class="flex space-x-3">
        <button
          on:click={() => showDeleteConfirm = false}
          class="flex-1 px-4 py-2 bg-gray-300 text-gray-700 rounded-md hover:bg-gray-400 transition-colors"
        >
          取消
        </button>
        <button
          on:click={deleteKeys}
          class="flex-1 px-4 py-2 bg-red-600 text-white rounded-md hover:bg-red-700 transition-colors"
        >
          确认删除
        </button>
      </div>
    </div>
  </div>
{/if}