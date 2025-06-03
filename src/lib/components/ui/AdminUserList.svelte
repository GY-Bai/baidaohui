<script>
  import { createEventDispatcher } from 'svelte';
  import Avatar from './Avatar.svelte';
  import Badge from './Badge.svelte';
  import Button from './Button.svelte';
  import Input from './Input.svelte';
  
  export let users = [];
  export let loading = false;
  export let searchQuery = '';
  export let selectedRole = 'all';
  export let selectedStatus = 'all';
  export let sortBy = 'createdAt';
  export let sortOrder = 'desc';
  export let currentPage = 1;
  export let totalPages = 1;
  export let totalUsers = 0;
  export let showBulkActions = true;
  export let permissions = {};
  
  const dispatch = createEventDispatcher();
  
  let selectedUsers = new Set();
  let showFilters = false;
  let showUserModal = false;
  let selectedUser = null;
  
  // 角色选项
  const roleOptions = [
    { value: 'all', label: '所有角色' },
    { value: 'fan', label: '普通用户' },
    { value: 'master', label: '算命大师' },
    { value: 'seller', label: '商家' },
    { value: 'admin', label: '管理员' }
  ];
  
  // 状态选项
  const statusOptions = [
    { value: 'all', label: '所有状态' },
    { value: 'active', label: '正常' },
    { value: 'inactive', label: '不活跃' },
    { value: 'suspended', label: '暂停' },
    { value: 'banned', label: '封禁' }
  ];
  
  // 排序选项
  const sortOptions = [
    { value: 'createdAt', label: '注册时间' },
    { value: 'lastActive', label: '最后活跃' },
    { value: 'username', label: '用户名' },
    { value: 'email', label: '邮箱' }
  ];
  
  // 计算属性
  $: filteredUsers = users;
  $: selectedCount = selectedUsers.size;
  $: isAllSelected = selectedCount > 0 && selectedCount === filteredUsers.length;
  $: isPartialSelected = selectedCount > 0 && selectedCount < filteredUsers.length;
  
  // 格式化日期
  function formatDate(dateStr) {
    if (!dateStr) return '-';
    const date = new Date(dateStr);
    return date.toLocaleDateString('zh-CN', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  }
  
  // 获取角色显示
  function getRoleDisplay(role) {
    const roleMap = {
      fan: { label: '用户', color: 'blue' },
      master: { label: '大师', color: 'purple' },
      seller: { label: '商家', color: 'green' },
      admin: { label: '管理员', color: 'red' }
    };
    return roleMap[role] || { label: role, color: 'gray' };
  }
  
  // 获取状态显示
  function getStatusDisplay(status) {
    const statusMap = {
      active: { label: '正常', color: 'green' },
      inactive: { label: '不活跃', color: 'yellow' },
      suspended: { label: '暂停', color: 'orange' },
      banned: { label: '封禁', color: 'red' }
    };
    return statusMap[status] || { label: status, color: 'gray' };
  }
  
  // 搜索处理
  function handleSearch() {
    dispatch('search', { query: searchQuery });
  }
  
  // 筛选处理
  function handleFilter() {
    dispatch('filter', {
      role: selectedRole,
      status: selectedStatus,
      sortBy,
      sortOrder
    });
  }
  
  // 切换排序
  function handleSort(field) {
    if (sortBy === field) {
      sortOrder = sortOrder === 'asc' ? 'desc' : 'asc';
    } else {
      sortBy = field;
      sortOrder = 'desc';
    }
    handleFilter();
  }
  
  // 全选/取消全选
  function handleSelectAll() {
    if (isAllSelected) {
      selectedUsers.clear();
    } else {
      filteredUsers.forEach(user => {
        selectedUsers.add(user.id);
      });
    }
    selectedUsers = selectedUsers;
  }
  
  // 选择/取消选择用户
  function handleSelectUser(userId) {
    if (selectedUsers.has(userId)) {
      selectedUsers.delete(userId);
    } else {
      selectedUsers.add(userId);
    }
    selectedUsers = selectedUsers;
  }
  
  // 用户操作
  function handleUserAction(action, user) {
    dispatch('userAction', { action, user, users: [user] });
  }
  
  // 批量操作
  function handleBulkAction(action) {
    const users = filteredUsers.filter(user => selectedUsers.has(user.id));
    dispatch('bulkAction', { action, users });
    selectedUsers.clear();
    selectedUsers = selectedUsers;
  }
  
  // 查看用户详情
  function handleViewUser(user) {
    selectedUser = user;
    showUserModal = true;
    dispatch('viewUser', { user });
  }
  
  // 编辑用户
  function handleEditUser(user) {
    dispatch('editUser', { user });
  }
  
  // 分页处理
  function handlePageChange(page) {
    dispatch('pageChange', { page });
  }
  
  // 刷新列表
  function handleRefresh() {
    dispatch('refresh');
  }
  
  // 导出用户
  function handleExport() {
    dispatch('export', { users: filteredUsers });
  }
</script>

<div class="admin-user-list">
  <!-- 头部操作栏 -->
  <header class="list-header">
    <div class="header-title">
      <h2 class="title">用户管理</h2>
      <div class="title-meta">
        共 {totalUsers} 个用户
        {#if selectedCount > 0}
          · 已选择 {selectedCount} 个
        {/if}
      </div>
    </div>
    
    <div class="header-actions">
      <Button variant="outline" size="sm" on:click={handleRefresh} disabled={loading}>
        🔄 刷新
      </Button>
      
      <Button variant="outline" size="sm" on:click={handleExport}>
        📊 导出
      </Button>
      
      <button class="filter-toggle" class:active={showFilters} on:click={() => showFilters = !showFilters}>
        🔍 筛选
      </button>
    </div>
  </header>
  
  <!-- 搜索和筛选 -->
  <div class="search-filters">
    <div class="search-bar">
      <Input
        bind:value={searchQuery}
        placeholder="搜索用户名、邮箱、手机号..."
        on:input={handleSearch}
      />
    </div>
    
    {#if showFilters}
      <div class="filters-panel">
        <div class="filter-group">
          <label class="filter-label">角色</label>
          <select bind:value={selectedRole} on:change={handleFilter} class="filter-select">
            {#each roleOptions as option}
              <option value={option.value}>{option.label}</option>
            {/each}
          </select>
        </div>
        
        <div class="filter-group">
          <label class="filter-label">状态</label>
          <select bind:value={selectedStatus} on:change={handleFilter} class="filter-select">
            {#each statusOptions as option}
              <option value={option.value}>{option.label}</option>
            {/each}
          </select>
        </div>
        
        <div class="filter-group">
          <label class="filter-label">排序</label>
          <select bind:value={sortBy} on:change={handleFilter} class="filter-select">
            {#each sortOptions as option}
              <option value={option.value}>{option.label}</option>
            {/each}
          </select>
        </div>
        
        <div class="filter-group">
          <label class="filter-label">顺序</label>
          <select bind:value={sortOrder} on:change={handleFilter} class="filter-select">
            <option value="desc">降序</option>
            <option value="asc">升序</option>
          </select>
        </div>
      </div>
    {/if}
  </div>
  
  <!-- 批量操作栏 -->
  {#if showBulkActions && selectedCount > 0}
    <div class="bulk-actions">
      <div class="bulk-info">
        已选择 {selectedCount} 个用户
      </div>
      
      <div class="bulk-buttons">
        <Button variant="outline" size="sm" on:click={() => handleBulkAction('activate')}>
          ✅ 激活
        </Button>
        <Button variant="outline" size="sm" on:click={() => handleBulkAction('suspend')}>
          ⏸️ 暂停
        </Button>
        <Button variant="danger" size="sm" on:click={() => handleBulkAction('ban')}>
          🚫 封禁
        </Button>
        <Button variant="outline" size="sm" on:click={() => handleBulkAction('delete')}>
          🗑️ 删除
        </Button>
      </div>
    </div>
  {/if}
  
  <!-- 用户列表 -->
  <div class="user-table-container">
    {#if loading}
      <div class="loading-state">
        <div class="loading-spinner"></div>
        <div class="loading-text">加载中...</div>
      </div>
    {:else if filteredUsers.length === 0}
      <div class="empty-state">
        <div class="empty-icon">👤</div>
        <div class="empty-text">
          {#if searchQuery}
            未找到匹配的用户
          {:else}
            暂无用户数据
          {/if}
        </div>
      </div>
    {:else}
      <table class="user-table">
        <thead>
          <tr>
            <th class="checkbox-col">
              <input
                type="checkbox"
                checked={isAllSelected}
                indeterminate={isPartialSelected}
                on:change={handleSelectAll}
              />
            </th>
            <th class="sortable" on:click={() => handleSort('username')}>
              用户信息
              {#if sortBy === 'username'}
                <span class="sort-icon">{sortOrder === 'asc' ? '↑' : '↓'}</span>
              {/if}
            </th>
            <th class="sortable" on:click={() => handleSort('email')}>
              联系方式
              {#if sortBy === 'email'}
                <span class="sort-icon">{sortOrder === 'asc' ? '↑' : '↓'}</span>
              {/if}
            </th>
            <th>角色 · 状态</th>
            <th class="sortable" on:click={() => handleSort('lastActive')}>
              最后活跃
              {#if sortBy === 'lastActive'}
                <span class="sort-icon">{sortOrder === 'asc' ? '↑' : '↓'}</span>
              {/if}
            </th>
            <th class="sortable" on:click={() => handleSort('createdAt')}>
              注册时间
              {#if sortBy === 'createdAt'}
                <span class="sort-icon">{sortOrder === 'asc' ? '↑' : '↓'}</span>
              {/if}
            </th>
            <th class="actions-col">操作</th>
          </tr>
        </thead>
        <tbody>
          {#each filteredUsers as user (user.id)}
            <tr class="user-row" class:selected={selectedUsers.has(user.id)}>
              <td class="checkbox-col">
                <input
                  type="checkbox"
                  checked={selectedUsers.has(user.id)}
                  on:change={() => handleSelectUser(user.id)}
                />
              </td>
              
              <td class="user-info">
                <div class="user-profile" on:click={() => handleViewUser(user)} role="button" tabindex="0">
                  <Avatar
                    src={user.avatar}
                    alt={user.username}
                    size="md"
                    status={user.onlineStatus}
                  />
                  <div class="profile-details">
                    <div class="username">
                      {user.username}
                      {#if user.verified}
                        <span class="verified-badge">✓</span>
                      {/if}
                    </div>
                    <div class="user-id">ID: {user.id}</div>
                  </div>
                </div>
              </td>
              
              <td class="contact-info">
                <div class="contact-item">
                  <span class="contact-label">邮箱:</span>
                  <span class="contact-value">{user.email || '-'}</span>
                </div>
                <div class="contact-item">
                  <span class="contact-label">手机:</span>
                  <span class="contact-value">{user.phone || '-'}</span>
                </div>
              </td>
              
              <td class="role-status">
                {@const roleDisplay = getRoleDisplay(user.role)}
                {@const statusDisplay = getStatusDisplay(user.status)}
                <Badge color={roleDisplay.color} size="sm">
                  {roleDisplay.label}
                </Badge>
                <Badge color={statusDisplay.color} size="sm" variant="outline">
                  {statusDisplay.label}
                </Badge>
              </td>
              
              <td class="last-active">
                <div class="time-info">
                  <div class="time-value">{formatDate(user.lastActive)}</div>
                  {#if user.lastActiveIp}
                    <div class="ip-info">IP: {user.lastActiveIp}</div>
                  {/if}
                </div>
              </td>
              
              <td class="created-at">
                {formatDate(user.createdAt)}
              </td>
              
              <td class="actions-col">
                <div class="action-buttons">
                  <button class="action-btn" on:click={() => handleViewUser(user)} title="查看详情">
                    👁️
                  </button>
                  
                  {#if permissions.canEdit}
                    <button class="action-btn" on:click={() => handleEditUser(user)} title="编辑">
                      ✏️
                    </button>
                  {/if}
                  
                  {#if permissions.canManage}
                    <div class="action-dropdown">
                      <button class="action-btn dropdown-trigger" title="更多操作">
                        ⋯
                      </button>
                      <div class="dropdown-menu">
                        {#if user.status === 'active'}
                          <button class="menu-item" on:click={() => handleUserAction('suspend', user)}>
                            ⏸️ 暂停账户
                          </button>
                          <button class="menu-item" on:click={() => handleUserAction('ban', user)}>
                            🚫 封禁账户
                          </button>
                        {:else if user.status === 'suspended'}
                          <button class="menu-item" on:click={() => handleUserAction('activate', user)}>
                            ✅ 激活账户
                          </button>
                          <button class="menu-item" on:click={() => handleUserAction('ban', user)}>
                            🚫 封禁账户
                          </button>
                        {:else if user.status === 'banned'}
                          <button class="menu-item" on:click={() => handleUserAction('activate', user)}>
                            ✅ 激活账户
                          </button>
                        {/if}
                        
                        <button class="menu-item" on:click={() => handleUserAction('resetPassword', user)}>
                          🔑 重置密码
                        </button>
                        <button class="menu-item danger" on:click={() => handleUserAction('delete', user)}>
                          🗑️ 删除账户
                        </button>
                      </div>
                    </div>
                  {/if}
                </div>
              </td>
            </tr>
          {/each}
        </tbody>
      </table>
    {/if}
  </div>
  
  <!-- 分页 -->
  {#if totalPages > 1}
    <div class="pagination">
      <Button
        variant="outline"
        size="sm"
        disabled={currentPage === 1}
        on:click={() => handlePageChange(currentPage - 1)}
      >
        上一页
      </Button>
      
      <div class="page-info">
        第 {currentPage} 页，共 {totalPages} 页
      </div>
      
      <Button
        variant="outline"
        size="sm"
        disabled={currentPage === totalPages}
        on:click={() => handlePageChange(currentPage + 1)}
      >
        下一页
      </Button>
    </div>
  {/if}
</div>

<style>
  .admin-user-list {
    background: white;
    border-radius: 16px;
    box-shadow: 0 4px 20px rgba(0, 0, 0, 0.08);
    border: 1px solid #e5e7eb;
    overflow: hidden;
  }
  
  /* 头部 */
  .list-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 24px;
    border-bottom: 1px solid #f3f4f6;
  }
  
  .header-title {
    flex: 1;
  }
  
  .title {
    font-size: 24px;
    font-weight: 700;
    color: #111827;
    margin: 0 0 4px 0;
  }
  
  .title-meta {
    font-size: 14px;
    color: #6b7280;
  }
  
  .header-actions {
    display: flex;
    gap: 12px;
  }
  
  .filter-toggle {
    background: none;
    border: 1px solid #d1d5db;
    border-radius: 8px;
    padding: 8px 16px;
    font-size: 14px;
    cursor: pointer;
    transition: all 0.2s ease;
  }
  
  .filter-toggle.active {
    background: #3b82f6;
    color: white;
    border-color: #3b82f6;
  }
  
  .filter-toggle:hover:not(.active) {
    background: #f3f4f6;
  }
  
  /* 搜索和筛选 */
  .search-filters {
    padding: 20px 24px;
    border-bottom: 1px solid #f3f4f6;
  }
  
  .search-bar {
    margin-bottom: 16px;
  }
  
  .filters-panel {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 16px;
    animation: slideDown 0.3s ease-out;
  }
  
  @keyframes slideDown {
    from {
      opacity: 0;
      transform: translateY(-10px);
    }
    to {
      opacity: 1;
      transform: translateY(0);
    }
  }
  
  .filter-group {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }
  
  .filter-label {
    font-size: 13px;
    font-weight: 500;
    color: #374151;
  }
  
  .filter-select {
    padding: 8px 12px;
    border: 1px solid #d1d5db;
    border-radius: 8px;
    font-size: 14px;
    background: white;
    cursor: pointer;
  }
  
  .filter-select:focus {
    outline: none;
    border-color: #3b82f6;
    box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
  }
  
  /* 批量操作 */
  .bulk-actions {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 16px 24px;
    background: #f8fafc;
    border-bottom: 1px solid #e5e7eb;
  }
  
  .bulk-info {
    font-size: 14px;
    font-weight: 500;
    color: #374151;
  }
  
  .bulk-buttons {
    display: flex;
    gap: 8px;
  }
  
  /* 表格容器 */
  .user-table-container {
    overflow-x: auto;
    min-height: 400px;
  }
  
  .user-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 14px;
  }
  
  .user-table th {
    background: #f9fafb;
    padding: 16px;
    text-align: left;
    font-weight: 600;
    color: #374151;
    border-bottom: 1px solid #e5e7eb;
    white-space: nowrap;
  }
  
  .user-table th.sortable {
    cursor: pointer;
    user-select: none;
    transition: background 0.2s ease;
  }
  
  .user-table th.sortable:hover {
    background: #f3f4f6;
  }
  
  .sort-icon {
    margin-left: 4px;
    font-size: 12px;
  }
  
  .user-table td {
    padding: 16px;
    border-bottom: 1px solid #f3f4f6;
    vertical-align: top;
  }
  
  .user-row {
    transition: background 0.2s ease;
  }
  
  .user-row:hover {
    background: #f9fafb;
  }
  
  .user-row.selected {
    background: #eff6ff;
  }
  
  .checkbox-col {
    width: 48px;
    text-align: center;
  }
  
  .actions-col {
    width: 120px;
  }
  
  /* 用户信息 */
  .user-profile {
    display: flex;
    align-items: center;
    gap: 12px;
    cursor: pointer;
    padding: 4px;
    border-radius: 8px;
    transition: background 0.2s ease;
  }
  
  .user-profile:hover {
    background: #f3f4f6;
  }
  
  .profile-details {
    flex: 1;
    min-width: 0;
  }
  
  .username {
    font-weight: 600;
    color: #111827;
    display: flex;
    align-items: center;
    gap: 6px;
    margin-bottom: 4px;
  }
  
  .verified-badge {
    color: #3b82f6;
    font-size: 12px;
  }
  
  .user-id {
    font-size: 13px;
    color: #6b7280;
    font-family: monospace;
  }
  
  /* 联系信息 */
  .contact-info {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }
  
  .contact-item {
    display: flex;
    gap: 6px;
    font-size: 13px;
  }
  
  .contact-label {
    color: #6b7280;
    min-width: 32px;
  }
  
  .contact-value {
    color: #111827;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  
  /* 角色状态 */
  .role-status {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }
  
  /* 时间信息 */
  .time-info {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }
  
  .time-value {
    color: #111827;
    font-size: 13px;
  }
  
  .ip-info {
    color: #6b7280;
    font-size: 12px;
    font-family: monospace;
  }
  
  /* 操作按钮 */
  .action-buttons {
    display: flex;
    gap: 6px;
    align-items: center;
  }
  
  .action-btn {
    background: none;
    border: none;
    padding: 6px;
    border-radius: 6px;
    cursor: pointer;
    font-size: 14px;
    transition: background 0.2s ease;
  }
  
  .action-btn:hover {
    background: #f3f4f6;
  }
  
  /* 下拉菜单 */
  .action-dropdown {
    position: relative;
  }
  
  .dropdown-menu {
    position: absolute;
    top: 100%;
    right: 0;
    background: white;
    border-radius: 8px;
    box-shadow: 0 4px 20px rgba(0, 0, 0, 0.15);
    border: 1px solid #e5e7eb;
    padding: 8px 0;
    min-width: 150px;
    z-index: 10;
    opacity: 0;
    visibility: hidden;
    transform: translateY(-10px);
    transition: all 0.2s ease;
  }
  
  .action-dropdown:hover .dropdown-menu {
    opacity: 1;
    visibility: visible;
    transform: translateY(0);
  }
  
  .menu-item {
    width: 100%;
    background: none;
    border: none;
    padding: 8px 16px;
    text-align: left;
    cursor: pointer;
    font-size: 14px;
    color: #374151;
    transition: background 0.2s ease;
  }
  
  .menu-item:hover {
    background: #f3f4f6;
  }
  
  .menu-item.danger {
    color: #dc2626;
  }
  
  .menu-item.danger:hover {
    background: #fef2f2;
  }
  
  /* 加载状态 */
  .loading-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 80px;
    text-align: center;
  }
  
  .loading-spinner {
    width: 32px;
    height: 32px;
    border: 3px solid #f3f4f6;
    border-top: 3px solid #3b82f6;
    border-radius: 50%;
    animation: spin 1s linear infinite;
    margin-bottom: 16px;
  }
  
  @keyframes spin {
    from { transform: rotate(0deg); }
    to { transform: rotate(360deg); }
  }
  
  .loading-text {
    font-size: 16px;
    color: #6b7280;
  }
  
  /* 空状态 */
  .empty-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 80px;
    text-align: center;
  }
  
  .empty-icon {
    font-size: 64px;
    opacity: 0.5;
    margin-bottom: 16px;
  }
  
  .empty-text {
    font-size: 16px;
    color: #6b7280;
  }
  
  /* 分页 */
  .pagination {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 20px 24px;
    border-top: 1px solid #f3f4f6;
  }
  
  .page-info {
    font-size: 14px;
    color: #6b7280;
  }
  
  /* 移动端适配 */
  @media (max-width: 768px) {
    .list-header {
      flex-direction: column;
      align-items: stretch;
      gap: 16px;
      padding: 20px;
    }
    
    .header-actions {
      justify-content: flex-end;
    }
    
    .search-filters {
      padding: 16px 20px;
    }
    
    .filters-panel {
      grid-template-columns: 1fr;
    }
    
    .bulk-actions {
      flex-direction: column;
      align-items: stretch;
      gap: 12px;
      padding: 16px 20px;
    }
    
    .bulk-buttons {
      flex-wrap: wrap;
    }
    
    .user-table {
      font-size: 12px;
    }
    
    .user-table th,
    .user-table td {
      padding: 12px 8px;
    }
    
    .user-profile {
      gap: 8px;
    }
    
    .contact-info {
      font-size: 12px;
    }
    
    .action-buttons {
      flex-direction: column;
      gap: 4px;
    }
    
    .pagination {
      flex-direction: column;
      gap: 12px;
      padding: 16px 20px;
    }
  }
</style> 