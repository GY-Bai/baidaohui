<script lang="ts">
  import { onMount } from 'svelte';

  let products = [];
  let loading = true;
  let selectedProduct = null;
  let showProductModal = false;

  onMount(() => {
    loadProducts();
  });

  async function loadProducts() {
    try {
      loading = true;
      const response = await fetch('/api/products');
      if (response.ok) {
        products = await response.json();
      }
    } catch (error) {
      console.error('加载商品失败:', error);
    } finally {
      loading = false;
    }
  }

  function openProductDetail(product) {
    selectedProduct = product;
    showProductModal = true;
  }

  function closeProductModal() {
    showProductModal = false;
    selectedProduct = null;
  }

  function formatPrice(price, currency = 'CNY') {
    const formatter = new Intl.NumberFormat('zh-CN', {
      style: 'currency',
      currency: currency
    });
    return formatter.format(price / 100); // 假设价格以分为单位
  }

  function truncateText(text, maxLength = 50) {
    if (text.length <= maxLength) return text;
    return text.substring(0, maxLength) + '...';
  }

  function handleImageError(event) {
    event.target.src = '/placeholder-image.jpg'; // 占位图片
  }
</script>

<div class="bg-white rounded-lg shadow p-6">
  <h2 class="text-2xl font-semibold text-gray-900 mb-6">带货</h2>

  {#if loading}
    <div class="text-center py-8">
      <svg class="animate-spin h-8 w-8 text-blue-600 mx-auto mb-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
      </svg>
      <p class="text-gray-600">加载商品中...</p>
    </div>
  {:else if products.length === 0}
    <div class="text-center py-8">
      <svg class="w-16 h-16 text-gray-400 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 11V7a4 4 0 00-8 0v4M5 9h14l1 12H4L5 9z"></path>
      </svg>
      <p class="text-gray-600">暂无商品</p>
    </div>
  {:else}
    <!-- 移动端两列瀑布流，桌面端四列网格 -->
    <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
      {#each products as product}
        <div 
          class="bg-white rounded-lg shadow-md overflow-hidden cursor-pointer transform transition-transform hover:scale-105"
          on:click={() => openProductDetail(product)}
          role="button"
          tabindex="0"
          aria-label="购买 {product.name}"
          on:keydown={(e) => e.key === 'Enter' && openProductDetail(product)}
        >
          <!-- 商品图片 -->
          <div class="relative aspect-square">
            <img 
              src={product.imageUrls[0]} 
              alt={product.name}
              class="w-full h-full object-cover"
              loading="lazy"
              on:error={handleImageError}
            />
            
            <!-- 商户徽章 -->
            <div class="absolute top-2 right-2 bg-blue-500 text-white text-xs px-2 py-1 rounded-full">
              {product.storeId}
            </div>
          </div>

          <!-- 商品信息 -->
          <div class="p-4">
            <!-- 商品名称 -->
            <h3 
              class="font-medium text-gray-900 mb-2 line-clamp-2 leading-tight"
              title={product.name}
            >
              {truncateText(product.name, 40)}
            </h3>

            <!-- 价格 -->
            <div class="flex items-center justify-between">
              {#if product.originalPrice && product.originalPrice > product.price}
                <div class="flex items-center space-x-2">
                  <span class="text-lg font-bold text-red-600">
                    {formatPrice(product.price)}
                  </span>
                  <span class="text-sm text-gray-500 line-through">
                    {formatPrice(product.originalPrice)}
                  </span>
                </div>
              {:else}
                <span class="text-lg font-bold text-gray-900">
                  {formatPrice(product.price)}
                </span>
              {/if}
            </div>

            <!-- 查看详情按钮 -->
            <button 
              class="w-full mt-3 px-4 py-2 bg-blue-600 text-white text-sm font-medium rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 transition-colors"
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
  <div class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50" on:click={closeProductModal}>
    <div class="relative top-10 mx-auto p-5 border w-full max-w-4xl shadow-lg rounded-md bg-white" on:click|stopPropagation>
      <div class="flex justify-between items-start mb-4">
        <h3 class="text-xl font-semibold text-gray-900">{selectedProduct.name}</h3>
        <button 
          on:click={closeProductModal}
          class="text-gray-400 hover:text-gray-600 text-2xl"
        >
          ×
        </button>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <!-- 图片轮播 -->
        <div class="space-y-4">
          <div class="aspect-square bg-gray-100 rounded-lg overflow-hidden">
            <img 
              src={selectedProduct.imageUrls[0]} 
              alt={selectedProduct.name}
              class="w-full h-full object-cover"
              on:error={handleImageError}
            />
          </div>
          
          {#if selectedProduct.imageUrls.length > 1}
            <div class="flex space-x-2 overflow-x-auto">
              {#each selectedProduct.imageUrls as imageUrl, index}
                <img 
                  src={imageUrl} 
                  alt="{selectedProduct.name} - 图片 {index + 1}"
                  class="w-16 h-16 object-cover rounded cursor-pointer border-2 border-transparent hover:border-blue-500"
                  on:error={handleImageError}
                />
              {/each}
            </div>
          {/if}
        </div>

        <!-- 商品信息 -->
        <div class="space-y-4">
          <!-- 价格 -->
          <div>
            {#if selectedProduct.originalPrice && selectedProduct.originalPrice > selectedProduct.price}
              <div class="flex items-center space-x-3">
                <span class="text-2xl font-bold text-red-600">
                  {formatPrice(selectedProduct.price)}
                </span>
                <span class="text-lg text-gray-500 line-through">
                  {formatPrice(selectedProduct.originalPrice)}
                </span>
                <span class="bg-red-100 text-red-800 text-sm px-2 py-1 rounded">
                  折扣
                </span>
              </div>
            {:else}
              <span class="text-2xl font-bold text-gray-900">
                {formatPrice(selectedProduct.price)}
              </span>
            {/if}
          </div>

          <!-- 商户信息 -->
          <div class="flex items-center space-x-2">
            <span class="text-sm text-gray-600">商户:</span>
            <span class="bg-blue-100 text-blue-800 text-sm px-2 py-1 rounded">
              {selectedProduct.storeId}
            </span>
          </div>

          <!-- 商品描述 -->
          {#if selectedProduct.description}
            <div>
              <h4 class="font-medium text-gray-900 mb-2">商品描述</h4>
              <p class="text-gray-700 text-sm leading-relaxed">
                {selectedProduct.description}
              </p>
            </div>
          {/if}

          <!-- 购买按钮 -->
          <div class="space-y-3">
            <button 
              class="w-full px-6 py-3 bg-red-600 text-white font-medium rounded-md hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-red-500 transition-colors"
              on:click={() => window.open(selectedProduct.paymentLink, '_blank')}
            >
              立即购买
            </button>
            
            <p class="text-xs text-gray-500 text-center">
              点击购买将跳转到安全支付页面
            </p>
          </div>

          <!-- 相关推荐 -->
          <div>
            <h4 class="font-medium text-gray-900 mb-2">相关推荐</h4>
            <div class="grid grid-cols-2 gap-2">
              {#each products.filter(p => p.storeId === selectedProduct.storeId && p.id !== selectedProduct.id).slice(0, 4) as relatedProduct}
                <div 
                  class="border rounded-lg p-2 cursor-pointer hover:bg-gray-50"
                  on:click={() => openProductDetail(relatedProduct)}
                >
                  <img 
                    src={relatedProduct.imageUrls[0]} 
                    alt={relatedProduct.name}
                    class="w-full aspect-square object-cover rounded mb-1"
                    loading="lazy"
                    on:error={handleImageError}
                  />
                  <p class="text-xs text-gray-700 truncate">{relatedProduct.name}</p>
                  <p class="text-xs font-medium text-gray-900">{formatPrice(relatedProduct.price)}</p>
                </div>
              {/each}
            </div>
          </div>
        </div>
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
</style> 