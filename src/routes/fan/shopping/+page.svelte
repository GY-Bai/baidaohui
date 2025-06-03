<script lang="ts">
  import { onMount } from 'svelte';
  import ProductGrid from '$lib/components/business/ProductGrid.svelte';
  import ProductList from '$lib/components/business/ProductList.svelte';
  import ImagePreviewModal from '$lib/components/business/ImagePreviewModal.svelte';
  import TabNavigation from '$lib/components/ui/TabNavigation.svelte';
  import Button from '$lib/components/ui/Button.svelte';
  import Input from '$lib/components/ui/Input.svelte';
  import Select from '$lib/components/ui/Select.svelte';
  
  // 状态管理
  let currentView = 'grid'; // grid | list
  let currentCategory = 'all';
  let searchQuery = '';
  let sortBy = 'default';
  let loading = false;
  let loadingMore = false;
  let hasMore = true;
  
  // 图片预览相关
  let showImagePreview = false;
  let previewImages = [];
  let currentImageIndex = 0;
  
  // 模拟商品数据
  let allProducts = [
    {
      id: 'prod001',
      name: '开运水晶手链',
      description: '天然水晶打造，增强个人气场，招财转运',
      price: 168.00,
      originalPrice: 228.00,
      images: [
        'https://images.unsplash.com/photo-1515562141207-7a88fb7ce338?w=400',
        'https://images.unsplash.com/photo-1506629905607-3aaca8d72df0?w=400'
      ],
      category: 'jewelry',
      stock: 15,
      rating: 4.8,
      reviewCount: 127,
      tags: ['水晶', '开运', '手链'],
      isNew: true,
      isBestSeller: false,
      isHot: true,
      discount: 26,
      isFavorited: false
    },
    {
      id: 'prod002',
      name: '紫檀木佛珠',
      description: '印度小叶紫檀，手工打磨，佩戴增福',
      price: 299.00,
      originalPrice: 399.00,
      images: [
        'https://images.unsplash.com/photo-1543857178-1b2c4d006c6b?w=400',
        'https://images.unsplash.com/photo-1578916171728-46686eac8d58?w=400'
      ],
      category: 'jewelry',
      stock: 8,
      rating: 4.9,
      reviewCount: 89,
      tags: ['紫檀', '佛珠', '祈福'],
      isNew: false,
      isBestSeller: true,
      isHot: false,
      discount: 25,
      isFavorited: true
    },
    {
      id: 'prod003',
      name: '五帝钱挂件',
      description: '清朝五帝钱币复制品，镇宅辟邪，招财纳福',
      price: 88.00,
      originalPrice: null,
      images: [
        'https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=400'
      ],
      category: 'amulet',
      stock: 25,
      rating: 4.6,
      reviewCount: 203,
      tags: ['五帝钱', '镇宅', '辟邪'],
      isNew: false,
      isBestSeller: false,
      isHot: false,
      discount: null,
      isFavorited: false
    },
    {
      id: 'prod004',
      name: '招财貔貅摆件',
      description: '天然和田玉雕刻，精工细作，招财进宝',
      price: 588.00,
      originalPrice: 888.00,
      images: [
        'https://images.unsplash.com/photo-1578662996442-48f60103fc96?w=400',
        'https://images.unsplash.com/photo-1513475382585-d06e58bcb0e0?w=400',
        'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=400'
      ],
      category: 'ornament',
      stock: 3,
      rating: 4.7,
      reviewCount: 45,
      tags: ['貔貅', '和田玉', '招财'],
      isNew: true,
      isBestSeller: true,
      isHot: true,
      discount: 34,
      isFavorited: false
    },
    {
      id: 'prod005',
      name: '平安符护身符',
      description: '寺庙开光加持，保平安健康，出入平安',
      price: 36.00,
      originalPrice: null,
      images: [
        'https://images.unsplash.com/photo-1578308938537-00095e11add4?w=400'
      ],
      category: 'amulet',
      stock: 50,
      rating: 4.5,
      reviewCount: 312,
      tags: ['平安符', '护身符', '开光'],
      isNew: false,
      isBestSeller: true,
      isHot: false,
      discount: null,
      isFavorited: true
    },
    {
      id: 'prod006',
      name: '龙凤呈祥茶具',
      description: '景德镇陶瓷，手绘龙凤图案，品茶修身',
      price: 368.00,
      originalPrice: 458.00,
      images: [
        'https://images.unsplash.com/photo-1544787219-7f47ccb76574?w=400',
        'https://images.unsplash.com/photo-1558618047-3c8c76ca7d13?w=400'
      ],
      category: 'lifestyle',
      stock: 12,
      rating: 4.4,
      reviewCount: 67,
      tags: ['茶具', '陶瓷', '龙凤'],
      isNew: false,
      isBestSeller: false,
      isHot: false,
      discount: 20,
      isFavorited: false
    }
  ];
  
  // 分类配置
  const categories = [
    { id: 'all', label: '全部商品', count: 0 },
    { id: 'jewelry', label: '饰品配件', count: 0 },
    { id: 'amulet', label: '护身符咒', count: 0 },
    { id: 'ornament', label: '风水摆件', count: 0 },
    { id: 'lifestyle', label: '生活用品', count: 0 }
  ];
  
  // 排序选项
  const sortOptions = [
    { value: 'default', label: '默认排序' },
    { value: 'price_asc', label: '价格从低到高' },
    { value: 'price_desc', label: '价格从高到低' },
    { value: 'rating', label: '评分最高' },
    { value: 'sales', label: '销量最高' },
    { value: 'newest', label: '最新上架' }
  ];
  
  // 标签页配置
  $: tabs = categories.map(cat => ({
    id: cat.id,
    label: cat.label,
    count: cat.id === 'all' ? filteredProducts.length : allProducts.filter(p => p.category === cat.id).length
  }));
  
  // 过滤和排序后的商品
  $: filteredProducts = allProducts
    .filter(product => {
      // 分类过滤
      if (currentCategory !== 'all' && product.category !== currentCategory) {
        return false;
      }
      
      // 搜索过滤
      if (searchQuery.trim()) {
        const query = searchQuery.toLowerCase();
        return product.name.toLowerCase().includes(query) ||
               product.description.toLowerCase().includes(query) ||
               product.tags.some(tag => tag.toLowerCase().includes(query));
      }
      
      return true;
    })
    .sort((a, b) => {
      switch (sortBy) {
        case 'price_asc':
          return a.price - b.price;
        case 'price_desc':
          return b.price - a.price;
        case 'rating':
          return (b.rating || 0) - (a.rating || 0);
        case 'sales':
          return (b.reviewCount || 0) - (a.reviewCount || 0);
        case 'newest':
          return b.isNew ? 1 : -1;
        default:
          // 默认排序：热门 > 新品 > 爆款 > 评分
          let scoreA = 0, scoreB = 0;
          if (a.isHot) scoreA += 100;
          if (a.isNew) scoreA += 80;
          if (a.isBestSeller) scoreA += 60;
          scoreA += (a.rating || 0) * 10;
          
          if (b.isHot) scoreB += 100;
          if (b.isNew) scoreB += 80;
          if (b.isBestSeller) scoreB += 60;
          scoreB += (b.rating || 0) * 10;
          
          return scoreB - scoreA;
      }
    });
  
  function handleCategoryChange(event) {
    currentCategory = event.detail.activeTab;
  }
  
  function handleProductClick(event) {
    const { product } = event.detail;
    console.log('查看商品详情:', product.name);
    // 这里可以跳转到商品详情页
  }
  
  function handleAddToCart(event) {
    const { product } = event.detail;
    console.log('添加到购物车:', product.name);
    // 这里实现添加购物车逻辑
    alert(`已将"${product.name}"添加到购物车`);
  }
  
  function handleProductAction(event) {
    const { action, product } = event.detail;
    
    switch (action) {
      case 'favorite':
        // 切换收藏状态
        product.isFavorited = !product.isFavorited;
        allProducts = [...allProducts];
        console.log(product.isFavorited ? '已收藏' : '已取消收藏', product.name);
        break;
      case 'share':
        console.log('分享商品:', product.name);
        // 实现分享功能
        if (navigator.share) {
          navigator.share({
            title: product.name,
            text: product.description,
            url: window.location.href
          });
        } else {
          navigator.clipboard.writeText(window.location.href);
          alert('商品链接已复制到剪贴板');
        }
        break;
      case 'preview':
        // 预览商品图片
        previewImages = product.images.map(url => ({ url, alt: product.name }));
        currentImageIndex = 0;
        showImagePreview = true;
        break;
    }
  }
  
  function handleLoadMore() {
    if (loadingMore) return;
    
    loadingMore = true;
    
    // 模拟加载更多商品
    setTimeout(() => {
      console.log('加载更多商品...');
      loadingMore = false;
      // 这里可以实际加载更多商品数据
      hasMore = false; // 示例中设置为没有更多数据
    }, 1000);
  }
  
  function handleImagePreviewClose() {
    showImagePreview = false;
    previewImages = [];
    currentImageIndex = 0;
  }
  
  function toggleView() {
    currentView = currentView === 'grid' ? 'list' : 'grid';
  }
  
  function handleSearch() {
    // 搜索功能已通过响应式实现
    console.log('搜索:', searchQuery);
  }
  
  onMount(() => {
    console.log('购物页面加载完成');
    // 模拟初始加载
    loading = true;
    setTimeout(() => {
      loading = false;
    }, 500);
  });
</script>

<svelte:head>
  <title>购物商城 - 百刀会</title>
</svelte:head>

<div class="shopping-view">
  <!-- 页面头部 -->
  <header class="shopping-header">
    <div class="header-content">
      <h1 class="page-title">🛍️ 购物商城</h1>
      <p class="page-subtitle">精选开运好物，助您运势亨通</p>
    </div>
    
    <!-- 搜索栏 -->
    <div class="search-section">
      <Input
        placeholder="搜索商品、分类或标签..."
        bind:value={searchQuery}
        type="search"
        on:input={handleSearch}
      />
    </div>
  </header>
  
  <!-- 分类标签栏 -->
  <div class="category-section">
    <TabNavigation
      {tabs}
      activeTab={currentCategory}
      variant="pills"
      size="md"
      showIndicator={true}
      on:change={handleCategoryChange}
    />
  </div>
  
  <!-- 工具栏 -->
  <div class="toolbar">
    <div class="toolbar-left">
      <span class="result-count">
        共 {filteredProducts.length} 件商品
      </span>
    </div>
    
    <div class="toolbar-right">
      <!-- 排序选择 -->
      <Select
        options={sortOptions}
        bind:value={sortBy}
        placeholder="排序方式"
        size="sm"
      />
      
      <!-- 视图切换 -->
      <div class="view-toggle">
        <button
          class="view-btn"
          class:active={currentView === 'grid'}
          on:click={() => currentView = 'grid'}
          title="网格视图"
        >
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
            <rect x="3" y="3" width="7" height="7" stroke="currentColor" stroke-width="2"/>
            <rect x="14" y="3" width="7" height="7" stroke="currentColor" stroke-width="2"/>
            <rect x="14" y="14" width="7" height="7" stroke="currentColor" stroke-width="2"/>
            <rect x="3" y="14" width="7" height="7" stroke="currentColor" stroke-width="2"/>
          </svg>
        </button>
        <button
          class="view-btn"
          class:active={currentView === 'list'}
          on:click={() => currentView = 'list'}
          title="列表视图"
        >
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
            <line x1="8" y1="6" x2="21" y2="6" stroke="currentColor" stroke-width="2"/>
            <line x1="8" y1="12" x2="21" y2="12" stroke="currentColor" stroke-width="2"/>
            <line x1="8" y1="18" x2="21" y2="18" stroke="currentColor" stroke-width="2"/>
            <line x1="3" y1="6" x2="3.01" y2="6" stroke="currentColor" stroke-width="2"/>
            <line x1="3" y1="12" x2="3.01" y2="12" stroke="currentColor" stroke-width="2"/>
            <line x1="3" y1="18" x2="3.01" y2="18" stroke="currentColor" stroke-width="2"/>
          </svg>
        </button>
      </div>
    </div>
  </div>
  
  <!-- 商品展示区域 -->
  <div class="products-section">
    {#if currentView === 'grid'}
      <ProductGrid
        products={filteredProducts}
        {loading}
        {hasMore}
        {loadingMore}
        columns={2}
        gap={16}
        emptyMessage="没有找到符合条件的商品"
        emptyIcon="🔍"
        on:productClick={handleProductClick}
        on:addToCart={handleAddToCart}
        on:productAction={handleProductAction}
        on:loadMore={handleLoadMore}
      />
    {:else}
      <ProductList
        products={filteredProducts}
        {loading}
        {hasMore}
        {loadingMore}
        showCompactMode={false}
        emptyMessage="没有找到符合条件的商品"
        emptyIcon="🔍"
        on:productClick={handleProductClick}
        on:addToCart={handleAddToCart}
        on:productAction={handleProductAction}
        on:loadMore={handleLoadMore}
      />
    {/if}
  </div>
</div>

<!-- 图片预览模态框 -->
<ImagePreviewModal
  isOpen={showImagePreview}
  images={previewImages}
  currentIndex={currentImageIndex}
  title="商品图片预览"
  allowDownload={false}
  allowShare={true}
  on:close={handleImagePreviewClose}
  on:indexChange={(e) => currentImageIndex = e.detail.index}
  on:share={(e) => console.log('分享图片:', e.detail)}
/>

<style>
  .shopping-view {
    padding: 20px;
    max-width: 1200px;
    margin: 0 auto;
    min-height: 100vh;
    background: #f8fafc;
  }
  
  /* 页面头部 */
  .shopping-header {
    background: white;
    border-radius: 20px;
    padding: 24px;
    margin-bottom: 24px;
    box-shadow: 0 4px 20px rgba(0, 0, 0, 0.08);
  }
  
  .header-content {
    margin-bottom: 20px;
  }
  
  .page-title {
    font-size: 28px;
    font-weight: 700;
    color: #111827;
    margin: 0 0 8px 0;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
  }
  
  .page-subtitle {
    font-size: 16px;
    color: #6b7280;
    margin: 0;
  }
  
  .search-section {
    max-width: 400px;
  }
  
  /* 分类部分 */
  .category-section {
    background: white;
    border-radius: 16px;
    padding: 20px;
    margin-bottom: 20px;
    box-shadow: 0 2px 12px rgba(0, 0, 0, 0.08);
  }
  
  /* 工具栏 */
  .toolbar {
    display: flex;
    justify-content: space-between;
    align-items: center;
    background: white;
    border-radius: 12px;
    padding: 16px 20px;
    margin-bottom: 20px;
    box-shadow: 0 2px 12px rgba(0, 0, 0, 0.08);
  }
  
  .toolbar-left {
    display: flex;
    align-items: center;
  }
  
  .result-count {
    font-size: 14px;
    color: #6b7280;
    font-weight: 500;
  }
  
  .toolbar-right {
    display: flex;
    align-items: center;
    gap: 16px;
  }
  
  .view-toggle {
    display: flex;
    background: #f3f4f6;
    border-radius: 8px;
    padding: 2px;
  }
  
  .view-btn {
    background: none;
    border: none;
    padding: 8px;
    border-radius: 6px;
    cursor: pointer;
    color: #6b7280;
    transition: all 0.2s ease;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  
  .view-btn:hover {
    color: #111827;
  }
  
  .view-btn.active {
    background: white;
    color: #667eea;
    box-shadow: 0 1px 2px rgba(0, 0, 0, 0.1);
  }
  
  /* 商品展示区域 */
  .products-section {
    background: white;
    border-radius: 20px;
    padding: 24px;
    box-shadow: 0 4px 20px rgba(0, 0, 0, 0.08);
  }
  
  /* 移动端适配 */
  @media (max-width: 768px) {
    .shopping-view {
      padding: 12px;
    }
    
    .shopping-header {
      padding: 20px;
      border-radius: 16px;
      margin-bottom: 16px;
    }
    
    .page-title {
      font-size: 24px;
    }
    
    .page-subtitle {
      font-size: 14px;
    }
    
    .category-section {
      padding: 16px;
      border-radius: 12px;
      margin-bottom: 16px;
    }
    
    .toolbar {
      flex-direction: column;
      gap: 12px;
      align-items: stretch;
      padding: 16px;
      border-radius: 12px;
      margin-bottom: 16px;
    }
    
    .toolbar-right {
      justify-content: space-between;
      gap: 12px;
    }
    
    .products-section {
      padding: 16px;
      border-radius: 16px;
    }
  }
  
  @media (max-width: 480px) {
    .shopping-view {
      padding: 8px;
    }
    
    .shopping-header {
      padding: 16px;
    }
    
    .page-title {
      font-size: 20px;
    }
    
    .toolbar-right {
      flex-direction: column;
      align-items: stretch;
    }
    
    .view-toggle {
      align-self: center;
    }
  }
</style> 