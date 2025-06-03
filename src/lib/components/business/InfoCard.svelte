<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import Button from '$lib/components/ui/Button.svelte';
  
  const dispatch = createEventDispatcher();
  
  export let title = '私信功能需要会员权限';
  export let description = '升级为会员即可享受以下特权：';
  export let features = [
    { icon: '💬', text: '与主播实时私聊' },
    { icon: '⚡', text: '优先获得算命回复' },
    { icon: '🎁', text: '专属会员礼品' },
    { icon: '📱', text: '手机App专享功能' }
  ];
  export let primaryButtonText = '完成会员认证';
  export let secondaryButtonText = '了解更多会员权益';
  export let icon = '🔒';
  
  function handlePrimaryAction() {
    dispatch('primaryAction');
  }
  
  function handleSecondaryAction() {
    dispatch('secondaryAction');
  }
</script>

<div class="permission-card">
  <div class="permission-icon">{icon}</div>
  <h2>{title}</h2>
  <p>{description}</p>
  
  <ul class="feature-list">
    {#each features as feature}
      <li>
        <span class="feature-icon">{feature.icon}</span>
        <span>{feature.text}</span>
      </li>
    {/each}
  </ul>
  
  <div class="upgrade-actions">
    <Button variant="primary" size="lg" fullWidth on:click={handlePrimaryAction}>
      {primaryButtonText}
    </Button>
    <Button variant="text" size="md" on:click={handleSecondaryAction}>
      {secondaryButtonText}
    </Button>
  </div>
</div>

<style>
  .permission-card {
    background: white;
    border-radius: 16px;
    padding: 40px 32px;
    text-align: center;
    box-shadow: 0 4px 20px rgba(0, 0, 0, 0.1);
    max-width: 400px;
    width: 100%;
  }
  
  .permission-icon {
    font-size: 64px;
    margin-bottom: 24px;
  }
  
  .permission-card h2 {
    margin: 0 0 16px 0;
    font-size: 24px;
    font-weight: 700;
    color: #374151;
  }
  
  .permission-card p {
    margin: 0 0 24px 0;
    color: #6b7280;
    line-height: 1.5;
  }
  
  .feature-list {
    list-style: none;
    padding: 0;
    margin: 0 0 32px 0;
    text-align: left;
  }
  
  .feature-list li {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 12px 0;
    border-bottom: 1px solid #f3f4f6;
  }
  
  .feature-list li:last-child {
    border-bottom: none;
  }
  
  .feature-icon {
    font-size: 20px;
    flex-shrink: 0;
  }
  
  .upgrade-actions {
    display: flex;
    flex-direction: column;
    gap: 12px;
  }
  
  /* 响应式优化 */
  @media (max-width: 480px) {
    .permission-card {
      padding: 32px 24px;
    }
    
    .permission-card h2 {
      font-size: 20px;
    }
  }
  
  /* 深色模式 */
  @media (prefers-color-scheme: dark) {
    .permission-card {
      background: #1f2937;
    }
    
    .permission-card h2 {
      color: #f3f4f6;
    }
    
    .feature-list li {
      border-bottom-color: #374151;
    }
  }
</style> 