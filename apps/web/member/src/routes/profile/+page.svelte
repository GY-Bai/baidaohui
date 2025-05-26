<script>
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  
  let user = null;
  let loading = true;
  let editingNickname = false;
  let newNickname = '';
  let nicknameError = '';
  let savingNickname = false;
  
  let applications = [];
  let recentFortuneOrders = [];
  
  onMount(async () => {
    await loadUserProfile();
    await loadRecentData();
  });
  
  async function loadUserProfile() {
    try {
      const response = await fetch('/api/profile', {
        headers: {
          'Authorization': `Bearer ${localStorage.getItem('supabase_token')}`
        }
      });
      
      if (response.ok) {
        user = await response.json();
        newNickname = user.nickname || '';
      }
    } catch (error) {
      console.error('加载用户信息失败:', error);
    } finally {
      loading = false;
    }
  }
  
  async function loadRecentData() {
    try {
      // 加载最近的算命申请
      const fortuneResponse = await fetch('https://fortune.baiduohui.com/applications?limit=3', {
        headers: {
          'Authorization': `Bearer ${localStorage.getItem('supabase_token')}`
        }
      });
      
      if (fortuneResponse.ok) {
        recentFortuneOrders = await fortuneResponse.json();
      }
      
    } catch (error) {
      console.error('加载最近数据失败:', error);
    }
  }
  
  function startEditNickname() {
    editingNickname = true;
    newNickname = user.nickname || '';
    nicknameError = '';
  }
  
  function cancelEditNickname() {
    editingNickname = false;
    newNickname = user.nickname || '';
    nicknameError = '';
  }
  
  async function validateNickname(nickname) {
    if (!nickname.trim()) {
      return '昵称不能为空';
    }
    
    if (nickname.length > 20) {
      return '昵称不能超过20个字符';
    }
    
    // 检查是否只包含中英文字母和emoji
    const validPattern = /^[\u4e00-\u9fa5a-zA-Z\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F1E0}-\u{1F1FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]+$/u;
    if (!validPattern.test(nickname)) {
      return '昵称只能包含中文、英文字母和emoji';
    }
    
    // 检查唯一性
    try {
      const response = await fetch('/api/profile/validate-nickname', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${localStorage.getItem('supabase_token')}`
        },
        body: JSON.stringify({ nickname })
      });
      
      const result = await response.json();
      if (!result.available) {
        return '该昵称已被使用';
      }
    } catch (error) {
      return '验证昵称时发生错误';
    }
    
    return null;
  }
  
  async function saveNickname() {
    const error = await validateNickname(newNickname);
    if (error) {
      nicknameError = error;
      return;
    }
    
    savingNickname = true;
    nicknameError = '';
    
    try {
      const response = await fetch('/api/profile/nickname', {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${localStorage.getItem('supabase_token')}`
        },
        body: JSON.stringify({ nickname: newNickname })
      });
      
      if (response.ok) {
        user.nickname = newNickname;
        editingNickname = false;
        alert('昵称更新成功');
      } else {
        const result = await response.json();
        nicknameError = result.message || '更新失败';
      }
    } catch (error) {
      console.error('更新昵称失败:', error);
      nicknameError = '更新失败，请稍后重试';
    } finally {
      savingNickname = false;
    }
  }
  
  function formatDate(dateString) {
    return new Date(dateString).toLocaleDateString('zh-CN');
  }
  
  function getRoleDisplayName(role) {
    const roleMap = {
      'fan': 'Fan',
      'member': 'Member',
      'master': 'Master',
      'firstmate': 'Firstmate'
    };
    return roleMap[role] || role;
  }
  
  function getStatusDisplayName(status) {
    const statusMap = {
      'pending': '排队中',
      'processing': '处理中',
      'completed': '已完成',
      'refunded': '已退款'
    };
    return statusMap[status] || status;
  }
  
  const currencySymbols = {
    'CNY': '¥',
    'USD': '$',
    'CAD': 'C$',
    'SGD': 'S$',
    'AUD': 'A$'
  };
</script>

<div class="min-h-screen bg-gray-50 py-8">
  <div class="max-w-4xl mx-auto px-4">
    {#if loading}
      <div class="text-center py-12">
        <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
        <p class="mt-2 text-gray-600">加载中...</p>
      </div>
    {:else}
      <div class="space-y-6">
        <!-- 个人信息卡片 -->
        <div class="bg-white rounded-lg shadow-md p-6">
          <h1 class="text-2xl font-bold text-gray-900 mb-6">个人信息</h1>
          
          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <!-- 基本信息 -->
            <div class="space-y-4">
              <div>
                <label class="block text-sm font-medium text-gray-700">邮箱</label>
                <p class="mt-1 text-sm text-gray-900">{user?.email || '未设置'}</p>
              </div>
              
              <div>
                <label class="block text-sm font-medium text-gray-700">角色</label>
                <span class="mt-1 inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                  {getRoleDisplayName(user?.role)}
                </span>
              </div>
              
              <div>
                <label class="block text-sm font-medium text-gray-700">注册时间</label>
                <p class="mt-1 text-sm text-gray-900">
                  {user?.created_at ? formatDate(user.created_at) : '未知'}
                </p>
              </div>
            </div>
            
            <!-- 昵称设置 -->
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">昵称</label>
              
              {#if editingNickname}
                <div class="space-y-2">
                  <input
                    type="text"
                    bind:value={newNickname}
                    maxlength="20"
                    class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                    placeholder="请输入昵称"
                  />
                  
                  {#if nicknameError}
                    <p class="text-sm text-red-600">{nicknameError}</p>
                  {/if}
                  
                  <div class="flex space-x-2">
                    <button
                      on:click={saveNickname}
                      disabled={savingNickname}
                      class="px-3 py-1 text-sm bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:opacity-50"
                    >
                      {savingNickname ? '保存中...' : '保存'}
                    </button>
                    <button
                      on:click={cancelEditNickname}
                      class="px-3 py-1 text-sm border border-gray-300 rounded-md text-gray-700 hover:bg-gray-50"
                    >
                      取消
                    </button>
                  </div>
                </div>
              {:else}
                <div class="flex items-center justify-between">
                  <p class="text-sm text-gray-900">
                    {user?.nickname || '未设置昵称'}
                  </p>
                  <button
                    on:click={startEditNickname}
                    class="text-sm text-blue-600 hover:text-blue-700"
                  >
                    编辑
                  </button>
                </div>
              {/if}
            </div>
          </div>
        </div>
        
        <!-- 快速操作 -->
        <div class="bg-white rounded-lg shadow-md p-6">
          <h2 class="text-lg font-medium text-gray-900 mb-4">快速操作</h2>
          
          <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
            <button
              on:click={() => goto('/fortune/new')}
              class="flex items-center p-4 border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors"
            >
              <div class="flex-shrink-0">
                <svg class="h-8 w-8 text-purple-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z" />
                </svg>
              </div>
              <div class="ml-3 text-left">
                <p class="text-sm font-medium text-gray-900">新建算命申请</p>
                <p class="text-sm text-gray-500">提交新的算命请求</p>
              </div>
            </button>
            
            <button
              on:click={() => goto('/fortune/history')}
              class="flex items-center p-4 border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors"
            >
              <div class="flex-shrink-0">
                <svg class="h-8 w-8 text-green-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                </svg>
              </div>
              <div class="ml-3 text-left">
                <p class="text-sm font-medium text-gray-900">算命历史</p>
                <p class="text-sm text-gray-500">查看所有申请记录</p>
              </div>
            </button>
            
            <button
              on:click={() => goto('/shop')}
              class="flex items-center p-4 border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors"
            >
              <div class="flex-shrink-0">
                <svg class="h-8 w-8 text-blue-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 11V7a4 4 0 00-8 0v4M5 9h14l1 12H4L5 9z" />
                </svg>
              </div>
              <div class="ml-3 text-left">
                <p class="text-sm font-medium text-gray-900">商店购物</p>
                <p class="text-sm text-gray-500">浏览和购买商品</p>
              </div>
            </button>
          </div>
        </div>
        
        <!-- 最近的算命申请 -->
        {#if recentFortuneOrders.length > 0}
          <div class="bg-white rounded-lg shadow-md p-6">
            <div class="flex items-center justify-between mb-4">
              <h2 class="text-lg font-medium text-gray-900">最近的算命申请</h2>
              <button
                on:click={() => goto('/fortune/history')}
                class="text-sm text-blue-600 hover:text-blue-700"
              >
                查看全部
              </button>
            </div>
            
            <div class="space-y-3">
              {#each recentFortuneOrders as order}
                <div class="flex items-center justify-between p-3 border border-gray-200 rounded-lg">
                  <div class="flex-1">
                    <div class="flex items-center space-x-2">
                      <span class="text-sm font-medium text-gray-900">
                        #{order.id.slice(-8)}
                      </span>
                      <span class="text-xs px-2 py-1 rounded-full bg-gray-100 text-gray-800">
                        {getStatusDisplayName(order.status)}
                      </span>
                      {#if order.is_child_emergency}
                        <span class="text-xs px-2 py-1 rounded-full bg-red-100 text-red-800">
                          小孩危急
                        </span>
                      {/if}
                    </div>
                    
                    <div class="mt-1 text-sm text-gray-600">
                      金额: {currencySymbols[order.currency]}{order.amount} | 
                      提交: {formatDate(order.created_at)}
                    </div>
                  </div>
                  
                  <button
                    on:click={() => goto(`/fortune/history`)}
                    class="text-sm text-blue-600 hover:text-blue-700"
                  >
                    查看详情
                  </button>
                </div>
              {/each}
            </div>
          </div>
        {/if}
        
        <!-- 账户统计 -->
        <div class="bg-white rounded-lg shadow-md p-6">
          <h2 class="text-lg font-medium text-gray-900 mb-4">账户统计</h2>
          
          <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
            <div class="text-center">
              <div class="text-2xl font-bold text-blue-600">
                {recentFortuneOrders.length}
              </div>
              <div class="text-sm text-gray-600">算命申请总数</div>
            </div>
            
            <div class="text-center">
              <div class="text-2xl font-bold text-green-600">
                {recentFortuneOrders.filter(o => o.status === 'completed').length}
              </div>
              <div class="text-sm text-gray-600">已完成申请</div>
            </div>
            
            <div class="text-center">
              <div class="text-2xl font-bold text-yellow-600">
                {recentFortuneOrders.filter(o => o.status === 'pending').length}
              </div>
              <div class="text-sm text-gray-600">排队中申请</div>
            </div>
          </div>
        </div>
      </div>
    {/if}
  </div>
</div> 