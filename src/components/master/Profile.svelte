<script>
  import { onMount } from 'svelte';
  import { signOut } from '$lib/auth';
  

  export let session;

  let loading = false;
  let editingNickname = false;
  let nickname = '';
  let originalNickname = '';
  let nicknameError = '';
  let nicknameChecking = false;
  let profileData = {
    totalMembers: 0,
    totalFortuneOrders: 0,
    totalSellers: 0,
    totalRevenue: 0,
    joinDate: '',
    lastLogin: ''
  };
  let updateSuccess = false;
  let updateError = '';

  onMount(async () => {
    await loadProfileData();
    nickname = session.user.nickname || '';
    originalNickname = nickname;
  });

  async function loadProfileData() {
    try {
      loading = true;
      const response = await fetch(`/api/profile/master-stats?userId=${session.user.id}`);
      if (response.ok) {
        profileData = await response.json();
      }
    } catch (error) {
      console.error('获取Master统计失败:', error);
    } finally {
      loading = false;
    }
  }

  function startEdit() {
    editingNickname = true;
    nickname = originalNickname;
    nicknameError = '';
    updateSuccess = false;
    updateError = '';
  }

  function cancelEdit() {
    editingNickname = false;
    nickname = originalNickname;
    nicknameError = '';
    updateSuccess = false;
    updateError = '';
  }

  async function checkNicknameAvailability(value) {
    if (!value || value === originalNickname) {
      nicknameError = '';
      return;
    }

    if (value.length < 2) {
      nicknameError = '昵称至少需要2个字符';
      return;
    }

    if (value.length > 20) {
      nicknameError = '昵称不能超过20个字符';
      return;
    }

    try {
      nicknameChecking = true;
      const response = await fetch(`/api/profile/check-nickname?nickname=${encodeURIComponent(value)}`);
      const result = await response.json();
      
      if (!result.available) {
        nicknameError = '昵称已被使用';
      } else {
        nicknameError = '';
      }
    } catch (error) {
      console.error('检查昵称失败:', error);
      nicknameError = '检查昵称时出错';
    } finally {
      nicknameChecking = false;
    }
  }

  async function saveNickname() {
    if (nicknameError || nicknameChecking || !nickname) return;

    try {
      loading = true;
      updateError = '';
      
      const response = await fetch('/api/profile/update-nickname', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          userId: session.user.id,
          nickname: nickname.trim()
        })
      });

      if (response.ok) {
        originalNickname = nickname.trim();
        editingNickname = false;
        updateSuccess = true;
        
        // 更新session中的昵称
        session.user.nickname = nickname.trim();
        
        setTimeout(() => {
          updateSuccess = false;
        }, 3000);
      } else {
        const error = await response.json();
        updateError = error.message || '更新失败';
      }
    } catch (error) {
      console.error('保存昵称失败:', error);
      updateError = '保存失败，请重试';
    } finally {
      loading = false;
    }
  }

  function formatDate(dateString) {
    if (!dateString) return '未知';
    return new Date(dateString).toLocaleDateString('zh-CN');
  }

  function formatCurrency(amount) {
    return new Intl.NumberFormat('zh-CN', {
      style: 'currency',
      currency: 'CAD'
    }).format(amount);
  }

  // 实时检查昵称
  $: if (nickname !== originalNickname) {
    checkNicknameAvailability(nickname);
  }

  async function handleSignOut() {
    if (confirm('确定要退出登录吗？')) {
      await signOut();
    }
  }
</script>

<div class="bg-white rounded-lg shadow p-6">
  <h2 class="text-2xl font-semibold text-gray-900 mb-6">个人资料</h2>

  <div class="space-y-6">
    <!-- Master基本信息 -->
    <div class="bg-gradient-to-r from-yellow-50 to-orange-50 rounded-lg p-6">
      <div class="flex items-center space-x-4">
        <div class="w-16 h-16 bg-yellow-500 rounded-full flex items-center justify-center text-white text-2xl font-semibold">
          {(nickname || session.user.email).charAt(0).toUpperCase()}
        </div>
        <div class="flex-1">
          <div class="flex items-center space-x-2 mb-2">
            <h3 class="text-lg font-semibold text-gray-900">{session.user.email}</h3>
            <span class="px-2 py-1 text-xs bg-yellow-100 text-yellow-800 rounded-full font-medium">
              {session.user.role}
            </span>
            <span class="text-yellow-600 text-sm">👑 大师权限</span>
          </div>
          
          <!-- 昵称编辑 -->
          <div class="flex items-center space-x-2">
            {#if editingNickname}
              <div class="flex-1">
                <input
                  type="text"
                  bind:value={nickname}
                  placeholder="输入昵称"
                  class="w-full px-3 py-1 text-sm border border-gray-300 rounded focus:outline-none focus:ring-2 focus:ring-yellow-500 {nicknameError ? 'border-red-300' : ''}"
                  maxlength="20"
                />
                {#if nicknameError}
                  <p class="text-xs text-red-600 mt-1">{nicknameError}</p>
                {/if}
                {#if nicknameChecking}
                  <p class="text-xs text-blue-600 mt-1">检查中...</p>
                {/if}
              </div>
              <button
                on:click={saveNickname}
                disabled={loading || nicknameError || nicknameChecking || !nickname}
                class="px-3 py-1 text-xs bg-yellow-600 text-white rounded hover:bg-yellow-700 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {loading ? '保存中...' : '保存'}
              </button>
              <button
                on:click={cancelEdit}
                class="px-3 py-1 text-xs bg-gray-300 text-gray-700 rounded hover:bg-gray-400"
              >
                取消
              </button>
            {:else}
              <span class="text-gray-600">
                昵称: {nickname || '未设置'}
              </span>
              <button
                on:click={startEdit}
                class="text-xs text-yellow-600 hover:text-yellow-800"
              >
                编辑
              </button>
            {/if}
          </div>
          
          <!-- 成功/错误提示 -->
          {#if updateSuccess}
            <p class="text-xs text-green-600 mt-1">✓ 更新成功</p>
          {/if}
          {#if updateError}
            <p class="text-xs text-red-600 mt-1">{updateError}</p>
          {/if}
        </div>
      </div>
    </div>

    <!-- Master统计面板 -->
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
      <div class="bg-blue-50 rounded-lg p-4 text-center">
        <div class="text-2xl font-bold text-blue-600">
          {loading ? '...' : profileData.totalMembers}
        </div>
        <div class="text-sm text-gray-600">管理会员</div>
      </div>
      <div class="bg-purple-50 rounded-lg p-4 text-center">
        <div class="text-2xl font-bold text-purple-600">
          {loading ? '...' : profileData.totalFortuneOrders}
        </div>
        <div class="text-sm text-gray-600">算命订单</div>
      </div>
      <div class="bg-green-50 rounded-lg p-4 text-center">
        <div class="text-2xl font-bold text-green-600">
          {loading ? '...' : profileData.totalSellers}
        </div>
        <div class="text-sm text-gray-600">合作商户</div>
      </div>
      <div class="bg-yellow-50 rounded-lg p-4 text-center">
        <div class="text-2xl font-bold text-yellow-600">
          {loading ? '...' : formatCurrency(profileData.totalRevenue)}
        </div>
        <div class="text-sm text-gray-600">总收入</div>
      </div>
    </div>

    <!-- 账户信息 -->
    <div class="bg-gray-50 rounded-lg p-4">
      <h4 class="font-medium text-gray-900 mb-3">账户信息</h4>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm">
        <div>
          <span class="text-gray-600">注册时间:</span>
          <span class="ml-2 text-gray-900">{formatDate(profileData.joinDate)}</span>
        </div>
        <div>
          <span class="text-gray-600">最后登录:</span>
          <span class="ml-2 text-gray-900">{formatDate(profileData.lastLogin)}</span>
        </div>
        <div>
          <span class="text-gray-600">权限等级:</span>
          <span class="ml-2 text-yellow-600 font-medium">Master (最高权限)</span>
        </div>
        <div>
          <span class="text-gray-600">管理状态:</span>
          <span class="ml-2 text-green-600 font-medium">● 在线管理中</span>
        </div>
      </div>
    </div>

    <!-- Master特权说明 -->
    <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
      <h4 class="font-medium text-yellow-800 mb-3">🎯 Master 特权</h4>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-3 text-sm text-yellow-700">
        <div class="flex items-center space-x-2">
          <span class="text-yellow-500">✓</span>
          <span>管理所有用户邀请链接</span>
        </div>
        <div class="flex items-center space-x-2">
          <span class="text-yellow-500">✓</span>
          <span>处理算命申请和回复</span>
        </div>
        <div class="flex items-center space-x-2">
          <span class="text-yellow-500">✓</span>
          <span>管理商户和密钥配置</span>
        </div>
        <div class="flex items-center space-x-2">
          <span class="text-yellow-500">✓</span>
          <span>开启/关闭私聊权限</span>
        </div>
        <div class="flex items-center space-x-2">
          <span class="text-yellow-500">✓</span>
          <span>查看所有统计数据</span>
        </div>
        <div class="flex items-center space-x-2">
          <span class="text-yellow-500">✓</span>
          <span>系统配置和维护</span>
        </div>
      </div>
    </div>

    <!-- 安全设置 -->
    <div class="bg-gray-50 rounded-lg p-4">
      <h4 class="font-medium text-gray-900 mb-3">安全设置</h4>
      <div class="space-y-3">
        <div class="flex items-center justify-between">
          <div>
            <span class="text-sm text-gray-700">Google 账号登录</span>
            <p class="text-xs text-gray-500">通过 Google OAuth 安全登录</p>
          </div>
          <span class="text-green-600 text-sm">✓ 已启用</span>
        </div>
        <div class="flex items-center justify-between">
          <div>
            <span class="text-sm text-gray-700">跨子域会话</span>
            <p class="text-xs text-gray-500">在所有子域名间保持登录状态</p>
          </div>
          <span class="text-green-600 text-sm">✓ 已启用</span>
        </div>
        <div class="flex items-center justify-between">
          <div>
            <span class="text-sm text-gray-700">操作日志记录</span>
            <p class="text-xs text-gray-500">记录所有管理操作以供审计</p>
          </div>
          <span class="text-green-600 text-sm">✓ 已启用</span>
        </div>
      </div>
    </div>

    <!-- 退出登录 -->
    <div class="border-t pt-4">
      <button
        on:click={handleSignOut}
        class="w-full md:w-auto px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-red-500 transition-colors"
      >
        退出登录
      </button>
    </div>
  </div>
</div> 