<script>
  import '../app.css';
  import NavBar from '$shared/components/NavBar.svelte';
  import NicknameDialog from '$shared/components/NicknameDialog.svelte';
  import { onMount } from 'svelte';
  
  let userRole = 'fan';
  let userName = '';
  let showNicknameDialog = false;
  
  onMount(() => {
    // 检查用户信息和昵称
    checkUserProfile();
  });
  
  async function checkUserProfile() {
    try {
      // 从 localStorage 或 API 获取用户信息
      const userStr = localStorage.getItem('currentUser');
      if (userStr) {
        const user = JSON.parse(userStr);
        userName = user.nickname || '';
        
        // 如果没有昵称，显示设置对话框
        if (!userName) {
          showNicknameDialog = true;
        }
      }
    } catch (error) {
      console.error('检查用户信息失败:', error);
    }
  }
  
  function handleNicknameUpdated(event) {
    userName = event.detail.nickname;
    // 更新 localStorage
    const userStr = localStorage.getItem('currentUser');
    if (userStr) {
      const user = JSON.parse(userStr);
      user.nickname = userName;
      localStorage.setItem('currentUser', JSON.stringify(user));
    }
  }
</script>

<svelte:head>
  <title>百刀会 - Fan</title>
</svelte:head>

<div class="min-h-screen bg-gray-50">
  <NavBar {userRole} {userName} />
  
  <main>
    <slot />
  </main>
  
  <!-- 昵称设置对话框 -->
  <NicknameDialog 
    bind:isOpen={showNicknameDialog}
    currentNickname={userName}
    on:nicknameUpdated={handleNicknameUpdated}
    on:close={() => showNicknameDialog = false}
  />
</div> 