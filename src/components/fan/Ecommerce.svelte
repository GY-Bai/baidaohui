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
              <div class="w-full aspect-square bg-gray-200 flex items-center justify-center">
                <span class="text-gray-400 text-4xl">📦</span>
              </div>
            {/if}
            
            <!-- 商户徽章 -->
            <div class="absolute top-2 right-2">
              <span 
                class="px-2 py-1 text-xs text-white rounded-full {getStoreBadgeColor(product.storeId)}"
                title={product.storeName || product.storeId}
              >
                {product.storeName || product.storeId}
              </span>
            </div>
          </div>

          <!-- 商品信息 -->
          <div class="p-4">
            <h3 
              class="font-medium text-gray-800 mb-2 leading-tight"
              title={product.name}
            >
              {truncateText(product.name, 50)}
            </h3>
            
            <div class="flex items-center justify-between mb-2">
              <span class="text-lg font-bold text-red-500">
                {formatPrice(product.default_price.unit_amount, product.default_price.currency)}
              </span>
              
              {#if product.payment_link && product.payment_link.active}
                <span class="text-xs text-green-600 bg-green-100 px-2 py-1 rounded">
                  可购买
                </span>
              {:else}
                <span class="text-xs text-gray-500 bg-gray-100 px-2 py-1 rounded">
                  暂不可购买
                </span>
              {/if}
            </div>

            <!-- 商品标签 -->
            {#if product.tags && product.tags.length > 0}
              <div class="flex flex-wrap gap-1">
                {#each product.tags.slice(0, 3) as tag}
                  <span class="text-xs bg-blue-100 text-blue-700 px-2 py-1 rounded">
                    {tag}
                  </span>
                {/each}
              </div>
            {/if}

            <!-- 查看详情按钮 -->
            <button 
              class="w-full mt-3 py-2 text-sm text-blue-600 border border-blue-600 rounded hover:bg-blue-50 transition-colors"
              on:click|stopPropagation={() => openProductDetail(product)}
            >
              查看详情
            </button>
          </div>
        </div>
      {/each}
    </div>
  {/if}
</div>

<!-- 商品详情模态框 -->
{#if showProductModal && selectedProduct}
  <div 
    class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4"
    on:click={closeProductDetail}
    role="dialog"
    aria-modal="true"
    aria-labelledby="product-modal-title"
  >
    <div 
      class="bg-white rounded-lg max-w-4xl w-full max-h-[90vh] overflow-y-auto"
      on:click|stopPropagation
    >
      <!-- 模态框头部 -->
      <div class="flex items-center justify-between p-4 border-b sticky top-0 bg-white z-10">
        <h2 id="product-modal-title" class="text-xl font-bold text-gray-800">
          {selectedProduct.name}
        </h2>
        <button 
          on:click={closeProductDetail}
          class="text-gray-400 hover:text-gray-600 text-2xl w-8 h-8 flex items-center justify-center"
          aria-label="关闭"
        >
          ×
        </button>
      </div>

      <!-- 模态框内容 -->
      <div class="p-4">
        <div class="grid md:grid-cols-2 gap-6">
          <!-- 左侧：商品图片 -->
          <div>
            {#if selectedProduct.images && selectedProduct.images.length > 0}
              <div class="mb-4">
                <div class="aspect-square bg-gray-100 rounded-lg overflow-hidden">
                  <img 
                    src={selectedProduct.images[currentImageIndex]} 
                    alt={selectedProduct.name}
                    class="w-full h-full object-cover"
                  />
                </div>
                
                {#if selectedProduct.images.length > 1}
                  <div class="flex gap-2 mt-2 overflow-x-auto">
                    {#each selectedProduct.images as image, index}
                      <button
                        on:click={() => changeImage(index)}
                        class="w-16 h-16 flex-shrink-0"
                      >
                        <img 
                          src={image} 
                          alt="{selectedProduct.name} 图片 {index + 1}"
                          class="w-full h-full object-cover rounded border-2 {currentImageIndex === index ? 'border-blue-500' : 'border-transparent hover:border-blue-300'} transition-colors"
                        />
                      </button>
                    {/each}
                  </div>
                {/if}
              </div>
            {/if}
          </div>

          <!-- 右侧：商品信息 -->
          <div>
            <div class="mb-4">
              <div class="flex items-center justify-between mb-2">
                <span class="text-3xl font-bold text-red-500">
                  {formatPrice(selectedProduct.default_price.unit_amount, selectedProduct.default_price.currency)}
                </span>
                <span class="text-sm text-gray-500 bg-gray-100 px-3 py-1 rounded-full">
                  {selectedProduct.storeName || selectedProduct.storeId}
                </span>
              </div>
              
              {#if selectedProduct.description}
                <div class="text-gray-600 whitespace-pre-wrap leading-relaxed">
                  {selectedProduct.description}
                </div>
              {/if}

              <!-- 商品标签 -->
              {#if selectedProduct.tags && selectedProduct.tags.length > 0}
                <div class="flex flex-wrap gap-2 mt-4">
                  {#each selectedProduct.tags as tag}
                    <span class="text-sm bg-blue-100 text-blue-700 px-3 py-1 rounded-full">
                      {tag}
                    </span>
                  {/each}
                </div>
              {/if}
            </div>

            <!-- 购买按钮 -->
            <div class="flex gap-3 mb-6">
              {#if selectedProduct.payment_link && selectedProduct.payment_link.active}
                <button 
                  on:click={() => buyNow(selectedProduct)}
                  class="flex-1 bg-red-500 text-white py-3 px-6 rounded-lg font-medium hover:bg-red-600 transition-colors"
                >
                  立即购买
                </button>
              {:else}
                <button 
                  disabled
                  class="flex-1 bg-gray-300 text-gray-500 py-3 px-6 rounded-lg font-medium cursor-not-allowed"
                >
                  暂不可购买
                </button>
              {/if}
              
              <button 
                on:click={closeProductDetail}
                class="px-6 py-3 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors"
              >
                取消
              </button>
            </div>
          </div>
        </div>

        <!-- 相关推荐 -->
        {#if relatedProducts.length > 0}
          <div class="border-t pt-6">
            <h3 class="text-lg font-semibold text-gray-800 mb-4">相关推荐</h3>
            <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
              {#each relatedProducts as product}
                <div 
                  class="bg-gray-50 rounded-lg overflow-hidden hover:bg-gray-100 transition-colors cursor-pointer"
                  on:click={() => openProductDetail(product)}
                >
                  <div class="aspect-square">
                    {#if product.images && product.images.length > 0}
                      <img 
                        src={product.images[0]} 
                        alt={product.name}
                        class="w-full h-full object-cover"
                        loading="lazy"
                      />
                    {:else}
                      <div class="w-full h-full bg-gray-200 flex items-center justify-center">
                        <span class="text-gray-400 text-2xl">📦</span>
                      </div>
                    {/if}
                  </div>
                  <div class="p-3">
                    <h4 class="text-sm font-medium text-gray-800 mb-1" title={product.name}>
                      {truncateText(product.name, 30)}
                    </h4>
                    <span class="text-sm font-bold text-red-500">
                      {formatPrice(product.default_price.unit_amount, product.default_price.currency)}
                    </span>
                  </div>
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
  
  .aspect-square {
    aspect-ratio: 1 / 1;
  }
  
  .aspect-video {
    aspect-ratio: 16 / 9;
  }

  /* 瀑布流优化 */
  .columns-2 {
    column-count: 2;
    column-gap: 1rem;
  }
  
  @media (min-width: 768px) {
    .columns-4 {
      column-count: 4;
    }
  }
  
  .break-inside-avoid {
    break-inside: avoid;
    page-break-inside: avoid;
  }
</style> 