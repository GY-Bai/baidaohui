<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import Checkbox from './Checkbox.svelte';
  import Badge from './Badge.svelte';
  import Avatar from './Avatar.svelte';
  import Button from './Button.svelte';
  import Skeleton from './Skeleton.svelte';
  import Pagination from './Pagination.svelte';
  import Input from './Input.svelte';
  import Dropdown from './Dropdown.svelte';
  
  export let data: any[] = [];
  export let columns: Array<{
    key: string;
    title: string;
    sortable?: boolean;
    width?: string;
    align?: 'left' | 'center' | 'right';
    render?: (value: any, row: any) => string;
  }> = [];
  export let loading: boolean = false;
  export let selectable: boolean = false;
  export let selectedRows: any[] = [];
  export let sortBy: string = '';
  export let sortOrder: 'asc' | 'desc' = 'asc';
  export let stickyHeader: boolean = false;
  export let compact: boolean = false;
  export let striped: boolean = false;
  export let hoverable: boolean = true;
  export let emptyText: string = '暂无数据';
  export let emptyIcon: string = '📊';
  export let pagination = null;
  export let rowKey = 'id';
  export let maxHeight = null;
  export let showHeader = true;
  export let showFooter = false;
  export let customActions = [];
  
  const dispatch = createEventDispatcher();
  
  let allSelected = false;
  let indeterminate = false;
  let searchQuery = '';
  let filteredData = [];
  let tableContainer;
  
  $: {
    updateFilteredData();
    const selectedCount = selectedRows.length;
    const totalCount = data.length;
    allSelected = selectedCount > 0 && selectedCount === totalCount;
    indeterminate = selectedCount > 0 && selectedCount < totalCount;
  }
  
  $: tableClasses = [
    'data-table',
    compact ? 'data-table-compact' : '',
    striped ? 'data-table-striped' : '',
    hoverable ? 'data-table-hoverable' : '',
    stickyHeader ? 'data-table-sticky' : ''
  ].filter(Boolean).join(' ');
  
  function updateFilteredData() {
    let result = [...data];
    
    // 搜索过滤
    if (searchQuery.trim()) {
      result = result.filter(row => {
        return columns.some(col => {
          const value = getNestedValue(row, col.key);
          return value?.toString().toLowerCase().includes(searchQuery.toLowerCase());
        });
      });
    }
    
    // 排序
    if (sortBy) {
      result.sort((a, b) => {
        const aVal = getNestedValue(a, sortBy);
        const bVal = getNestedValue(b, sortBy);
        
        if (aVal === bVal) return 0;
        if (aVal === null || aVal === undefined) return 1;
        if (bVal === null || bVal === undefined) return -1;
        
        const comparison = aVal < bVal ? -1 : 1;
        return sortOrder === 'asc' ? comparison : -comparison;
      });
    }
    
    filteredData = result;
  }
  
  function getNestedValue(obj, path) {
    return path.split('.').reduce((current, key) => current?.[key], obj);
  }
  
  function handleSort(column: any) {
    if (!column.sortable) return;
    
    let newSortOrder: 'asc' | 'desc' = 'asc';
    if (sortBy === column.key) {
      newSortOrder = sortOrder === 'asc' ? 'desc' : 'asc';
    }
    
    dispatch('sort', {
      column: column.key,
      order: newSortOrder
    });
  }
  
  function handleSelectAll() {
    if (allSelected) {
      selectedRows = [];
    } else {
      selectedRows = filteredData.map(row => row[rowKey]);
    }
    
    dispatch('selectAll', { selectedRows });
  }
  
  function handleRowSelect(row: any, checked: boolean) {
    if (checked) {
      selectedRows = [...selectedRows, row[rowKey]];
    } else {
      selectedRows = selectedRows.filter(r => r !== row[rowKey]);
    }
    
    dispatch('rowSelect', { row, selected: checked, selectedRows });
  }
  
  function handleRowClick(row: any, index: number) {
    dispatch('rowClick', { row, index });
  }
  
  function handleRowDoubleClick(row: any, index: number) {
    dispatch('rowDoubleClick', { row, index });
  }
  
  function handleCellClick(row: any, column: any, value: any) {
    dispatch('cellClick', { row, column, value });
  }
  
  function handleAction(action: any, row: any) {
    dispatch('action', { action, row });
  }
  
  function renderCellValue(column: any, row: any) {
    const value = getNestedValue(row, column.key);
    
    if (column.render) {
      return column.render(value, row);
    }
    
    if (value === null || value === undefined) {
      return column.defaultValue || '-';
    }
    
    return value;
  }
  
  function getSortIcon(column: any) {
    if (!column.sortable) return '';
    if (sortBy !== column.key) return '↕️';
    return sortOrder === 'asc' ? '↑' : '↓';
  }
  
  function handleSearch(event: Event) {
    searchQuery = (event.target as HTMLInputElement).value;
    dispatch('search', { query: searchQuery });
  }
  
  function clearSearch() {
    searchQuery = '';
    dispatch('search', { query: '' });
  }
  
  function exportData() {
    dispatch('export', { data: filteredData, selectedRows });
  }
  
  function refreshData() {
    dispatch('refresh');
  }
</script>

<div class="data-table-wrapper" class:compact class:bordered>
  <!-- 表格工具栏 -->
  <div class="table-toolbar">
    <div class="toolbar-left">
      {#if columns.some(col => col.sortable) || columns.some(col => col.key === 'id')}
        <div class="search-box">
          <Input
            placeholder="搜索表格数据..."
            bind:value={searchQuery}
            on:input={handleSearch}
            on:clear={clearSearch}
            size="sm"
            clearable
          >
            <span slot="prefix">🔍</span>
          </Input>
        </div>
      {/if}
      
      {#if selectedRows.length > 0}
        <div class="selected-info">
          已选择 <strong>{selectedRows.length}</strong> 项
        </div>
      {/if}
    </div>
    
    <div class="toolbar-right">
      {#if customActions.length > 0}
        {#each customActions as action}
          <Button
            variant={action.variant || 'outline'}
            size="sm"
            on:click={() => handleAction(action.key, null)}
            disabled={action.disabled}
          >
            {action.icon || ''} {action.label}
          </Button>
        {/each}
      {/if}
      
      <Button variant="outline" size="sm" on:click={exportData}>
        📤 导出
      </Button>
      
      <Button variant="outline" size="sm" on:click={refreshData}>
        🔄 刷新
      </Button>
    </div>
  </div>
  
  <!-- 表格容器 -->
  <div 
    class="table-container"
    class:sticky-header={stickyHeader}
    style={maxHeight ? `max-height: ${maxHeight}` : ''}
    bind:this={tableContainer}
  >
    <table class="data-table" class:striped class:hover>
      <!-- 表头 -->
      {#if showHeader}
        <thead class="table-header">
          <tr class="header-row">
            {#if selectable}
              <th class="select-column">
                <div class="header-checkbox">
                  <Checkbox
                    checked={allSelected}
                    indeterminate={indeterminate}
                    on:change={handleSelectAll}
                    size="sm"
                  />
                </div>
              </th>
            {/if}
            
            {#each columns as column}
              <th 
                class="table-header-cell"
                class:sortable={column.sortable}
                class:sorted={sortBy === column.key}
                style={column.width ? `width: ${column.width}` : ''}
                on:click={() => handleSort(column)}
              >
                <div class="header-content" style="text-align: {column.align || 'left'}">
                  <span class="header-title">{column.title}</span>
                  {#if column.sortable}
                    <span class="sort-indicator">{getSortIcon(column)}</span>
                  {/if}
                </div>
              </th>
            {/each}
          </tr>
        </thead>
      {/if}
      
      <!-- 表体 -->
      <tbody class="table-body">
        {#if loading}
          {#each Array(5) as _}
            <tr class="table-row skeleton-row">
              {#if selectable}
                <td class="select-column">
                  <Skeleton variant="circle" width="20px" height="20px" />
                </td>
              {/if}
              {#each columns as column}
                <td class="table-cell">
                  <Skeleton variant="text" width="80%" />
                </td>
              {/each}
            </tr>
          {/each}
        {:else if filteredData.length === 0}
          <tr class="empty-row">
            <td class="empty-cell" colspan={columns.length + (selectable ? 1 : 0)}>
              <div class="empty-state">
                <div class="empty-icon">{emptyIcon}</div>
                <p class="empty-text">{emptyText}</p>
              </div>
            </td>
          </tr>
        {:else}
          {#each filteredData as row, index}
            <tr 
              class="table-row"
              class:selected={selectedRows.includes(row[rowKey])}
              on:click={(e) => handleRowClick(row, index)}
              on:dblclick={(e) => handleRowDoubleClick(row, index)}
            >
              {#if selectable}
                <td class="select-column">
                  <div class="row-checkbox">
                    <Checkbox
                      checked={selectedRows.includes(row[rowKey])}
                      on:change={(e) => handleRowSelect(row, e.detail.checked)}
                      size="sm"
                    />
                  </div>
                </td>
              {/if}
              
              {#each columns as column}
                <td 
                  class="table-cell"
                  style="text-align: {column.align || 'left'}"
                >
                  <div class="cell-content">
                    <slot name="cell" {row} {column} value={getNestedValue(row, column.key)}>
                      {@html renderCellValue(column, row)}
                    </slot>
                  </div>
                </td>
              {/each}
            </tr>
          {/each}
        {/if}
      </tbody>
    </table>
  </div>
  
  <!-- 表格底部 -->
  {#if showFooter || pagination}
    <div class="table-footer">
      <div class="footer-left">
        {#if showFooter}
          <div class="table-info">
            显示 {filteredData.length} 条记录
            {#if selectedRows.length > 0}
              ，已选择 {selectedRows.length} 项
            {/if}
          </div>
        {/if}
      </div>
      
      <div class="footer-right">
        {#if pagination}
          <Pagination
            current={pagination.current}
            total={pagination.total}
            pageSize={pagination.pageSize}
            showSizeChanger={pagination.showSizeChanger}
            showQuickJumper={pagination.showQuickJumper}
            on:change={(e) => dispatch('pageChange', e.detail)}
          />
        {/if}
      </div>
    </div>
  {/if}
</div>

<style>
  .data-table-wrapper {
    background: white;
    border-radius: 12px;
    box-shadow: 0 4px 20px rgba(0, 0, 0, 0.08);
    overflow: hidden;
    border: 1px solid #e5e7eb;
  }
  
  .data-table-wrapper.compact {
    border-radius: 8px;
  }
  
  .data-table-wrapper.bordered {
    border: 1px solid #d1d5db;
  }
  
  /* 工具栏 */
  .table-toolbar {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 16px 20px;
    border-bottom: 1px solid #f3f4f6;
    background: #fafbfc;
  }
  
  .toolbar-left,
  .toolbar-right {
    display: flex;
    align-items: center;
    gap: 12px;
  }
  
  .search-box {
    min-width: 280px;
  }
  
  .selected-info {
    font-size: 14px;
    color: #6b7280;
    padding: 6px 12px;
    background: #e0f2fe;
    border-radius: 6px;
    border: 1px solid #b3e5fc;
  }
  
  /* 表格容器 */
  .table-container {
    overflow: auto;
    position: relative;
  }
  
  .table-container.sticky-header {
    overflow-y: auto;
  }
  
  .table-container.sticky-header .table-header {
    position: sticky;
    top: 0;
    z-index: 10;
  }
  
  /* 表格样式 */
  .data-table {
    width: 100%;
    border-collapse: collapse;
    border-spacing: 0;
    font-size: 14px;
  }
  
  .table-cell {
    padding: 12px 16px;
    vertical-align: middle;
    border-bottom: 1px solid #f3f4f6;
    transition: background 0.2s ease;
  }
  
  .compact .table-cell {
    padding: 8px 12px;
  }
  
  .select-column {
    width: 48px;
    padding: 12px 16px;
  }
  
  .data-table-compact .select-column {
    width: 40px;
    padding: 8px 12px;
  }
  
  /* 表头样式 */
  .table-header {
    background: #f8fafc;
  }
  
  .header-row {
    border: none;
  }
  
  .table-header-cell {
    padding: 12px 16px;
    text-align: left;
    font-weight: 600;
    color: #374151;
    border: none;
    white-space: nowrap;
  }
  
  .data-table-compact .table-header-cell {
    padding: 8px 12px;
  }
  
  .table-header-cell.sortable {
    cursor: pointer;
    user-select: none;
    transition: background-color 0.2s;
  }
  
  .table-header-cell.sortable:hover {
    background: #f1f5f9;
  }
  
  .table-header-cell.sorted {
    background: #f0f9ff;
    color: #667eea;
  }
  
  .header-content {
    display: flex;
    align-items: center;
    gap: 8px;
  }
  
  .header-title {
    flex: 1;
  }
  
  .sort-indicator {
    font-size: 12px;
    opacity: 0.6;
  }
  
  .header-checkbox,
  .row-checkbox {
    display: flex;
    align-items: center;
    justify-content: center;
  }
  
  /* 表体样式 */
  .table-body {
    background: white;
  }
  
  .table-row {
    border-bottom: 1px solid #f3f4f6;
    transition: background-color 0.2s;
  }
  
  .table-row:last-child {
    border-bottom: none;
  }
  
  .data-table-striped .table-row:nth-child(even) {
    background: #fafbfc;
  }
  
  .data-table-hoverable .table-row:hover {
    background: #f3f4f6;
  }
  
  .table-row.selected {
    background: #eff6ff !important;
  }
  
  .table-row:not(.skeleton-row):not(.empty-row) {
    cursor: pointer;
  }
  
  .cell-content {
    display: flex;
    align-items: center;
    min-height: 20px;
  }
  
  /* 空状态 */
  .empty-row {
    border: none;
  }
  
  .empty-cell {
    padding: 40px 20px;
    text-align: center;
    border: none;
  }
  
  .empty-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 12px;
    color: #6b7280;
  }
  
  .empty-icon {
    font-size: 48px;
    opacity: 0.5;
  }
  
  .empty-text {
    margin: 0;
    font-size: 16px;
  }
  
  /* 骨架屏行 */
  .skeleton-row {
    pointer-events: none;
  }
  
  .skeleton-row:hover {
    background: transparent !important;
  }
  
  /* 表格底部 */
  .table-footer {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 16px 20px;
    border-top: 1px solid #f3f4f6;
    background: #fafbfc;
  }
  
  .table-info {
    font-size: 13px;
    color: #6b7280;
  }
  
  /* 移动端适配 */
  @media (max-width: 768px) {
    .table-toolbar {
      flex-direction: column;
      gap: 12px;
      align-items: stretch;
    }
    
    .toolbar-left,
    .toolbar-right {
      justify-content: space-between;
    }
    
    .search-box {
      min-width: auto;
      flex: 1;
    }
    
    .table-container {
      overflow-x: auto;
    }
    
    .data-table {
      min-width: 600px;
    }
    
    .table-cell {
      padding: 8px 12px;
      font-size: 13px;
    }
    
    .table-footer {
      flex-direction: column;
      gap: 12px;
      align-items: stretch;
    }
  }
  
  /* 滚动条样式 */
  .table-container::-webkit-scrollbar {
    width: 6px;
    height: 6px;
  }
  
  .table-container::-webkit-scrollbar-track {
    background: #f1f5f9;
    border-radius: 3px;
  }
  
  .table-container::-webkit-scrollbar-thumb {
    background: #cbd5e1;
    border-radius: 3px;
  }
  
  .table-container::-webkit-scrollbar-thumb:hover {
    background: #94a3b8;
  }
</style> 