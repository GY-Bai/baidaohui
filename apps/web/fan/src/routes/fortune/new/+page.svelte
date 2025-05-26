<script>
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  
  let showUpgradePrompt = false;
  
  onMount(() => {
    // Fan用户访问时显示升级提示
    showUpgradePrompt = true;
  });
  
  function handleUpgrade() {
    // 跳转到邀请链接页面或联系主播
    alert('请联系主播获取邀请链接升级为Member');
  }
</script>

<div class="min-h-screen bg-gray-50 py-8">
  <div class="max-w-2xl mx-auto px-4">
    {#if showUpgradePrompt}
      <!-- 升级提示 -->
      <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-6 mb-6">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <svg class="h-5 w-5 text-yellow-400" viewBox="0 0 20 20" fill="currentColor">
              <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
            </svg>
          </div>
          <div class="ml-3">
            <h3 class="text-sm font-medium text-yellow-800">
              需要升级为Member
            </h3>
            <div class="mt-2 text-sm text-yellow-700">
              <p>Fan用户暂时无法提交算命申请，请使用邀请链接升级为Member后再试。</p>
            </div>
            <div class="mt-4">
              <div class="flex space-x-3">
                <button
                  type="button"
                  on:click={handleUpgrade}
                  class="bg-yellow-50 text-yellow-800 rounded-md px-3 py-2 text-sm font-medium hover:bg-yellow-100 border border-yellow-200"
                >
                  联系主播升级
                </button>
                <button
                  type="button"
                  on:click={() => goto('/')}
                  class="bg-white text-yellow-800 rounded-md px-3 py-2 text-sm font-medium hover:bg-gray-50 border border-yellow-200"
                >
                  返回首页
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    {/if}
    
    <!-- 禁用的表单 -->
    <div class="bg-white rounded-lg shadow-md p-6 opacity-50">
      <h1 class="text-2xl font-bold text-gray-900 mb-6">提交算命申请</h1>
      
      <!-- 图片上传区域 -->
      <div class="mb-6">
        <label class="block text-sm font-medium text-gray-700 mb-2">
          上传图片 (最多3张)
        </label>
        
        <div class="border-2 border-dashed border-gray-300 rounded-lg p-6 text-center">
          <button
            type="button"
            disabled
            class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-gray-400 cursor-not-allowed"
          >
            选择图片
          </button>
          
          <p class="mt-2 text-sm text-gray-500">
            支持 JPG、PNG 格式，单张图片不超过 5MB
          </p>
        </div>
      </div>
      
      <!-- 附言输入 -->
      <div class="mb-6">
        <label for="description" class="block text-sm font-medium text-gray-700 mb-2">
          附言 (0/800字)
        </label>
        <textarea
          id="description"
          disabled
          rows="6"
          class="w-full px-3 py-2 border border-gray-300 rounded-md bg-gray-100 cursor-not-allowed"
          placeholder="请详细描述您的问题..."
        ></textarea>
      </div>
      
      <!-- 金额和币种 -->
      <div class="mb-6">
        <label class="block text-sm font-medium text-gray-700 mb-2">
          金额
        </label>
        <div class="flex space-x-4">
          <div class="flex-1">
            <input
              type="number"
              disabled
              class="w-full px-3 py-2 border border-gray-300 rounded-md bg-gray-100 cursor-not-allowed"
              placeholder="请输入金额"
            />
          </div>
          <div class="w-32">
            <select
              disabled
              class="w-full px-3 py-2 border border-gray-300 rounded-md bg-gray-100 cursor-not-allowed"
            >
              <option>¥ 人民币</option>
            </select>
          </div>
        </div>
      </div>
      
      <!-- 小孩危急选项 -->
      <div class="mb-6">
        <label class="flex items-center">
          <input
            type="checkbox"
            disabled
            class="h-4 w-4 text-gray-400 border-gray-300 rounded cursor-not-allowed"
          />
          <span class="ml-2 text-sm text-gray-500">小孩危急情况（优先处理）</span>
        </label>
      </div>
      
      <!-- 提交按钮 -->
      <div class="flex justify-end space-x-4">
        <button
          type="button"
          on:click={() => goto('/')}
          class="px-4 py-2 border border-gray-300 rounded-md text-gray-700 hover:bg-gray-50"
        >
          返回
        </button>
        <button
          type="button"
          disabled
          class="px-6 py-2 bg-gray-400 text-white rounded-md cursor-not-allowed"
        >
          提交申请
        </button>
      </div>
    </div>
  </div>
</div> 