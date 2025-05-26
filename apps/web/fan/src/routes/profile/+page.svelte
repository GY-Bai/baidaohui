<script lang="ts">
  import { onMount } from 'svelte';
  
  onMount(() => {
    console.log('个人资料页面加载完成');
  });
</script>

<svelte:head>
  <title>百刀会 - 个人资料</title>
  <meta name="description" content="百刀会个人资料" />
</svelte:head>

<div class="container">
  <h1>👤 个人资料</h1>
  <p>个人资料功能正在开发中...</p>
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