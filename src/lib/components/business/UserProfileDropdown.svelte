<script lang="ts">
  import { createEventDispatcher, onMount } from 'svelte';
  import { clickOutside } from '$lib/utils/clickOutside';
  import Avatar from '$lib/components/ui/Avatar.svelte';
  import Badge from '$lib/components/ui/Badge.svelte';
  import OnlineStatusIndicator from '$lib/components/business/OnlineStatusIndicator.svelte';
  
  export let user = {
    id: '',
    name: '',
    username: '',
    email: '',
    avatar: '',
    status: 'offline',
    role: '',
    verified: false,
    premium: false
  };
  export let visible = false;
  export let position = 'bottom-right'; // bottom-left, bottom-right, top-left, top-right
  export let showUserInfo = true;
  export let showStatusToggle = true;
  export let menuItems = [];
  export let className = '';
  
  const dispatch = createEventDispatcher();
  
  // 默认菜单项
  const defaultMenuItems = [
    { type: 'item', icon: '👤', label: '个人资料', key: 'profile' },
    { type: 'item', icon: '⚙️', label: '账户设置', key: 'settings' },
    { type: 'item', icon: '🎨', label: '个性化', key: 'appearance' },
    { type: 'divider' },
    { type: 'item', icon: '📊', label: '数据统计', key: 'analytics' },
    { type: 'item', icon: '💎', label: '升级会员', key: 'upgrade', badge: '新功能' },
    { type: 'divider' },
    { type: 'item', icon: '❓', label: '帮助中心', key: 'help' },
    { type: 'item', icon: '📝', label: '意见反馈', key: 'feedback' },
    { type: 'divider' },
    { type: 'item', icon: '🚪', label: '退出登录', key: 'logout', variant: 'danger' }
  ];
  
  $: finalMenuItems = menuItems.length > 0 ? menuItems : defaultMenuItems;
  
  // 状态选项
  const statusOptions = [
    { value: 'online', label: '在线', icon: '🟢' },
    { value: 'away', label: '离开', icon: '🟡' },
    { value: 'busy', label: '忙碌', icon: '🔴' },
    { value: 'invisible', label: '隐身', icon: '⚫' }
  ];
  
  let dropdownElement;
  let showStatusMenu = false;
  
  function handleMenuClick(item) {
    if (item.disabled) return;
    
    dispatch('menuClick', { item });
    
    // 根据菜单项类型执行相应操作
    switch (item.key) {
      case 'profile':
        dispatch('profile', { user });
        break;
      case 'settings':
        dispatch('settings', { user });
        break;
      case 'logout':
        dispatch('logout', { user });
        break;
      default:
        // 自定义菜单项
        break;
    }
    
    visible = false;
  }
  
  function handleStatusChange(status) {
    dispatch('statusChange', { status, user });
    showStatusMenu = false;
  }
  
  function handleClose() {
    visible = false;
    showStatusMenu = false;
    dispatch('close');
  }
  
  function handleUserInfoClick() {
    dispatch('userInfoClick', { user });
  }
  
  // 键盘导航
  function handleKeydown(event) {
    if (event.key === 'Escape') {
      handleClose();
    }
  }
  
  onMount(() => {
    if (visible) {
      dropdownElement?.focus();
    }
  });
  
  $: if (visible) {
    document.addEventListener('keydown', handleKeydown);
  } else {
    document.removeEventListener('keydown', handleKeydown);
  }
</script>

{#if visible}
  <div 
    bind:this={dropdownElement}
    class="user-dropdown {position} {className}"
    use:clickOutside={handleClose}
    tabindex="-1"
    role="menu"
    aria-label="用户菜单"
  >
    <!-- 用户信息区域 -->
    {#if showUserInfo}
      <div class="user-info" on:click={handleUserInfoClick} role="button" tabindex="0">
        <div class="user-avatar">
          <Avatar
            src={user.avatar}
            alt={user.name}
            size="default"
            showStatus={false}
          />
          <OnlineStatusIndicator 
            status={user.status}
            position="bottom-right"
            size="sm"
            animated
          />
        </div>
        
        <div class="user-details">
          <div class="user-name">
            {user.name}
            {#if user.verified}
              <span class="verified-icon">✓</span>
            {/if}
            {#if user.premium}
              <Badge variant="warning" size="xs">👑</Badge>
            {/if}
          </div>
          
          {#if user.username}
            <div class="user-username">@{user.username}</div>
          {/if}
          
          {#if user.email}
            <div class="user-email">{user.email}</div>
          {/if}
          
          {#if user.role}
            <Badge variant="secondary" size="xs">{user.role}</Badge>
          {/if}
        </div>
        
        <div class="user-arrow">
          →
        </div>
      </div>
    {/if}
    
    <!-- 状态切换器 -->
    {#if showStatusToggle}
      <div class="status-section">
        <button 
          class="status-toggle"
          on:click={() => showStatusMenu = !showStatusMenu}
          aria-expanded={showStatusMenu}
        >
          <div class="status-current">
            <OnlineStatusIndicator 
              status={user.status}
              showText
              animated={false}
            />
          </div>
          <span class="toggle-arrow" class:expanded={showStatusMenu}>▼</span>
        </button>
        
        {#if showStatusMenu}
          <div class="status-menu">
            {#each statusOptions as option}
              <button 
                class="status-option"
                class:active={user.status === option.value}
                on:click={() => handleStatusChange(option.value)}
              >
                <span class="status-icon">{option.icon}</span>
                <span class="status-label">{option.label}</span>
                {#if user.status === option.value}
                  <span class="check-icon">✓</span>
                {/if}
              </button>
            {/each}
          </div>
        {/if}
      </div>
    {/if}
    
    <!-- 菜单项 -->
    <div class="menu-items">
      {#each finalMenuItems as item}
        {#if item.type === 'divider'}
          <div class="menu-divider"></div>
        {:else}
          <button 
            class="menu-item"
            class:danger={item.variant === 'danger'}
            class:disabled={item.disabled}
            on:click={() => handleMenuClick(item)}
            disabled={item.disabled}
          >
            <span class="menu-icon">{item.icon}</span>
            <span class="menu-label">{item.label}</span>
            
            {#if item.badge}
              <Badge variant="primary" size="xs">{item.badge}</Badge>
            {/if}
            
            {#if item.shortcut}
              <span class="menu-shortcut">{item.shortcut}</span>
            {/if}
            
            {#if item.hasSubmenu}
              <span class="submenu-arrow">→</span>
            {/if}
          </button>
        {/if}
      {/each}
    </div>
  </div>
{/if}

<style>
  .user-dropdown {
    position: absolute;
    z-index: 1000;
    background: white;
    border-radius: 12px;
    box-shadow: 0 12px 40px rgba(0, 0, 0, 0.15);
    border: 1px solid #e5e7eb;
    min-width: 280px;
    max-width: 320px;
    padding: 8px 0;
    backdrop-filter: blur(20px);
    background: rgba(255, 255, 255, 0.95);
    animation: dropdownFadeIn 0.2s ease-out;
  }
  
  @keyframes dropdownFadeIn {
    from {
      opacity: 0;
      transform: translateY(-8px) scale(0.95);
    }
    to {
      opacity: 1;
      transform: translateY(0) scale(1);
    }
  }
  
  /* 位置样式 */
  .bottom-left {
    top: 100%;
    left: 0;
    margin-top: 8px;
  }
  
  .bottom-right {
    top: 100%;
    right: 0;
    margin-top: 8px;
  }
  
  .top-left {
    bottom: 100%;
    left: 0;
    margin-bottom: 8px;
  }
  
  .top-right {
    bottom: 100%;
    right: 0;
    margin-bottom: 8px;
  }
  
  /* 用户信息区域 */
  .user-info {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 16px 20px;
    margin-bottom: 8px;
    cursor: pointer;
    transition: background-color 0.2s ease;
    border-bottom: 1px solid #f3f4f6;
  }
  
  .user-info:hover {
    background: #f9fafb;
  }
  
  .user-avatar {
    position: relative;
    flex-shrink: 0;
  }
  
  .user-details {
    flex: 1;
    min-width: 0;
  }
  
  .user-name {
    font-size: 16px;
    font-weight: 600;
    color: #111827;
    margin-bottom: 2px;
    display: flex;
    align-items: center;
    gap: 6px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  
  .verified-icon {
    color: #3b82f6;
    font-size: 14px;
  }
  
  .user-username {
    font-size: 13px;
    color: #6b7280;
    margin-bottom: 2px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  
  .user-email {
    font-size: 12px;
    color: #9ca3af;
    margin-bottom: 6px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  
  .user-arrow {
    color: #9ca3af;
    font-size: 14px;
    flex-shrink: 0;
  }
  
  /* 状态切换器 */
  .status-section {
    position: relative;
    padding: 8px 20px;
    margin-bottom: 8px;
    border-bottom: 1px solid #f3f4f6;
  }
  
  .status-toggle {
    width: 100%;
    display: flex;
    align-items: center;
    justify-content: space-between;
    background: none;
    border: 1px solid #e5e7eb;
    border-radius: 8px;
    padding: 8px 12px;
    cursor: pointer;
    transition: all 0.2s ease;
  }
  
  .status-toggle:hover {
    background: #f9fafb;
    border-color: #d1d5db;
  }
  
  .status-current {
    display: flex;
    align-items: center;
  }
  
  .toggle-arrow {
    font-size: 10px;
    color: #6b7280;
    transition: transform 0.2s ease;
  }
  
  .toggle-arrow.expanded {
    transform: rotate(180deg);
  }
  
  .status-menu {
    position: absolute;
    top: 100%;
    left: 20px;
    right: 20px;
    background: white;
    border-radius: 8px;
    box-shadow: 0 8px 24px rgba(0, 0, 0, 0.15);
    border: 1px solid #e5e7eb;
    z-index: 10;
    margin-top: 4px;
    animation: statusMenuFadeIn 0.15s ease-out;
  }
  
  @keyframes statusMenuFadeIn {
    from {
      opacity: 0;
      transform: translateY(-4px);
    }
    to {
      opacity: 1;
      transform: translateY(0);
    }
  }
  
  .status-option {
    width: 100%;
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 8px 12px;
    background: none;
    border: none;
    cursor: pointer;
    transition: background-color 0.2s ease;
    font-size: 13px;
  }
  
  .status-option:hover {
    background: #f9fafb;
  }
  
  .status-option.active {
    background: #eff6ff;
    color: #2563eb;
  }
  
  .status-icon {
    font-size: 12px;
  }
  
  .status-label {
    flex: 1;
    text-align: left;
  }
  
  .check-icon {
    color: #16a34a;
    font-size: 12px;
  }
  
  /* 菜单项 */
  .menu-items {
    padding: 0;
  }
  
  .menu-item {
    width: 100%;
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 10px 20px;
    background: none;
    border: none;
    cursor: pointer;
    font-size: 14px;
    color: #374151;
    text-align: left;
    transition: background-color 0.2s ease;
  }
  
  .menu-item:hover:not(.disabled) {
    background: #f9fafb;
  }
  
  .menu-item.danger {
    color: #ef4444;
  }
  
  .menu-item.danger:hover {
    background: #fef2f2;
  }
  
  .menu-item.disabled {
    color: #9ca3af;
    cursor: not-allowed;
    opacity: 0.5;
  }
  
  .menu-icon {
    font-size: 16px;
    flex-shrink: 0;
    width: 20px;
    text-align: center;
  }
  
  .menu-label {
    flex: 1;
    font-weight: 500;
  }
  
  .menu-shortcut {
    font-size: 12px;
    color: #9ca3af;
    background: #f3f4f6;
    border-radius: 4px;
    padding: 2px 6px;
    font-family: monospace;
  }
  
  .submenu-arrow {
    font-size: 12px;
    color: #9ca3af;
  }
  
  .menu-divider {
    height: 1px;
    background: #f3f4f6;
    margin: 8px 0;
  }
  
  /* 移动端适配 */
  @media (max-width: 768px) {
    .user-dropdown {
      min-width: 260px;
      max-width: 300px;
    }
    
    .user-info {
      padding: 12px 16px;
    }
    
    .status-section {
      padding: 6px 16px;
    }
    
    .menu-item {
      padding: 8px 16px;
    }
    
    .user-name {
      font-size: 15px;
    }
    
    .menu-item {
      font-size: 13px;
    }
  }
  
  /* 深色模式 */
  @media (prefers-color-scheme: dark) {
    .user-dropdown {
      background: rgba(31, 41, 55, 0.95);
      border-color: #374151;
    }
    
    .user-info {
      border-bottom-color: #374151;
    }
    
    .user-info:hover {
      background: #374151;
    }
    
    .user-name {
      color: #f9fafb;
    }
    
    .user-username {
      color: #d1d5db;
    }
    
    .user-email {
      color: #9ca3af;
    }
    
    .status-section {
      border-bottom-color: #374151;
    }
    
    .status-toggle {
      border-color: #4b5563;
    }
    
    .status-toggle:hover {
      background: #374151;
      border-color: #6b7280;
    }
    
    .status-menu {
      background: #1f2937;
      border-color: #374151;
    }
    
    .status-option:hover {
      background: #374151;
    }
    
    .status-option.active {
      background: #1e3a8a;
      color: #93c5fd;
    }
    
    .menu-item {
      color: #e5e7eb;
    }
    
    .menu-item:hover:not(.disabled) {
      background: #374151;
    }
    
    .menu-item.danger:hover {
      background: #7f1d1d;
    }
    
    .menu-shortcut {
      background: #4b5563;
      color: #d1d5db;
    }
    
    .menu-divider {
      background: #374151;
    }
  }
  
  /* 高对比度模式 */
  @media (prefers-contrast: high) {
    .user-dropdown {
      border-width: 2px;
      border-color: #000;
    }
    
    .menu-item {
      border-bottom: 1px solid #e5e7eb;
    }
  }
  
  /* 减少动画模式 */
  @media (prefers-reduced-motion: reduce) {
    .user-dropdown {
      animation: none;
    }
    
    .status-menu {
      animation: none;
    }
    
    .toggle-arrow {
      transition: none;
    }
    
    .menu-item,
    .status-toggle,
    .status-option {
      transition: none;
    }
  }
</style> 