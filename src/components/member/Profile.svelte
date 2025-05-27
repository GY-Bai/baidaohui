<script lang="ts">
  import { onMount } from 'svelte';
  import { signOut, getSession } from '$lib/auth';
  import type { UserSession } from '$lib/auth';

  let user: UserSession | null = null;
  let loading = true;
  let stats = {
    fortuneApplications: 0,
    orders: 0,
    chatMessages: 0
  };

  onMount(async () => {
    try {
      user = await getSession();
      await loadUserStats();
    } catch (error) {
      console.error('获取用户信息失败:', error);
    } finally {
      loading = false;
    }
  });

  async function loadUserStats() {
    try {
      const response = await fetch('/api/user/stats');
      if (response.ok) {
        stats = await response.json();
      }
    } catch (error) {
      console.error('获取用户统计失败:', error);
    }
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
</script>

<div class="bg-white rounded-lg shadow p-6">
  <h2 class="text-2xl font-semibold text-gray-900 mb-6">个人资料</h2>

  {#if loading}
    <div class="text-center py-8">
      <svg class="animate-spin h-8 w-8 text-blue-600 mx-auto mb-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 714 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
      </svg>
      <p class="text-gray-600">加载中...</p>
    </div>
  {:else if user}
    <div class="space-y-6">
      <!-- 用户基本信息 -->
      <div class="bg-gradient-to-r from-green-50 to-blue-50 rounded-lg p-6">
        <div class="flex items-center space-x-4">
          <div class="w-16 h-16 bg-green-500 rounded-full flex items-center justify-center text-white text-2xl font-semibold">
            {user.user.email.charAt(0).toUpperCase()}
          </div>
          <div>
            <h3 class="text-lg font-semibold text-gray-900">{user.user.email}</h3>
            <div class="flex items-center space-x-2">
              <span class="text-gray-600">角色:</span>
              <span class="px-2 py-1 text-sm bg-green-100 text-green-800 rounded-full font-medium">
                {user.user.role}
              </span>
              <span class="text-green-600 text-sm">✨ 已升级</span>
            </div>
          </div>
        </div>
      </div>

      <!-- Member特权展示 -->
      <div class="bg-green-50 border border-green-200 rounded-lg p-4">
        <h4 class="font-medium text-green-800 mb-3 flex items-center">
          <svg class="w-5 h-5 mr-2" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"></path>
          </svg>
          Member 特权
        </h4>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
          <div class="flex items-center text-green-700 text-sm">
            <svg class="w-4 h-4 mr-2" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"></path>
            </svg>
            私信聊天功能
          </div>
          <div class="flex items-center text-green-700 text-sm">
            <svg class="w-4 h-4 mr-2" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"></path>
            </svg>
            群聊参与权限
          </div>
          <div class="flex items-center text-green-700 text-sm">
            <svg class="w-4 h-4 mr-2" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"></path>
            </svg>
            实时状态更新
          </div>
          <div class="flex items-center text-green-700 text-sm">
            <svg class="w-4 h-4 mr-2" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"></path>
            </svg>
            专享商品折扣
          </div>
          <div class="flex items-center text-green-700 text-sm">
            <svg class="w-4 h-4 mr-2" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"></path>
            </svg>
            优先客服支持
          </div>
          <div class="flex items-center text-green-700 text-sm">
            <svg class="w-4 h-4 mr-2" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"></path>
            </svg>
            消息已读提示
          </div>
        </div>
      </div>

      <!-- 账户统计 -->
      <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div class="bg-blue-50 rounded-lg p-4 text-center">
          <div class="text-2xl font-bold text-blue-600">{stats.fortuneApplications}</div>
          <div class="text-sm text-gray-600">算命申请</div>
        </div>
        <div class="bg-green-50 rounded-lg p-4 text-center">
          <div class="text-2xl font-bold text-green-600">{stats.orders}</div>
          <div class="text-sm text-gray-600">购买订单</div>
        </div>
        <div class="bg-purple-50 rounded-lg p-4 text-center">
          <div class="text-2xl font-bold text-purple-600">{stats.chatMessages}</div>
          <div class="text-sm text-gray-600">聊天消息</div>
        </div>
      </div>

      <!-- 最近活动 -->
      <div class="bg-gray-50 rounded-lg p-4">
        <h4 class="font-medium text-gray-900 mb-3">最近活动</h4>
        <div class="space-y-2">
          <div class="flex items-center text-sm text-gray-600">
            <svg class="w-4 h-4 mr-2 text-green-500" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"></path>
            </svg>
            成功升级为 Member 用户
          </div>
          <div class="flex items-center text-sm text-gray-600">
            <svg class="w-4 h-4 mr-2 text-blue-500" fill="currentColor" viewBox="0 0 20 20">
              <path d="M2.003 5.884L10 9.882l7.997-3.998A2 2 0 0016 4H4a2 2 0 00-1.997 1.884z"></path>
              <path d="M18 8.118l-8 4-8-4V14a2 2 0 002 2h12a2 2 0 002-2V8.118z"></path>
            </svg>
            开启了聊天功能
          </div>
          <div class="flex items-center text-sm text-gray-600">
            <svg class="w-4 h-4 mr-2 text-purple-500" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M3 4a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zm0 4a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zm0 4a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1z" clip-rule="evenodd"></path>
            </svg>
            可以查看专享商品
          </div>
        </div>
      </div>

      <!-- 设置选项 -->
      <div class="space-y-4">
        <h4 class="font-medium text-gray-900">设置</h4>
        
        <div class="space-y-2">
          <button class="w-full text-left px-4 py-3 bg-gray-50 rounded-lg hover:bg-gray-100 transition-colors">
            <div class="flex items-center justify-between">
              <span class="text-gray-700">聊天通知设置</span>
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
              <span class="text-gray-700">Member 特权说明</span>
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