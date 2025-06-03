<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import Card from './Card.svelte';
  import Badge from './Badge.svelte';
  import Button from './Button.svelte';
  import Input from './Input.svelte';
  import Select from './Select.svelte';
  import Avatar from './Avatar.svelte';
  import Pagination from './Pagination.svelte';
  
  export let activities = [];
  export let loading = false;
  export let pagination = {
    page: 1,
    size: 20,
    total: 0
  };
  export let showFilters = true;
  export let showExport = false;
  export let groupByDate = true;
  export let className = '';
  
  const dispatch = createEventDispatcher();
  
  // 筛选选项
  let filters = {
    search: '',
    type: '',
    user: '',
    dateRange: '',
    status: ''
  };
  
  // 活动类型配置
  const activityTypes = {
    'user.login': { label: '用户登录', icon: '🔑', color: 'success' },
    'user.logout': { label: '用户登出', icon: '🚪', color: 'secondary' },
    'user.register': { label: '用户注册', icon: '👤', color: 'primary' },
    'user.update': { label: '更新资料', icon: '✏️', color: 'info' },
    'user.delete': { label: '删除用户', icon: '🗑️', color: 'error' },
    'api.request': { label: 'API请求', icon: '🔗', color: 'info' },
    'api.error': { label: 'API错误', icon: '❌', color: 'error' },
    'data.create': { label: '创建数据', icon: '➕', color: 'success' },
    'data.update': { label: '更新数据', icon: '📝', color: 'warning' },
    'data.delete': { label: '删除数据', icon: '🗑️', color: 'error' },
    'system.backup': { label: '系统备份', icon: '💾', color: 'info' },
    'system.restore': { label: '系统恢复', icon: '🔄', color: 'warning' },
    'security.alert': { label: '安全警告', icon: '⚠️', color: 'error' },
    'payment.success': { label: '支付成功', icon: '💰', color: 'success' },
    'payment.failed': { label: '支付失败', icon: '💳', color: 'error' }
  };
  
  // 筛选选项
  const typeOptions = [
    { value: '', label: '全部类型' },
    ...Object.entries(activityTypes).map(([key, config]) => ({
      value: key,
      label: config.label
    }))
  ];
  
  const dateRangeOptions = [
    { value: '', label: '全部时间' },
    { value: 'today', label: '今天' },
    { value: 'yesterday', label: '昨天' },
    { value: 'week', label: '本周' },
    { value: 'month', label: '本月' },
    { value: 'quarter', label: '本季度' }
  ];
  
  const statusOptions = [
    { value: '', label: '全部状态' },
    { value: 'success', label: '成功' },
    { value: 'failed', label: '失败' },
    { value: 'pending', label: '进行中' },
    { value: 'cancelled', label: '已取消' }
  ];
  
  // 计算属性
  $: filteredActivities = filterActivities(activities, filters);
  $: groupedActivities = groupByDate ? groupActivitiesByDate(filteredActivities) : null;
  
  function filterActivities(activities, filters) {
    return activities.filter(activity => {
      // 搜索过滤
      if (filters.search) {
        const searchLower = filters.search.toLowerCase();
        const matchesSearch = 
          activity.description?.toLowerCase().includes(searchLower) ||
          activity.user?.name?.toLowerCase().includes(searchLower) ||
          activity.ip?.includes(searchLower) ||
          activity.userAgent?.toLowerCase().includes(searchLower);
        if (!matchesSearch) return false;
      }
      
      // 类型过滤
      if (filters.type && activity.type !== filters.type) {
        return false;
      }
      
      // 用户过滤
      if (filters.user && activity.user?.id !== filters.user) {
        return false;
      }
      
      // 状态过滤
      if (filters.status && activity.status !== filters.status) {
        return false;
      }
      
      // 日期范围过滤
      if (filters.dateRange) {
        const activityDate = new Date(activity.createdAt);
        const now = new Date();
        const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        
        switch (filters.dateRange) {
          case 'today':
            if (activityDate < today) return false;
            break;
          case 'yesterday':
            const yesterday = new Date(today);
            yesterday.setDate(yesterday.getDate() - 1);
            if (activityDate < yesterday || activityDate >= today) return false;
            break;
          case 'week':
            const weekStart = new Date(today);
            weekStart.setDate(weekStart.getDate() - weekStart.getDay());
            if (activityDate < weekStart) return false;
            break;
          case 'month':
            const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
            if (activityDate < monthStart) return false;
            break;
          case 'quarter':
            const quarterStart = new Date(now.getFullYear(), Math.floor(now.getMonth() / 3) * 3, 1);
            if (activityDate < quarterStart) return false;
            break;
        }
      }
      
      return true;
    });
  }
  
  function groupActivitiesByDate(activities) {
    const groups = {};
    
    activities.forEach(activity => {
      const date = new Date(activity.createdAt);
      const dateKey = date.toDateString();
      
      if (!groups[dateKey]) {
        groups[dateKey] = {
          date: date,
          activities: []
        };
      }
      
      groups[dateKey].activities.push(activity);
    });
    
    return Object.values(groups).sort((a, b) => b.date.getTime() - a.date.getTime());
  }
  
  function getActivityConfig(type) {
    return activityTypes[type] || { 
      label: type, 
      icon: '📝', 
      color: 'secondary' 
    };
  }
  
  function formatDateTime(date) {
    return new Date(date).toLocaleString('zh-CN', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  }
  
  function formatTime(date) {
    return new Date(date).toLocaleTimeString('zh-CN', {
      hour: '2-digit',
      minute: '2-digit'
    });
  }
  
  function formatDateHeader(date) {
    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const yesterday = new Date(today);
    yesterday.setDate(yesterday.getDate() - 1);
    
    if (date >= today) {
      return '今天';
    } else if (date >= yesterday) {
      return '昨天';
    } else {
      return date.toLocaleDateString('zh-CN', {
        year: 'numeric',
        month: 'long',
        day: 'numeric'
      });
    }
  }
  
  function handleFilterChange() {
    dispatch('filterChange', { filters });
  }
  
  function handlePageChange(event) {
    dispatch('pageChange', { page: event.detail.page, size: event.detail.size });
  }
  
  function handleExport() {
    dispatch('export', { filters, activities: filteredActivities });
  }
  
  function handleActivityClick(activity) {
    dispatch('activityClick', { activity });
  }
  
  function getStatusColor(status) {
    switch (status) {
      case 'success': return 'success';
      case 'failed': return 'error';
      case 'pending': return 'warning';
      case 'cancelled': return 'secondary';
      default: return 'info';
    }
  }
  
  function getStatusText(status) {
    switch (status) {
      case 'success': return '成功';
      case 'failed': return '失败';
      case 'pending': return '进行中';
      case 'cancelled': return '已取消';
      default: return status;
    }
  }
</script>

<div class="activity-log {className}">
  <!-- 筛选器 -->
  {#if showFilters}
    <Card variant="outlined" className="filters-card">
      <h3 slot="header">筛选条件</h3>
      
      <div class="filters-grid">
        <div class="filter-group">
          <label>搜索</label>
          <Input
            bind:value={filters.search}
            placeholder="搜索描述、用户、IP..."
            on:input={handleFilterChange}
          />
        </div>
        
        <div class="filter-group">
          <label>活动类型</label>
          <Select
            bind:value={filters.type}
            options={typeOptions}
            placeholder="选择类型"
            on:change={handleFilterChange}
          />
        </div>
        
        <div class="filter-group">
          <label>时间范围</label>
          <Select
            bind:value={filters.dateRange}
            options={dateRangeOptions}
            placeholder="选择时间"
            on:change={handleFilterChange}
          />
        </div>
        
        <div class="filter-group">
          <label>状态</label>
          <Select
            bind:value={filters.status}
            options={statusOptions}
            placeholder="选择状态"
            on:change={handleFilterChange}
          />
        </div>
      </div>
      
      <div class="filter-actions">
        <Button
          variant="ghost"
          size="sm"
          on:click={() => { 
            filters = { search: '', type: '', user: '', dateRange: '', status: '' };
            handleFilterChange();
          }}
        >
          清除筛选
        </Button>
        
        {#if showExport}
          <Button
            variant="outline"
            size="sm"
            on:click={handleExport}
          >
            📊 导出日志
          </Button>
        {/if}
      </div>
    </Card>
  {/if}
  
  <!-- 活动列表 -->
  <Card variant="outlined">
    <div class="list-header" slot="header">
      <h3>活动日志</h3>
      <Badge variant="secondary" size="sm">
        {filteredActivities.length} 条记录
      </Badge>
    </div>
    
    {#if loading}
      <div class="loading-state">
        <div class="loading-spinner"></div>
        <p>加载中...</p>
      </div>
    {:else if filteredActivities.length === 0}
      <div class="empty-state">
        <div class="empty-icon">📝</div>
        <h4>暂无活动记录</h4>
        <p>没有找到符合条件的活动日志</p>
      </div>
    {:else}
      <div class="activities-list">
        {#if groupByDate && groupedActivities}
          {#each groupedActivities as group}
            <div class="date-group">
              <div class="date-header">
                <h4>{formatDateHeader(group.date)}</h4>
                <Badge variant="secondary" size="xs">
                  {group.activities.length} 条
                </Badge>
              </div>
              
              <div class="activities">
                {#each group.activities as activity}
                  <div 
                    class="activity-item"
                    on:click={() => handleActivityClick(activity)}
                    role="button"
                    tabindex="0"
                  >
                    <div class="activity-icon">
                      <span class="icon">{getActivityConfig(activity.type).icon}</span>
                    </div>
                    
                    <div class="activity-content">
                      <div class="activity-header">
                        <div class="activity-title">
                          <span class="type-label">
                            {getActivityConfig(activity.type).label}
                          </span>
                          <Badge 
                            variant={getStatusColor(activity.status)} 
                            size="xs"
                          >
                            {getStatusText(activity.status)}
                          </Badge>
                        </div>
                        
                        <div class="activity-time">
                          {formatTime(activity.createdAt)}
                        </div>
                      </div>
                      
                      <div class="activity-description">
                        {activity.description}
                      </div>
                      
                      <div class="activity-meta">
                        {#if activity.user}
                          <div class="meta-user">
                            <Avatar
                              src={activity.user.avatar}
                              alt={activity.user.name}
                              size="xs"
                            />
                            <span>{activity.user.name}</span>
                          </div>
                        {/if}
                        
                        {#if activity.ip}
                          <span class="meta-ip">IP: {activity.ip}</span>
                        {/if}
                        
                        {#if activity.location}
                          <span class="meta-location">📍 {activity.location}</span>
                        {/if}
                      </div>
                    </div>
                  </div>
                {/each}
              </div>
            </div>
          {/each}
        {:else}
          <div class="activities">
            {#each filteredActivities as activity}
              <div 
                class="activity-item"
                on:click={() => handleActivityClick(activity)}
                role="button"
                tabindex="0"
              >
                <div class="activity-icon">
                  <span class="icon">{getActivityConfig(activity.type).icon}</span>
                </div>
                
                <div class="activity-content">
                  <div class="activity-header">
                    <div class="activity-title">
                      <span class="type-label">
                        {getActivityConfig(activity.type).label}
                      </span>
                      <Badge 
                        variant={getStatusColor(activity.status)} 
                        size="xs"
                      >
                        {getStatusText(activity.status)}
                      </Badge>
                    </div>
                    
                    <div class="activity-time">
                      {formatDateTime(activity.createdAt)}
                    </div>
                  </div>
                  
                  <div class="activity-description">
                    {activity.description}
                  </div>
                  
                  <div class="activity-meta">
                    {#if activity.user}
                      <div class="meta-user">
                        <Avatar
                          src={activity.user.avatar}
                          alt={activity.user.name}
                          size="xs"
                        />
                        <span>{activity.user.name}</span>
                      </div>
                    {/if}
                    
                    {#if activity.ip}
                      <span class="meta-ip">IP: {activity.ip}</span>
                    {/if}
                    
                    {#if activity.location}
                      <span class="meta-location">📍 {activity.location}</span>
                    {/if}
                  </div>
                </div>
              </div>
            {/each}
          </div>
        {/if}
      </div>
    {/if}
    
    <!-- 分页 -->
    {#if pagination.total > pagination.size}
      <div class="pagination-container">
        <Pagination
          page={pagination.page}
          size={pagination.size}
          total={pagination.total}
          on:change={handlePageChange}
        />
      </div>
    {/if}
  </Card>
</div>

<style>
  .activity-log {
    display: flex;
    flex-direction: column;
    gap: 20px;
    max-width: 1200px;
  }
  
  /* 筛选器 */
  .filters-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 16px;
    margin-bottom: 16px;
  }
  
  .filter-group {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }
  
  .filter-group label {
    font-size: 14px;
    font-weight: 500;
    color: #374151;
  }
  
  .filter-actions {
    display: flex;
    gap: 12px;
    justify-content: flex-end;
    padding-top: 16px;
    border-top: 1px solid #f3f4f6;
  }
  
  /* 列表头部 */
  .list-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }
  
  .list-header h3 {
    margin: 0;
    font-size: 18px;
    font-weight: 600;
    color: #111827;
  }
  
  /* 加载状态 */
  .loading-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 16px;
    padding: 48px 24px;
    color: #6b7280;
  }
  
  .loading-spinner {
    width: 32px;
    height: 32px;
    border: 3px solid #f3f4f6;
    border-top: 3px solid #3b82f6;
    border-radius: 50%;
    animation: spin 1s linear infinite;
  }
  
  @keyframes spin {
    from { transform: rotate(0deg); }
    to { transform: rotate(360deg); }
  }
  
  /* 空状态 */
  .empty-state {
    text-align: center;
    padding: 48px 24px;
    color: #6b7280;
  }
  
  .empty-icon {
    font-size: 48px;
    margin-bottom: 16px;
  }
  
  .empty-state h4 {
    margin: 0 0 8px 0;
    font-size: 16px;
    font-weight: 600;
    color: #374151;
  }
  
  .empty-state p {
    margin: 0;
    font-size: 14px;
  }
  
  /* 日期分组 */
  .date-group {
    margin-bottom: 24px;
  }
  
  .date-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 12px 0;
    margin-bottom: 12px;
    border-bottom: 2px solid #f3f4f6;
  }
  
  .date-header h4 {
    margin: 0;
    font-size: 16px;
    font-weight: 600;
    color: #111827;
  }
  
  /* 活动列表 */
  .activities {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }
  
  .activity-item {
    display: flex;
    gap: 12px;
    padding: 16px;
    border-radius: 8px;
    cursor: pointer;
    transition: all 0.2s ease;
    border: 1px solid transparent;
  }
  
  .activity-item:hover {
    background: #f9fafb;
    border-color: #e5e7eb;
  }
  
  .activity-icon {
    flex-shrink: 0;
    width: 40px;
    height: 40px;
    border-radius: 8px;
    background: #f3f4f6;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 18px;
  }
  
  .activity-content {
    flex: 1;
    min-width: 0;
  }
  
  .activity-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    margin-bottom: 6px;
  }
  
  .activity-title {
    display: flex;
    align-items: center;
    gap: 8px;
    flex-wrap: wrap;
  }
  
  .type-label {
    font-size: 14px;
    font-weight: 600;
    color: #111827;
  }
  
  .activity-time {
    font-size: 12px;
    color: #6b7280;
    white-space: nowrap;
  }
  
  .activity-description {
    font-size: 14px;
    color: #374151;
    line-height: 1.4;
    margin-bottom: 8px;
  }
  
  .activity-meta {
    display: flex;
    gap: 16px;
    align-items: center;
    flex-wrap: wrap;
    font-size: 12px;
    color: #6b7280;
  }
  
  .meta-user {
    display: flex;
    align-items: center;
    gap: 6px;
  }
  
  .meta-ip,
  .meta-location {
    font-family: monospace;
  }
  
  /* 分页 */
  .pagination-container {
    padding-top: 16px;
    border-top: 1px solid #f3f4f6;
    display: flex;
    justify-content: center;
  }
  
  /* 移动端适配 */
  @media (max-width: 768px) {
    .filters-grid {
      grid-template-columns: 1fr;
    }
    
    .filter-actions {
      flex-direction: column;
    }
    
    .list-header {
      flex-direction: column;
      gap: 8px;
      align-items: flex-start;
    }
    
    .activity-header {
      flex-direction: column;
      gap: 4px;
      align-items: flex-start;
    }
    
    .activity-time {
      white-space: normal;
    }
    
    .activity-meta {
      flex-direction: column;
      gap: 4px;
      align-items: flex-start;
    }
    
    .date-header {
      flex-direction: column;
      gap: 8px;
      align-items: flex-start;
    }
  }
  
  /* 深色模式 */
  @media (prefers-color-scheme: dark) {
    .filter-group label {
      color: #f3f4f6;
    }
    
    .filter-actions {
      border-top-color: #374151;
    }
    
    .list-header h3 {
      color: #f9fafb;
    }
    
    .loading-state {
      color: #d1d5db;
    }
    
    .loading-spinner {
      border-color: #4b5563;
      border-top-color: #60a5fa;
    }
    
    .empty-state h4 {
      color: #e5e7eb;
    }
    
    .empty-state {
      color: #d1d5db;
    }
    
    .date-header {
      border-bottom-color: #374151;
    }
    
    .date-header h4 {
      color: #f9fafb;
    }
    
    .activity-item:hover {
      background: #374151;
      border-color: #4b5563;
    }
    
    .activity-icon {
      background: #4b5563;
    }
    
    .type-label {
      color: #f9fafb;
    }
    
    .activity-time {
      color: #d1d5db;
    }
    
    .activity-description {
      color: #e5e7eb;
    }
    
    .activity-meta {
      color: #d1d5db;
    }
    
    .pagination-container {
      border-top-color: #374151;
    }
  }
  
  /* 高对比度模式 */
  @media (prefers-contrast: high) {
    .activity-item {
      border-width: 2px;
    }
    
    .filter-group label {
      font-weight: 600;
    }
  }
  
  /* 减少动画模式 */
  @media (prefers-reduced-motion: reduce) {
    .loading-spinner {
      animation: none;
    }
    
    .activity-item {
      transition: none;
    }
  }
</style> 