<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { scale, fade } from 'svelte/transition';
  import { cubicOut } from 'svelte/easing';
  
  export let product: {
    id: string;
    title: string;
    description?: string;
    price: number;
    originalPrice?: number;
    currency: string;
    images: string[];
    store: {
      name: string;
      badge?: string;
    };
    discount?: number;
  };
  
  export let layout: 'grid' | 'list' = 'grid';
  export let showBadge: boolean = true;
  export let showDescription: boolean = false;
  export let lazy: boolean = true;
  
  const dispatch = createEventDispatcher();
  
  let imageLoaded = false;
  let imageError = false;
  
  $: hasDiscount = product.originalPrice && product.originalPrice > product.price;
  $: discountPercentage = hasDiscount 
    ? Math.round(((product.originalPrice! - product.price) / product.originalPrice!) * 100)
    : 0;
  
  function handleCardClick() {
    dispatch('click', { product });
  }
  
  function handleImageClick(event: MouseEvent) {
    event.stopPropagation();
    dispatch('imageClick', { product, images: product.images });
  }
  
  function handleImageLoad() {
    imageLoaded = true;
  }
  
  function handleImageError() {
    imageError = true;
  }
  
  function formatPrice(price: number, currency: string) {
    const symbols = {
      'CNY': '¥',
      'USD': '$',
      'CAD': 'C$',
      'SGD': 'S$',
      'AUD': 'A$'
    };
    
    return `${symbols[currency] || currency} ${price.toFixed(2)}`;
  }
</script>

<article 
  class="product-card {layout}"
  on:click={handleCardClick}
  on:keydown={(e) => e.key === 'Enter' && handleCardClick()}
  role="button"
  tabindex="0"
  aria-label="查看商品: {product.title}"
>
  <!-- 商品图片区域 -->
  <div class="product-image-container">
    {#if product.images.length > 0}
      <!-- 主图片 -->
      <div class="product-image-wrapper">
        {#if !imageLoaded && !imageError}
          <div class="image-skeleton" in:fade={{ duration: 200 }}>
            <div class="skeleton-shimmer"></div>
          </div>
        {/if}
        
        <img
          src={product.images[0]}
          alt={product.title}
          class="product-image"
          class:loaded={imageLoaded}
          loading={lazy ? 'lazy' : 'eager'}
          on:load={handleImageLoad}
          on:error={handleImageError}
          on:click={handleImageClick}
        />
        
        {#if imageError}
          <div class="image-error" in:fade={{ duration: 200 }}>
            <span class="error-icon">🖼️</span>
            <span class="error-text">图片加载失败</span>
          </div>
        {/if}
      </div>
      
      <!-- 图片指示器 -->
      {#if product.images.length > 1}
        <div class="image-indicators">
          {#each product.images as _, index}
            <div 
              class="indicator-dot"
              class:active={index === 0}
            ></div>
          {/each}
        </div>
      {/if}
    {:else}
      <div class="product-image-placeholder">
        <span class="placeholder-icon">📦</span>
        <span class="placeholder-text">暂无图片</span>
      </div>
    {/if}
    
    <!-- 折扣标签 -->
    {#if hasDiscount}
      <div class="discount-badge" in:scale={{ duration: 200, easing: cubicOut }}>
        -{discountPercentage}%
      </div>
    {/if}
    
    <!-- 商店徽章 -->
    {#if showBadge && product.store.badge}
      <div class="store-badge">
        {product.store.badge}
      </div>
    {/if}
  </div>
  
  <!-- 商品信息区域 -->
  <div class="product-info">
    <!-- 商品标题 -->
    <h3 class="product-title" title={product.title}>
      {product.title}
    </h3>
    
    <!-- 商品描述 -->
    {#if showDescription && product.description}
      <p class="product-description">
        {product.description}
      </p>
    {/if}
    
    <!-- 价格区域 -->
    <div class="product-pricing">
      <span class="current-price">
        {formatPrice(product.price, product.currency)}
      </span>
      
      {#if hasDiscount}
        <span class="original-price">
          {formatPrice(product.originalPrice!, product.currency)}
        </span>
      {/if}
    </div>
    
    <!-- 商店信息 -->
    <div class="store-info">
      <span class="store-name">{product.store.name}</span>
    </div>
    
    <!-- 操作按钮 -->
    <div class="product-actions">
      <button 
        class="action-button primary"
        on:click|stopPropagation={() => dispatch('purchase', { product })}
        aria-label="立即购买 {product.title}"
      >
        立即购买
      </button>
      
      <button 
        class="action-button secondary"
        on:click|stopPropagation={() => dispatch('favorite', { product })}
        aria-label="收藏 {product.title}"
      >
        ❤️
      </button>
    </div>
  </div>
</article>

<style>
  .product-card {
    background: white;
    border-radius: 12px;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
    overflow: hidden;
    transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
    cursor: pointer;
    height: fit-content;
    
    /* 触摸优化 */
    -webkit-tap-highlight-color: transparent;
  }
  
  .product-card:hover {
    transform: translateY(-4px);
    box-shadow: 0 8px 24px rgba(0, 0, 0, 0.15);
  }
  
  .product-card:active {
    transform: translateY(-2px);
  }
  
  /* 布局变体 */
  .product-card.list {
    display: flex;
    flex-direction: row;
    align-items: center;
  }
  
  .product-card.list .product-image-container {
    width: 120px;
    min-height: 120px;
    flex-shrink: 0;
  }
  
  .product-card.list .product-info {
    flex: 1;
    padding: 16px;
  }
  
  /* 图片容器 */
  .product-image-container {
    position: relative;
    width: 100%;
    aspect-ratio: 1;
    overflow: hidden;
  }
  
  .product-image-wrapper {
    position: relative;
    width: 100%;
    height: 100%;
  }
  
  .product-image {
    width: 100%;
    height: 100%;
    object-fit: cover;
    transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
    opacity: 0;
  }
  
  .product-image.loaded {
    opacity: 1;
  }
  
  .product-image:hover {
    transform: scale(1.05);
  }
  
  /* 图片骨架屏 */
  .image-skeleton {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: #f3f4f6;
    display: flex;
    align-items: center;
    justify-content: center;
    overflow: hidden;
  }
  
  .skeleton-shimmer {
    width: 100%;
    height: 100%;
    background: linear-gradient(
      90deg,
      transparent,
      rgba(255, 255, 255, 0.6),
      transparent
    );
    animation: shimmer 1.5s infinite;
  }
  
  @keyframes shimmer {
    0% { transform: translateX(-100%); }
    100% { transform: translateX(100%); }
  }
  
  /* 图片错误状态 */
  .image-error {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: #f9fafb;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 8px;
  }
  
  .error-icon {
    font-size: 32px;
    opacity: 0.5;
  }
  
  .error-text {
    font-size: 12px;
    color: #6b7280;
  }
  
  /* 图片占位符 */
  .product-image-placeholder {
    width: 100%;
    height: 100%;
    background: #f9fafb;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 8px;
  }
  
  .placeholder-icon {
    font-size: 40px;
    opacity: 0.5;
  }
  
  .placeholder-text {
    font-size: 14px;
    color: #9ca3af;
  }
  
  /* 图片指示器 */
  .image-indicators {
    position: absolute;
    bottom: 8px;
    left: 50%;
    transform: translateX(-50%);
    display: flex;
    gap: 4px;
  }
  
  .indicator-dot {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    background: rgba(255, 255, 255, 0.5);
    transition: all 0.2s;
  }
  
  .indicator-dot.active {
    background: white;
    transform: scale(1.2);
  }
  
  /* 折扣标签 */
  .discount-badge {
    position: absolute;
    top: 8px;
    left: 8px;
    background: #ef4444;
    color: white;
    font-size: 12px;
    font-weight: 700;
    padding: 4px 8px;
    border-radius: 6px;
    box-shadow: 0 2px 4px rgba(239, 68, 68, 0.3);
  }
  
  /* 商店徽章 */
  .store-badge {
    position: absolute;
    top: 8px;
    right: 8px;
    background: rgba(0, 0, 0, 0.7);
    color: white;
    font-size: 10px;
    font-weight: 600;
    padding: 4px 6px;
    border-radius: 4px;
    backdrop-filter: blur(4px);
  }
  
  /* 商品信息 */
  .product-info {
    padding: 16px;
    display: flex;
    flex-direction: column;
    gap: 8px;
  }
  
  .product-title {
    margin: 0;
    font-size: 16px;
    font-weight: 600;
    color: #374151;
    line-height: 1.4;
    
    /* 限制两行，超出省略 */
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
  }
  
  .product-description {
    margin: 0;
    font-size: 14px;
    color: #6b7280;
    line-height: 1.4;
    
    /* 限制三行，超出省略 */
    display: -webkit-box;
    -webkit-line-clamp: 3;
    -webkit-box-orient: vertical;
    overflow: hidden;
  }
  
  /* 价格信息 */
  .product-pricing {
    display: flex;
    align-items: baseline;
    gap: 8px;
    margin: 4px 0;
  }
  
  .current-price {
    font-size: 18px;
    font-weight: 700;
    color: #ef4444;
  }
  
  .original-price {
    font-size: 14px;
    color: #9ca3af;
    text-decoration: line-through;
  }
  
  /* 商店信息 */
  .store-info {
    display: flex;
    align-items: center;
    gap: 6px;
  }
  
  .store-name {
    font-size: 12px;
    color: #6b7280;
    background: #f3f4f6;
    padding: 2px 6px;
    border-radius: 4px;
  }
  
  /* 操作按钮 */
  .product-actions {
    display: flex;
    gap: 8px;
    margin-top: 8px;
  }
  
  .action-button {
    flex: 1;
    padding: 8px 16px;
    border: none;
    border-radius: 6px;
    font-weight: 600;
    font-size: 14px;
    cursor: pointer;
    transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
    
    /* 触摸优化 */
    -webkit-tap-highlight-color: transparent;
    touch-action: manipulation;
  }
  
  .action-button.primary {
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    color: white;
  }
  
  .action-button.primary:hover {
    transform: translateY(-1px);
    box-shadow: 0 4px 12px rgba(102, 126, 234, 0.3);
  }
  
  .action-button.secondary {
    background: #f3f4f6;
    color: #6b7280;
    border: 1px solid #d1d5db;
    flex: 0 0 44px;
    padding: 8px;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  
  .action-button.secondary:hover {
    background: #e5e7eb;
    transform: scale(1.05);
  }
  
  /* 焦点状态 */
  .product-card:focus-visible {
    outline: 2px solid #667eea;
    outline-offset: 2px;
  }
  
  .action-button:focus-visible {
    box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.2);
  }
  
  /* 响应式优化 */
  @media (max-width: 480px) {
    .product-info {
      padding: 12px;
    }
    
    .product-title {
      font-size: 15px;
    }
    
    .current-price {
      font-size: 16px;
    }
    
    .action-button {
      padding: 6px 12px;
      font-size: 13px;
    }
    
    .action-button.secondary {
      flex: 0 0 40px;
      padding: 6px;
    }
  }
  
  /* 深色模式 */
  @media (prefers-color-scheme: dark) {
    .product-card {
      background: #1f2937;
    }
    
    .product-title {
      color: #f3f4f6;
    }
    
    .product-description {
      color: #9ca3af;
    }
    
    .store-name {
      background: #374151;
      color: #d1d5db;
    }
    
    .action-button.secondary {
      background: #374151;
      color: #d1d5db;
      border-color: #4b5563;
    }
    
    .action-button.secondary:hover {
      background: #4b5563;
    }
    
    .image-skeleton {
      background: #374151;
    }
    
    .product-image-placeholder,
    .image-error {
      background: #374151;
    }
  }
  
  /* 无障碍优化 */
  @media (prefers-reduced-motion: reduce) {
    .product-card,
    .product-image,
    .action-button {
      transition: none;
    }
    
    .skeleton-shimmer {
      animation: none;
    }
  }
</style> 