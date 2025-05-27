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
  <div class="flex justify-between items-center mb-6">
    <h2 class="text-2xl font-semibold text-gray-900">带货</h2>
    <div class="flex items-center space-x-2">
      <span class="px-2 py-1 text-xs bg-green-100 text-green-800 rounded-full">Member 特权</span>
      <button
        on:click={loadProducts}
        class="px-3 py-2 text-sm bg-gray-100 text-gray-700 rounded-md hover:bg-gray-200 focus:outline-none focus:ring-2 focus:ring-gray-500"
      >
        🔄 刷新
      </button>
    </div>
  </div>

  <!-- Member特有的优惠提示 -->
  <div class="mb-4 p-3 bg-green-50 border border-green-200 rounded-lg">
    <div class="flex items-center">
      <svg class="w-5 h-5 text-green-500 mr-2" fill="currentColor" viewBox="0 0 20 20">
        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"></path>
      </svg>
      <span class="text-green-800 text-sm font-medium">Member 专享优惠</span>
    </div>
    <p class="text-green-700 text-sm mt-1">部分商品享受 Member 专属折扣，购买时自动应用</p>
  </div>

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
          class="bg-white rounded-lg shadow-md overflow-hidden cursor-pointer transform transition-transform hover:scale-105 relative"
          on:click={() => openProductDetail(product)}
          role="button"
          tabindex="0"
          aria-label="购买 {product.name}"
          on:keydown={(e) => e.key === 'Enter' && openProductDetail(product)}
        >
          <!-- Member专享标识 -->
          {#if product.memberDiscount}
            <div class="absolute top-2 left-2 bg-green-500 text-white text-xs px-2 py-1 rounded-full z-10">
              Member 专享
            </div>
          {/if}

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
              {#if product.memberPrice && product.memberPrice < product.price}
                <div class="flex items-center space-x-2">
                  <span class="text-lg font-bold text-green-600">
                    {formatPrice(product.memberPrice)}
                  </span>
                  <span class="text-sm text-gray-500 line-through">
                    {formatPrice(product.price)}
                  </span>
                </div>
              {:else if product.originalPrice && product.originalPrice > product.price}
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
              class="w-full mt-3 px-4 py-2 bg-green-600 text-white text-sm font-medium rounded-md hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-green-500 transition-colors"
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
                  class="w-16 h-16 object-cover rounded cursor-pointer border-2 border-transparent hover:border-green-500"
                  on:error={handleImageError}
                />
              {/each}
            </div>
          {/if}
        </div>

        <!-- 商品信息 -->
        <div class="space-y-4">
          <!-- Member专享提示 -->
          {#if selectedProduct.memberPrice && selectedProduct.memberPrice < selectedProduct.price}
            <div class="bg-green-50 border border-green-200 rounded-lg p-3">
              <div class="flex items-center">
                <svg class="w-5 h-5 text-green-500 mr-2" fill="currentColor" viewBox="0 0 20 20">
                  <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"></path>
                </svg>
                <span class="text-green-800 text-sm font-medium">Member 专享价格</span>
              </div>
            </div>
          {/if}

          <!-- 价格 -->
          <div>
            {#if selectedProduct.memberPrice && selectedProduct.memberPrice < selectedProduct.price}
              <div class="flex items-center space-x-3">
                <span class="text-2xl font-bold text-green-600">
                  {formatPrice(selectedProduct.memberPrice)}
                </span>
                <span class="text-lg text-gray-500 line-through">
                  {formatPrice(selectedProduct.price)}
                </span>
                <span class="bg-green-100 text-green-800 text-sm px-2 py-1 rounded">
                  Member 专享
                </span>
              </div>
            {:else if selectedProduct.originalPrice && selectedProduct.originalPrice > selectedProduct.price}
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
              class="w-full px-6 py-3 bg-green-600 text-white font-medium rounded-md hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-green-500 transition-colors"
              on:click={() => window.open(selectedProduct.paymentLink, '_blank')}
            >
              立即购买
            </button>
            
            <p class="text-xs text-gray-500 text-center">
              Member 专享价格将在支付时自动应用
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
                  <p class="text-xs font-medium text-gray-900">
                    {relatedProduct.memberPrice && relatedProduct.memberPrice < relatedProduct.price 
                      ? formatPrice(relatedProduct.memberPrice) 
                      : formatPrice(relatedProduct.price)}
                  </p>
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