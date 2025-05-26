<script lang="ts">
  import { onMount } from 'svelte';
  
  onMount(() => {
    console.log('商店页面加载完成');
  });
</script>

<svelte:head>
  <title>百刀会 - 商店</title>
  <meta name="description" content="百刀会好物推荐" />
</svelte:head>

<div class="container">
  <h1>🛍️ 好物推荐</h1>
  <p>商店功能正在开发中...</p>
</div>

<style>
  .container {
    padding: 2rem;
    text-align: center;
  }
  
  h1 {
    color: #333;
    margin-bottom: 1rem;
  }
  
  p {
    color: #666;
  }
</style> 