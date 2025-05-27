<!-- Firstmate的邀请链接组件，与Master相同但有助理标识 -->
<script lang="ts">
  import QRCode from 'qrcode';

  let memberForm = {
    validHours: 24,
    maxUses: 1
  };

  let sellerForm = {
    maxUses: 1
  };

  let generatedLinks = [];
  let loading = false;
  let showQRModal = false;
  let qrCodeUrl = '';
  let selectedLink = null;

  async function generateMemberLink() {
    if (memberForm.validHours < 1 || memberForm.validHours > 48) {
      alert('有效期必须在1-48小时之间');
      return;
    }

    if (memberForm.maxUses < 1 || memberForm.maxUses > 100) {
      alert('使用次数必须在1-100次之间');
      return;
    }

    try {
      loading = true;
      const response = await fetch('/api/invite/generate', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          type: 'member',
          validHours: memberForm.validHours,
          maxUses: memberForm.maxUses,
          generatedBy: 'firstmate' // 标记为助理生成
        })
      });

      if (response.ok) {
        const data = await response.json();
        generatedLinks = [{
          ...data,
          type: 'Member',
          createdAt: new Date().toISOString(),
          expiresAt: new Date(Date.now() + memberForm.validHours * 60 * 60 * 1000).toISOString(),
          generatedBy: 'Firstmate'
        }, ...generatedLinks];
        
        // 重置表单
        memberForm = { validHours: 24, maxUses: 1 };
        alert('Member 邀请链接生成成功！');
        
        // 记录操作日志
        logOperation('invite_link', `生成 Member 邀请链接`);
      } else {
        const error = await response.json();
        alert(error.message || '生成失败，请重试');
      }
    } catch (error) {
      console.error('生成Member邀请链接失败:', error);
      alert('生成失败，请重试');
    } finally {
      loading = false;
    }
  }

  async function generateSellerLink() {
    try {
      loading = true;
      const response = await fetch('/api/invite/generate', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          type: 'seller',
          maxUses: 1,
          generatedBy: 'firstmate' // 标记为助理生成
        })
      });

      if (response.ok) {
        const data = await response.json();
        generatedLinks = [{
          ...data,
          type: 'Seller',
          createdAt: new Date().toISOString(),
          expiresAt: null,
          generatedBy: 'Firstmate'
        }, ...generatedLinks];
        
        alert('Seller 邀请链接生成成功！');
        
        // 记录操作日志
        logOperation('invite_link', `生成 Seller 邀请链接`);
      } else {
        const error = await response.json();
        alert(error.message || '生成失败，请重试');
      }
    } catch (error) {
      console.error('生成Seller邀请链接失败:', error);
      alert('生成失败，请重试');
    } finally {
      loading = false;
    }
  }

  async function logOperation(type, description) {
    try {
      await fetch('/api/firstmate/operation-logs', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          type,
          description,
          timestamp: new Date().toISOString()
        })
      });
    } catch (error) {
      console.error('记录操作日志失败:', error);
    }
  }

  function copyLink(url) {
    navigator.clipboard.writeText(url).then(() => {
      alert('链接已复制到剪贴板');
    });
  }

  async function showQRCode(link) {
    try {
      selectedLink = link;
      qrCodeUrl = await QRCode.toDataURL(link.url, {
        width: 256,
        margin: 2
      });
      showQRModal = true;
    } catch (error) {
      console.error('生成二维码失败:', error);
      alert('生成二维码失败');
    }
  }

  function downloadQRCode() {
    const link = document.createElement('a');
    link.download = `invite-qr-${selectedLink.type.toLowerCase()}.png`;
    link.href = qrCodeUrl;
    link.click();
  }

  function closeQRModal() {
    showQRModal = false;
    qrCodeUrl = '';
    selectedLink = null;
  }

  function formatTimeRemaining(expiresAt) {
    if (!expiresAt) return '永久有效';
    
    const now = new Date();
    const expires = new Date(expiresAt);
    const diff = expires.getTime() - now.getTime();
    
    if (diff <= 0) return '已过期';
    
    const hours = Math.floor(diff / (1000 * 60 * 60));
    const minutes = Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60));
    
    if (hours < 1) {
      return `${minutes}分钟`;
    }
    
    return `${hours}小时${minutes}分钟`;
  }

  function getTimeRemainingColor(expiresAt) {
    if (!expiresAt) return 'text-green-600';
    
    const now = new Date();
    const expires = new Date(expiresAt);
    const diff = expires.getTime() - now.getTime();
    const hours = diff / (1000 * 60 * 60);
    
    if (hours <= 0) return 'text-red-600';
    if (hours < 1) return 'text-red-600';
    if (hours < 6) return 'text-yellow-600';
    return 'text-green-600';
  }
</script>

<div class="space-y-6">
  <div class="bg-white rounded-lg shadow p-6">
    <div class="flex items-center justify-between mb-6">
      <h2 class="text-2xl font-semibold text-gray-900">邀请链接管理</h2>
      <div class="flex items-center space-x-2">
        <span class="px-2 py-1 text-xs bg-orange-100 text-orange-800 rounded-full">助理操作</span>
      </div>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
      <!-- Member 邀请链接生成 -->
      <div class="border rounded-lg p-4">
        <h3 class="text-lg font-medium text-gray-900 mb-4">助理生成 Member 邀请链接</h3>
        
        <div class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">
              有效期 (1-48小时)
            </label>
            <input
              type="number"
              bind:value={memberForm.validHours}
              min="1"
              max="48"
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-orange-500"
            />
            <p class="text-xs text-gray-500 mt-1">链接将在指定时间后自动失效</p>
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">
              可使用次数 (1-100)
            </label>
            <input
              type="number"
              bind:value={memberForm.maxUses}
              min="1"
              max="100"
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-orange-500"
            />
            <p class="text-xs text-gray-500 mt-1">达到使用次数后链接自动失效</p>
          </div>

          <button
            on:click={generateMemberLink}
            disabled={loading}
            class="w-full px-4 py-2 bg-orange-600 text-white rounded-md hover:bg-orange-700 focus:outline-none focus:ring-2 focus:ring-orange-500 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {loading ? '生成中...' : '助理生成链接'}
          </button>
        </div>
      </div>

      <!-- Seller 邀请链接生成 -->
      <div class="border rounded-lg p-4">
        <h3 class="text-lg font-medium text-gray-900 mb-4">助理生成 Seller 邀请链接</h3>
        
        <div class="space-y-4">
          <div class="bg-blue-50 border border-blue-200 rounded-lg p-3">
            <p class="text-sm text-blue-800">
              <strong>注意：</strong>该链接一旦生成，仅限1人使用且永久有效
            </p>
          </div>

          <button
            on:click={generateSellerLink}
            disabled={loading}
            class="w-full px-4 py-2 bg-orange-600 text-white rounded-md hover:bg-orange-700 focus:outline-none focus:ring-2 focus:ring-orange-500 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {loading ? '生成中...' : '助理生成链接'}
          </button>
        </div>
      </div>
    </div>

    <!-- 生成的链接列表 -->
    {#if generatedLinks.length > 0}
      <div class="mt-8">
        <h3 class="text-lg font-medium text-gray-900 mb-4">已生成的链接</h3>
        
        <div class="space-y-4">
          {#each generatedLinks as link}
            <div class="border rounded-lg p-4 bg-gray-50">
              <div class="flex items-center justify-between mb-3">
                <div class="flex items-center space-x-2">
                  <span class="px-2 py-1 text-xs bg-blue-100 text-blue-800 rounded-full">
                    {link.type}
                  </span>
                  <span class="px-2 py-1 text-xs bg-orange-100 text-orange-800 rounded-full">
                    {link.generatedBy}
                  </span>
                  <span class="text-sm {getTimeRemainingColor(link.expiresAt)}">
                    {formatTimeRemaining(link.expiresAt)}
                  </span>
                </div>
                <div class="text-xs text-gray-500">
                  {new Date(link.createdAt).toLocaleString('zh-CN')}
                </div>
              </div>

              <div class="bg-white rounded border p-3 mb-3">
                <code class="text-sm text-gray-800 break-all">{link.url}</code>
              </div>

              <div class="flex space-x-2">
                <button
                  on:click={() => copyLink(link.url)}
                  class="px-3 py-1 text-sm bg-blue-600 text-white rounded hover:bg-blue-700"
                >
                  复制链接
                </button>
                <button
                  on:click={() => showQRCode(link)}
                  class="px-3 py-1 text-sm bg-green-600 text-white rounded hover:bg-green-700"
                >
                  生成二维码
                </button>
              </div>
            </div>
          {/each}
        </div>
      </div>
    {/if}
  </div>
</div>

<!-- 二维码模态框 -->
{#if showQRModal && selectedLink}
  <div class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50" on:click={closeQRModal}>
    <div class="relative top-20 mx-auto p-5 border w-96 shadow-lg rounded-md bg-white" on:click|stopPropagation>
      <div class="mt-3 text-center">
        <div class="flex items-center justify-between mb-4">
          <h3 class="text-lg font-medium text-gray-900">{selectedLink.type} 邀请二维码</h3>
          {#if selectedLink.expiresAt}
            <span class="text-sm {getTimeRemainingColor(selectedLink.expiresAt)}">
              {formatTimeRemaining(selectedLink.expiresAt)}
            </span>
          {/if}
        </div>
        
        <div class="mb-4">
          <img src={qrCodeUrl} alt="邀请二维码" class="mx-auto" />
        </div>
        
        <div class="flex space-x-3">
          <button
            on:click={downloadQRCode}
            class="flex-1 px-4 py-2 bg-green-600 text-white text-sm font-medium rounded-md hover:bg-green-700"
          >
            下载二维码
          </button>
          <button
            on:click={closeQRModal}
            class="flex-1 px-4 py-2 bg-gray-300 text-gray-700 text-sm font-medium rounded-md hover:bg-gray-400"
          >
            关闭
          </button>
        </div>
      </div>
    </div>
  </div>
{/if} 