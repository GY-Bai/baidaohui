<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import Avatar from '$lib/components/ui/Avatar.svelte';
  import Badge from '$lib/components/ui/Badge.svelte';
  import Button from '$lib/components/ui/Button.svelte';
  import OnlineStatusIndicator from '$lib/components/business/OnlineStatusIndicator.svelte';
  
  export let user = {
    id: '',
    name: '',
    username: '',
    email: '',
    avatar: '',
    bio: '',
    status: 'offline',
    location: '',
    website: '',
    joinDate: '',
    lastSeen: null,
    stats: {
      followers: 0,
      following: 0,
      posts: 0
    },
    badges: [],
    verified: false,
    premium: false
  };
  export let showActions = true;
  export let showStats = true;
  export let showContact = true;
  export let compact = false;
  export let editable = false;
  export let className = '';
  
  const dispatch = createEventDispatcher();
  
  // 格式化日期
  function formatDate(dateString) {
    if (!dateString) return '';
    const date = new Date(dateString);
    return date.toLocaleDateString('zh-CN', {
      year: 'numeric',
      month: 'long'
    });
  }
  
  // 格式化数字
  function formatNumber(num) {
    if (num >= 1000000) {
      return (num / 1000000).toFixed(1) + 'M';
    }
    if (num >= 1000) {
      return (num / 1000).toFixed(1) + 'K';
    }
    return num.toString();
  }
  
  function handleFollow() {
    dispatch('follow', { user });
  }
  
  function handleMessage() {
    dispatch('message', { user });
  }
  
  function handleEdit() {
    dispatch('edit', { user });
  }
  
  function handleShare() {
    dispatch('share', { user });
  }
  
  function handleBlock() {
    dispatch('block', { user });
  }
  
  function handleReport() {
    dispatch('report', { user });
  }
  
  function handleAvatarClick() {
    dispatch('avatarClick', { user });
  }
  
  function handleStatClick(type) {
    dispatch('statClick', { type, user });
  }
  
  function handleBadgeClick(badge) {
    dispatch('badgeClick', { badge, user });
  }
</script>

<div class="user-profile-card {compact ? 'compact' : ''} {className}">
  <!-- 背景图/渐变 -->
  <div class="profile-header">
    <div class="header-background"></div>
    
    <!-- 头像区域 -->
    <div class="avatar-section">
      <div class="avatar-container">
        <Avatar
          src={user.avatar}
          alt={user.name}
          size={compact ? 'lg' : 'xl'}
          bordered
          clickable
          on:click={handleAvatarClick}
        />
        <OnlineStatusIndicator 
          status={user.status}
          position="bottom-right"
          size={compact ? 'sm' : 'default'}
          animated
        />
      </div>
      
      <!-- 认证徽章 -->
      {#if user.verified}
        <div class="verification-badge" title="已认证用户">
          ✓
        </div>
      {/if}
      
      <!-- 会员徽章 -->
      {#if user.premium}
        <div class="premium-badge" title="高级会员">
          👑
        </div>
      {/if}
    </div>
  </div>
  
  <!-- 用户信息 -->
  <div class="profile-content">
    <!-- 基本信息 -->
    <div class="basic-info">
      <h2 class="user-name">
        {user.name}
        {#if user.verified}
          <span class="verify-icon">✓</span>
        {/if}
      </h2>
      
      {#if user.username}
        <p class="username">@{user.username}</p>
      {/if}
      
      {#if user.bio}
        <p class="bio">{user.bio}</p>
      {/if}
      
      <!-- 用户标签 -->
      {#if user.badges && user.badges.length > 0}
        <div class="badges">
          {#each user.badges as badge}
            <Badge
              variant={badge.variant || 'default'}
              size="xs"
              on:click={() => handleBadgeClick(badge)}
            >
              {badge.icon || ''} {badge.label}
            </Badge>
          {/each}
        </div>
      {/if}
    </div>
    
    <!-- 详细信息 -->
    {#if !compact}
      <div class="details">
        {#if user.location}
          <div class="detail-item">
            <span class="detail-icon">📍</span>
            <span class="detail-text">{user.location}</span>
          </div>
        {/if}
        
        {#if user.website}
          <div class="detail-item">
            <span class="detail-icon">🔗</span>
            <a href={user.website} class="detail-link" target="_blank" rel="noopener">
              {user.website.replace(/^https?:\/\//, '')}
            </a>
          </div>
        {/if}
        
        {#if user.joinDate}
          <div class="detail-item">
            <span class="detail-icon">📅</span>
            <span class="detail-text">加入于 {formatDate(user.joinDate)}</span>
          </div>
        {/if}
      </div>
    {/if}
    
    <!-- 统计信息 -->
    {#if showStats && user.stats}
      <div class="stats">
        <button class="stat-item" on:click={() => handleStatClick('posts')}>
          <span class="stat-number">{formatNumber(user.stats.posts)}</span>
          <span class="stat-label">帖子</span>
        </button>
        
        <button class="stat-item" on:click={() => handleStatClick('followers')}>
          <span class="stat-number">{formatNumber(user.stats.followers)}</span>
          <span class="stat-label">粉丝</span>
        </button>
        
        <button class="stat-item" on:click={() => handleStatClick('following')}>
          <span class="stat-number">{formatNumber(user.stats.following)}</span>
          <span class="stat-label">关注</span>
        </button>
      </div>
    {/if}
    
    <!-- 操作按钮 -->
    {#if showActions}
      <div class="actions">
        {#if editable}
          <Button variant="primary" size="sm" on:click={handleEdit}>
            编辑资料
          </Button>
        {:else}
          <Button variant="primary" size="sm" on:click={handleFollow}>
            关注
          </Button>
          
          {#if showContact}
            <Button variant="outline" size="sm" on:click={handleMessage}>
              💬 私信
            </Button>
          {/if}
        {/if}
        
        <Button variant="ghost" size="sm" on:click={handleShare}>
          🔗
        </Button>
        
        <!-- 更多菜单 -->
        <div class="more-menu">
          <Button variant="ghost" size="sm">
            ⋯
          </Button>
          
          <div class="menu-dropdown">
            <button class="menu-item" on:click={handleReport}>
              🚨 举报用户
            </button>
            <button class="menu-item danger" on:click={handleBlock}>
              🚫 拉黑用户
            </button>
          </div>
        </div>
      </div>
    {/if}
  </div>
</div>

<style>
  .user-profile-card {
    background: white;
    border-radius: 16px;
    box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
    overflow: hidden;
    transition: all 0.3s ease;
    max-width: 400px;
  }
  
  .user-profile-card:hover {
    transform: translateY(-4px);
    box-shadow: 0 12px 40px rgba(0, 0, 0, 0.15);
  }
  
  .compact {
    max-width: 320px;
  }
  
  /* 头部区域 */
  .profile-header {
    position: relative;
    height: 120px;
    overflow: hidden;
  }
  
  .compact .profile-header {
    height: 80px;
  }
  
  .header-background {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  }
  
  .avatar-section {
    position: absolute;
    bottom: -30px;
    left: 20px;
    display: flex;
    align-items: flex-end;
    gap: 8px;
  }
  
  .compact .avatar-section {
    bottom: -20px;
    left: 16px;
  }
  
  .avatar-container {
    position: relative;
  }
  
  .verification-badge {
    position: absolute;
    top: -4px;
    right: -4px;
    width: 20px;
    height: 20px;
    background: #3b82f6;
    color: white;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 10px;
    font-weight: bold;
    border: 2px solid white;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  }
  
  .premium-badge {
    position: absolute;
    top: -8px;
    left: -8px;
    width: 24px;
    height: 24px;
    background: linear-gradient(135deg, #fbbf24, #f59e0b);
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 12px;
    border: 2px solid white;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  }
  
  /* 内容区域 */
  .profile-content {
    padding: 40px 20px 20px;
  }
  
  .compact .profile-content {
    padding: 30px 16px 16px;
  }
  
  .basic-info {
    margin-bottom: 16px;
  }
  
  .user-name {
    font-size: 20px;
    font-weight: 700;
    color: #111827;
    margin: 0 0 4px 0;
    display: flex;
    align-items: center;
    gap: 6px;
  }
  
  .compact .user-name {
    font-size: 18px;
  }
  
  .verify-icon {
    color: #3b82f6;
    font-size: 16px;
  }
  
  .username {
    font-size: 14px;
    color: #6b7280;
    margin: 0 0 8px 0;
  }
  
  .bio {
    font-size: 14px;
    color: #374151;
    line-height: 1.5;
    margin: 0 0 12px 0;
  }
  
  .badges {
    display: flex;
    flex-wrap: wrap;
    gap: 6px;
    margin-bottom: 12px;
  }
  
  /* 详细信息 */
  .details {
    margin-bottom: 16px;
  }
  
  .detail-item {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-bottom: 8px;
    font-size: 13px;
    color: #6b7280;
  }
  
  .detail-icon {
    font-size: 12px;
    width: 16px;
    text-align: center;
  }
  
  .detail-text {
    flex: 1;
  }
  
  .detail-link {
    color: #3b82f6;
    text-decoration: none;
    flex: 1;
  }
  
  .detail-link:hover {
    text-decoration: underline;
  }
  
  /* 统计信息 */
  .stats {
    display: flex;
    gap: 20px;
    margin-bottom: 20px;
    padding: 16px 0;
    border-top: 1px solid #f3f4f6;
    border-bottom: 1px solid #f3f4f6;
  }
  
  .compact .stats {
    gap: 16px;
    padding: 12px 0;
    margin-bottom: 16px;
  }
  
  .stat-item {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 2px;
    background: none;
    border: none;
    cursor: pointer;
    padding: 4px;
    border-radius: 8px;
    transition: background-color 0.2s ease;
    flex: 1;
  }
  
  .stat-item:hover {
    background: #f9fafb;
  }
  
  .stat-number {
    font-size: 18px;
    font-weight: 700;
    color: #111827;
  }
  
  .compact .stat-number {
    font-size: 16px;
  }
  
  .stat-label {
    font-size: 12px;
    color: #6b7280;
  }
  
  /* 操作按钮 */
  .actions {
    display: flex;
    gap: 8px;
    align-items: center;
  }
  
  .more-menu {
    position: relative;
  }
  
  .menu-dropdown {
    position: absolute;
    top: 100%;
    right: 0;
    background: white;
    border-radius: 8px;
    box-shadow: 0 8px 24px rgba(0, 0, 0, 0.15);
    border: 1px solid #e5e7eb;
    min-width: 120px;
    z-index: 10;
    opacity: 0;
    visibility: hidden;
    transform: translateY(-8px);
    transition: all 0.2s ease;
  }
  
  .more-menu:hover .menu-dropdown {
    opacity: 1;
    visibility: visible;
    transform: translateY(0);
  }
  
  .menu-item {
    display: block;
    width: 100%;
    padding: 8px 12px;
    text-align: left;
    border: none;
    background: none;
    font-size: 13px;
    color: #374151;
    cursor: pointer;
    transition: background-color 0.2s ease;
  }
  
  .menu-item:hover {
    background: #f9fafb;
  }
  
  .menu-item.danger {
    color: #ef4444;
  }
  
  .menu-item.danger:hover {
    background: #fef2f2;
  }
  
  /* 移动端适配 */
  @media (max-width: 768px) {
    .user-profile-card {
      max-width: 100%;
      margin: 0 16px;
    }
    
    .user-name {
      font-size: 18px;
    }
    
    .stats {
      gap: 12px;
    }
    
    .stat-number {
      font-size: 16px;
    }
    
    .actions {
      flex-wrap: wrap;
    }
  }
  
  /* 深色模式 */
  @media (prefers-color-scheme: dark) {
    .user-profile-card {
      background: #1f2937;
    }
    
    .user-name {
      color: #f9fafb;
    }
    
    .username {
      color: #d1d5db;
    }
    
    .bio {
      color: #e5e7eb;
    }
    
    .detail-item {
      color: #d1d5db;
    }
    
    .detail-link {
      color: #60a5fa;
    }
    
    .stats {
      border-color: #374151;
    }
    
    .stat-item:hover {
      background: #374151;
    }
    
    .stat-number {
      color: #f9fafb;
    }
    
    .stat-label {
      color: #d1d5db;
    }
    
    .menu-dropdown {
      background: #1f2937;
      border-color: #374151;
    }
    
    .menu-item {
      color: #e5e7eb;
    }
    
    .menu-item:hover {
      background: #374151;
    }
    
    .menu-item.danger:hover {
      background: #7f1d1d;
    }
  }
  
  /* 高对比度模式 */
  @media (prefers-contrast: high) {
    .user-profile-card {
      border: 2px solid #000;
    }
    
    .user-name {
      color: #000;
    }
    
    .stats {
      border-color: #000;
    }
  }
  
  /* 减少动画模式 */
  @media (prefers-reduced-motion: reduce) {
    .user-profile-card {
      transition: none;
    }
    
    .user-profile-card:hover {
      transform: none;
    }
    
    .stat-item,
    .menu-dropdown {
      transition: none;
    }
  }
</style> 