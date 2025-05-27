<script lang="ts">
  import { onMount, createEventDispatcher } from 'svelte';

  const dispatch = createEventDispatcher();

  let storeInfo = {
    name: '',
    description: '',
    logo: '',
    isActive: true,
    contactEmail: '',
    contactPhone: '',
    address: '',
    businessHours: ''
  };
  let loading = true;
  let saving = false;

  onMount(() => {
    loadStoreInfo();
  });

  async function loadStoreInfo() {
    try {
      loading = true;
      const response = await fetch('/api/seller/store-settings');
      if (response.ok) {
        storeInfo = await response.json();
      }
    } catch (error) {
      console.error('加载店铺信息失败:', error);
    } finally {
      loading = false;
    }
  }

  async function saveStoreInfo() {
    if (!storeInfo.name.trim()) {
      alert('请输入店铺名称');
      return;
    }

    try {
      saving = true;
      const response = await fetch('/api/seller/store-settings', {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(storeInfo)
      });

      if (response.ok) {
        alert('店铺信息保存成功');
        dispatch('storeUpdated');
      } else {
        const error = await response.json();
        alert(error.message || '保存失败');
      }
    } catch (error) {
      console.error('保存店铺信息失败:', error);
      alert('保存失败，请重试');
    } finally {
      saving = false;
    }
  }

  function handleLogoUpload(event) {
    const file = event.target.files[0];
    if (file) {
      // 这里应该上传文件到服务器并获取URL
      // 暂时使用模拟URL
      storeInfo.logo = `https://via.placeholder.com/200x200?text=Logo`;
    }
  }
</script>

<div class="space-y-6">
  <div class="bg-white rounded-lg shadow p-6">
    <h2 class="text-2xl font-semibold text-gray-900 mb-6">店铺设置</h2>

    {#if loading}
      <div class="text-center py-8">
        <svg class="animate-spin h-8 w-8 text-blue-600 mx-auto mb-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 714 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
        <p class="text-gray-600">加载中...</p>
      </div>
    {:else}
      <form on:submit|preventDefault={saveStoreInfo} class="space-y-6">
        <!-- 基本信息 -->
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <div class="space-y-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">
                店铺名称 *
              </label>
              <input
                type="text"
                bind:value={storeInfo.name}
                required
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                placeholder="请输入店铺名称"
              />
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">
                店铺描述
              </label>
              <textarea
                bind:value={storeInfo.description}
                rows="4"
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                placeholder="请输入店铺描述"
              ></textarea>
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">
                营业时间
              </label>
              <input
                type="text"
                bind:value={storeInfo.businessHours}
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                placeholder="例如：周一至周日 9:00-21:00"
              />
            </div>

            <div class="flex items-center">
              <input
                type="checkbox"
                bind:checked={storeInfo.isActive}
                id="storeActive"
                class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
              />
              <label for="storeActive" class="ml-2 block text-sm text-gray-900">
                店铺营业中
              </label>
            </div>
          </div>

          <div class="space-y-4">
            <!-- 店铺Logo -->
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">
                店铺Logo
              </label>
              <div class="flex items-center space-x-4">
                {#if storeInfo.logo}
                  <img src={storeInfo.logo} alt="店铺Logo" class="w-20 h-20 rounded-lg object-cover" />
                {:else}
                  <div class="w-20 h-20 bg-gray-200 rounded-lg flex items-center justify-center">
                    <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"></path>
                    </svg>
                  </div>
                {/if}
                <div>
                  <input
                    type="file"
                    accept="image/*"
                    on:change={handleLogoUpload}
                    class="block w-full text-sm text-gray-500 file:mr-4 file:py-2 file:px-4 file:rounded-full file:border-0 file:text-sm file:font-semibold file:bg-blue-50 file:text-blue-700 hover:file:bg-blue-100"
                  />
                  <p class="text-xs text-gray-500 mt-1">建议尺寸 200x200 像素</p>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- 联系信息 -->
        <div class="border-t pt-6">
          <h3 class="text-lg font-medium text-gray-900 mb-4">联系信息</h3>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">
                联系邮箱
              </label>
              <input
                type="email"
                bind:value={storeInfo.contactEmail}
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                placeholder="请输入联系邮箱"
              />
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">
                联系电话
              </label>
              <input
                type="tel"
                bind:value={storeInfo.contactPhone}
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                placeholder="请输入联系电话"
              />
            </div>
          </div>

          <div class="mt-4">
            <label class="block text-sm font-medium text-gray-700 mb-2">
              店铺地址
            </label>
            <input
              type="text"
              bind:value={storeInfo.address}
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              placeholder="请输入店铺地址"
            />
          </div>
        </div>

        <!-- 保存按钮 -->
        <div class="flex justify-end pt-6 border-t">
          <button
            type="submit"
            disabled={saving}
            class="px-6 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {saving ? '保存中...' : '保存设置'}
          </button>
        </div>
      </form>
    {/if}
  </div>

  <!-- 店铺预览 -->
  <div class="bg-white rounded-lg shadow p-6">
    <h3 class="text-lg font-semibold text-gray-900 mb-4">店铺预览</h3>
    <div class="border rounded-lg p-6 bg-gray-50">
      <div class="flex items-start space-x-4">
        {#if storeInfo.logo}
          <img src={storeInfo.logo} alt="店铺Logo" class="w-16 h-16 rounded-lg object-cover" />
        {:else}
          <div class="w-16 h-16 bg-gray-300 rounded-lg flex items-center justify-center">
            <svg class="w-6 h-6 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 11V7a4 4 0 00-8 0v4M5 9h14l1 12H4L5 9z"></path>
            </svg>
          </div>
        {/if}
        <div class="flex-1">
          <div class="flex items-center space-x-2 mb-2">
            <h4 class="text-xl font-semibold text-gray-900">
              {storeInfo.name || '店铺名称'}
            </h4>
            <span class="px-2 py-1 text-xs rounded-full {storeInfo.isActive ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'}">
              {storeInfo.isActive ? '营业中' : '已暂停'}
            </span>
          </div>
          <p class="text-gray-600 mb-3">
            {storeInfo.description || '暂无店铺描述'}
          </p>
          <div class="space-y-1 text-sm text-gray-500">
            {#if storeInfo.businessHours}
              <p>⏰ {storeInfo.businessHours}</p>
            {/if}
            {#if storeInfo.contactPhone}
              <p>📞 {storeInfo.contactPhone}</p>
            {/if}
            {#if storeInfo.address}
              <p>📍 {storeInfo.address}</p>
            {/if}
          </div>
        </div>
      </div>
    </div>
  </div>
</div>