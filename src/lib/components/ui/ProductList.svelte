<script>
  import { createEventDispatcher } from 'svelte';
  import Loading from './Loading.svelte';
  import Button from './Button.svelte';
  import Badge from './Badge.svelte';
  
  export let products = [];
  export let loading = false;
  export let hasMore = true;
  export let loadingMore = false;
  export let emptyMessage = '暂无商品';
  export let emptyIcon = '📦';
  export let showCompactMode = false;
  
  const dispatch = createEventDispatcher();
  
  function handleProductClick(product) {
    dispatch('productClick', { product });
  }
  
  function handleAddToCart(product) {
    dispatch('addToCart', { product });
  }
  
  function handleLoadMore() {
    if (!loadingMore && hasMore) {
      dispatch('loadMore');
    }
  }
  
  function handleProductAction(action, product) {
    dispatch('productAction', { action, product });
  }
  
  function formatPrice(price) {
    return `¥${price.toFixed(2)}`;
  }
  
  function getStockStatus(stock) {
    if (stock === 0) return { text: '缺货', variant: 'red' };
    if (stock < 10) return { text: '库存紧张', variant: 'yellow' };
    return { text: '有库存', variant: 'green' };
  }
</script>

<div class="product-list-container">
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
    <div class="product-list" class:compact={showCompactMode}>
      {#each products as product, index}
        {@const stockStatus = getStockStatus(product.stock)}
        <article 
          class="product-item"
          class:compact={showCompactMode}
          style="animation-delay: {index * 0.1}s"
          on:click={() => handleProductClick(product)}
          role="button"
          tabindex="0"
          on:keydown={(e) => e.key === 'Enter' && handleProductClick(product)}
        >
          <!-- 商品图片 -->
          <div class="product-image">
            <img 
              src={product.images?.[0] || '/placeholder-product.jpg'} 
              alt={product.title}
              loading="lazy"
            />
            {#if product.badge}
              <div class="product-badge {product.badge.type}">
                {product.badge.text}
              </div>
            {/if}
          </div>
          
          <!-- 商品信息 -->
          <div class="product-info">
            <div class="product-header">
              <h3 class="product-title">{product.title}</h3>
              {#if product.store}
                <div class="store-info">
                  <span class="store-name">{product.store.name}</span>
                  {#if product.store.verified}
                    <span class="verified-badge">✓</span>
                  {/if}
                </div>
              {/if}
            </div>
            
            {#if !showCompactMode && product.description}
              <p class="product-description">{product.description}</p>
            {/if}
            
            <div class="product-pricing">
              <div class="price-section">
                <span class="current-price">{formatPrice(product.price)}</span>
                {#if product.originalPrice && product.originalPrice > product.price}
                  <span class="original-price">{formatPrice(product.originalPrice)}</span>
                {/if}
              </div>
              
              <div class="stock-info">
                <Badge variant={stockStatus.variant} size="xs">
                  {stockStatus.text}
                </Badge>
                <span class="stock-count">库存: {product.stock}</span>
              </div>
            </div>
            
            {#if !showCompactMode}
              <div class="product-meta">
                {#if product.rating}
                  <div class="rating">
                    <span class="rating-stars">
                      {#each Array(5) as _, i}
                        <span class="star" class:filled={i < Math.floor(product.rating)}>
                          ⭐
                        </span>
                      {/each}
                    </span>
                    <span class="rating-text">{product.rating}</span>
                    {#if product.reviewCount}
                      <span class="review-count">({product.reviewCount}评)</span>
                    {/if}
                  </div>
                {/if}
                
                {#if product.tags && product.tags.length > 0}
                  <div class="product-tags">
                    {#each product.tags.slice(0, 3) as tag}
                      <span class="tag">#{tag}</span>
                    {/each}
                  </div>
                {/if}
              </div>
            {/if}
          </div>
          
          <!-- 操作按钮 -->
          <div class="product-actions">
            {#if product.stock > 0}
              <button 
                class="action-btn primary"
                on:click|stopPropagation={() => handleAddToCart(product)}
              >
                {showCompactMode ? '🛒' : '加入购物车'}
              </button>
            {:else}
              <button class="action-btn disabled" disabled>
                缺货
              </button>
            {/if}
            
            <button 
              class="action-btn secondary"
              on:click|stopPropagation={() => handleProductAction('favorite', product)}
              title="收藏"
            >
              {product.isFavorited ? '❤️' : '🤍'}
            </button>
            
            {#if !showCompactMode}
              <button 
                class="action-btn secondary"
                on:click|stopPropagation={() => handleProductAction('share', product)}
                title="分享"
              >
                📤
              </button>
            {/if}
          </div>
        </article>
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
  .product-list-container {
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
  
  /* 商品列表 */
  .product-list {
    display: flex;
    flex-direction: column;
    gap: 16px;
  }
  
  .product-list.compact {
    gap: 12px;
  }
  
  .product-item {
    background: white;
    border-radius: 16px;
    padding: 16px;
    box-shadow: 0 2px 12px rgba(0, 0, 0, 0.08);
    border: 1px solid rgba(0, 0, 0, 0.04);
    cursor: pointer;
    transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
    display: flex;
    gap: 16px;
    opacity: 0;
    transform: translateY(20px);
    animation: fadeInUp 0.4s ease forwards;
  }
  
  .product-item:hover {
    transform: translateY(-2px);
    box-shadow: 0 8px 24px rgba(0, 0, 0, 0.12);
  }
  
  .product-item.compact {
    padding: 12px;
    gap: 12px;
  }
  
  @keyframes fadeInUp {
    to {
      opacity: 1;
      transform: translateY(0);
    }
  }
  
  /* 商品图片 */
  .product-image {
    position: relative;
    width: 120px;
    height: 120px;
    border-radius: 12px;
    overflow: hidden;
    flex-shrink: 0;
  }
  
  .product-item.compact .product-image {
    width: 80px;
    height: 80px;
  }
  
  .product-image img {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }
  
  .image-placeholder {
    width: 100%;
    height: 100%;
    background: linear-gradient(135deg, #f3f4f6 0%, #e5e7eb 100%);
    display: flex;
    align-items: center;
    justify-content: center;
  }
  
  .placeholder-icon {
    font-size: 32px;
    opacity: 0.5;
  }
  
  .product-item.compact .placeholder-icon {
    font-size: 24px;
  }
  
  .discount-badge {
    position: absolute;
    top: 8px;
    left: 8px;
    background: #dc2626;
    color: white;
    padding: 4px 8px;
    border-radius: 6px;
    font-size: 12px;
    font-weight: 600;
  }
  
  .hot-badge {
    position: absolute;
    top: 8px;
    right: 8px;
    font-size: 16px;
  }
  
  /* 商品信息 */
  .product-info {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: 8px;
  }
  
  .product-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    gap: 12px;
  }
  
  .product-title {
    font-size: 16px;
    font-weight: 600;
    color: #111827;
    margin: 0;
    line-height: 1.4;
    flex: 1;
  }
  
  .product-item.compact .product-title {
    font-size: 14px;
  }
  
  .store-info {
    display: flex;
    align-items: center;
    gap: 4px;
  }
  
  .store-name {
    font-size: 12px;
    color: #6b7280;
  }
  
  .verified-badge {
    font-size: 12px;
    color: #6b7280;
  }
  
  .product-description {
    font-size: 14px;
    color: #6b7280;
    line-height: 1.5;
    margin: 0;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
  }
  
  .product-pricing {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 16px;
  }
  
  .price-section {
    display: flex;
    align-items: center;
    gap: 8px;
  }
  
  .current-price {
    font-size: 18px;
    font-weight: 700;
    color: #dc2626;
  }
  
  .product-item.compact .current-price {
    font-size: 16px;
  }
  
  .original-price {
    font-size: 14px;
    color: #9ca3af;
    text-decoration: line-through;
  }
  
  .stock-info {
    display: flex;
    align-items: center;
    gap: 8px;
  }
  
  .stock-count {
    font-size: 12px;
    color: #6b7280;
  }
  
  .product-meta {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 16px;
  }
  
  .rating {
    display: flex;
    align-items: center;
    gap: 6px;
  }
  
  .rating-stars {
    display: flex;
    gap: 2px;
  }
  
  .star {
    font-size: 12px;
    opacity: 0.3;
  }
  
  .star.filled {
    opacity: 1;
  }
  
  .rating-text {
    font-size: 13px;
    font-weight: 500;
    color: #111827;
  }
  
  .review-count {
    font-size: 12px;
    color: #6b7280;
  }
  
  .product-tags {
    display: flex;
    gap: 6px;
    flex-wrap: wrap;
  }
  
  .tag {
    font-size: 11px;
    color: #667eea;
    background: rgba(102, 126, 234, 0.1);
    padding: 2px 6px;
    border-radius: 4px;
    font-weight: 500;
  }
  
  /* 操作按钮 */
  .product-actions {
    display: flex;
    flex-direction: column;
    gap: 8px;
    align-items: center;
    flex-shrink: 0;
  }
  
  .action-btn {
    padding: 8px 12px;
    border-radius: 8px;
    font-size: 13px;
    font-weight: 500;
    border: none;
    cursor: pointer;
    transition: all 0.2s ease;
    min-width: 80px;
    text-align: center;
  }
  
  .product-item.compact .action-btn {
    padding: 6px 10px;
    min-width: 60px;
    font-size: 12px;
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
    min-width: 40px;
    padding: 8px;
  }
  
  .action-btn.secondary:hover {
    background: #e5e7eb;
  }
  
  .action-btn.disabled {
    background: #f9fafb;
    color: #9ca3af;
    cursor: not-allowed;
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
    .product-item {
      padding: 12px;
      gap: 12px;
      border-radius: 12px;
    }
    
    .product-image {
      width: 80px;
      height: 80px;
    }
    
    .product-title {
      font-size: 14px;
    }
    
    .current-price {
      font-size: 16px;
    }
    
    .product-actions {
      gap: 6px;
    }
    
    .action-btn {
      padding: 6px 8px;
      min-width: 60px;
      font-size: 12px;
    }
    
    .product-meta {
      flex-direction: column;
      align-items: flex-start;
      gap: 8px;
    }
    
    .load-more-section {
      margin-top: 24px;
      padding: 0 8px;
    }
  }
</style> 