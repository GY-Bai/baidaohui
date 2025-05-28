<script lang="ts">
  import { apiCall } from '$lib/auth';
  import type { UserSession } from '$lib/auth';
  import QRCode from 'qrcode';

  export let session: UserSession;

  let memberForm = {
    validHours: 24,
    maxUses: 10
  };

  let sellerForm = {
    maxUses: 1
  };

  let generatedLinks: Array<{
    type: 'member' | 'seller';
    token: string;
    url: string;
    expiresAt?: string;
    maxUses: number;
    usedCount: number;
    createdAt: string;
  }> = [];

  let loading = false;
  let showQRCode = false;
  let qrCodeUrl = '';
  let qrCodeData = '';
  let countdown = '';

  // 生成Member邀请链接
  async function generateMemberLink() {
    if (memberForm.validHours < 1 || memberForm.validHours > 48) {
      alert('有效期必须在1-48小时之间');
      return;
    }

    if (memberForm.maxUses < 1 || memberForm.maxUses > 100) {
      alert('使用次数必须在1-100之间');
      return;
    }

    try {
      loading = true;
      const result = await apiCall('/invite/generate', {
        method: 'POST',
        body: JSON.stringify({
          type: 'member',
          validHours: memberForm.validHours,
          maxUses: memberForm.maxUses
        })
      });

      generatedLinks = [result, ...generatedLinks];
      
      // 重置表单
      memberForm = { validHours: 24, maxUses: 10 };
      
      alert('Member邀请链接生成成功！');
    } catch (error) {
      console.error('生成邀请链接失败:', error);
      alert('生成邀请链接失败，请重试');
    } finally {
      loading = false;
    }
  }

  // 生成Seller邀请链接
  async function generateSellerLink() {
    try {
      loading = true;
      const result = await apiCall('/invite/generate', {
        method: 'POST',
        body: JSON.stringify({
          type: 'seller',
          maxUses: 1
        })
      });

      generatedLinks = [result, ...generatedLinks];
      
      alert('Seller邀请链接生成成功！');
    } catch (error) {
      console.error('生成邀请链接失败:', error);
      alert('生成邀请链接失败，请重试');
    } finally {
      loading = false;
    }
  }

  // 复制链接到剪贴板
  async function copyToClipboard(url: string) {
    try {
      await navigator.clipboard.writeText(url);
      alert('链接已复制到剪贴板');
    } catch (error) {
      console.error('复制失败:', error);
      alert('复制失败，请手动复制');
    }
  }

  // 生成二维码数据URL
  async function generateQRCodeDataURL(text: string): Promise<string> {
    try {
      return await QRCode.toDataURL(text, {
        width: 200,
        margin: 2,
        color: {
          dark: '#000000',
          light: '#FFFFFF'
        }
      });
    } catch (error) {
      console.error('生成二维码失败:', error);
      // 返回一个错误占位符
      return `data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" width="200" height="200"><rect width="200" height="200" fill="white"/><text x="100" y="100" text-anchor="middle" font-size="12" fill="red">二维码生成失败</text></svg>`;
    }
  }

  // 显示二维码
  async function showQRCodeModal(url: string) {
    qrCodeUrl = url;
    qrCodeData = await generateQRCodeDataURL(url);
    showQRCode = true;
    
    // 如果是Member链接，启动倒计时
    const link = generatedLinks.find(l => l.url === url);
    if (link && link.type === 'member' && link.expiresAt) {
      startCountdown(link.expiresAt);
    }
  }

  // 下载二维码
  function downloadQRCode() {
    const link = document.createElement('a');
    link.download = 'invite-qrcode.png';
    link.href = qrCodeData;
    link.click();
  }

  // 启动倒计时
  function startCountdown(expiresAt: string) {
    const updateCountdown = () => {
      const now = new Date().getTime();
      const expiry = new Date(expiresAt).getTime();
      const distance = expiry - now;

      if (distance < 0) {
        countdown = '已过期';
        return;
      }

      const hours = Math.floor(distance / (1000 * 60 * 60));
      const minutes = Math.floor((distance % (1000 * 60 * 60)) / (1000 * 60));
      
      if (hours < 1) {
        countdown = `即将过期：${minutes}分钟`;
      } else {
        countdown = `剩余：${hours}小时${minutes}分钟`;
      }
    };

    updateCountdown();
    const interval = setInterval(updateCountdown, 60000); // 每分钟更新

    // 清理定时器
    setTimeout(() => clearInterval(interval), 24 * 60 * 60 * 1000);
  }

  // 格式化时间
  function formatDateTime(dateString: string): string {
    return new Date(dateString).toLocaleString('zh-CN');
  }

  // 获取链接状态
  function getLinkStatus(link: any): { text: string; color: string } {
    if (link.type === 'member' && link.expiresAt) {
      const now = new Date().getTime();
      const expiry = new Date(link.expiresAt).getTime();
      if (now > expiry) {
        return { text: '已过期', color: 'text-red-600' };
      }
      if (expiry - now < 60 * 60 * 1000) { // 小于1小时
        return { text: '即将过期', color: 'text-orange-600' };
      }
    }
    
    if (link.usedCount >= link.maxUses) {
      return { text: '已用完', color: 'text-gray-600' };
    }
    
    return { text: '有效', color: 'text-green-600' };
  }
</script>

<div class="space-y-6">
  <div class="bg-white rounded-lg shadow p-6">
    <h2 class="text-lg font-semibold text-gray-900 mb-6">邀请链接管理</h2>
    
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
      <!-- Member邀请链接生成 -->
      <div class="border rounded-lg p-4">
        <h3 class="text-md font-medium text-gray-900 mb-4">生成 Member 邀请链接</h3>
        
        <div class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">
              有效期（小时）
            </label>
            <input
              type="number"
              bind:value={memberForm.validHours}
              min="1"
              max="48"
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              placeholder="1-48小时"
            />
            <p class="text-xs text-gray-500 mt-1">链接有效期，1-48小时</p>
          </div>
          
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">
              可使用次数
            </label>
            <input
              type="number"
              bind:value={memberForm.maxUses}
              min="1"
              max="100"
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              placeholder="1-100次"
            />
            <p class="text-xs text-gray-500 mt-1">链接可使用次数，1-100次</p>
          </div>
          
          <button
            on:click={generateMemberLink}
            disabled={loading}
            class="w-full px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
          >
            {loading ? '生成中...' : '生成 Member 链接'}
          </button>
        </div>
      </div>
      
      <!-- Seller邀请链接生成 -->
      <div class="border rounded-lg p-4">
        <h3 class="text-md font-medium text-gray-900 mb-4">生成 Seller 邀请链接</h3>
        
        <div class="space-y-4">
          <div class="bg-yellow-50 border border-yellow-200 rounded-md p-3">
            <p class="text-sm text-yellow-800">
              <strong>注意：</strong>该链接一旦生成，仅限1人使用且永久有效
            </p>
          </div>
          
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">
              可使用人数
            </label>
            <input
              type="number"
              value={sellerForm.maxUses}
              disabled
              class="w-full px-3 py-2 border border-gray-300 rounded-md bg-gray-50 text-gray-500"
            />
            <p class="text-xs text-gray-500 mt-1">固定为1人使用</p>
          </div>
          
          <button
            on:click={generateSellerLink}
            disabled={loading}
            class="w-full px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-green-500 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
          >
            {loading ? '生成中...' : '生成 Seller 链接'}
          </button>
        </div>
      </div>
    </div>
  </div>

  <!-- 已生成的链接列表 -->
  {#if generatedLinks.length > 0}
    <div class="bg-white rounded-lg shadow p-6">
      <h3 class="text-lg font-semibold text-gray-900 mb-4">已生成的邀请链接</h3>
      
      <div class="space-y-4">
        {#each generatedLinks as link}
          {@const status = getLinkStatus(link)}
          <div class="border rounded-lg p-4">
            <div class="flex items-center justify-between mb-2">
              <div class="flex items-center space-x-2">
                <span class="px-2 py-1 text-xs rounded-full {
                  link.type === 'member' ? 'bg-blue-100 text-blue-800' : 'bg-green-100 text-green-800'
                }">
                  {link.type === 'member' ? 'Member' : 'Seller'}
                </span>
                <span class="text-sm {status.color} font-medium">
                  {status.text}
                </span>
              </div>
              <span class="text-xs text-gray-500">
                {formatDateTime(link.createdAt)}
              </span>
            </div>
            
            <div class="bg-gray-50 rounded p-2 mb-3">
              <code class="text-sm text-gray-800 break-all">{link.url}</code>
            </div>
            
            <div class="flex items-center justify-between text-sm text-gray-600 mb-3">
              <span>使用情况：{link.usedCount}/{link.maxUses}</span>
              {#if link.expiresAt}
                <span>过期时间：{formatDateTime(link.expiresAt)}</span>
              {:else}
                <span>永久有效</span>
              {/if}
            </div>
            
            <div class="flex space-x-2">
              <button
                on:click={() => copyToClipboard(link.url)}
                class="px-3 py-1 text-sm bg-gray-100 text-gray-700 rounded hover:bg-gray-200 transition-colors"
              >
                复制链接
              </button>
              <button
                on:click={() => showQRCodeModal(link.url)}
                class="px-3 py-1 text-sm bg-blue-100 text-blue-700 rounded hover:bg-blue-200 transition-colors"
              >
                预览二维码
              </button>
            </div>
          </div>
        {/each}
      </div>
    </div>
  {/if}
</div>

<!-- 二维码预览弹窗 -->
{#if showQRCode}
  <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
    <div class="bg-white rounded-lg p-6 max-w-md w-full mx-4">
      <div class="flex items-center justify-between mb-4">
        <h3 class="text-lg font-semibold text-gray-900">邀请链接二维码</h3>
        {#if countdown}
          <span class="text-sm {countdown.includes('即将过期') ? 'text-red-600' : 'text-gray-600'}">
            {countdown}
          </span>
        {/if}
      </div>
      
      <div class="text-center mb-4">
        <img src={qrCodeData} alt="邀请链接二维码" class="mx-auto border rounded" />
      </div>
      
      <div class="bg-gray-50 rounded p-2 mb-4">
        <code class="text-sm text-gray-800 break-all">{qrCodeUrl}</code>
      </div>
      
      <div class="flex space-x-3">
        <button
          on:click={downloadQRCode}
          class="flex-1 px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 transition-colors"
        >
          下载二维码
        </button>
        <button
          on:click={() => showQRCode = false}
          class="flex-1 px-4 py-2 bg-gray-300 text-gray-700 rounded-md hover:bg-gray-400 transition-colors"
        >
          关闭
        </button>
      </div>
    </div>
  </div>
{/if} 