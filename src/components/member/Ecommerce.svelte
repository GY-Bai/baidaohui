<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import type { UserSession } from '$lib/auth';
  
  export let session: UserSession;
  
  interface Product {
    id: string;
    name: string;
    description: string;
    images: string[];
    default_price: {
      id: string;
      unit_amount: number;
      currency: string;
    };
    payment_link?: {
      id: string;
      url: string;
      active: boolean;
    };
    storeId: string;
    storeName?: string;
    tags?: string[];
    created: number;
    updated: number;
  }

  let products: Product[] = [];
  let relatedProducts: Product[] = [];
  let loading = true;
  let error = '';
  let selectedProduct: Product | null = null;
  let showProductModal = false;
  let currentImageIndex = 0;

  // 格式化价格
  function formatPrice(amount: number, currency: string): string {
    const formatter = new Intl.NumberFormat('zh-CN', {
      style: 'currency',
      currency: currency.toUpperCase(),
      minimumFractionDigits: 2
    });
    return formatter.format(amount / 100);
  }

  // 获取商品列表
  async function fetchProducts() {
    try {
      loading = true;
      const response = await fetch('/api/products');
      
      if (!response.ok) {
        throw new Error('获取商品列表失败');
      }
      
      const data = await response.json();
      products = data.products || [];
    } catch (err) {
      error = err instanceof Error ? err.message : '获取商品失败';
      console.error('获取商品失败:', err);
    } finally {
      loading = false;
    }
  }

  // 获取相关推荐商品
  function getRelatedProducts(product: Product): Product[] {
    return products
      .filter(p => p.id !== product.id)
      .filter(p => 
        p.storeId === product.storeId || 
        (product.tags && p.tags && product.tags.some(tag => p.tags?.includes(tag)))
      )
      .slice(0, 4);
  }

  // 打开商品详情
  function openProductDetail(product: Product) {
    selectedProduct = product;
    relatedProducts = getRelatedProducts(product);
    currentImageIndex = 0;
    showProductModal = true;
    // 防止背景滚动
    document.body.style.overflow = 'hidden';
  }

  // 关闭商品详情
  function closeProductDetail() {
    selectedProduct = null;
    relatedProducts = [];
    showProductModal = false;
    currentImageIndex = 0;
    // 恢复背景滚动
    document.body.style.overflow = 'auto';
  }

  // 切换图片
  function changeImage(index: number) {
    currentImageIndex = index;
  }

  // 立即购买
  function buyNow(product: Product) {
    if (product.payment_link && product.payment_link.active) {
      // 直接跳转到静态Payment Link
      window.open(product.payment_link.url, '_blank');
    } else {
      alert('该商品暂时无法购买，请稍后再试');
    }
  }

  // 获取商户徽章颜色
  function getStoreBadgeColor(storeId: string): string {
    const colors = [
      'bg-blue-500',
      'bg-green-500', 
      'bg-purple-500',
      'bg-red-500',
      'bg-yellow-500',
      'bg-indigo-500'
    ];
    const hash = storeId.split('').reduce((a, b) => {
      a = ((a << 5) - a) + b.charCodeAt(0);
      return a & a;
    }, 0);
    return colors[Math.abs(hash) % colors.length];
  }

  // 处理图片加载错误
  function handleImageError(event: Event) {
    const img = event.target as HTMLImageElement;
    img.src = '/placeholder-product.png'; // 默认占位图
  }

  // 截断文本并添加tooltip
  function truncateText(text: string, maxLength: number): string {
    return text.length > maxLength ? text.substring(0, maxLength) + '...' : text;
  }

  onMount(() => {
    fetchProducts();
    
    // 清理函数
    return () => {
      document.body.style.overflow = 'auto';
    };
  });
</script>

<div class="ecommerce-container p-4">
  <div class="mb-6">
    <h2 class="text-2xl font-bold text-gray-800 mb-2">精选好物</h2>
    <p class="text-gray-600">发现优质商品，享受便捷购物体验</p>
  </div>

  {#if loading}
    <div class="flex justify-center items-center py-12">
      <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-500"></div>
      <span class="ml-3 text-gray-600">加载中...</span>
    </div>
  {:else if error}
    <div class="bg-red-50 border border-red-200 rounded-lg p-4 text-center">
      <p class="text-red-600">{error}</p>
      <button 
        on:click={fetchProducts}
        class="mt-2 px-4 py-2 bg-red-500 text-white rounded hover:bg-red-600 transition-colors"
      >
        重试
      </button>
    </div>
  {:else if products.length === 0}
    <div class="text-center py-12">
      <div class="text-gray-400 text-6xl mb-4">🛍️</div>
      <p class="text-gray-600">暂无商品</p>
    </div>
  {:else}
    <!-- 商品瀑布流网格 -->
    <div class="columns-2 md:columns-4 gap-4 space-y-4">
      {#each products as product (product.id)}
        <div 
          class="bg-white rounded-lg shadow-md overflow-hidden hover:shadow-lg transition-all duration-300 cursor-pointer break-inside-avoid mb-4"
          on:click={() => openProductDetail(product)}
          role="button"
          tabindex="0"
          aria-label="查看 {product.name} 详情"
          on:keydown={(e) => e.key === 'Enter' && openProductDetail(product)}
        >
          <!-- 商品图片 -->
          <div class="relative">
            {#if product.images && product.images.length > 0}
              <img 
                src={product.images[0]} 
                alt={product.name}
                class="w-full h-auto object-cover"
                loading="lazy"
                on:error={handleImageError}
                style="aspect-ratio: auto;"
              />
            {:else}
              <div class="w-full h-48 bg-gray-200 flex items-center justify-center">
                <span class="text-gray-400">暂无图片</span>
              </div>
            {/if}
            
            <!-- 商户徽章 -->
            <div class="absolute top-2 right-2">
              <span class="px-2 py-1 text-xs text-white rounded-full {getStoreBadgeColor(product.storeId)}">
                {product.storeName || product.storeId}
              </span>
            </div>
          </div>

          <!-- 商品信息 -->
          <div class="p-4">
            <!-- 商品名称 -->
            <h3 
              class="font-medium text-gray-900 mb-2 line-clamp-2"
              title={product.name}
            >
              {truncateText(product.name, 50)}
            </h3>

            <!-- 价格信息 -->
            <div class="flex items-center justify-between">
              <div class="flex items-center space-x-2">
                <span class="text-lg font-bold text-red-500">
                  {formatPrice(product.default_price.unit_amount, product.default_price.currency)}
                </span>
              </div>
              
              <!-- 查看详情按钮 -->
              <button
                class="px-3 py-1 text-sm bg-blue-500 text-white rounded hover:bg-blue-600 transition-colors"
                on:click|stopPropagation={() => openProductDetail(product)}
                aria-label="查看 {product.name} 详情"
              >
                详情
              </button>
            </div>
          </div>
        </div>
      {/each}
    </div>
  {/if}
</div>

<!-- 商品详情模态框 -->
{#if showProductModal && selectedProduct}
  <div 
    class="fixed inset-0 bg-black bg-opacity-50 z-50 flex items-center justify-center p-4"
    on:click={closeProductDetail}
  >
    <div 
      class="bg-white rounded-lg max-w-4xl w-full max-h-[90vh] overflow-y-auto"
      on:click|stopPropagation
    >
      <div class="p-6">
        <!-- 头部 -->
        <div class="flex justify-between items-center mb-6">
          <h2 class="text-2xl font-bold text-gray-900">{selectedProduct.name}</h2>
          <button
            on:click={closeProductDetail}
            class="text-gray-400 hover:text-gray-600 text-2xl"
            aria-label="关闭"
          >
            ×
          </button>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
          <!-- 左侧：图片轮播 -->
          <div>
            {#if selectedProduct.images && selectedProduct.images.length > 0}
              <!-- 主图 -->
              <div class="mb-4">
                <img 
                  src={selectedProduct.images[currentImageIndex]} 
                  alt={selectedProduct.name}
                  class="w-full h-96 object-cover rounded-lg border"
                  on:error={handleImageError}
                />
              </div>
              
              <!-- 缩略图 -->
              {#if selectedProduct.images.length > 1}
                <div class="flex space-x-2 overflow-x-auto">
                  {#each selectedProduct.images as image, index}
                    <button
                      class="flex-shrink-0 w-16 h-16 rounded border-2 overflow-hidden {
                        index === currentImageIndex ? 'border-blue-500' : 'border-gray-200'
                      }"
                      on:click={() => changeImage(index)}
                    >
                      <img 
                        src={image} 
                        alt="缩略图 {index + 1}"
                        class="w-full h-full object-cover"
                        on:error={handleImageError}
                      />
                    </button>
                  {/each}
                </div>
              {/if}
            {:else}
              <div class="w-full h-96 bg-gray-200 rounded-lg flex items-center justify-center">
                <span class="text-gray-400">暂无图片</span>
              </div>
            {/if}
          </div>

          <!-- 右侧：商品信息 -->
          <div>
            <!-- 价格 -->
            <div class="mb-6">
              <div class="text-3xl font-bold text-red-500 mb-2">
                {formatPrice(selectedProduct.default_price.unit_amount, selectedProduct.default_price.currency)}
              </div>
              <div class="flex items-center space-x-2">
                <span class="px-2 py-1 text-sm text-white rounded {getStoreBadgeColor(selectedProduct.storeId)}">
                  {selectedProduct.storeName || selectedProduct.storeId}
                </span>
                {#if selectedProduct.tags}
                  {#each selectedProduct.tags as tag}
                    <span class="px-2 py-1 text-xs bg-gray-100 text-gray-600 rounded">
                      {tag}
                    </span>
                  {/each}
                {/if}
              </div>
            </div>

            <!-- 商品描述 -->
            {#if selectedProduct.description}
              <div class="mb-6">
                <h3 class="text-lg font-semibold text-gray-900 mb-2">商品描述</h3>
                <div class="text-gray-700 leading-relaxed">
                  {@html selectedProduct.description.replace(/\n/g, '<br>')}
                </div>
              </div>
            {/if}

            <!-- 购买按钮 -->
            <div class="mb-6">
              <button
                on:click={() => buyNow(selectedProduct)}
                disabled={!selectedProduct.payment_link?.active}
                class="w-full py-3 px-6 bg-red-500 text-white font-semibold rounded-lg hover:bg-red-600 disabled:bg-gray-300 disabled:cursor-not-allowed transition-colors"
                aria-label="购买 {selectedProduct.name}"
              >
                {selectedProduct.payment_link?.active ? '立即购买' : '暂时无法购买'}
              </button>
              <p class="text-sm text-gray-500 mt-2 text-center">
                点击购买将跳转到安全支付页面
              </p>
            </div>

            <!-- 商品信息 -->
            <div class="border-t pt-4">
              <div class="grid grid-cols-2 gap-4 text-sm">
                <div>
                  <span class="text-gray-500">商品ID:</span>
                  <span class="ml-2 text-gray-900">{selectedProduct.id}</span>
                </div>
                <div>
                  <span class="text-gray-500">创建时间:</span>
                  <span class="ml-2 text-gray-900">
                    {new Date(selectedProduct.created * 1000).toLocaleDateString()}
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- 相关推荐 -->
        {#if relatedProducts.length > 0}
          <div class="mt-8 border-t pt-6">
            <h3 class="text-lg font-semibold text-gray-900 mb-4">相关推荐</h3>
            <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
              {#each relatedProducts as product}
                <div 
                  class="bg-gray-50 rounded-lg p-3 cursor-pointer hover:bg-gray-100 transition-colors"
                  on:click={() => openProductDetail(product)}
                  role="button"
                  tabindex="0"
                  aria-label="查看 {product.name} 详情"
                  on:keydown={(e) => e.key === 'Enter' && openProductDetail(product)}
                >
                  {#if product.images && product.images.length > 0}
                    <img 
                      src={product.images[0]} 
                      alt={product.name}
                      class="w-full h-24 object-cover rounded mb-2"
                      loading="lazy"
                      on:error={handleImageError}
                    />
                  {:else}
                    <div class="w-full h-24 bg-gray-200 rounded mb-2 flex items-center justify-center">
                      <span class="text-gray-400 text-xs">暂无图片</span>
                    </div>
                  {/if}
                  <h4 class="text-sm font-medium text-gray-900 line-clamp-2 mb-1">
                    {truncateText(product.name, 30)}
                  </h4>
                  <p class="text-sm font-bold text-red-500">
                    {formatPrice(product.default_price.unit_amount, product.default_price.currency)}
                  </p>
                </div>
              {/each}
            </div>
          </div>
        {/if}
      </div>
    </div>
  </div>
{/if}

<style>
  .line-clamp-2 {
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
  }
  
  .ecommerce-container {
    min-height: 400px;
  }
  
  /* 瀑布流优化 */
  .columns-2 {
    column-count: 2;
  }
  
  @media (min-width: 768px) {
    .columns-4 {
      column-count: 4;
    }
  }
  
  /* 防止卡片被分割 */
  .break-inside-avoid {
    break-inside: avoid;
    page-break-inside: avoid;
  }
</style> 