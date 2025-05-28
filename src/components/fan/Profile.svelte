<script lang="ts">
  import { onMount } from 'svelte';
  import { signOut } from '$lib/auth';
  import type { UserSession } from '$lib/auth';

  export let session: UserSession;

  let loading = false;
  let editingNickname = false;
  let nickname = '';
  let originalNickname = '';
  let nicknameError = '';
  let nicknameChecking = false;
  let profileData = {
    fortuneApplications: 0,
    purchaseOrders: 0,
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
      const response = await fetch(`/api/profile/stats?userId=${session.user.id}`);
      if (response.ok) {
        profileData = await response.json();
      }
    } catch (error) {
      console.error('获取个人统计失败:', error);
    } finally {
      loading = false;
    }
  }

  async function checkNicknameUniqueness() {
    if (!nickname || nickname === originalNickname) {
      nicknameError = '';
      return;
    }

    if (nickname.length < 2) {
      nicknameError = '昵称至少需要2个字符';
      return;
    }

    if (nickname.length > 20) {
      nicknameError = '昵称不能超过20个字符';
      return;
    }

    try {
      nicknameChecking = true;
      nicknameError = '';
      
      const response = await fetch('/api/profile/check-nickname', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ nickname })
      });

      const result = await response.json();
      
      if (!response.ok) {
        nicknameError = result.message || '检查昵称失败';
      } else if (!result.available) {
        nicknameError = '该昵称已被使用，请选择其他昵称';
      }
    } catch (error) {
      console.error('检查昵称失败:', error);
      nicknameError = '检查昵称失败，请重试';
    } finally {
      nicknameChecking = false;
    }
  }

  async function saveNickname() {
    if (nicknameError || nicknameChecking) {
      return;
    }

    try {
      loading = true;
      updateError = '';
      
      const response = await fetch('/api/profile/update', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          userId: session.user.id,
          nickname: nickname
        })
      });

      const result = await response.json();
      
      if (response.ok) {
        originalNickname = nickname;
        editingNickname = false;
        updateSuccess = true;
        // 更新session中的昵称
        session.user.nickname = nickname;
        
        setTimeout(() => {
          updateSuccess = false;
        }, 3000);
      } else {
        updateError = result.message || '更新失败，请重试';
      }
    } catch (error) {
      console.error('更新昵称失败:', error);
      updateError = '更新失败，请重试';
    } finally {
      loading = false;
    }
  }

  function cancelEdit() {
    nickname = originalNickname;
    editingNickname = false;
    nicknameError = '';
    updateError = '';
  }

  function startEdit() {
    editingNickname = true;
    updateError = '';
    updateSuccess = false;
  }

  async function handleSignOut() {
    if (confirm('确定要退出登录吗？')) {
      try {
        await signOut();
      } catch (error) {
        console.error('退出登录失败:', error);
        alert('退出登录失败，请重试');
      }
    }
  }

  function formatDate(dateString: string): string {
    if (!dateString) return '未知';
    return new Date(dateString).toLocaleDateString('zh-CN');
  }

  // 实时检查昵称
  $: if (nickname !== originalNickname) {
    const timeoutId = setTimeout(() => {
      checkNicknameUniqueness();
    }, 500);
    
    return () => clearTimeout(timeoutId);
  }
</script>

<div class="bg-white rounded-lg shadow p-6">
  <h2 class="text-2xl font-semibold text-gray-900 mb-6">个人资料</h2>

  <div class="space-y-6">
    <!-- 用户基本信息 -->
    <div class="bg-gray-50 rounded-lg p-6">
      <div class="flex items-center space-x-4">
        <div class="w-16 h-16 bg-blue-500 rounded-full flex items-center justify-center text-white text-2xl font-semibold">
          {(nickname || session.user.email).charAt(0).toUpperCase()}
        </div>
        <div class="flex-1">
          <div class="flex items-center space-x-2 mb-2">
            <h3 class="text-lg font-semibold text-gray-900">{session.user.email}</h3>
            <span class="px-2 py-1 text-xs bg-blue-100 text-blue-800 rounded-full">{session.user.role}</span>
          </div>
          
          <!-- 昵称编辑 -->
          <div class="flex items-center space-x-2">
            {#if editingNickname}
              <div class="flex-1">
                <input
                  type="text"
                  bind:value={nickname}
                  placeholder="输入昵称"
                  class="w-full px-3 py-1 text-sm border border-gray-300 rounded focus:outline-none focus:ring-2 focus:ring-blue-500 {nicknameError ? 'border-red-300' : ''}"
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
                class="px-3 py-1 text-xs bg-blue-600 text-white rounded hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
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
                class="text-xs text-blue-600 hover:text-blue-800"
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

    <!-- 账户统计 -->
    <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
      <div class="bg-blue-50 rounded-lg p-4 text-center">
        <div class="text-2xl font-bold text-blue-600">
          {loading ? '...' : profileData.fortuneApplications}
        </div>
        <div class="text-sm text-gray-600">算命申请</div>
      </div>
      <div class="bg-green-50 rounded-lg p-4 text-center">
        <div class="text-2xl font-bold text-green-600">
          {loading ? '...' : profileData.purchaseOrders}
        </div>
        <div class="text-sm text-gray-600">购买订单</div>
      </div>
      <div class="bg-purple-50 rounded-lg p-4 text-center">
        <div class="text-2xl font-bold text-purple-600">{session.user.role}</div>
        <div class="text-sm text-gray-600">当前等级</div>
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
      </div>
    </div>

    <!-- 功能说明 -->
    {#if session.user.role === 'Fan'}
      <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
        <h4 class="font-medium text-yellow-800 mb-2">🎉 升级提示</h4>
        <p class="text-yellow-700 text-sm mb-3">
          升级为 Member 可解锁更多功能：私信聊天、群聊参与、实时通知等
        </p>
        <button class="text-yellow-800 text-sm font-medium hover:underline">
          了解如何升级 →
        </button>
      </div>
    {/if}

    <!-- 设置选项 -->
    <div class="space-y-4">
      <h4 class="font-medium text-gray-900">设置</h4>
      
      <div class="space-y-2">
        <button class="w-full text-left px-4 py-3 bg-gray-50 rounded-lg hover:bg-gray-100 transition-colors">
          <div class="flex items-center justify-between">
            <span class="text-gray-700">通知设置</span>
            <svg class="w-5 h-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path>
            </svg>
          </div>
        </button>
        
        <button class="w-full text-left px-4 py-3 bg-gray-50 rounded-lg hover:bg-gray-100 transition-colors">
          <div class="flex items-center justify-between">
            <span class="text-gray-700">隐私设置</span>
            <svg class="w-5 h-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path>
            </svg>
          </div>
        </button>
        
        <button class="w-full text-left px-4 py-3 bg-gray-50 rounded-lg hover:bg-gray-100 transition-colors">
          <div class="flex items-center justify-between">
            <span class="text-gray-700">帮助与支持</span>
            <svg class="w-5 h-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path>
            </svg>
          </div>
        </button>
      </div>
    </div>

    <!-- 退出登录 -->
    <div class="pt-4 border-t border-gray-200">
      <button 
        on:click={handleSignOut}
        class="w-full px-4 py-3 bg-red-600 text-white font-medium rounded-lg hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-red-500 transition-colors"
      >
        退出登录
      </button>
    </div>
  </div>
</div> 