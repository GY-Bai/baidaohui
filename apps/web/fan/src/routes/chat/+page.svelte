<script>
  import { onMount } from 'svelte';
  
  let showUpgradePrompt = true;
  
  function handleUpgradeClick() {
    // 跳转到邀请链接页面或显示升级说明
    alert('请联系主播获取邀请链接以升级为 Member');
  }
  
  function handleContactMaster() {
    // 可以跳转到其他联系方式
    window.open('mailto:master@baiduohui.com', '_blank');
  }
</script>

<svelte:head>
  <title>私信 - 百刀会</title>
</svelte:head>

<div class="max-w-4xl mx-auto px-4 py-8">
  <div class="text-center">
    <!-- 图标 -->
    <div class="mx-auto h-24 w-24 rounded-full bg-gradient-to-r from-blue-100 to-purple-100 flex items-center justify-center mb-6">
      <span class="text-4xl">💬</span>
    </div>
    
    <h1 class="text-3xl font-bold text-gray-900 mb-4">私信功能</h1>
    
    <!-- Fan 用户提示 -->
    <div class="max-w-md mx-auto">
      <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-6 mb-6">
        <div class="flex items-center justify-center mb-4">
          <svg class="h-8 w-8 text-yellow-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.732-.833-2.5 0L4.268 18.5c-.77.833.192 2.5 1.732 2.5z" />
          </svg>
        </div>
        
        <h3 class="text-lg font-semibold text-yellow-800 mb-2">
          升级为 Member 以启用聊天功能
        </h3>
        
        <p class="text-yellow-700 mb-4">
          您当前是 Fan 用户，需要升级为 Member 才能使用私信功能与主播交流。
        </p>
        
        <div class="space-y-3">
          <button
            on:click={handleUpgradeClick}
            class="w-full bg-yellow-600 text-white px-4 py-2 rounded-md font-medium hover:bg-yellow-700 focus:outline-none focus:ring-2 focus:ring-yellow-500 focus:ring-offset-2 transition-colors duration-200"
          >
            了解如何升级
          </button>
          
          <button
            on:click={handleContactMaster}
            class="w-full bg-white text-yellow-700 px-4 py-2 rounded-md font-medium border border-yellow-300 hover:bg-yellow-50 focus:outline-none focus:ring-2 focus:ring-yellow-500 focus:ring-offset-2 transition-colors duration-200"
          >
            联系主播
          </button>
        </div>
      </div>
      
      <!-- 功能说明 -->
      <div class="bg-gray-50 rounded-lg p-4">
        <h4 class="font-medium text-gray-900 mb-2">Member 专享功能</h4>
        <ul class="text-sm text-gray-600 space-y-1">
          <li class="flex items-center">
            <svg class="h-4 w-4 text-green-500 mr-2" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd" />
            </svg>
            与主播私信交流
          </li>
          <li class="flex items-center">
            <svg class="h-4 w-4 text-green-500 mr-2" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd" />
            </svg>
            查看群聊消息
          </li>
          <li class="flex items-center">
            <svg class="h-4 w-4 text-green-500 mr-2" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd" />
            </svg>
            实时消息通知
          </li>
          <li class="flex items-center">
            <svg class="h-4 w-4 text-green-500 mr-2" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd" />
            </svg>
            优先算命服务
          </li>
        </ul>
      </div>
    </div>
  </div>
</div> 