<script lang="ts">
  import { onMount } from 'svelte';

  let stores = [];
  let loading = true;
  let showKeyModal = false;
  let selectedStore = null;
  let newKey = {
    secretKey: '',
    publishableKey: ''
  };
  let testingConnection = false;
  let showSecretKey = false;
  let secretKeyTimeout = null;

  onMount(() => {
    loadStores();
  });

  async function loadStores() {
    try {
      loading = true;
      const response = await fetch('/api/ecommerce/stores');
      if (response.ok) {
        stores = await response.json();
      }
    } catch (error) {
      console.error('加载商户失败:', error);
    } finally {
      loading = false;
    }
  }

  function openKeyModal(store) {
    selectedStore = store;
    showKeyModal = true;
    newKey = { secretKey: '', publishableKey: '' };
  }

  function closeKeyModal() {
    showKeyModal = false;
    selectedStore = null;
    newKey = { secretKey: '', publishableKey: '' };
    showSecretKey = false;
    if (secretKeyTimeout) {
      clearTimeout(secretKeyTimeout);
      secretKeyTimeout = null;
    }
  }

  async function testConnection() {
    if (!newKey.secretKey.trim()) {
      alert('请输入Secret Key');
      return;
    }

    try {
      testingConnection = true;
      const response = await fetch('/api/keys/test', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          secretKey: newKey.secretKey.trim(),
          storeId: selectedStore.id
        })
      });

      if (response.ok) {
        alert('连接成功！密钥有效');
      } else {
        const error = await response.json();
        alert(`连接失败: ${error.message || '密钥无效'}`);
      }
    } catch (error) {
      console.error('测试连接失败:', error);
      alert('测试连接失败，请重试');
    } finally {
      testingConnection = false;
    }
  }

  async function saveKey() {
    if (!newKey.secretKey.trim() || !newKey.publishableKey.trim()) {
      alert('请填写完整的密钥信息');
      return;
    }

    try {
      const response = await fetch('/api/keys', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          storeId: selectedStore.id,
          secretKey: newKey.secretKey.trim(),
          publishableKey: newKey.publishableKey.trim()
        })
      });

      if (response.ok) {
        alert('密钥保存成功');
        closeKeyModal();
        loadStores(); // 刷新列表
      } else {
        const error = await response.json();
        alert(error.message || '保存失败');
      }
    } catch (error) {
      console.error('保存密钥失败:', error);
      alert('保存失败，请重试');
    }
  }

  async function deleteKey(storeId, keyId) {
    if (!confirm('您确定要删除该商户的 Key 吗？删除后相关商品将无法被轮询同步。')) {
      return;
    }

    try {
      const response = await fetch(`/api/keys/${keyId}`, {
        method: 'DELETE'
      });

      if (response.ok) {
        alert('密钥删除成功');
        loadStores(); // 刷新列表
      } else {
        const error = await response.json();
        alert(error.message || '删除失败');
      }
    } catch (error) {
      console.error('删除密钥失败:', error);
      alert('删除失败，请重试');
    }
  }

  function toggleSecretKeyVisibility(key) {
    showSecretKey = !showSecretKey;
    
    if (showSecretKey) {
      // 3秒后自动隐藏
      secretKeyTimeout = setTimeout(() => {
        showSecretKey = false;
      }, 3000);
    } else if (secretKeyTimeout) {
      clearTimeout(secretKeyTimeout);
      secretKeyTimeout = null;
    }
  }

  function maskSecretKey(key) {
    if (!key) return '';
    const prefix = key.substring(0, 7); // sk_test 或 sk_live
    const suffix = key.substring(key.length - 4);
    return `${prefix}****${suffix}`;
  }

  async function exportCSV() {
    try {
      const response = await fetch('/api/ecommerce/stores/export');
      if (response.ok) {
        const blob = await response.blob();
        const url = window.URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `stores-${new Date().toISOString().split('T')[0]}.csv`;
        a.click();
        window.URL.revokeObjectURL(url);
      } else {
        alert('导出失败');
      }
    } catch (error) {
      console.error('导出CSV失败:', error);
      alert('导出失败');
    }
  }

  function getKeyStatusText(hasKeys) {
    return hasKeys ? '已配置' : '未配置';
  }

  function getKeyStatusColor(hasKeys) {
    return hasKeys ? 'text-green-600' : 'text-red-600';
  }

  function getKeyStatusIcon(hasKeys) {
    return hasKeys ? '✓' : '×';
  }
</script>

<div class="space-y-6">
  <div class="bg-white rounded-lg shadow p-6">
    <div class="flex justify-between items-center mb-6">
      <h2 class="text-2xl font-semibold text-gray-900">电商管理</h2>
      <div class="flex space-x-3">
        <button
          on:click={exportCSV}
          class="px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-green-500"
        >
          📊 导出 CSV
        </button>
        <button
          on:click={loadStores}
          class="px-4 py-2 bg-purple-600 text-white rounded-md hover:bg-purple-700 focus:outline-none focus:ring-2 focus:ring-purple-500"
        >
          🔄 刷新
        </button>
      </div>
    </div>

    <!-- 商户列表 -->
    {#if loading}
      <div class="text-center py-8">
        <svg class="animate-spin h-8 w-8 text-purple-600 mx-auto mb-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 714 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
        <p class="text-gray-600">加载中...</p>
      </div>
    {:else if stores.length === 0}
      <div class="text-center py-8">
        <svg class="w-16 h-16 text-gray-400 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 11V7a4 4 0 00-8 0v4M5 9h14l1 12H4L5 9z"></path>
        </svg>
        <p class="text-gray-600">暂无商户</p>
      </div>
    {:else}
      <div class="overflow-x-auto">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Store ID</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">商户名称</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">商品总数</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">密钥状态</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">最后同步</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">操作</th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            {#each stores as store}
              <tr class="hover:bg-gray-50">
                <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                  {store.id}
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  {store.name || '未设置'}
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  {store.productCount || 0}
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <span class="flex items-center {getKeyStatusColor(store.hasKeys)}">
                    <span class="mr-1">{getKeyStatusIcon(store.hasKeys)}</span>
                    {getKeyStatusText(store.hasKeys)}
                  </span>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  {store.lastSyncAt ? new Date(store.lastSyncAt).toLocaleString('zh-CN') : '从未同步'}
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
                  <button
                    on:click={() => openKeyModal(store)}
                    class="text-purple-600 hover:text-purple-900"
                  >
                    管理密钥
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

<!-- 密钥管理模态框 -->
{#if showKeyModal && selectedStore}
  <div class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50">
    <div class="relative top-20 mx-auto p-5 border w-full max-w-2xl shadow-lg rounded-md bg-white">
      <div class="mt-3">
        <div class="flex justify-between items-center mb-4">
          <h3 class="text-lg font-medium text-gray-900">
            管理密钥 - {selectedStore.name || selectedStore.id}
          </h3>
          <button
            on:click={closeKeyModal}
            class="text-gray-400 hover:text-gray-600"
          >
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
            </svg>
          </button>
        </div>

        <!-- 当前密钥列表 -->
        {#if selectedStore.keys && selectedStore.keys.length > 0}
          <div class="mb-6">
            <h4 class="font-medium text-gray-900 mb-3">当前密钥</h4>
            <div class="space-y-3">
              {#each selectedStore.keys as key}
                <div class="bg-gray-50 rounded-lg p-4">
                  <div class="flex justify-between items-start">
                    <div class="flex-1">
                      <div class="flex items-center space-x-2 mb-2">
                        <span class="text-sm font-medium text-gray-700">Secret Key:</span>
                        <span class="text-sm font-mono text-gray-900">
                          {showSecretKey ? key.secretKey : maskSecretKey(key.secretKey)}
                        </span>
                        <button
                          on:click={() => toggleSecretKeyVisibility(key)}
                          class="text-blue-600 hover:text-blue-800 text-sm"
                        >
                          {showSecretKey ? '隐藏' : '查看'}
                        </button>
                      </div>
                      <div class="flex items-center space-x-2">
                        <span class="text-sm font-medium text-gray-700">Publishable Key:</span>
                        <span class="text-sm font-mono text-gray-900">{key.publishableKey}</span>
                      </div>
                      <div class="mt-2 text-xs text-gray-500">
                        创建时间: {new Date(key.createdAt).toLocaleString('zh-CN')}
                      </div>
                    </div>
                    <button
                      on:click={() => deleteKey(selectedStore.id, key.id)}
                      class="ml-4 text-red-600 hover:text-red-800 text-sm"
                    >
                      删除
                    </button>
                  </div>
                </div>
              {/each}
            </div>
          </div>
        {/if}

        <!-- 添加新密钥表单 -->
        <div>
          <h4 class="font-medium text-gray-900 mb-3">添加新密钥</h4>
          
          <div class="space-y-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">
                Secret Key
              </label>
              <input
                type="password"
                bind:value={newKey.secretKey}
                placeholder="sk_test_... 或 sk_live_..."
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-purple-500"
              />
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">
                Publishable Key
              </label>
              <input
                type="text"
                bind:value={newKey.publishableKey}
                placeholder="pk_test_... 或 pk_live_..."
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-purple-500"
              />
            </div>

            <div class="flex space-x-3">
              <button
                on:click={testConnection}
                disabled={testingConnection || !newKey.secretKey.trim()}
                class="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {testingConnection ? '测试中...' : '测试连接'}
              </button>
              <button
                on:click={saveKey}
                disabled={!newKey.secretKey.trim() || !newKey.publishableKey.trim()}
                class="px-4 py-2 bg-purple-600 text-white rounded-md hover:bg-purple-700 focus:outline-none focus:ring-2 focus:ring-purple-500 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                保存密钥
              </button>
              <button
                on:click={closeKeyModal}
                class="px-4 py-2 bg-gray-300 text-gray-700 rounded-md hover:bg-gray-400 focus:outline-none focus:ring-2 focus:ring-gray-500"
              >
                取消
              </button>
            </div>
          </div>

          <div class="mt-4 p-3 bg-yellow-50 border border-yellow-200 rounded-lg">
            <div class="flex">
              <svg class="w-5 h-5 text-yellow-400 mr-2" fill="currentColor" viewBox="0 0 20 20">
                <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd"></path>
              </svg>
              <div class="text-sm text-yellow-800">
                <p class="font-medium">注意事项:</p>
                <ul class="mt-1 list-disc list-inside">
                  <li>请确保密钥来自正确的 Stripe 账户</li>
                  <li>测试环境使用 test 密钥，生产环境使用 live 密钥</li>
                  <li>密钥将被安全存储，Secret Key 会被加密保护</li>
                </ul>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
{/if} 