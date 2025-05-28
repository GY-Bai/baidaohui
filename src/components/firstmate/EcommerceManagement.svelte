<!-- Firstmate的电商管理组件，只能查看不能修改密钥 -->
<script>
  import { onMount } from 'svelte';

  let stores = [];
  let loading = true;

  onMount(() => {
    loadStores();
  });

  async function loadStores() {
    try {
      loading = true;
      const response = await fetch('/api/ecommerce/stores?role=firstmate');
      if (response.ok) {
        stores = await response.json();
      }
    } catch (error) {
      console.error('加载商户失败:', error);
    } finally {
      loading = false;
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
      <div class="flex items-center space-x-2">
        <span class="px-2 py-1 text-xs bg-orange-100 text-orange-800 rounded-full">助理权限 - 仅查看</span>
        <button
          on:click={loadStores}
          class="px-4 py-2 bg-orange-600 text-white rounded-md hover:bg-orange-700 focus:outline-none focus:ring-2 focus:ring-orange-500"
        >
          🔄 刷新
        </button>
      </div>
    </div>

    <!-- 权限说明 -->
    <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-6">
      <div class="flex">
        <svg class="w-5 h-5 text-blue-400 mr-2" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd"></path>
        </svg>
        <div class="text-sm text-blue-800">
          <p class="font-medium">助理权限说明:</p>
          <p class="mt-1">作为助理，您只能查看商户信息和密钥状态，无法添加、修改或删除密钥。如需进行密钥操作，请联系 Master。</p>
        </div>
      </div>
    </div>

    <!-- 商户列表 -->
    {#if loading}
      <div class="text-center py-8">
        <svg class="animate-spin h-8 w-8 text-orange-600 mx-auto mb-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
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
                  <span class="text-gray-400">仅查看权限</span>
                </td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>
    {/if}

    <!-- 统计信息 -->
    {#if stores.length > 0}
      <div class="mt-6 grid grid-cols-1 md:grid-cols-3 gap-4">
        <div class="bg-gray-50 rounded-lg p-4">
          <div class="text-sm font-medium text-gray-500">总商户数</div>
          <div class="text-2xl font-bold text-gray-900">{stores.length}</div>
        </div>
        <div class="bg-gray-50 rounded-lg p-4">
          <div class="text-sm font-medium text-gray-500">已配置密钥</div>
          <div class="text-2xl font-bold text-green-600">{stores.filter(s => s.hasKeys).length}</div>
        </div>
        <div class="bg-gray-50 rounded-lg p-4">
          <div class="text-sm font-medium text-gray-500">总商品数</div>
          <div class="text-2xl font-bold text-blue-600">{stores.reduce((sum, s) => sum + (s.productCount || 0), 0)}</div>
        </div>
      </div>
    {/if}
  </div>
</div> 