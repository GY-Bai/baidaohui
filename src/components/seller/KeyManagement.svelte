<script>
  import { onMount } from 'svelte';
  
  let keys = [];
  let loading = false;
  let showAddModal = false;
  let keyForm = {
    keyValue: '',
    keyType: 'stripe_secret',
    storeId: ''
  };
  let showFullKey = {};
  let testingKey = {};
  
  onMount(() => {
    loadKeys();
  });
  
  async function loadKeys() {
    try {
      loading = true;
      const response = await fetch('/api/keys', {
        credentials: 'include'
      });
      
      if (response.ok) {
        const result = await response.json();
        keys = result.data.filter(key => key.userRole === 'seller');
      } else {
        console.error('加载密钥失败');
      }
    } catch (error) {
      console.error('加载密钥失败:', error);
    } finally {
      loading = false;
    }
  }
  
  function openAddModal() {
    keyForm = {
      keyValue: '',
      keyType: 'stripe_secret',
      storeId: ''
    };
    showAddModal = true;
  }
  
  async function addKey() {
    try {
      if (!keyForm.keyValue.trim() || !keyForm.storeId.trim()) {
        alert('请填写完整信息');
        return;
      }
      
      const response = await fetch('/api/keys', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        credentials: 'include',
        body: JSON.stringify(keyForm)
      });
      
      const result = await response.json();
      
      if (result.success) {
        showAddModal = false;
        await loadKeys();
        alert('密钥添加成功！');
      } else {
        alert(result.error || '添加失败');
      }
    } catch (error) {
      console.error('添加密钥失败:', error);
      alert('添加失败');
    }
  }
  
  async function deleteKey(keyId) {
    if (!confirm('确定要删除该密钥吗？删除后相关商品将无法被同步。')) {
      return;
    }
    
    try {
      const response = await fetch(`/api/keys/${keyId}`, {
        method: 'DELETE',
        credentials: 'include'
      });
      
      const result = await response.json();
      
      if (result.success) {
        await loadKeys();
        alert('密钥删除成功');
      } else {
        alert(result.error || '删除失败');
      }
    } catch (error) {
      console.error('删除密钥失败:', error);
      alert('删除失败');
    }
  }
  
  async function testKey(keyId) {
    try {
      testingKey[keyId] = true;
      testingKey = { ...testingKey };
      
      const response = await fetch(`/api/keys/${keyId}/test`, {
        method: 'POST',
        credentials: 'include'
      });
      
      const result = await response.json();
      
      if (result.success) {
        alert('密钥连接测试成功！');
      } else {
        alert(result.error || '测试失败');
      }
    } catch (error) {
      console.error('测试密钥失败:', error);
      alert('测试失败');
    } finally {
      testingKey[keyId] = false;
      testingKey = { ...testingKey };
    }
  }
  
  function toggleKeyVisibility(keyId) {
    showFullKey[keyId] = !showFullKey[keyId];
    showFullKey = { ...showFullKey };
    
    // 3秒后自动隐藏
    if (showFullKey[keyId]) {
      setTimeout(() => {
        showFullKey[keyId] = false;
        showFullKey = { ...showFullKey };
      }, 3000);
    }
  }
  
  function validateStripeKey(keyValue, keyType) {
    if (keyType === 'stripe_secret') {
      return keyValue.startsWith('sk_test_') || keyValue.startsWith('sk_live_');
    } else if (keyType === 'stripe_publishable') {
      return keyValue.startsWith('pk_test_') || keyValue.startsWith('pk_live_');
    }
    return false;
  }
  
  function getKeyTypeDisplay(keyType) {
    return keyType === 'stripe_secret' ? 'Secret Key' : 'Publishable Key';
  }
  
  function getStatusColor(isActive, isListed) {
    if (!isActive) return 'bg-red-100 text-red-800';
    if (!isListed) return 'bg-yellow-100 text-yellow-800';
    return 'bg-green-100 text-green-800';
  }
  
  function getStatusText(isActive, isListed) {
    if (!isActive) return '未激活';
    if (!isListed) return '已下架';
    return '已上架';
  }
</script>

<div class="max-w-4xl mx-auto p-6">
  <div class="bg-white rounded-lg shadow">
    <div class="px-6 py-4 border-b border-gray-200">
      <div class="flex justify-between items-center">
        <div>
          <h2 class="text-xl font-semibold text-gray-900">Stripe 密钥管理</h2>
          <p class="text-sm text-gray-600 mt-1">管理您的 Stripe 密钥以启用电商功能</p>
        </div>
        <button
          on:click={openAddModal}
          class="bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700 transition-colors"
        >
          添加密钥
        </button>
      </div>
    </div>
    
    <div class="p-6">
      {#if loading}
        <div class="text-center py-8">
          <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
          <p class="mt-2 text-gray-600">加载中...</p>
        </div>
      {:else if keys.length === 0}
        <div class="text-center py-12">
          <div class="mx-auto h-12 w-12 text-gray-400">
            <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 7a2 2 0 012 2m4 0a6 6 0 01-7.743 5.743L11 17H9v2H7v2H4a1 1 0 01-1-1v-2.586a1 1 0 01.293-.707l5.964-5.964A6 6 0 1121 9z" />
            </svg>
          </div>
          <h3 class="mt-2 text-sm font-medium text-gray-900">暂无密钥</h3>
          <p class="mt-1 text-sm text-gray-500">开始添加您的第一个 Stripe 密钥</p>
          <div class="mt-6">
            <button
              on:click={openAddModal}
              class="inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700"
            >
              添加密钥
            </button>
          </div>
        </div>
      {:else}
        <div class="space-y-4">
          {#each keys as key}
            <div class="border border-gray-200 rounded-lg p-4 hover:shadow-md transition-shadow">
              <div class="flex justify-between items-start">
                <div class="flex-1">
                  <div class="flex items-center space-x-3">
                    <h3 class="text-lg font-medium text-gray-900">
                      {getKeyTypeDisplay(key.keyType)}
                    </h3>
                    <span class="inline-flex px-2 py-1 text-xs font-semibold rounded-full {getStatusColor(key.isActive, key.isListed)}">
                      {getStatusText(key.isActive, key.isListed)}
                    </span>
                  </div>
                  
                  <div class="mt-2">
                    <div class="text-sm text-gray-600">
                      <span class="font-medium">Store ID:</span> {key.storeId}
                    </div>
                    <div class="text-sm text-gray-600 mt-1">
                      <span class="font-medium">密钥值:</span>
                      {#if showFullKey[key.id]}
                        <span class="font-mono bg-gray-100 px-2 py-1 rounded ml-2">{key.keyValue || '无法显示完整密钥'}</span>
                      {:else}
                        <span class="font-mono ml-2">{key.maskedKey}</span>
                      {/if}
                      <button
                        on:click={() => toggleKeyVisibility(key.id)}
                        class="ml-2 text-blue-600 hover:text-blue-800 text-sm"
                      >
                        {showFullKey[key.id] ? '隐藏' : '查看'}
                      </button>
                    </div>
                    <div class="text-xs text-gray-500 mt-2">
                      创建时间: {new Date(key.createdAt).toLocaleString()}
                      {#if key.lastUsed}
                        | 最后使用: {new Date(key.lastUsed).toLocaleString()}
                      {/if}
                    </div>
                  </div>
                </div>
                
                <div class="flex space-x-2 ml-4">
                  <button
                    on:click={() => testKey(key.id)}
                    disabled={testingKey[key.id]}
                    class="bg-green-600 text-white px-3 py-1 rounded text-sm hover:bg-green-700 transition-colors disabled:opacity-50"
                  >
                    {testingKey[key.id] ? '测试中...' : '测试连接'}
                  </button>
                  <button
                    on:click={() => deleteKey(key.id)}
                    class="bg-red-600 text-white px-3 py-1 rounded text-sm hover:bg-red-700 transition-colors"
                  >
                    删除
                  </button>
                </div>
              </div>
              
              {#if !key.isListed}
                <div class="mt-3 p-3 bg-yellow-50 border border-yellow-200 rounded-md">
                  <div class="flex">
                    <div class="flex-shrink-0">
                      <svg class="h-5 w-5 text-yellow-400" fill="currentColor" viewBox="0 0 20 20">
                        <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
                      </svg>
                    </div>
                    <div class="ml-3">
                      <p class="text-sm text-yellow-800">
                        该密钥已被管理员下架，相关商品暂时不会在电商页面显示。
                      </p>
                    </div>
                  </div>
                </div>
              {/if}
            </div>
          {/each}
        </div>
      {/if}
    </div>
  </div>
</div>

<!-- 添加密钥模态框 -->
{#if showAddModal}
  <div class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50">
    <div class="relative top-20 mx-auto p-5 border w-96 shadow-lg rounded-md bg-white">
      <div class="mt-3">
        <h3 class="text-lg font-medium text-gray-900 mb-4">添加 Stripe 密钥</h3>
        
        <form on:submit|preventDefault={addKey} class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700">Store ID</label>
            <input
              type="text"
              bind:value={keyForm.storeId}
              required
              class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-blue-500 focus:border-blue-500"
              placeholder="输入您的 Store ID"
            />
            <p class="mt-1 text-xs text-gray-500">
              用于标识您的商店，建议使用有意义的名称
            </p>
          </div>
          
          <div>
            <label class="block text-sm font-medium text-gray-700">密钥类型</label>
            <select
              bind:value={keyForm.keyType}
              class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-blue-500 focus:border-blue-500"
            >
              <option value="stripe_secret">Secret Key (sk_...)</option>
              <option value="stripe_publishable">Publishable Key (pk_...)</option>
            </select>
          </div>
          
          <div>
            <label class="block text-sm font-medium text-gray-700">密钥值</label>
            <textarea
              bind:value={keyForm.keyValue}
              required
              rows="3"
              class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-blue-500 focus:border-blue-500"
              placeholder="输入您的 Stripe 密钥"
            ></textarea>
            <p class="mt-1 text-xs text-gray-500">
              请从 Stripe Dashboard 复制完整的密钥
            </p>
            
            {#if keyForm.keyValue && !validateStripeKey(keyForm.keyValue, keyForm.keyType)}
              <p class="mt-1 text-xs text-red-600">
                密钥格式不正确，请检查密钥类型和值是否匹配
              </p>
            {/if}
          </div>
          
          <div class="bg-blue-50 border border-blue-200 rounded-md p-3">
            <div class="flex">
              <div class="flex-shrink-0">
                <svg class="h-5 w-5 text-blue-400" fill="currentColor" viewBox="0 0 20 20">
                  <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd" />
                </svg>
              </div>
              <div class="ml-3">
                <p class="text-sm text-blue-800">
                  <strong>提示：</strong>您需要在 Stripe Dashboard 中创建 Payment Links 来销售商品。
                  系统会自动同步您的商品和支付链接。
                </p>
              </div>
            </div>
          </div>
          
          <div class="flex justify-end space-x-2 pt-4">
            <button
              type="button"
              on:click={() => showAddModal = false}
              class="px-4 py-2 text-sm font-medium text-gray-700 bg-gray-200 rounded-md hover:bg-gray-300"
            >
              取消
            </button>
            <button
              type="submit"
              disabled={!keyForm.keyValue || !keyForm.storeId || !validateStripeKey(keyForm.keyValue, keyForm.keyType)}
              class="px-4 py-2 text-sm font-medium text-white bg-blue-600 rounded-md hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              保存密钥
            </button>
          </div>
        </form>
      </div>
    </div>
  </div>
{/if} 