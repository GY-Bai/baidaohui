<script lang="ts">
  import { onMount } from 'svelte';
  import { apiCall } from '$lib/auth';
  import type { UserSession } from '$lib/auth';

  export let session: UserSession;

  interface Merchant {
    _id: string;
    storeId: string;
    storeName: string;
    productCount: number;
    keysConfigured: boolean;
    secretKey?: string;
    publishableKey?: string;
    city?: string;
    notificationEmail?: string;
    createdAt: string;
    lastSyncAt?: string;
  }

  interface StripeKey {
    _id: string;
    storeId: string;
    secretKey: string;
    publishableKey: string;
    isActive: boolean;
    createdAt: string;
  }

  let merchants: Merchant[] = [];
  let loading = true;
  let showKeyModal = false;
  let selectedMerchant: Merchant | null = null;
  let keys: StripeKey[] = [];
  let showAddKeyForm = false;
  let testingConnection = false;

  // 新密钥表单
  let newKey = {
    secretKey: '',
    publishableKey: ''
  };

  // 邀请链接生成
  let showInviteModal = false;
  let generatingInvite = false;
  let inviteLink = '';

  onMount(() => {
    loadMerchants();
  });

  async function loadMerchants() {
    try {
      loading = true;
      const response = await apiCall('/ecommerce/merchants');
      merchants = response.merchants;
    } catch (error) {
      console.error('加载商户列表失败:', error);
      alert('加载商户列表失败，请重试');
    } finally {
      loading = false;
    }
  }

  async function openKeyManagement(merchant: Merchant) {
    selectedMerchant = merchant;
    showKeyModal = true;
    await loadKeys(merchant.storeId);
  }

  async function loadKeys(storeId: string) {
    try {
      const response = await apiCall(`/keys?storeId=${storeId}`);
      keys = response.keys;
    } catch (error) {
      console.error('加载密钥失败:', error);
      keys = [];
    }
  }

  function closeKeyModal() {
    showKeyModal = false;
    selectedMerchant = null;
    keys = [];
    showAddKeyForm = false;
    newKey = { secretKey: '', publishableKey: '' };
  }

  async function testConnection() {
    if (!newKey.secretKey || !newKey.publishableKey) {
      alert('请输入完整的密钥信息');
      return;
    }

    try {
      testingConnection = true;
      await apiCall('/keys/test', {
        method: 'POST',
        body: JSON.stringify({
          secretKey: newKey.secretKey,
          publishableKey: newKey.publishableKey
        })
      });
      alert('连接测试成功！');
    } catch (error) {
      console.error('连接测试失败:', error);
      alert('连接测试失败，请检查密钥是否正确');
    } finally {
      testingConnection = false;
    }
  }

  async function addKey() {
    if (!selectedMerchant || !newKey.secretKey || !newKey.publishableKey) {
      alert('请输入完整的密钥信息');
      return;
    }

    try {
      await apiCall('/keys', {
        method: 'POST',
        body: JSON.stringify({
          storeId: selectedMerchant.storeId,
          secretKey: newKey.secretKey,
          publishableKey: newKey.publishableKey
        })
      });

      alert('密钥添加成功');
      showAddKeyForm = false;
      newKey = { secretKey: '', publishableKey: '' };
      await loadKeys(selectedMerchant.storeId);
      await loadMerchants(); // 刷新商户列表状态
    } catch (error) {
      console.error('添加密钥失败:', error);
      alert('添加密钥失败，请重试');
    }
  }

  async function deleteKey(keyId: string) {
    if (!confirm('您确定要删除该商户的 Key 吗？删除后相关商品将无法被轮询同步。')) {
      return;
    }

    try {
      await apiCall(`/keys/${keyId}`, {
        method: 'DELETE'
      });

      alert('密钥删除成功');
      if (selectedMerchant) {
        await loadKeys(selectedMerchant.storeId);
        await loadMerchants(); // 刷新商户列表状态
      }
    } catch (error) {
      console.error('删除密钥失败:', error);
      alert('删除密钥失败，请重试');
    }
  }

  async function generateSellerInvite() {
    try {
      generatingInvite = true;
      const response = await apiCall('/invite/generate', {
        method: 'POST',
        body: JSON.stringify({
          type: 'seller',
          maxUses: 1
        })
      });
      
      inviteLink = response.url;
      showInviteModal = true;
    } catch (error) {
      console.error('生成邀请链接失败:', error);
      alert('生成邀请链接失败，请重试');
    } finally {
      generatingInvite = false;
    }
  }

  async function copyInviteLink() {
    try {
      await navigator.clipboard.writeText(inviteLink);
      alert('邀请链接已复制到剪贴板');
    } catch (error) {
      console.error('复制失败:', error);
      alert('复制失败，请手动复制');
    }
  }

  function downloadQRCode() {
    // 生成二维码并下载
    const qrCodeData = generateQRCodeDataURL(inviteLink);
    const link = document.createElement('a');
    link.download = 'seller-invite-qrcode.png';
    link.href = qrCodeData;
    link.click();
  }

  function generateQRCodeDataURL(text: string): string {
    // 简化版二维码生成，实际项目中应使用qrcode库
    return `data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" width="200" height="200"><rect width="200" height="200" fill="white"/><text x="100" y="100" text-anchor="middle" font-size="10" fill="black">QR Code for Seller Invite</text></svg>`;
  }

  async function exportCSV() {
    try {
      const csvContent = [
        ['商户ID', '商户名称', '商品数量', '密钥状态', '城市', '通知邮箱', '创建时间', '最后同步时间'],
        ...merchants.map(m => [
          m.storeId,
          m.storeName || '-',
          m.productCount.toString(),
          m.keysConfigured ? '已配置' : '未配置',
          m.city || '-',
          m.notificationEmail || '-',
          new Date(m.createdAt).toLocaleString('zh-CN'),
          m.lastSyncAt ? new Date(m.lastSyncAt).toLocaleString('zh-CN') : '-'
        ])
      ].map(row => row.join(',')).join('\n');

      const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
      const link = document.createElement('a');
      link.href = URL.createObjectURL(blob);
      link.download = `merchants-${new Date().toISOString().split('T')[0]}.csv`;
      link.click();
    } catch (error) {
      console.error('导出CSV失败:', error);
      alert('导出CSV失败，请重试');
    }
  }

  function maskSecretKey(key: string): string {
    if (!key) return '';
    return `****${key.slice(-6)}`;
  }

  function formatDate(dateString: string): string {
    return new Date(dateString).toLocaleString('zh-CN');
  }
</script>

<div class="space-y-6">
  <!-- 顶部操作栏 -->
  <div class="bg-white rounded-lg shadow p-6">
    <div class="flex items-center justify-between">
      <h2 class="text-lg font-semibold text-gray-900">电商管理</h2>
      <div class="flex space-x-3">
        <button
          on:click={generateSellerInvite}
          disabled={generatingInvite}
          class="px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
        >
          {generatingInvite ? '生成中...' : '生成 Seller 邀请链接'}
        </button>
        <button
          on:click={exportCSV}
          class="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 transition-colors"
        >
          导出 CSV
        </button>
        <button
          on:click={loadMerchants}
          class="px-4 py-2 bg-gray-300 text-gray-700 rounded-md hover:bg-gray-400 transition-colors"
        >
          刷新
        </button>
      </div>
    </div>
  </div>

  <!-- 商户列表 -->
  <div class="bg-white rounded-lg shadow">
    <div class="px-6 py-4 border-b border-gray-200">
      <h3 class="text-lg font-semibold text-gray-900">注册商户列表</h3>
    </div>

    {#if loading}
      <div class="p-8 text-center">
        <svg class="animate-spin h-8 w-8 text-blue-600 mx-auto mb-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 714 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
        <p class="text-gray-600">加载中...</p>
      </div>
    {:else if merchants.length === 0}
      <div class="p-8 text-center">
        <svg class="w-12 h-12 text-gray-400 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4"></path>
        </svg>
        <p class="text-gray-600">暂无注册商户</p>
      </div>
    {:else}
      <div class="overflow-x-auto">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">商户信息</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">商品数量</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">密钥状态</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">最后同步</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">操作</th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            {#each merchants as merchant}
              <tr class="hover:bg-gray-50">
                <td class="px-6 py-4 whitespace-nowrap">
                  <div>
                    <div class="text-sm font-medium text-gray-900">{merchant.storeName || merchant.storeId}</div>
                    <div class="text-sm text-gray-500">ID: {merchant.storeId}</div>
                    {#if merchant.city}
                      <div class="text-sm text-gray-500">📍 {merchant.city}</div>
                    {/if}
                  </div>
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <span class="text-sm font-medium text-gray-900">{merchant.productCount}</span>
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  {#if merchant.keysConfigured}
                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                      ✓ 已配置
                    </span>
                  {:else}
                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800">
                      × 未配置
                    </span>
                  {/if}
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  {merchant.lastSyncAt ? formatDate(merchant.lastSyncAt) : '从未同步'}
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
                  <button
                    on:click={() => openKeyManagement(merchant)}
                    class="text-blue-600 hover:text-blue-900"
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

<!-- 密钥管理弹窗 -->
{#if showKeyModal && selectedMerchant}
  <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
    <div class="bg-white rounded-lg p-6 max-w-2xl w-full mx-4 max-h-[90vh] overflow-y-auto">
      <div class="flex items-center justify-between mb-6">
        <h3 class="text-lg font-semibold text-gray-900">
          管理密钥 - {selectedMerchant.storeName || selectedMerchant.storeId}
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
      <div class="mb-6">
        <h4 class="text-md font-medium text-gray-900 mb-3">当前密钥</h4>
        {#if keys.length === 0}
          <div class="text-center py-4 bg-gray-50 rounded-lg">
            <p class="text-gray-500">暂无配置密钥</p>
          </div>
        {:else}
          <div class="space-y-3">
            {#each keys as key}
              <div class="border rounded-lg p-4">
                <div class="flex items-center justify-between">
                  <div class="flex-1">
                    <div class="text-sm">
                      <span class="font-medium text-gray-700">Secret Key:</span>
                      <span class="font-mono text-gray-900">{maskSecretKey(key.secretKey)}</span>
                      <button
                        class="ml-2 text-blue-600 hover:text-blue-800 text-xs"
                        on:click={() => {
                          const fullKey = key.secretKey;
                          navigator.clipboard.writeText(fullKey);
                          alert('完整密钥已复制到剪贴板');
                        }}
                      >
                        查看完整
                      </button>
                    </div>
                    <div class="text-sm mt-1">
                      <span class="font-medium text-gray-700">Publishable Key:</span>
                      <span class="font-mono text-gray-900">{key.publishableKey}</span>
                    </div>
                    <div class="text-xs text-gray-500 mt-2">
                      创建时间: {formatDate(key.createdAt)}
                    </div>
                  </div>
                  <button
                    on:click={() => deleteKey(key._id)}
                    class="ml-4 px-3 py-1 text-sm bg-red-100 text-red-700 rounded hover:bg-red-200 transition-colors"
                  >
                    删除
                  </button>
                </div>
              </div>
            {/each}
          </div>
        {/if}
      </div>

      <!-- 添加新密钥 -->
      <div class="border-t pt-6">
        <div class="flex items-center justify-between mb-4">
          <h4 class="text-md font-medium text-gray-900">添加新密钥</h4>
          <button
            on:click={() => showAddKeyForm = !showAddKeyForm}
            class="px-3 py-1 text-sm bg-blue-100 text-blue-700 rounded hover:bg-blue-200 transition-colors"
          >
            {showAddKeyForm ? '取消' : '添加密钥'}
          </button>
        </div>

        {#if showAddKeyForm}
          <div class="space-y-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Secret Key</label>
              <input
                type="password"
                bind:value={newKey.secretKey}
                placeholder="sk_test_..."
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>
            
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Publishable Key</label>
              <input
                type="text"
                bind:value={newKey.publishableKey}
                placeholder="pk_test_..."
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>
            
            <div class="flex space-x-3">
              <button
                on:click={testConnection}
                disabled={testingConnection || !newKey.secretKey || !newKey.publishableKey}
                class="px-4 py-2 bg-yellow-600 text-white rounded-md hover:bg-yellow-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
              >
                {testingConnection ? '测试中...' : '测试连接'}
              </button>
              <button
                on:click={addKey}
                disabled={!newKey.secretKey || !newKey.publishableKey}
                class="px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
              >
                保存密钥
              </button>
            </div>
          </div>
        {/if}
      </div>
    </div>
  </div>
{/if}

<!-- Seller邀请链接弹窗 -->
{#if showInviteModal}
  <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
    <div class="bg-white rounded-lg p-6 max-w-md w-full mx-4">
      <div class="flex items-center justify-between mb-4">
        <h3 class="text-lg font-semibold text-gray-900">Seller 邀请链接</h3>
        <button
          on:click={() => showInviteModal = false}
          class="text-gray-400 hover:text-gray-600"
        >
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
          </svg>
        </button>
      </div>
      
      <div class="text-center mb-4">
        <div class="w-32 h-32 mx-auto mb-4 border rounded-lg flex items-center justify-center bg-gray-50">
          <span class="text-gray-500 text-sm">二维码预览</span>
        </div>
      </div>
      
      <div class="bg-gray-50 rounded p-2 mb-4">
        <code class="text-sm text-gray-800 break-all">{inviteLink}</code>
      </div>
      
      <div class="flex space-x-3">
        <button
          on:click={copyInviteLink}
          class="flex-1 px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 transition-colors"
        >
          复制链接
        </button>
        <button
          on:click={downloadQRCode}
          class="flex-1 px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700 transition-colors"
        >
          下载二维码
        </button>
      </div>
    </div>
  </div>
{/if} 