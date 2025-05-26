<script lang="ts">
  import { onMount } from 'svelte';
  
  export let userRole: string = 'fan'; // fan, member, master, firstmate
  export let userName: string = '';
  
  let mobileMenuOpen = false;
  
  interface MenuItem {
    name: string;
    href: string;
    icon: string;
  }
  
  // 根据角色定义菜单项
  $: menuItems = getMenuItems(userRole);
  
  function getMenuItems(role: string): MenuItem[] {
    const baseItems = [
      { name: '私信', href: '/chat', icon: '💬' },
      { name: '算命', href: '/fortune', icon: '🔮' },
      { name: '带货', href: '/shop', icon: '🛍️' },
      { name: '个人', href: '/profile', icon: '👤' }
    ];
    
    if (role === 'master' || role === 'firstmate') {
      return [
        ...baseItems,
        { name: '邀请链接', href: '/invite', icon: '🔗' },
        { name: '算命开关', href: '/fortune/settings', icon: '⚙️' }
      ];
    }
    
    return baseItems;
  }
  
  function toggleMobileMenu() {
    mobileMenuOpen = !mobileMenuOpen;
  }
  
  function logout() {
    // 实际项目中这里应该调用 Supabase 的登出方法
    window.location.assign('https://baiduohui.com');
  }
</script>

<nav class="bg-white shadow-sm border-b border-gray-200">
  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
    <div class="flex justify-between h-16">
      <!-- Logo 和主导航 -->
      <div class="flex">
        <div class="flex-shrink-0 flex items-center">
          <div class="h-8 w-8 rounded-full bg-gradient-to-r from-blue-600 to-purple-600 flex items-center justify-center">
            <span class="text-sm font-bold text-white">百</span>
          </div>
          <span class="ml-2 text-xl font-semibold text-gray-900">百刀会</span>
        </div>
        
        <!-- 桌面端菜单 -->
        <div class="hidden sm:ml-6 sm:flex sm:space-x-8">
          {#each menuItems as item}
            <a
              href={item.href}
              class="inline-flex items-center px-1 pt-1 text-sm font-medium text-gray-500 hover:text-gray-700 hover:border-gray-300 transition-colors duration-200"
            >
              <span class="mr-1">{item.icon}</span>
              {item.name}
            </a>
          {/each}
        </div>
      </div>
      
      <!-- 右侧用户信息 -->
      <div class="hidden sm:ml-6 sm:flex sm:items-center">
        <div class="relative">
          <button
            type="button"
            class="bg-white rounded-full flex text-sm focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
            on:click={toggleMobileMenu}
          >
            <span class="sr-only">打开用户菜单</span>
            <div class="h-8 w-8 rounded-full bg-gray-300 flex items-center justify-center">
              <span class="text-sm font-medium text-gray-700">
                {userName ? userName.charAt(0).toUpperCase() : '用'}
              </span>
            </div>
          </button>
          
          {#if mobileMenuOpen}
            <div class="origin-top-right absolute right-0 mt-2 w-48 rounded-md shadow-lg bg-white ring-1 ring-black ring-opacity-5 z-50">
              <div class="py-1">
                <div class="px-4 py-2 text-sm text-gray-700 border-b border-gray-100">
                  <div class="font-medium">{userName || '用户'}</div>
                  <div class="text-xs text-gray-500 capitalize">{userRole}</div>
                </div>
                <a href="/profile" class="block px-4 py-2 text-sm text-gray-700 hover:bg-gray-100">个人设置</a>
                <button
                  on:click={logout}
                  class="block w-full text-left px-4 py-2 text-sm text-gray-700 hover:bg-gray-100"
                >
                  退出登录
                </button>
              </div>
            </div>
          {/if}
        </div>
      </div>
      
      <!-- 移动端菜单按钮 -->
      <div class="sm:hidden flex items-center">
        <button
          type="button"
          class="inline-flex items-center justify-center p-2 rounded-md text-gray-400 hover:text-gray-500 hover:bg-gray-100 focus:outline-none focus:ring-2 focus:ring-inset focus:ring-blue-500"
          on:click={toggleMobileMenu}
        >
          <span class="sr-only">打开主菜单</span>
          {#if !mobileMenuOpen}
            <svg class="block h-6 w-6" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16" />
            </svg>
          {:else}
            <svg class="block h-6 w-6" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          {/if}
        </button>
      </div>
    </div>
  </div>
  
  <!-- 移动端菜单 -->
  {#if mobileMenuOpen}
    <div class="sm:hidden">
      <div class="pt-2 pb-3 space-y-1">
        {#each menuItems as item}
          <a
            href={item.href}
            class="block pl-3 pr-4 py-2 text-base font-medium text-gray-500 hover:text-gray-700 hover:bg-gray-50"
          >
            <span class="mr-2">{item.icon}</span>
            {item.name}
          </a>
        {/each}
      </div>
      <div class="pt-4 pb-3 border-t border-gray-200">
        <div class="flex items-center px-4">
          <div class="flex-shrink-0">
            <div class="h-10 w-10 rounded-full bg-gray-300 flex items-center justify-center">
              <span class="text-sm font-medium text-gray-700">
                {userName ? userName.charAt(0).toUpperCase() : '用'}
              </span>
            </div>
          </div>
          <div class="ml-3">
            <div class="text-base font-medium text-gray-800">{userName || '用户'}</div>
            <div class="text-sm font-medium text-gray-500 capitalize">{userRole}</div>
          </div>
        </div>
        <div class="mt-3 space-y-1">
          <a href="/profile" class="block px-4 py-2 text-base font-medium text-gray-500 hover:text-gray-700 hover:bg-gray-50">
            个人设置
          </a>
          <button
            on:click={logout}
            class="block w-full text-left px-4 py-2 text-base font-medium text-gray-500 hover:text-gray-700 hover:bg-gray-50"
          >
            退出登录
          </button>
        </div>
      </div>
    </div>
  {/if}
</nav>

<!-- 点击外部关闭菜单 -->
{#if mobileMenuOpen}
  <div
    class="fixed inset-0 z-40"
    role="button"
    tabindex="0"
    on:click={toggleMobileMenu}
    on:keydown={(e) => e.key === 'Escape' && toggleMobileMenu()}
  ></div>
{/if} 