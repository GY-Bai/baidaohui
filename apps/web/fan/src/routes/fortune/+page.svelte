<script lang="ts">
  import { onMount } from 'svelte';
  
  onMount(() => {
    console.log('算命页面加载完成');
  });
</script>

<svelte:head>
  <title>百刀会 - 算命</title>
  <meta name="description" content="百刀会算命服务" />
</svelte:head>

<div class="container">
  <h1>🔮 算命服务</h1>
  <p>算命功能正在开发中...</p>
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