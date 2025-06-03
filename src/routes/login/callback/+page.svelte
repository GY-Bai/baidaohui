<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { page } from '$app/stores';
  import { handleAuthCallback, redirectToRolePath, refreshUserRole } from '$lib/auth';

  export let data;

  let loading = true;
  let error = '';

  onMount(async () => {
    try {
      console.log('🔄 回调页面：开始处理认证回调...');
      console.log('📊 回调页面：接收到的数据:', { code: data.code, url: window.location.href });
      
      // 🚀 第一步：使用专门的回调处理函数（已优化为查询最新角色）
      const session = await handleAuthCallback();
      
      if (session) {
        console.log('✅ 回调页面：成功获取会话');
        console.log(`   用户ID: ${session.id}`);
        console.log(`   邮箱: ${session.email}`);
        console.log(`   角色: ${session.role}`);
        console.log(`   昵称: ${session.nickname || '未设置'}`);
        
        // 🎯 额外验证：强制刷新一次角色以确保最新
        console.log('🔍 回调页面：执行二次角色验证...');
        const refreshedSession = await refreshUserRole();
        
        if (refreshedSession && refreshedSession.role !== session.role) {
          console.log(`🔄 回调页面：检测到角色更新 ${session.role} -> ${refreshedSession.role}`);
          redirectToRolePath(refreshedSession.role);
        } else {
          console.log('✅ 回调页面：角色验证完成，开始重定向');
          redirectToRolePath(session.role);
        }
        return;
      }

      // 如果没有会话，尝试使用服务端提供的授权码
      if (data.code) {
        console.log('🔑 回调页面：使用授权码交换会话...');
        const { supabase } = await import('$lib/auth');
        const { error: authError } = await supabase.auth.exchangeCodeForSession(data.code);
        
        if (authError) {
          console.error('❌ 回调页面：授权码交换失败:', authError);
          error = '认证失败: ' + authError.message;
          setTimeout(() => {
            goto('/login?error=auth_failed&message=' + encodeURIComponent(error));
          }, 2000);
          return;
        }

        // 重新获取会话（现在已优化为查询最新角色）
        console.log('🔄 回调页面：授权码交换成功，重新获取会话...');
        const newSession = await handleAuthCallback();
        if (newSession) {
          console.log('✅ 回调页面：授权码交换成功');
          console.log(`   用户ID: ${newSession.id}`);
          console.log(`   邮箱: ${newSession.email}`);
          console.log(`   角色: ${newSession.role}`);
          
          // 🎯 同样进行二次验证
          const refreshedSession = await refreshUserRole();
          if (refreshedSession && refreshedSession.role !== newSession.role) {
            console.log(`🔄 回调页面：检测到角色更新 ${newSession.role} -> ${refreshedSession.role}`);
            redirectToRolePath(refreshedSession.role);
          } else {
            redirectToRolePath(newSession.role);
          }
          return;
        }
      }

      // 如果还是没有会话，返回登录页
      console.log('⚠️ 回调页面：无法获取有效会话，返回登录页面');
      setTimeout(() => {
        goto('/login?error=no_session&message=' + encodeURIComponent('未找到有效登录会话'));
      }, 1500);
      
    } catch (err) {
      error = '登录过程中出现错误';
      console.error('❌ 回调页面：处理错误:', err);
      setTimeout(() => {
        goto('/login?error=callback_error&message=' + encodeURIComponent(error));
      }, 2000);
    } finally {
      loading = false;
    }
  });
</script>

<svelte:head>
  <title>登录中... - 百刀会</title>
</svelte:head>

<div class="min-h-screen flex items-center justify-center bg-gradient-to-br from-blue-50 to-indigo-100">
  <div class="text-center">
    {#if loading}
      <div class="mb-4">
        <svg class="animate-spin h-12 w-12 text-blue-600 mx-auto" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
      </div>
      <h2 class="text-2xl font-semibold text-gray-900 mb-2">正在验证登录...</h2>
      <p class="text-gray-600">请稍候，正在通过Supabase验证您的身份</p>
    {:else if error}
      <div class="mb-4">
        <svg class="h-12 w-12 text-red-600 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z"></path>
        </svg>
      </div>
      <h2 class="text-2xl font-semibold text-red-900 mb-2">登录失败</h2>
      <p class="text-red-600 mb-4">{error}</p>
      <p class="text-gray-600">正在返回登录页面...</p>
    {:else}
      <div class="mb-4">
        <svg class="h-12 w-12 text-yellow-600 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z"></path>
        </svg>
      </div>
      <h2 class="text-2xl font-semibold text-gray-900 mb-2">正在重定向...</h2>
      <p class="text-gray-600">正在返回登录页面</p>
    {/if}
  </div>
</div> 