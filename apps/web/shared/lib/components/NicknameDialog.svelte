<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  
  const dispatch = createEventDispatcher();
  
  export let isOpen: boolean = false;
  export let currentNickname: string = '';
  
  let nickname: string = currentNickname;
  let isValidating: boolean = false;
  let isSubmitting: boolean = false;
  let error: string = '';
  let validationMessage: string = '';
  
  // 昵称验证规则：仅中英文字母+emoji
  const nicknameRegex = /^[\u4e00-\u9fa5a-zA-Z\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F1E0}-\u{1F1FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]+$/u;
  
  $: if (nickname) {
    validateNickname();
  }
  
  function validateNickname() {
    error = '';
    validationMessage = '';
    
    if (!nickname.trim()) {
      error = '昵称不能为空';
      return;
    }
    
    if (nickname.length < 2) {
      error = '昵称至少需要2个字符';
      return;
    }
    
    if (nickname.length > 20) {
      error = '昵称不能超过20个字符';
      return;
    }
    
    if (!nicknameRegex.test(nickname)) {
      error = '昵称只能包含中文、英文字母和emoji';
      return;
    }
    
    // 如果格式正确，检查唯一性
    if (nickname !== currentNickname) {
      checkNicknameAvailability();
    }
  }
  
  async function checkNicknameAvailability() {
    if (isValidating) return;
    
    try {
      isValidating = true;
      
      const response = await fetch('/api/profile/validate_nickname', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${getAuthToken()}`
        },
        body: JSON.stringify({ nickname })
      });
      
      const data = await response.json();
      
      if (!response.ok) {
        if (response.status === 409) {
          error = '昵称已被占用，请选择其他昵称';
        } else {
          error = data.message || '验证失败，请重试';
        }
      } else {
        validationMessage = '昵称可用';
      }
      
    } catch (err) {
      console.error('昵称验证失败:', err);
      error = '网络错误，请重试';
    } finally {
      isValidating = false;
    }
  }
  
  async function submitNickname() {
    if (error || isSubmitting || isValidating) return;
    
    try {
      isSubmitting = true;
      
      const response = await fetch('/api/profile/update_nickname', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${getAuthToken()}`
        },
        body: JSON.stringify({ nickname })
      });
      
      if (!response.ok) {
        const data = await response.json();
        error = data.message || '更新失败，请重试';
        return;
      }
      
      // 成功更新昵称
      dispatch('nicknameUpdated', { nickname });
      closeDialog();
      
    } catch (err) {
      console.error('更新昵称失败:', err);
      error = '网络错误，请重试';
    } finally {
      isSubmitting = false;
    }
  }
  
  function closeDialog() {
    if (!currentNickname && !nickname.trim()) {
      // 如果是强制设置昵称（首次登录），不允许关闭
      return;
    }
    isOpen = false;
    dispatch('close');
  }
  
  function getAuthToken() {
    // 实际项目中从 Supabase 获取 JWT token
    return localStorage.getItem('supabase.auth.token') || '';
  }
  
  function handleKeydown(event: KeyboardEvent) {
    if (event.key === 'Enter' && !error && !isValidating && !isSubmitting) {
      submitNickname();
    }
    if (event.key === 'Escape') {
      closeDialog();
    }
  }
</script>

{#if isOpen}
  <!-- 背景遮罩 -->
  <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
    <div class="bg-white rounded-lg shadow-xl max-w-md w-full">
      <!-- 头部 -->
      <div class="px-6 py-4 border-b border-gray-200">
        <h3 class="text-lg font-semibold text-gray-900">
          {currentNickname ? '修改昵称' : '设置昵称'}
        </h3>
        <p class="mt-1 text-sm text-gray-600">
          {currentNickname ? '您可以修改您的昵称' : '请设置您的昵称以继续使用'}
        </p>
      </div>
      
      <!-- 内容 -->
      <div class="px-6 py-4">
        <div class="mb-4">
          <label for="nickname" class="block text-sm font-medium text-gray-700 mb-2">
            昵称
          </label>
          <input
            id="nickname"
            type="text"
            bind:value={nickname}
            on:keydown={handleKeydown}
            placeholder="请输入昵称（中文、英文、emoji）"
            class="block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 {error ? 'border-red-300' : ''}"
            maxlength="20"
          />
          
          <!-- 验证状态 -->
          <div class="mt-2 min-h-[1.25rem]">
            {#if isValidating}
              <div class="flex items-center text-sm text-gray-500">
                <svg class="animate-spin -ml-1 mr-2 h-4 w-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                  <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                  <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                </svg>
                验证中...
              </div>
            {:else if error}
              <p class="text-sm text-red-600">{error}</p>
            {:else if validationMessage}
              <p class="text-sm text-green-600">{validationMessage}</p>
            {/if}
          </div>
        </div>
        
        <!-- 规则说明 -->
        <div class="bg-blue-50 rounded-md p-3 mb-4">
          <h4 class="text-sm font-medium text-blue-900 mb-1">昵称规则</h4>
          <ul class="text-sm text-blue-700 space-y-1">
            <li>• 长度：2-20个字符</li>
            <li>• 格式：仅支持中文、英文字母和emoji</li>
            <li>• 唯一性：不能与其他用户重复</li>
          </ul>
        </div>
      </div>
      
      <!-- 底部按钮 -->
      <div class="px-6 py-4 border-t border-gray-200 flex justify-end space-x-3">
        {#if currentNickname}
          <button
            type="button"
            on:click={closeDialog}
            class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
          >
            取消
          </button>
        {/if}
        
        <button
          type="button"
          on:click={submitNickname}
          disabled={!!error || isValidating || isSubmitting || !nickname.trim()}
          class="px-4 py-2 text-sm font-medium text-white bg-blue-600 border border-transparent rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {#if isSubmitting}
            <svg class="animate-spin -ml-1 mr-2 h-4 w-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
            提交中...
          {:else}
            {currentNickname ? '更新昵称' : '设置昵称'}
          {/if}
        </button>
      </div>
    </div>
  </div>
{/if} 