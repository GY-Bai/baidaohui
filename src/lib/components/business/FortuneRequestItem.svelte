<script>
  import { createEventDispatcher } from 'svelte';
  import Badge from '$lib/components/ui/Badge.svelte';
  import Avatar from '$lib/components/ui/Avatar.svelte';
  
  export let id = '';
  export let title = '';
  export let category = '';
  export let description = '';
  export let status = 'pending'; // pending, processing, completed, cancelled
  export let urgency = 'normal'; // low, normal, high
  export let budget = '';
  export let createdAt = '';
  export let userAvatar = '';
  export let userName = '';
  export let queuePosition = null;
  export let estimatedTime = '';
  
  const dispatch = createEventDispatcher();
  
  const statusMap = {
    pending: { label: '等待中', color: 'yellow', icon: '⏳' },
    processing: { label: '处理中', color: 'blue', icon: '🔮' },
    completed: { label: '已完成', color: 'green', icon: '✅' },
    cancelled: { label: '已取消', color: 'red', icon: '❌' }
  };
  
  const urgencyMap = {
    low: { label: '不急', color: 'gray' },
    normal: { label: '一般', color: 'blue' },
    high: { label: '急需', color: 'red' }
  };
  
  function handleClick() {
    dispatch('click', { id });
  }
  
  function handleAction(action) {
    dispatch('action', { id, action });
  }
  
  function formatTime(timeStr) {
    if (!timeStr) return '';
    const date = new Date(timeStr);
    const now = new Date();
    const diff = now - date;
    const hours = Math.floor(diff / (1000 * 60 * 60));
    const days = Math.floor(hours / 24);
    
    if (days > 0) return `${days}天前`;
    if (hours > 0) return `${hours}小时前`;
    return '刚刚';
  }
</script>

<article 
  class="fortune-request-item"
  on:click={handleClick}
  on:keypress={(e) => e.key === 'Enter' && handleClick()}
  role="button"
  tabindex="0"
>
  <!-- 头部信息 -->
  <header class="item-header">
    <div class="user-info">
      <Avatar 
        src={userAvatar} 
        alt={userName}
        size="sm"
        showOnlineStatus={false}
      />
      <div class="user-details">
        <h3 class="user-name">{userName}</h3>
        <p class="time-ago">{formatTime(createdAt)}</p>
      </div>
    </div>
    
    <div class="status-badges">
      <Badge 
        variant={statusMap[status].color}
        size="sm"
      >
        {statusMap[status].icon} {statusMap[status].label}
      </Badge>
      
      {#if urgency !== 'normal'}
        <Badge 
          variant={urgencyMap[urgency].color}
          size="sm"
        >
          {urgencyMap[urgency].label}
        </Badge>
      {/if}
    </div>
  </header>
  
  <!-- 主要内容 -->
  <main class="item-content">
    <div class="content-header">
      <h2 class="title">{title}</h2>
      <span class="category">{category}</span>
    </div>
    
    <p class="description">{description}</p>
    
    <!-- 排队信息 -->
    {#if status === 'pending' && queuePosition}
      <div class="queue-info">
        <span class="queue-icon">🎯</span>
        <span class="queue-text">排队第 {queuePosition} 位</span>
        {#if estimatedTime}
          <span class="estimated-time">预计 {estimatedTime}</span>
        {/if}
      </div>
    {/if}
  </main>
  
  <!-- 底部信息 -->
  <footer class="item-footer">
    <div class="budget-info">
      <span class="budget-label">预算</span>
      <span class="budget-value">{budget}</span>
    </div>
    
    <div class="actions">
      {#if status === 'pending'}
        <button 
          class="action-btn secondary" 
          on:click|stopPropagation={() => handleAction('edit')}
        >
          编辑
        </button>
        <button 
          class="action-btn danger" 
          on:click|stopPropagation={() => handleAction('cancel')}
        >
          取消
        </button>
      {:else if status === 'completed'}
        <button 
          class="action-btn primary" 
          on:click|stopPropagation={() => handleAction('view')}
        >
          查看结果
        </button>
      {:else if status === 'processing'}
        <button 
          class="action-btn secondary" 
          on:click|stopPropagation={() => handleAction('contact')}
        >
          联系大师
        </button>
      {/if}
    </div>
  </footer>
</article>

<style>
  .fortune-request-item {
    background: white;
    border-radius: 16px;
    padding: 20px;
    margin-bottom: 16px;
    box-shadow: 0 2px 12px rgba(0, 0, 0, 0.08);
    border: 1px solid rgba(0, 0, 0, 0.04);
    cursor: pointer;
    transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
    position: relative;
    overflow: hidden;
  }
  
  .fortune-request-item:hover {
    transform: translateY(-2px);
    box-shadow: 0 8px 24px rgba(0, 0, 0, 0.12);
  }
  
  .fortune-request-item:active {
    transform: translateY(0);
  }
  
  /* 头部信息 */
  .item-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    margin-bottom: 16px;
  }
  
  .user-info {
    display: flex;
    align-items: center;
    gap: 12px;
  }
  
  .user-details {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }
  
  .user-name {
    font-size: 14px;
    font-weight: 600;
    color: #1f2937;
    margin: 0;
  }
  
  .time-ago {
    font-size: 12px;
    color: #6b7280;
    margin: 0;
  }
  
  .status-badges {
    display: flex;
    gap: 8px;
    flex-wrap: wrap;
  }
  
  /* 主要内容 */
  .item-content {
    margin-bottom: 16px;
  }
  
  .content-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    margin-bottom: 8px;
    gap: 12px;
  }
  
  .title {
    font-size: 16px;
    font-weight: 600;
    color: #111827;
    margin: 0;
    line-height: 1.4;
    flex: 1;
  }
  
  .category {
    font-size: 12px;
    color: #667eea;
    background: rgba(102, 126, 234, 0.1);
    padding: 4px 8px;
    border-radius: 8px;
    white-space: nowrap;
    font-weight: 500;
  }
  
  .description {
    font-size: 14px;
    color: #4b5563;
    line-height: 1.5;
    margin: 0 0 12px 0;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
  }
  
  .queue-info {
    display: flex;
    align-items: center;
    gap: 8px;
    background: rgba(59, 130, 246, 0.05);
    padding: 8px 12px;
    border-radius: 12px;
    border-left: 3px solid #3b82f6;
  }
  
  .queue-icon {
    font-size: 14px;
  }
  
  .queue-text {
    font-size: 13px;
    font-weight: 600;
    color: #1e40af;
  }
  
  .estimated-time {
    font-size: 13px;
    color: #6b7280;
    margin-left: auto;
  }
  
  /* 底部信息 */
  .item-footer {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 16px;
  }
  
  .budget-info {
    display: flex;
    align-items: center;
    gap: 8px;
  }
  
  .budget-label {
    font-size: 12px;
    color: #6b7280;
  }
  
  .budget-value {
    font-size: 14px;
    font-weight: 600;
    color: #059669;
  }
  
  .actions {
    display: flex;
    gap: 8px;
  }
  
  .action-btn {
    padding: 6px 12px;
    border-radius: 8px;
    font-size: 13px;
    font-weight: 500;
    border: none;
    cursor: pointer;
    transition: all 0.2s ease;
    min-width: 60px;
  }
  
  .action-btn.primary {
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    color: white;
  }
  
  .action-btn.primary:hover {
    box-shadow: 0 4px 12px rgba(102, 126, 234, 0.3);
  }
  
  .action-btn.secondary {
    background: #f3f4f6;
    color: #4b5563;
  }
  
  .action-btn.secondary:hover {
    background: #e5e7eb;
  }
  
  .action-btn.danger {
    background: #fef2f2;
    color: #dc2626;
  }
  
  .action-btn.danger:hover {
    background: #fee2e2;
  }
  
  /* 移动端适配 */
  @media (max-width: 640px) {
    .fortune-request-item {
      padding: 16px;
      margin-bottom: 12px;
      border-radius: 12px;
    }
    
    .item-header {
      margin-bottom: 12px;
    }
    
    .status-badges {
      flex-direction: column;
      align-items: flex-end;
    }
    
    .content-header {
      flex-direction: column;
      align-items: flex-start;
      gap: 8px;
    }
    
    .category {
      align-self: flex-start;
    }
    
    .item-footer {
      flex-direction: column;
      gap: 12px;
      align-items: stretch;
    }
    
    .actions {
      justify-content: flex-end;
    }
    
    .action-btn {
      flex: 1;
      max-width: 80px;
    }
  }
</style> 