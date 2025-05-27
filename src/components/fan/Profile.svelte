<script lang="ts">
  import { onMount } from 'svelte';
  import { signOut, getSession } from '$lib/auth';
  import type { UserSession } from '$lib/auth';

  let user: UserSession | null = null;
  let loading = true;

  onMount(async () => {
    try {
      user = await getSession();
    } catch (error) {
      console.error('获取用户信息失败:', error);
    } finally {
      loading = false;
    }
  });

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
</script>

<div class="bg-white rounded-lg shadow p-6">
  <h2 class="text-2xl font-semibold text-gray-900 mb-6">个人资料</h2>

  {#if loading}
    <div class="text-center py-8">
      <svg class="animate-spin h-8 w-8 text-blue-600 mx-auto mb-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
      </svg>
      <p class="text-gray-600">加载中...</p>
    </div>
  {:else if user}
    <div class="space-y-6">
      <!-- 用户基本信息 -->
      <div class="bg-gray-50 rounded-lg p-6">
        <div class="flex items-center space-x-4">
          <div class="w-16 h-16 bg-blue-500 rounded-full flex items-center justify-center text-white text-2xl font-semibold">
            {user.user.email.charAt(0).toUpperCase()}
          </div>
          <div>
            <h3 class="text-lg font-semibold text-gray-900">{user.user.email}</h3>
            <p class="text-gray-600">角色: {user.user.role}</p>
          </div>
        </div>
      </div>

      <!-- 账户统计 -->
      <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div class="bg-blue-50 rounded-lg p-4 text-center">
          <div class="text-2xl font-bold text-blue-600">0</div>
          <div class="text-sm text-gray-600">算命申请</div>
        </div>
        <div class="bg-green-50 rounded-lg p-4 text-center">
          <div class="text-2xl font-bold text-green-600">0</div>
          <div class="text-sm text-gray-600">购买订单</div>
        </div>
        <div class="bg-purple-50 rounded-lg p-4 text-center">
          <div class="text-2xl font-bold text-purple-600">Fan</div>
          <div class="text-sm text-gray-600">当前等级</div>
        </div>
      </div>

      <!-- 功能说明 -->
      <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
        <h4 class="font-medium text-yellow-800 mb-2">🎉 升级提示</h4>
        <p class="text-yellow-700 text-sm mb-3">
          升级为 Member 可解锁更多功能：私信聊天、群聊参与、实时通知等
        </p>
        <button class="text-yellow-800 text-sm font-medium hover:underline">
          了解如何升级 →
        </button>
      </div>

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
  {:else}
    <div class="text-center py-8">
      <svg class="w-16 h-16 text-gray-400 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z"></path>
      </svg>
      <p class="text-gray-600">无法获取用户信息</p>
    </div>
  {/if}
</div> 