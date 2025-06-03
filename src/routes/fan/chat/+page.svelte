<script lang="ts">
  import InfoCard from '$lib/components/business/InfoCard.svelte';
  
  function handleUpgrade() {
    console.log('完成会员认证');
    // 这里可以跳转到会员认证页面
  }
  
  function handleLearnMore() {
    console.log('了解更多会员权益');
    // 这里可以跳转到会员权益说明页面
  }
</script>

<svelte:head>
  <title>私信功能 - 百刀会</title>
</svelte:head>

<div class="chat-view">
  <InfoCard
    on:primaryAction={handleUpgrade}
    on:secondaryAction={handleLearnMore}
  />
</div>

<style>
  .chat-view {
    display: flex;
    align-items: center;
    justify-content: center;
    min-height: 60vh;
    padding: 40px 20px;
  }
  
  /* 响应式优化 */
  @media (max-width: 480px) {
    .chat-view {
      padding: 20px 16px;
    }
  }
</style> 