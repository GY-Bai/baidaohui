<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import Button from './Button.svelte';
  import Input from './Input.svelte';
  import Select from './Select.svelte';
  
  export let current = 1;
  export let total = 0;
  export let pageSize = 10;
  export let showSizeChanger = true;
  export let showQuickJumper = true;
  export let showTotal = true;
  export let size = 'default'; // small, default, large
  export let disabled = false;
  export let hideOnSinglePage = false;
  export let pageSizeOptions = [10, 20, 50, 100];
  export let showLessItems = false;
  export let simple = false;
  
  const dispatch = createEventDispatcher();
  
  let jumpPage = '';
  
  // 计算属性
  $: totalPages = Math.ceil(total / pageSize);
  $: startRecord = Math.min((current - 1) * pageSize + 1, total);
  $: endRecord = Math.min(current * pageSize, total);
  $: canGoPrev = current > 1;
  $: canGoNext = current < totalPages;
  $: shouldHide = hideOnSinglePage && totalPages <= 1;
  
  // 生成页码数组
  $: pageNumbers = generatePageNumbers();
  
  function generatePageNumbers() {
    if (totalPages <= 1) return [];
    
    const maxVisible = showLessItems ? 5 : 7;
    const pages = [];
    
    if (totalPages <= maxVisible) {
      // 总页数不超过最大显示数，显示所有页码
      for (let i = 1; i <= totalPages; i++) {
        pages.push(i);
      }
    } else {
      // 总页数超过最大显示数，需要省略
      const half = Math.floor(maxVisible / 2);
      let start = Math.max(1, current - half);
      let end = Math.min(totalPages, start + maxVisible - 1);
      
      if (end - start < maxVisible - 1) {
        start = Math.max(1, end - maxVisible + 1);
      }
      
      // 添加首页
      if (start > 1) {
        pages.push(1);
        if (start > 2) {
          pages.push('...');
        }
      }
      
      // 添加中间页码
      for (let i = start; i <= end; i++) {
        pages.push(i);
      }
      
      // 添加末页
      if (end < totalPages) {
        if (end < totalPages - 1) {
          pages.push('...');
        }
        pages.push(totalPages);
      }
    }
    
    return pages;
  }
  
  function handlePageChange(page) {
    if (page === current || page < 1 || page > totalPages || disabled) {
      return;
    }
    
    dispatch('change', {
      current: page,
      pageSize,
      total
    });
  }
  
  function handlePageSizeChange(newPageSize) {
    const newCurrent = Math.min(current, Math.ceil(total / newPageSize));
    
    dispatch('change', {
      current: newCurrent,
      pageSize: newPageSize,
      total
    });
  }
  
  function handleQuickJump() {
    const page = parseInt(jumpPage);
    if (isNaN(page) || page < 1 || page > totalPages) {
      jumpPage = '';
      return;
    }
    
    handlePageChange(page);
    jumpPage = '';
  }
  
  function handleJumpKeydown(event) {
    if (event.key === 'Enter') {
      handleQuickJump();
    }
  }
  
  function handlePrevPage() {
    if (canGoPrev) {
      handlePageChange(current - 1);
    }
  }
  
  function handleNextPage() {
    if (canGoNext) {
      handlePageChange(current + 1);
    }
  }
  
  function handleFirstPage() {
    handlePageChange(1);
  }
  
  function handleLastPage() {
    handlePageChange(totalPages);
  }
</script>

{#if !shouldHide}
  <div class="pagination" class:simple class:size-small={size === 'small'} class:size-large={size === 'large'} class:disabled>
    {#if simple}
      <!-- 简单模式 -->
      <div class="simple-pagination">
        <Button
          variant="outline"
          size={size === 'small' ? 'xs' : size === 'large' ? 'md' : 'sm'}
          {disabled}
          on:click={handlePrevPage}
          disabled={disabled || !canGoPrev}
        >
          ← 上一页
        </Button>
        
        <div class="simple-info">
          <Input
            bind:value={jumpPage}
            placeholder={current.toString()}
            size={size === 'small' ? 'xs' : 'sm'}
            style="width: 60px; text-align: center;"
            on:keydown={handleJumpKeydown}
            on:blur={handleQuickJump}
          />
          <span class="simple-divider">/</span>
          <span class="simple-total">{totalPages}</span>
        </div>
        
        <Button
          variant="outline"
          size={size === 'small' ? 'xs' : size === 'large' ? 'md' : 'sm'}
          {disabled}
          on:click={handleNextPage}
          disabled={disabled || !canGoNext}
        >
          下一页 →
        </Button>
      </div>
    {:else}
      <!-- 完整模式 -->
      <div class="pagination-content">
        <!-- 总数信息 -->
        {#if showTotal}
          <div class="pagination-total">
            共 {total} 条记录，第 {startRecord}-{endRecord} 条
          </div>
        {/if}
        
        <!-- 页码控制 -->
        <div class="pagination-pages">
          <!-- 上一页 -->
          <button
            class="page-btn prev-btn"
            class:disabled={!canGoPrev || disabled}
            on:click={handlePrevPage}
            disabled={!canGoPrev || disabled}
            title="上一页"
          >
            <span class="page-icon">‹</span>
          </button>
          
          <!-- 页码列表 -->
          <div class="page-list">
            {#each pageNumbers as page}
              {#if page === '...'}
                <span class="page-ellipsis">...</span>
              {:else}
                <button
                  class="page-btn page-number"
                  class:active={page === current}
                  class:disabled
                  on:click={() => handlePageChange(page)}
                  {disabled}
                >
                  {page}
                </button>
              {/if}
            {/each}
          </div>
          
          <!-- 下一页 -->
          <button
            class="page-btn next-btn"
            class:disabled={!canGoNext || disabled}
            on:click={handleNextPage}
            disabled={!canGoNext || disabled}
            title="下一页"
          >
            <span class="page-icon">›</span>
          </button>
        </div>
        
        <!-- 页面大小选择 -->
        {#if showSizeChanger}
          <div class="page-size-changer">
            <span class="size-label">每页</span>
            <Select
              value={pageSize}
              options={pageSizeOptions.map(size => ({ value: size, label: `${size} 条` }))}
              size={size === 'small' ? 'xs' : 'sm'}
              on:change={(e) => handlePageSizeChange(e.detail.value)}
              {disabled}
            />
          </div>
        {/if}
        
        <!-- 快速跳转 -->
        {#if showQuickJumper}
          <div class="quick-jumper">
            <span class="jumper-label">跳至</span>
            <Input
              bind:value={jumpPage}
              placeholder="页码"
              size={size === 'small' ? 'xs' : 'sm'}
              style="width: 60px;"
              on:keydown={handleJumpKeydown}
              on:blur={handleQuickJump}
              {disabled}
            />
            <span class="jumper-label">页</span>
          </div>
        {/if}
      </div>
    {/if}
  </div>
{/if}

<style>
  .pagination {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 16px;
    font-size: 14px;
    user-select: none;
  }
  
  .pagination.size-small {
    font-size: 12px;
    gap: 12px;
  }
  
  .pagination.size-large {
    font-size: 16px;
    gap: 20px;
  }
  
  .pagination.disabled {
    opacity: 0.6;
    pointer-events: none;
  }
  
  /* 简单模式 */
  .simple-pagination {
    display: flex;
    align-items: center;
    gap: 12px;
  }
  
  .simple-info {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 14px;
    color: #6b7280;
  }
  
  .simple-divider {
    color: #9ca3af;
  }
  
  .simple-total {
    font-weight: 500;
  }
  
  /* 完整模式 */
  .pagination-content {
    display: flex;
    align-items: center;
    gap: 16px;
    flex-wrap: wrap;
  }
  
  .pagination-total {
    color: #6b7280;
    font-size: 13px;
    white-space: nowrap;
  }
  
  .pagination-pages {
    display: flex;
    align-items: center;
    gap: 4px;
  }
  
  .page-list {
    display: flex;
    align-items: center;
    gap: 4px;
  }
  
  /* 页码按钮 */
  .page-btn {
    display: flex;
    align-items: center;
    justify-content: center;
    min-width: 32px;
    height: 32px;
    padding: 0 8px;
    border: 1px solid #e5e7eb;
    border-radius: 6px;
    background: white;
    color: #374151;
    font-size: inherit;
    font-weight: 500;
    cursor: pointer;
    transition: all 0.2s ease;
    user-select: none;
  }
  
  .size-small .page-btn {
    min-width: 28px;
    height: 28px;
    padding: 0 6px;
    border-radius: 5px;
  }
  
  .size-large .page-btn {
    min-width: 36px;
    height: 36px;
    padding: 0 10px;
    border-radius: 8px;
  }
  
  .page-btn:hover:not(.disabled):not(.active) {
    border-color: #667eea;
    color: #667eea;
    background: #f8fafc;
  }
  
  .page-btn.active {
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    border-color: #667eea;
    color: white;
    box-shadow: 0 2px 8px rgba(102, 126, 234, 0.3);
  }
  
  .page-btn.disabled {
    opacity: 0.4;
    cursor: not-allowed;
    border-color: #f3f4f6;
    color: #9ca3af;
    background: #f9fafb;
  }
  
  .page-icon {
    font-size: 16px;
    line-height: 1;
  }
  
  .page-ellipsis {
    display: flex;
    align-items: center;
    justify-content: center;
    min-width: 32px;
    height: 32px;
    color: #9ca3af;
    font-weight: 500;
  }
  
  .size-small .page-ellipsis {
    min-width: 28px;
    height: 28px;
  }
  
  .size-large .page-ellipsis {
    min-width: 36px;
    height: 36px;
  }
  
  /* 页面大小选择器 */
  .page-size-changer {
    display: flex;
    align-items: center;
    gap: 8px;
    white-space: nowrap;
  }
  
  .size-label {
    color: #6b7280;
    font-size: 13px;
  }
  
  /* 快速跳转 */
  .quick-jumper {
    display: flex;
    align-items: center;
    gap: 8px;
    white-space: nowrap;
  }
  
  .jumper-label {
    color: #6b7280;
    font-size: 13px;
  }
  
  /* 移动端适配 */
  @media (max-width: 768px) {
    .pagination {
      gap: 12px;
    }
    
    .pagination-content {
      flex-direction: column;
      gap: 12px;
      align-items: center;
    }
    
    .pagination-total {
      order: 3;
    }
    
    .pagination-pages {
      order: 1;
    }
    
    .page-size-changer,
    .quick-jumper {
      order: 2;
    }
    
    .page-btn {
      min-width: 36px;
      height: 36px;
      touch-action: manipulation;
    }
    
    .page-list {
      gap: 2px;
    }
    
    /* 隐藏部分功能以节省空间 */
    .pagination-total {
      font-size: 12px;
    }
    
    .page-size-changer,
    .quick-jumper {
      font-size: 12px;
    }
  }
  
  @media (max-width: 480px) {
    .pagination-content {
      gap: 8px;
    }
    
    .page-btn {
      min-width: 32px;
      height: 32px;
      padding: 0 4px;
    }
    
    .page-ellipsis {
      min-width: 24px;
      height: 32px;
    }
    
    /* 在极小屏幕上隐藏部分功能 */
    .quick-jumper {
      display: none;
    }
  }
  
  /* 焦点样式 */
  .page-btn:focus-visible {
    outline: none;
    box-shadow: 0 0 0 2px rgba(102, 126, 234, 0.3);
  }
  
  /* 高对比度模式 */
  @media (prefers-contrast: high) {
    .page-btn {
      border-width: 2px;
    }
    
    .page-btn.active {
      border-width: 2px;
      border-color: #1e3a8a;
    }
  }
  
  /* 减少动画模式 */
  @media (prefers-reduced-motion: reduce) {
    .page-btn {
      transition: none;
    }
  }
  
  /* 深色模式 */
  @media (prefers-color-scheme: dark) {
    .pagination-total,
    .size-label,
    .jumper-label {
      color: #d1d5db;
    }
    
    .simple-info {
      color: #d1d5db;
    }
    
    .simple-divider {
      color: #9ca3af;
    }
    
    .page-btn {
      background: #374151;
      border-color: #4b5563;
      color: #f9fafb;
    }
    
    .page-btn:hover:not(.disabled):not(.active) {
      background: #4b5563;
      border-color: #667eea;
    }
    
    .page-btn.disabled {
      background: #1f2937;
      border-color: #374151;
      color: #6b7280;
    }
    
    .page-ellipsis {
      color: #6b7280;
    }
  }
</style> 