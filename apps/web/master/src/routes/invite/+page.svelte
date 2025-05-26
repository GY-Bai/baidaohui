<script>
  import { onMount } from 'svelte';
  
  let validityHours = 24;
  let maxUses = 10;
  let generatedLink = '';
  let isGenerating = false;
  let copySuccess = false;
  let inviteHistory = [];
  let qrCodeDataUrl = '';
  let showQRCode = false;
  
  onMount(() => {
    loadInviteHistory();
  });
  
  async function generateInviteLink() {
    try {
      isGenerating = true;
      
      // 调用后端 API 生成邀请链接
      const response = await fetch('/api/auth/generate_invite_link', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${getAuthToken()}`
        },
        body: JSON.stringify({
          valid_hours: validityHours,
          max_uses: maxUses
        })
      });
      
      if (!response.ok) {
        throw new Error('生成邀请链接失败');
      }
      
      const data = await response.json();
      generatedLink = `https://baiduohui.com?invite=${data.code}`;
      
      // 生成二维码
      await generateQRCode(generatedLink);
      
      // 自动复制到剪贴板
      await copyToClipboard();
      
      // 刷新历史记录
      loadInviteHistory();
      
    } catch (error) {
      console.error('生成邀请链接失败:', error);
      alert('生成邀请链接失败，请重试');
    } finally {
      isGenerating = false;
    }
  }

  async function generateQRCode(text) {
    try {
      // 使用 QR.js 库生成二维码
      const QRCode = (await import('qrcode')).default;
      qrCodeDataUrl = await QRCode.toDataURL(text, {
        width: 256,
        margin: 2,
        color: {
          dark: '#000000',
          light: '#FFFFFF'
        }
      });
      showQRCode = true;
    } catch (error) {
      console.error('生成二维码失败:', error);
      // 如果QR库不可用，使用在线API作为备选
      try {
        qrCodeDataUrl = `https://api.qrserver.com/v1/create-qr-code/?size=256x256&data=${encodeURIComponent(text)}`;
        showQRCode = true;
      } catch (fallbackError) {
        console.error('备选二维码生成也失败:', fallbackError);
      }
    }
  }

  async function downloadQRCode() {
    try {
      const link = document.createElement('a');
      link.download = `invite-qr-${Date.now()}.png`;
      link.href = qrCodeDataUrl;
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
    } catch (error) {
      console.error('下载二维码失败:', error);
      alert('下载失败，请重试');
    }
  }
  
  async function copyToClipboard() {
    try {
      await navigator.clipboard.writeText(generatedLink);
      copySuccess = true;
      setTimeout(() => {
        copySuccess = false;
      }, 2000);
    } catch (error) {
      console.error('复制失败:', error);
      // 降级方案：选择文本
      const textArea = document.createElement('textarea');
      textArea.value = generatedLink;
      document.body.appendChild(textArea);
      textArea.select();
      document.execCommand('copy');
      document.body.removeChild(textArea);
      copySuccess = true;
      setTimeout(() => {
        copySuccess = false;
      }, 2000);
    }
  }
  
  async function loadInviteHistory() {
    try {
      const response = await fetch('/api/auth/invite_history', {
        headers: {
          'Authorization': `Bearer ${getAuthToken()}`
        }
      });
      
      if (response.ok) {
        inviteHistory = await response.json();
      }
    } catch (error) {
      console.error('加载邀请历史失败:', error);
    }
  }
  
  function getAuthToken() {
    // 实际项目中从 Supabase 获取 JWT token
    return localStorage.getItem('supabase.auth.token') || '';
  }
  
  function formatDate(dateString) {
    return new Date(dateString).toLocaleString('zh-CN');
  }
  
  function getStatusText(invite) {
    if (invite.expired) return '已过期';
    if (invite.used_count >= invite.max_uses) return '已用完';
    return '有效';
  }
  
  function getStatusColor(invite) {
    if (invite.expired || invite.used_count >= invite.max_uses) {
      return 'text-red-600 bg-red-100';
    }
    return 'text-green-600 bg-green-100';
  }
</script>

<svelte:head>
  <title>邀请链接管理 - 百刀会</title>
</svelte:head>

<div class="max-w-4xl mx-auto px-4 py-8">
  <div class="mb-8">
    <h1 class="text-3xl font-bold text-gray-900 mb-2">邀请链接管理</h1>
    <p class="text-gray-600">生成邀请链接，让 Fan 用户升级为 Member</p>
  </div>
  
  <!-- 生成新邀请链接 -->
  <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-6 mb-8">
    <h2 class="text-xl font-semibold text-gray-900 mb-4">生成新邀请链接</h2>
    
    <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">
      <div>
        <label for="validity" class="block text-sm font-medium text-gray-700 mb-2">
          有效期（小时）
        </label>
        <select
          id="validity"
          bind:value={validityHours}
          class="block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
        >
          <option value={1}>1 小时</option>
          <option value={6}>6 小时</option>
          <option value={12}>12 小时</option>
          <option value={24}>24 小时</option>
          <option value={48}>48 小时</option>
        </select>
      </div>
      
      <div>
        <label for="maxUses" class="block text-sm font-medium text-gray-700 mb-2">
          最大使用次数
        </label>
        <select
          id="maxUses"
          bind:value={maxUses}
          class="block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
        >
          <option value={1}>1 人</option>
          <option value={5}>5 人</option>
          <option value={10}>10 人</option>
          <option value={20}>20 人</option>
          <option value={50}>50 人</option>
          <option value={100}>100 人</option>
        </select>
      </div>
    </div>
    
    <button
      on:click={generateInviteLink}
      disabled={isGenerating}
      class="w-full md:w-auto bg-blue-600 text-white px-6 py-3 rounded-md font-medium hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed transition-colors duration-200"
    >
      {isGenerating ? '生成中...' : '生成邀请链接'}
    </button>
    
    {#if generatedLink}
      <div class="mt-6 p-4 bg-gray-50 rounded-md">
        <label class="block text-sm font-medium text-gray-700 mb-2">生成的邀请链接</label>
        <div class="flex items-center space-x-2 mb-4">
          <input
            type="text"
            value={generatedLink}
            readonly
            class="flex-1 block w-full rounded-md border-gray-300 bg-white shadow-sm focus:border-blue-500 focus:ring-blue-500"
          />
          <button
            on:click={copyToClipboard}
            class="bg-gray-600 text-white px-4 py-2 rounded-md hover:bg-gray-700 focus:outline-none focus:ring-2 focus:ring-gray-500 focus:ring-offset-2 transition-colors duration-200"
          >
            {copySuccess ? '已复制!' : '复制'}
          </button>
        </div>
        
        {#if showQRCode}
          <div class="flex flex-col md:flex-row items-start md:items-center space-y-4 md:space-y-0 md:space-x-6">
            <div class="flex-shrink-0">
              <label class="block text-sm font-medium text-gray-700 mb-2">二维码</label>
              <div class="border border-gray-200 rounded-lg p-4 bg-white">
                <img 
                  src={qrCodeDataUrl} 
                  alt="邀请链接二维码" 
                  class="w-32 h-32 mx-auto"
                />
              </div>
            </div>
            
            <div class="flex-1">
              <p class="text-sm text-gray-600 mb-3">
                扫描二维码或点击下载保存到本地，方便分享给需要升级的用户。
              </p>
              <button
                on:click={downloadQRCode}
                class="bg-green-600 text-white px-4 py-2 rounded-md hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-green-500 focus:ring-offset-2 transition-colors duration-200"
              >
                下载二维码
              </button>
            </div>
          </div>
        {/if}
        
        {#if copySuccess}
          <p class="mt-2 text-sm text-green-600">链接已复制到剪贴板</p>
        {/if}
      </div>
    {/if}
  </div>
  
  <!-- 邀请历史 -->
  <div class="bg-white rounded-lg shadow-sm border border-gray-200">
    <div class="px-6 py-4 border-b border-gray-200">
      <h2 class="text-xl font-semibold text-gray-900">邀请历史</h2>
    </div>
    
    <div class="overflow-x-auto">
      <table class="min-w-full divide-y divide-gray-200">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
              邀请码
            </th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
              创建时间
            </th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
              有效期
            </th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
              使用情况
            </th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
              状态
            </th>
          </tr>
        </thead>
        <tbody class="bg-white divide-y divide-gray-200">
          {#each inviteHistory as invite}
            <tr>
              <td class="px-6 py-4 whitespace-nowrap text-sm font-mono text-gray-900">
                {invite.code}
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                {formatDate(invite.created_at)}
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                {formatDate(invite.expires_at)}
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                {invite.used_count} / {invite.max_uses}
              </td>
              <td class="px-6 py-4 whitespace-nowrap">
                <span class="inline-flex px-2 py-1 text-xs font-semibold rounded-full {getStatusColor(invite)}">
                  {getStatusText(invite)}
                </span>
              </td>
            </tr>
          {:else}
            <tr>
              <td colspan="5" class="px-6 py-4 text-center text-sm text-gray-500">
                暂无邀请记录
              </td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>
  </div>
</div> 