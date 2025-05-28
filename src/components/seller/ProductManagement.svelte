<script lang="ts">
  import { onMount, createEventDispatcher } from 'svelte';
  import { apiCall } from '$lib/auth';
  import type { UserSession } from '$lib/auth';

  const dispatch = createEventDispatcher();

  export let session: UserSession;

  interface Product {
    id: string;
    name: string;
    description: string;
    price: number;
    originalPrice?: number;
    stock: number;
    category: string;
    images: string[];
    isActive: boolean;
    stripeProductId?: string;
    stripePriceId?: string;
    paymentLinkUrl?: string;
    createdAt: string;
    updatedAt: string;
  }

  let products: Product[] = [];
  let loading = true;
  let error = '';
  let showProductModal = false;
  let showVideoModal = false;
  let editingProduct: Product | null = null;
  let activeTab = 'products';

  let productForm = {
    name: '',
    description: '',
    price: '',
    originalPrice: '',
    stock: '',
    category: '',
    images: [],
    isActive: true
  };

  // YouTube视频相关
  let currentVideoId = 'dQw4w9WgXcQ'; // 默认视频ID
  let videoQuality = '720p';
  let isFullscreen = false;

  const categories = [
    '服装配饰',
    '美妆护肤',
    '数码电子',
    '家居生活',
    '食品饮料',
    '运动户外',
    '图书文具',
    '其他'
  ];

  const videoQualities = [
    { value: '360p', label: '360p' },
    { value: '480p', label: '480p' },
    { value: '720p', label: '720p (推荐)' },
    { value: '1080p', label: '1080p' }
  ];

  // 教程视频列表
  const tutorialVideos = [
    {
      id: 'dQw4w9WgXcQ',
      title: '百道会商户入门指南',
      description: '了解如何在百道会平台开始销售您的商品',
      duration: '10:30'
    },
    {
      id: 'dQw4w9WgXcQ',
      title: 'Stripe密钥配置教程',
      description: '详细介绍如何获取和配置Stripe支付密钥',
      duration: '8:45'
    },
    {
      id: 'dQw4w9WgXcQ',
      title: '商品管理最佳实践',
      description: '学习如何优化商品信息以提高销售转化率',
      duration: '15:20'
    }
  ];

  onMount(() => {
    loadProducts();
  });

  async function loadProducts() {
    try {
      loading = true;
      error = '';
      
      const response = await apiCall('/seller/products');
      products = response.products || [];
    } catch (err) {
      console.error('加载商品失败:', err);
      error = '加载商品失败，请重试';
      products = [];
    } finally {
      loading = false;
    }
  }

  function openProductModal(product: Product | null = null) {
    editingProduct = product;
    if (product) {
      productForm = {
        name: product.name,
        description: product.description,
        price: product.price.toString(),
        originalPrice: product.originalPrice?.toString() || '',
        stock: product.stock.toString(),
        category: product.category,
        images: [...product.images],
        isActive: product.isActive
      };
    } else {
      productForm = {
        name: '',
        description: '',
        price: '',
        originalPrice: '',
        stock: '',
        category: '',
        images: [],
        isActive: true
      };
    }
    showProductModal = true;
  }

  function closeProductModal() {
    showProductModal = false;
    editingProduct = null;
    productForm = {
      name: '',
      description: '',
      price: '',
      originalPrice: '',
      stock: '',
      category: '',
      images: [],
      isActive: true
    };
  }

  async function saveProduct() {
    if (!productForm.name.trim() || !productForm.price || !productForm.stock) {
      alert('请填写必填字段');
      return;
    }

    const price = parseFloat(productForm.price);
    const originalPrice = productForm.originalPrice ? parseFloat(productForm.originalPrice) : null;
    const stock = parseInt(productForm.stock);

    if (isNaN(price) || price <= 0) {
      alert('请输入有效的价格');
      return;
    }

    if (originalPrice && (isNaN(originalPrice) || originalPrice <= price)) {
      alert('原价必须大于现价');
      return;
    }

    if (isNaN(stock) || stock < 0) {
      alert('请输入有效的库存数量');
      return;
    }

    try {
      const productData = {
        name: productForm.name.trim(),
        description: productForm.description.trim(),
        price,
        originalPrice,
        stock,
        category: productForm.category,
        images: productForm.images,
        isActive: productForm.isActive
      };

      const endpoint = editingProduct 
        ? `/seller/products/${editingProduct.id}`
        : '/seller/products';
      
      const method = editingProduct ? 'PUT' : 'POST';

      await apiCall(endpoint, {
        method,
        body: JSON.stringify(productData)
      });

      alert(editingProduct ? '商品更新成功' : '商品添加成功');
      closeProductModal();
      loadProducts();
    } catch (err) {
      console.error('保存商品失败:', err);
      alert('保存失败，请重试');
    }
  }

  async function toggleProductStatus(product: Product) {
    try {
      await apiCall(`/seller/products/${product.id}/toggle`, {
        method: 'PATCH'
      });
      loadProducts();
    } catch (err) {
      console.error('切换商品状态失败:', err);
      alert('操作失败');
    }
  }

  async function deleteProduct(product: Product) {
    if (!confirm(`确定要删除商品"${product.name}"吗？此操作不可撤销。`)) {
      return;
    }

    try {
      await apiCall(`/seller/products/${product.id}`, {
        method: 'DELETE'
      });
      alert('商品删除成功');
      loadProducts();
    } catch (err) {
      console.error('删除商品失败:', err);
      alert('删除失败');
    }
  }

  async function handleImageUpload(event: Event) {
    const target = event.target as HTMLInputElement;
    const files = Array.from(target.files || []);
    
    if (files.length === 0) return;

    try {
      const uploadPromises = files.map(async (file) => {
        const formData = new FormData();
        formData.append('file', file);
        
        const response = await fetch('/api/upload/image', {
          method: 'POST',
          body: formData
        });
        
        if (response.ok) {
          const result = await response.json();
          return result.url;
        }
        throw new Error('上传失败');
      });

      const urls = await Promise.all(uploadPromises);
      productForm.images = [...productForm.images, ...urls];
    } catch (err) {
      console.error('图片上传失败:', err);
      alert('图片上传失败，请重试');
    }
  }

  function removeImage(index: number) {
    productForm.images = productForm.images.filter((_, i) => i !== index);
  }

  function formatCurrency(amount: number): string {
    return new Intl.NumberFormat('zh-CN', {
      style: 'currency',
      currency: 'CNY'
    }).format(amount);
  }

  function formatDate(dateString: string): string {
    return new Date(dateString).toLocaleString('zh-CN');
  }

  // YouTube视频相关函数
  function playVideo(videoId: string) {
    currentVideoId = videoId;
    showVideoModal = true;
  }

  function closeVideoModal() {
    showVideoModal = false;
    isFullscreen = false;
  }

  function toggleFullscreen() {
    isFullscreen = !isFullscreen;
  }

  function getYouTubeEmbedUrl(videoId: string): string {
    const qualityParam = videoQuality === '1080p' ? 'hd1080' : 
                        videoQuality === '720p' ? 'hd720' : 
                        videoQuality === '480p' ? 'large' : 'medium';
    
    return `https://www.youtube.com/embed/${videoId}?autoplay=1&quality=${qualityParam}&rel=0&modestbranding=1`;
  }
</script>

<div class="space-y-6">
  <div class="bg-white rounded-lg shadow p-6">
    <div class="flex items-center justify-between mb-6">
      <h2 class="text-2xl font-semibold text-gray-900">商品与教程</h2>
    </div>

    <!-- 标签切换 -->
    <div class="border-b border-gray-200 mb-6">
      <nav class="-mb-px flex space-x-8">
        <button
          on:click={() => activeTab = 'products'}
          class="py-2 px-1 border-b-2 font-medium text-sm {
            activeTab === 'products'
              ? 'border-green-500 text-green-600'
              : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
          }"
        >
          商品管理
        </button>
        <button
          on:click={() => activeTab = 'tutorials'}
          class="py-2 px-1 border-b-2 font-medium text-sm {
            activeTab === 'tutorials'
              ? 'border-green-500 text-green-600'
              : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
          }"
        >
          教程视频
        </button>
      </nav>
    </div>

    <!-- 商品管理 -->
    {#if activeTab === 'products'}
      <div class="space-y-6">
        <div class="flex justify-between items-center">
          <div>
            <h3 class="text-lg font-semibold text-gray-900">我的商品</h3>
            <p class="text-sm text-gray-600">管理您在Stripe中的商品，这些商品将自动同步到平台</p>
          </div>
          <button
            on:click={() => openProductModal()}
            class="px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700 transition-colors"
          >
            添加商品
          </button>
        </div>

        <!-- 错误提示 -->
        {#if error}
          <div class="bg-red-50 border border-red-200 rounded-lg p-4">
            <div class="flex">
              <svg class="w-5 h-5 text-red-400 mr-2" fill="currentColor" viewBox="0 0 20 20">
                <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clip-rule="evenodd"></path>
              </svg>
              <span class="text-red-800">{error}</span>
            </div>
          </div>
        {/if}

        <!-- 商品列表 -->
        {#if loading}
          <div class="text-center py-8">
            <svg class="animate-spin h-8 w-8 text-green-600 mx-auto mb-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 714 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
            <p class="text-gray-600">加载中...</p>
          </div>
        {:else if products.length === 0}
          <div class="text-center py-8">
            <svg class="w-16 h-16 text-gray-400 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4"></path>
            </svg>
            <p class="text-gray-600 mb-4">暂无商品</p>
            <button
              on:click={() => openProductModal()}
              class="px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700 transition-colors"
            >
              添加第一个商品
            </button>
          </div>
        {:else}
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {#each products as product}
              <div class="bg-white border border-gray-200 rounded-lg overflow-hidden hover:shadow-md transition-shadow">
                <div class="aspect-w-16 aspect-h-9">
                  {#if product.images.length > 0}
                    <img src={product.images[0]} alt={product.name} class="w-full h-48 object-cover" />
                  {:else}
                    <div class="w-full h-48 bg-gray-200 flex items-center justify-center">
                      <svg class="w-12 h-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"></path>
                      </svg>
                    </div>
                  {/if}
                </div>
                
                <div class="p-4">
                  <div class="flex items-start justify-between mb-2">
                    <h4 class="font-medium text-gray-900 truncate">{product.name}</h4>
                    <span class="px-2 py-1 text-xs rounded-full {
                      product.isActive ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'
                    }">
                      {product.isActive ? '上架' : '下架'}
                    </span>
                  </div>
                  
                  <p class="text-sm text-gray-600 mb-3 line-clamp-2">{product.description}</p>
                  
                  <div class="flex items-center justify-between mb-3">
                    <div>
                      <span class="text-lg font-semibold text-gray-900">{formatCurrency(product.price)}</span>
                      {#if product.originalPrice}
                        <span class="text-sm text-gray-500 line-through ml-2">{formatCurrency(product.originalPrice)}</span>
                      {/if}
                    </div>
                    <span class="text-sm text-gray-600">库存: {product.stock}</span>
                  </div>
                  
                  <div class="flex space-x-2">
                    <button
                      on:click={() => openProductModal(product)}
                      class="flex-1 px-3 py-2 text-sm bg-blue-600 text-white rounded-md hover:bg-blue-700 transition-colors"
                    >
                      编辑
                    </button>
                    <button
                      on:click={() => toggleProductStatus(product)}
                      class="flex-1 px-3 py-2 text-sm {
                        product.isActive 
                          ? 'bg-yellow-600 hover:bg-yellow-700' 
                          : 'bg-green-600 hover:bg-green-700'
                      } text-white rounded-md transition-colors"
                    >
                      {product.isActive ? '下架' : '上架'}
                    </button>
                    <button
                      on:click={() => deleteProduct(product)}
                      class="px-3 py-2 text-sm bg-red-600 text-white rounded-md hover:bg-red-700 transition-colors"
                    >
                      删除
                    </button>
                  </div>
                </div>
              </div>
            {/each}
          </div>
        {/if}
      </div>
    {/if}

    <!-- 教程视频 -->
    {#if activeTab === 'tutorials'}
      <div class="space-y-6">
        <div>
          <h3 class="text-lg font-semibold text-gray-900 mb-2">教程视频</h3>
          <p class="text-sm text-gray-600">观看教程视频，快速掌握平台使用技巧</p>
        </div>

        <!-- 视频质量选择 -->
        <div class="flex items-center space-x-4">
          <label class="text-sm font-medium text-gray-700">视频质量:</label>
          <select
            bind:value={videoQuality}
            class="px-3 py-1 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-green-500"
          >
            {#each videoQualities as quality}
              <option value={quality.value}>{quality.label}</option>
            {/each}
          </select>
        </div>

        <!-- 视频列表 -->
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {#each tutorialVideos as video}
            <div class="bg-white border border-gray-200 rounded-lg overflow-hidden hover:shadow-md transition-shadow">
              <div class="relative">
                <img 
                  src={`https://img.youtube.com/vi/${video.id}/maxresdefault.jpg`} 
                  alt={video.title}
                  class="w-full h-48 object-cover"
                />
                <button
                  on:click={() => playVideo(video.id)}
                  class="absolute inset-0 flex items-center justify-center bg-black bg-opacity-30 hover:bg-opacity-50 transition-all"
                >
                  <svg class="w-16 h-16 text-white" fill="currentColor" viewBox="0 0 24 24">
                    <path d="M8 5v14l11-7z"/>
                  </svg>
                </button>
                <div class="absolute bottom-2 right-2 bg-black bg-opacity-75 text-white text-xs px-2 py-1 rounded">
                  {video.duration}
                </div>
              </div>
              
              <div class="p-4">
                <h4 class="font-medium text-gray-900 mb-2">{video.title}</h4>
                <p class="text-sm text-gray-600">{video.description}</p>
              </div>
            </div>
          {/each}
        </div>
      </div>
    {/if}
  </div>
</div>

<!-- 商品编辑弹窗 -->
{#if showProductModal}
  <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
    <div class="bg-white rounded-lg p-6 max-w-2xl w-full mx-4 max-h-[90vh] overflow-y-auto">
      <div class="flex items-center justify-between mb-6">
        <h3 class="text-lg font-semibold text-gray-900">
          {editingProduct ? '编辑商品' : '添加商品'}
        </h3>
        <button
          on:click={closeProductModal}
          class="text-gray-400 hover:text-gray-600"
        >
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
          </svg>
        </button>
      </div>

      <div class="space-y-4">
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">商品名称 *</label>
            <input
              type="text"
              bind:value={productForm.name}
              placeholder="输入商品名称"
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-green-500"
            />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">分类</label>
            <select
              bind:value={productForm.category}
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-green-500"
            >
              <option value="">选择分类</option>
              {#each categories as category}
                <option value={category}>{category}</option>
              {/each}
            </select>
          </div>
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">商品描述</label>
          <textarea
            bind:value={productForm.description}
            placeholder="输入商品描述"
            rows="3"
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-green-500"
          ></textarea>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">现价 * (元)</label>
            <input
              type="number"
              bind:value={productForm.price}
              placeholder="0.00"
              step="0.01"
              min="0"
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-green-500"
            />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">原价 (元)</label>
            <input
              type="number"
              bind:value={productForm.originalPrice}
              placeholder="0.00"
              step="0.01"
              min="0"
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-green-500"
            />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">库存 *</label>
            <input
              type="number"
              bind:value={productForm.stock}
              placeholder="0"
              min="0"
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-green-500"
            />
          </div>
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">商品图片</label>
          <input
            type="file"
            multiple
            accept="image/*"
            on:change={handleImageUpload}
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-green-500"
          />
          {#if productForm.images.length > 0}
            <div class="grid grid-cols-4 gap-2 mt-2">
              {#each productForm.images as image, index}
                <div class="relative">
                  <img src={image} alt="商品图片" class="w-full h-20 object-cover rounded" />
                  <button
                    on:click={() => removeImage(index)}
                    class="absolute -top-1 -right-1 w-5 h-5 bg-red-500 text-white rounded-full text-xs hover:bg-red-600"
                  >
                    ×
                  </button>
                </div>
              {/each}
            </div>
          {/if}
        </div>

        <div class="flex items-center">
          <input
            type="checkbox"
            bind:checked={productForm.isActive}
            class="h-4 w-4 text-green-600 focus:ring-green-500 border-gray-300 rounded"
          />
          <label class="ml-2 text-sm text-gray-700">立即上架</label>
        </div>

        <div class="flex space-x-3 pt-4">
          <button
            on:click={closeProductModal}
            class="flex-1 px-4 py-2 bg-gray-300 text-gray-700 rounded-md hover:bg-gray-400 transition-colors"
          >
            取消
          </button>
          <button
            on:click={saveProduct}
            class="flex-1 px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700 transition-colors"
          >
            {editingProduct ? '更新' : '添加'}
          </button>
        </div>
      </div>
    </div>
  </div>
{/if}

<!-- YouTube视频播放弹窗 -->
{#if showVideoModal}
  <div class="fixed inset-0 bg-black bg-opacity-75 flex items-center justify-center z-50">
    <div class="relative {isFullscreen ? 'w-full h-full' : 'w-full max-w-4xl mx-4'}">
      <div class="bg-white rounded-lg overflow-hidden {isFullscreen ? 'h-full' : ''}">
        <div class="flex items-center justify-between p-4 bg-gray-50">
          <h3 class="text-lg font-semibold text-gray-900">教程视频</h3>
          <div class="flex items-center space-x-2">
            <button
              on:click={toggleFullscreen}
              class="p-2 text-gray-600 hover:text-gray-900 transition-colors"
              title={isFullscreen ? '退出全屏' : '全屏播放'}
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                {#if isFullscreen}
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
                {:else}
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 8V4m0 0h4M4 4l5 5m11-1V4m0 0h-4m4 0l-5 5M4 16v4m0 0h4m-4 0l5-5m11 5l-5-5m5 5v-4m0 4h-4"></path>
                {/if}
              </svg>
            </button>
            <button
              on:click={closeVideoModal}
              class="p-2 text-gray-600 hover:text-gray-900 transition-colors"
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
              </svg>
            </button>
          </div>
        </div>
        
        <div class="{isFullscreen ? 'h-full' : 'aspect-w-16 aspect-h-9'}">
          <iframe
            src={getYouTubeEmbedUrl(currentVideoId)}
            title="YouTube video player"
            frameborder="0"
            allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
            allowfullscreen
            class="w-full {isFullscreen ? 'h-full' : 'h-96'}"
          ></iframe>
        </div>
      </div>
    </div>
  </div>
{/if} 