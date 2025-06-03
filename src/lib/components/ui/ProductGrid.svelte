<script>
  import { createEventDispatcher } from 'svelte';
  import ProductCard from './ProductCard.svelte';
  import Loading from './Loading.svelte';
  import Button from './Button.svelte';
  
  export let products = [];
  export let loading = false;
  export let columns = 2; // 网格列数
  export let gap = 16; // 间距
  export let hasMore = true;
  export let loadingMore = false;
  export let emptyMessage = '暂无商品';
  export let emptyIcon = '🛍️';
  
  const dispatch = createEventDispatcher();
  
  function handleProductClick(event) {
    dispatch('productClick', event.detail);
  }
  
  function handleAddToCart(event) {
    dispatch('addToCart', event.detail);
  }
  
  function handleLoadMore() {
    if (!loadingMore && hasMore) {
      dispatch('loadMore');
    }
  }
  
  function handleProductAction(event) {
    dispatch('productAction', event.detail);
  }
  
  // 响应式列数调整
  function getGridColumns() {
    if (typeof window === 'undefined') return columns;
    
    const width = window.innerWidth;
    if (width < 640) return 2; // 手机端显示2列
    if (width < 768) return Math.min(columns, 3); // 平板显示最多3列
    return columns; // 桌面端使用指定列数
  }
  
  let actualColumns = columns;
  
  if (typeof window !== 'undefined') {
    actualColumns = getGridColumns();
    
    // 监听窗口大小变化
    window.addEventListener('resize', () => {
      actualColumns = getGridColumns();
    });
  }
</script>

<div class="product-grid-container">
  {#if loading}
    <div class="loading-container">
      <Loading size="lg" />
      <p class="loading-text">正在加载商品...</p>
    </div>
  {:else if products.length === 0}
    <div class="empty-state">
      <div class="empty-icon">{emptyIcon}</div>
      <h3 class="empty-title">暂无商品</h3>
      <p class="empty-message">{emptyMessage}</p>
    </div>
  {:else}
    <div 
      class="product-grid"
      style="
        grid-template-columns: repeat({actualColumns}, 1fr);
        gap: {gap}px;
      "
    >
      {#each products as product, index (product.id)}
        <div class="grid-item" style="animation-delay: {index * 50}ms;">
          <ProductCard
            {product}
            variant="grid"
            showQuickActions={true}
            on:click={handleProductClick}
            on:addToCart={handleAddToCart}
            on:action={handleProductAction}
          />
        </div>
      {/each}
    </div>
    
    <!-- 加载更多 -->
    {#if hasMore}
      <div class="load-more-section">
        {#if loadingMore}
          <div class="loading-more">
            <Loading size="sm" />
            <span>加载更多商品...</span>
          </div>
        {:else}
          <Button
            variant="outline"
            size="lg"
            fullWidth
            on:click={handleLoadMore}
          >
            加载更多商品
          </Button>
        {/if}
      </div>
    {:else if products.length > 0}
      <div class="end-message">
        <span class="end-icon">🎉</span>
        <span class="end-text">已显示全部商品</span>
      </div>
    {/if}
  {/if}
</div>

<style>
  .product-grid-container {
    width: 100%;
  }
  
  /* 加载状态 */
  .loading-container {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 60px 20px;
    gap: 16px;
  }
  
  .loading-text {
    font-size: 14px;
    color: #6b7280;
    margin: 0;
  }
  
  /* 空状态 */
  .empty-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 60px 20px;
    text-align: center;
  }
  
  .empty-icon {
    font-size: 48px;
    margin-bottom: 16px;
    opacity: 0.5;
  }
  
  .empty-title {
    font-size: 20px;
    font-weight: 600;
    color: #111827;
    margin: 0 0 8px 0;
  }
  
  .empty-message {
    font-size: 14px;
    color: #6b7280;
    margin: 0;
    max-width: 280px;
    line-height: 1.5;
  }
  
  /* 商品网格 */
  .product-grid {
    display: grid;
    width: 100%;
  }
  
  .grid-item {
    opacity: 0;
    transform: translateY(20px);
    animation: fadeInUp 0.4s ease forwards;
  }
  
  @keyframes fadeInUp {
    to {
      opacity: 1;
      transform: translateY(0);
    }
  }
  
  /* 加载更多部分 */
  .load-more-section {
    margin-top: 32px;
    padding: 0 16px;
  }
  
  .loading-more {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 12px;
    padding: 20px;
    color: #6b7280;
    font-size: 14px;
  }
  
  .end-message {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 8px;
    padding: 24px;
    margin-top: 16px;
    font-size: 14px;
    color: #6b7280;
  }
  
  .end-icon {
    font-size: 16px;
  }
  
  .end-text {
    font-weight: 500;
  }
  
  /* 移动端适配 */
  @media (max-width: 640px) {
    .product-grid {
      padding: 0 4px;
    }
    
    .loading-container,
    .empty-state {
      padding: 40px 20px;
    }
    
    .empty-icon {
      font-size: 40px;
    }
    
    .empty-title {
      font-size: 18px;
    }
    
    .load-more-section {
      margin-top: 24px;
      padding: 0 8px;
    }
    
    .grid-item {
      animation-delay: 0ms !important;
    }
  }
  
  /* 平板端适配 */
  @media (min-width: 641px) and (max-width: 1024px) {
    .product-grid {
      padding: 0 8px;
    }
    
    .load-more-section {
      padding: 0 12px;
    }
  }
  
  /* 桌面端优化 */
  @media (min-width: 1025px) {
    .product-grid {
      gap: 20px;
    }
    
    .load-more-section {
      margin-top: 40px;
    }
    
    .grid-item:hover {
      transform: translateY(-4px);
      transition: transform 0.3s ease;
    }
    
    .grid-item:hover :global(.product-card) {
      box-shadow: 0 12px 28px rgba(0, 0, 0, 0.12);
    }
  }
  
  /* 网格响应式断点 */
  @media (max-width: 480px) {
    .product-grid {
      grid-template-columns: repeat(2, 1fr) !important;
      gap: 12px !important;
    }
  }
  
  @media (min-width: 481px) and (max-width: 768px) {
    .product-grid {
      grid-template-columns: repeat(2, 1fr) !important;
      gap: 16px !important;
    }
  }
  
  @media (min-width: 769px) and (max-width: 1024px) {
    .product-grid {
      grid-template-columns: repeat(3, 1fr) !important;
      gap: 18px !important;
    }
  }
  
  /* 骨架屏效果 */
  @media (prefers-reduced-motion: reduce) {
    .grid-item {
      animation: none;
      opacity: 1;
      transform: none;
    }
  }
  
  /* 无障碍优化 */
  @media (prefers-contrast: high) {
    .empty-state {
      border: 2px solid #000;
      border-radius: 12px;
      background: #fff;
    }
    
    .empty-title {
      color: #000;
    }
    
    .empty-message {
      color: #333;
    }
  }
</style> 