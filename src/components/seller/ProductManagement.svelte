<script lang="ts">
  import { onMount, createEventDispatcher } from 'svelte';

  const dispatch = createEventDispatcher();

  let products = [];
  let loading = true;
  let showProductModal = false;
  let editingProduct = null;
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

  onMount(() => {
    loadProducts();
  });

  async function loadProducts() {
    try {
      loading = true;
      const response = await fetch('/api/seller/products');
      if (response.ok) {
        products = await response.json();
      }
    } catch (error) {
      console.error('加载商品失败:', error);
    } finally {
      loading = false;
    }
  }

  function openProductModal(product = null) {
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

      const url = editingProduct 
        ? `/api/seller/products/${editingProduct.id}`
        : '/api/seller/products';
      
      const method = editingProduct ? 'PUT' : 'POST';

      const response = await fetch(url, {
        method,
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(productData)
      });

      if (response.ok) {
        alert(editingProduct ? '商品更新成功' : '商品添加成功');
        closeProductModal();
        loadProducts();
      } else {
        const error = await response.json();
        alert(error.message || '保存失败');
      }
    } catch (error) {
      console.error('保存商品失败:', error);
      alert('保存失败，请重试');
    }
  }

  async function toggleProductStatus(product) {
    try {
      const response = await fetch(`/api/seller/products/${product.id}/toggle`, {
        method: 'PATCH'
      });

      if (response.ok) {
        loadProducts();
      } else {
        alert('操作失败');
      }
    } catch (error) {
      console.error('切换商品状态失败:', error);
      alert('操作失败');
    }
  }

  async function deleteProduct(product) {
    if (!confirm(`确定要删除商品"${product.name}"吗？此操作不可撤销。`)) {
      return;
    }

    try {
      const response = await fetch(`/api/seller/products/${product.id}`, {
        method: 'DELETE'
      });

      if (response.ok) {
        alert('商品删除成功');
        loadProducts();
      } else {
        alert('删除失败');
      }
    } catch (error) {
      console.error('删除商品失败:', error);
      alert('删除失败');
    }
  }

  function handleImageUpload(event) {
    const files = Array.from(event.target.files);
    // 这里应该上传图片到服务器并获取URL
    // 暂时使用模拟URL
    files.forEach((file, index) => {
      const mockUrl = `https://via.placeholder.com/300x300?text=Product+${productForm.images.length + index + 1}`;
      productForm.images = [...productForm.images, mockUrl];
    });
  }

  function removeImage(index) {
    productForm.images = productForm.images.filter((_, i) => i !== index);
  }

  function formatCurrency(amount) {
    return new Intl.NumberFormat('zh-CN', {
      style: 'currency',
      currency: 'CNY'
    }).format(amount);
  }

  function getStockStatusColor(stock) {
    if (stock === 0) return 'text-red-600 bg-red-100';
    if (stock < 10) return 'text-yellow-600 bg-yellow-100';
    return 'text-green-600 bg-green-100';
  }

  function getStockStatusText(stock) {
    if (stock === 0) return '缺货';
    if (stock < 10) return '库存不足';
    return '库存充足';
  }
</script>

<div class="space-y-6">
  <div class="bg-white rounded-lg shadow p-6">
    <div class="flex justify-between items-center mb-6">
      <h2 class="text-2xl font-semibold text-gray-900">商品管理</h2>
      <button
        on:click={() => openProductModal()}
        class="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500"
      >
        ➕ 添加商品
      </button>
    </div>

    <!-- 商品列表 -->
    {#if loading}
      <div class="text-center py-8">
        <svg class="animate-spin h-8 w-8 text-blue-600 mx-auto mb-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
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
        <p class="text-gray-600 mb-4">还没有商品</p>
        <button
          on:click={() => openProductModal()}
          class="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700"
        >
          添加第一个商品
        </button>
      </div>
    {:else}
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {#each products as product}
          <div class="border rounded-lg overflow-hidden hover:shadow-lg transition-shadow">
            <!-- 商品图片 -->
            <div class="aspect-w-1 aspect-h-1 bg-gray-200">
              {#if product.images && product.images.length > 0}
                <img src={product.images[0]} alt={product.name} class="w-full h-48 object-cover" />
              {:else}
                <div class="w-full h-48 flex items-center justify-center text-gray-400">
                  <svg class="w-12 h-12" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"></path>
                  </svg>
                </div>
              {/if}
            </div>

            <!-- 商品信息 -->
            <div class="p-4">
              <div class="flex items-start justify-between mb-2">
                <h3 class="text-lg font-medium text-gray-900 truncate flex-1">{product.name}</h3>
                <div class="ml-2 flex items-center space-x-1">
                  {#if !product.isActive}
                    <span class="px-2 py-1 text-xs bg-gray-100 text-gray-800 rounded-full">已下架</span>
                  {/if}
                </div>
              </div>

              <p class="text-sm text-gray-600 mb-3 line-clamp-2">{product.description}</p>

              <div class="flex items-center justify-between mb-3">
                <div class="flex items-center space-x-2">
                  <span class="text-lg font-bold text-red-600">{formatCurrency(product.price)}</span>
                  {#if product.originalPrice}
                    <span class="text-sm text-gray-500 line-through">{formatCurrency(product.originalPrice)}</span>
                  {/if}
                </div>
                <span class="px-2 py-1 text-xs rounded-full {getStockStatusColor(product.stock)}">
                  {getStockStatusText(product.stock)}
                </span>
              </div>

              <div class="flex items-center justify-between text-sm text-gray-500 mb-4">
                <span>库存: {product.stock}</span>
                <span>分类: {product.category}</span>
              </div>

              <!-- 操作按钮 -->
              <div class="flex space-x-2">
                <button
                  on:click={() => openProductModal(product)}
                  class="flex-1 px-3 py-2 text-sm bg-blue-600 text-white rounded hover:bg-blue-700"
                >
                  编辑
                </button>
                <button
                  on:click={() => toggleProductStatus(product)}
                  class="flex-1 px-3 py-2 text-sm {product.isActive ? 'bg-yellow-600 hover:bg-yellow-700' : 'bg-green-600 hover:bg-green-700'} text-white rounded"
                >
                  {product.isActive ? '下架' : '上架'}
                </button>
                <button
                  on:click={() => deleteProduct(product)}
                  class="px-3 py-2 text-sm bg-red-600 text-white rounded hover:bg-red-700"
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
</div>

<!-- 商品编辑模态框 -->
{#if showProductModal}
  <div class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50">
    <div class="relative top-20 mx-auto p-5 border w-full max-w-2xl shadow-lg rounded-md bg-white">
      <div class="mt-3">
        <div class="flex justify-between items-center mb-4">
          <h3 class="text-lg font-medium text-gray-900">
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

        <form on:submit|preventDefault={saveProduct} class="space-y-4">
          <!-- 商品名称 -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">
              商品名称 *
            </label>
            <input
              type="text"
              bind:value={productForm.name}
              required
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              placeholder="请输入商品名称"
            />
          </div>

          <!-- 商品描述 -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">
              商品描述
            </label>
            <textarea
              bind:value={productForm.description}
              rows="3"
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              placeholder="请输入商品描述"
            ></textarea>
          </div>

          <!-- 价格信息 -->
          <div class="grid grid-cols-2 gap-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">
                现价 * (元)
              </label>
              <input
                type="number"
                bind:value={productForm.price}
                step="0.01"
                min="0"
                required
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                placeholder="0.00"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">
                原价 (元)
              </label>
              <input
                type="number"
                bind:value={productForm.originalPrice}
                step="0.01"
                min="0"
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                placeholder="0.00"
              />
            </div>
          </div>

          <!-- 库存和分类 -->
          <div class="grid grid-cols-2 gap-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">
                库存数量 *
              </label>
              <input
                type="number"
                bind:value={productForm.stock}
                min="0"
                required
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                placeholder="0"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">
                商品分类
              </label>
              <select
                bind:value={productForm.category}
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              >
                <option value="">请选择分类</option>
                {#each categories as category}
                  <option value={category}>{category}</option>
                {/each}
              </select>
            </div>
          </div>

          <!-- 商品图片 -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">
              商品图片
            </label>
            <div class="space-y-3">
              <!-- 图片预览 -->
              {#if productForm.images.length > 0}
                <div class="grid grid-cols-4 gap-2">
                  {#each productForm.images as image, index}
                    <div class="relative">
                      <img src={image} alt="商品图片" class="w-full h-20 object-cover rounded" />
                      <button
                        type="button"
                        on:click={() => removeImage(index)}
                        class="absolute -top-1 -right-1 w-5 h-5 bg-red-500 text-white rounded-full text-xs hover:bg-red-600"
                      >
                        ×
                      </button>
                    </div>
                  {/each}
                </div>
              {/if}
              
              <!-- 上传按钮 -->
              <input
                type="file"
                multiple
                accept="image/*"
                on:change={handleImageUpload}
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
              <p class="text-xs text-gray-500">支持多张图片上传，建议尺寸 800x800 像素</p>
            </div>
          </div>

          <!-- 商品状态 -->
          <div class="flex items-center">
            <input
              type="checkbox"
              bind:checked={productForm.isActive}
              id="isActive"
              class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
            />
            <label for="isActive" class="ml-2 block text-sm text-gray-900">
              立即上架销售
            </label>
          </div>

          <!-- 操作按钮 -->
          <div class="flex space-x-3 pt-4">
            <button
              type="submit"
              class="flex-1 px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
              {editingProduct ? '更新商品' : '添加商品'}
            </button>
            <button
              type="button"
              on:click={closeProductModal}
              class="flex-1 px-4 py-2 bg-gray-300 text-gray-700 rounded-md hover:bg-gray-400 focus:outline-none focus:ring-2 focus:ring-gray-500"
            >
              取消
            </button>
          </div>
        </form>
      </div>
    </div>
  </div>
{/if} 