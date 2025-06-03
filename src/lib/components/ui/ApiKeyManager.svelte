<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import Button from './Button.svelte';
  import Input from './Input.svelte';
  import Select from './Select.svelte';
  import Card from './Card.svelte';
  import Badge from './Badge.svelte';
  import Toast from './Toast.svelte';
  
  export let keys = [];
  export let canCreate = true;
  export let canRevoke = true;
  export let canEdit = true;
  export let className = '';
  
  const dispatch = createEventDispatcher();
  
  // 创建新密钥的表单
  let showCreateForm = false;
  let createForm = {
    name: '',
    description: '',
    permissions: 'read',
    expiresAt: '',
    rateLimit: 1000
  };
  
  // 状态管理
  let isCreating = false;
  let showToast = false;
  let toastMessage = '';
  let toastType = 'success';
  let revealedKeys = new Set();
  
  // 权限选项
  const permissionOptions = [
    { value: 'read', label: '只读', description: '只能读取数据' },
    { value: 'write', label: '读写', description: '可以读取和修改数据' },
    { value: 'admin', label: '管理', description: '完全访问权限' }
  ];
  
  // 过期时间选项
  const expiryOptions = [
    { value: '', label: '永不过期' },
    { value: '30d', label: '30天后' },
    { value: '90d', label: '90天后' },
    { value: '1y', label: '1年后' },
    { value: 'custom', label: '自定义日期' }
  ];
  
  function generateApiKey() {
    // 生成随机的API密钥
    const prefix = 'bah_';
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    let result = prefix;
    for (let i = 0; i < 40; i++) {
      result += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return result;
  }
  
  function calculateExpiryDate(expiresIn) {
    if (!expiresIn || expiresIn === '') return null;
    
    const now = new Date();
    switch (expiresIn) {
      case '30d':
        return new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000);
      case '90d':
        return new Date(now.getTime() + 90 * 24 * 60 * 60 * 1000);
      case '1y':
        return new Date(now.getTime() + 365 * 24 * 60 * 60 * 1000);
      default:
        return null;
    }
  }
  
  async function handleCreateKey() {
    if (!createForm.name.trim()) {
      showToast = true;
      toastMessage = '请输入密钥名称';
      toastType = 'error';
      return;
    }
    
    isCreating = true;
    
    // 模拟API调用
    setTimeout(() => {
      const newKey = {
        id: Date.now().toString(),
        name: createForm.name.trim(),
        description: createForm.description.trim(),
        key: generateApiKey(),
        permissions: createForm.permissions,
        rateLimit: createForm.rateLimit,
        expiresAt: calculateExpiryDate(createForm.expiresAt),
        createdAt: new Date(),
        lastUsed: null,
        usageCount: 0,
        isActive: true
      };
      
      keys = [newKey, ...keys];
      
      // 重置表单
      createForm = {
        name: '',
        description: '',
        permissions: 'read',
        expiresAt: '',
        rateLimit: 1000
      };
      showCreateForm = false;
      isCreating = false;
      
      // 自动显示新创建的密钥
      revealedKeys.add(newKey.id);
      revealedKeys = revealedKeys;
      
      dispatch('keyCreated', { key: newKey });
      showToast = true;
      toastMessage = 'API密钥创建成功！请安全保存，离开页面后将无法再次查看完整密钥。';
      toastType = 'success';
    }, 1000);
  }
  
  function handleRevokeKey(key) {
    keys = keys.map(k => 
      k.id === key.id ? { ...k, isActive: false } : k
    );
    
    // 从已显示列表中移除
    revealedKeys.delete(key.id);
    revealedKeys = revealedKeys;
    
    dispatch('keyRevoked', { key });
    showToast = true;
    toastMessage = '密钥已撤销';
    toastType = 'warning';
  }
  
  function handleDeleteKey(key) {
    keys = keys.filter(k => k.id !== key.id);
    revealedKeys.delete(key.id);
    revealedKeys = revealedKeys;
    
    dispatch('keyDeleted', { key });
    showToast = true;
    toastMessage = '密钥已删除';
    toastType = 'success';
  }
  
  function toggleKeyVisibility(keyId) {
    if (revealedKeys.has(keyId)) {
      revealedKeys.delete(keyId);
    } else {
      revealedKeys.add(keyId);
    }
    revealedKeys = revealedKeys;
  }
  
  async function copyToClipboard(text) {
    try {
      await navigator.clipboard.writeText(text);
      showToast = true;
      toastMessage = '已复制到剪贴板';
      toastType = 'success';
    } catch (err) {
      console.error('复制失败:', err);
      showToast = true;
      toastMessage = '复制失败';
      toastType = 'error';
    }
  }
  
  function formatDate(date) {
    if (!date) return '永不过期';
    return new Date(date).toLocaleDateString('zh-CN', {
      year: 'numeric',
      month: 'short',
      day: 'numeric'
    });
  }
  
  function formatLastUsed(date) {
    if (!date) return '从未使用';
    
    const now = new Date();
    const diff = now.getTime() - new Date(date).getTime();
    const days = Math.floor(diff / (1000 * 60 * 60 * 24));
    
    if (days === 0) return '今天';
    if (days === 1) return '昨天';
    if (days < 7) return `${days}天前`;
    if (days < 30) return `${Math.floor(days / 7)}周前`;
    return formatDate(date);
  }
  
  function getPermissionColor(permission) {
    switch (permission) {
      case 'admin': return 'error';
      case 'write': return 'warning';
      case 'read': return 'success';
      default: return 'secondary';
    }
  }
  
  function getStatusColor(key) {
    if (!key.isActive) return 'secondary';
    if (key.expiresAt && new Date() > new Date(key.expiresAt)) return 'error';
    return 'success';
  }
  
  function getStatusText(key) {
    if (!key.isActive) return '已撤销';
    if (key.expiresAt && new Date() > new Date(key.expiresAt)) return '已过期';
    return '有效';
  }
  
  function maskKey(key) {
    if (key.length <= 8) return key;
    return key.substring(0, 8) + '•'.repeat(key.length - 12) + key.substring(key.length - 4);
  }
</script>

<div class="api-key-manager {className}">
  <!-- 头部操作 -->
  <Card variant="outlined">
    <div class="manager-header" slot="header">
      <div class="header-info">
        <h2>API密钥管理</h2>
        <p>管理您的API访问密钥，确保应用程序安全访问</p>
      </div>
      
      {#if canCreate}
        <Button
          variant="primary"
          size="default"
          on:click={() => showCreateForm = !showCreateForm}
          disabled={isCreating}
        >
          {showCreateForm ? '取消创建' : '+ 创建新密钥'}
        </Button>
      {/if}
    </div>
    
    <!-- 创建表单 -->
    {#if showCreateForm}
      <div class="create-form">
        <h3>创建新的API密钥</h3>
        
        <div class="form-grid">
          <div class="form-group">
            <label>密钥名称 *</label>
            <Input
              bind:value={createForm.name}
              placeholder="例如：移动应用API"
              maxlength="50"
            />
          </div>
          
          <div class="form-group">
            <label>权限级别</label>
            <Select
              bind:value={createForm.permissions}
              options={permissionOptions}
              placeholder="选择权限"
            />
          </div>
          
          <div class="form-group">
            <label>过期时间</label>
            <Select
              bind:value={createForm.expiresAt}
              options={expiryOptions}
              placeholder="选择过期时间"
            />
          </div>
          
          <div class="form-group">
            <label>速率限制 (请求/小时)</label>
            <Input
              type="number"
              bind:value={createForm.rateLimit}
              placeholder="1000"
              min="1"
              max="10000"
            />
          </div>
        </div>
        
        <div class="form-group">
          <label>描述 (可选)</label>
          <textarea
            bind:value={createForm.description}
            placeholder="描述这个密钥的用途..."
            rows="3"
            class="description-input"
          ></textarea>
        </div>
        
        <div class="form-actions">
          <Button
            variant="primary"
            size="default"
            on:click={handleCreateKey}
            loading={isCreating}
            disabled={isCreating || !createForm.name.trim()}
          >
            {isCreating ? '创建中...' : '创建密钥'}
          </Button>
          
          <Button
            variant="ghost"
            size="default"
            on:click={() => showCreateForm = false}
            disabled={isCreating}
          >
            取消
          </Button>
        </div>
      </div>
    {/if}
  </Card>
  
  <!-- 密钥列表 -->
  {#if keys.length > 0}
    <div class="keys-list">
      {#each keys as key}
        <Card variant="outlined" className="key-card">
          <div class="key-header">
            <div class="key-info">
              <h4>{key.name}</h4>
              {#if key.description}
                <p class="key-description">{key.description}</p>
              {/if}
              
              <div class="key-meta">
                <Badge variant={getPermissionColor(key.permissions)} size="xs">
                  {permissionOptions.find(p => p.value === key.permissions)?.label}
                </Badge>
                <Badge variant={getStatusColor(key)} size="xs">
                  {getStatusText(key)}
                </Badge>
                <span class="meta-text">创建于 {formatDate(key.createdAt)}</span>
              </div>
            </div>
            
            <div class="key-actions">
              {#if key.isActive && canRevoke}
                <Button
                  variant="outline"
                  size="xs"
                  on:click={() => handleRevokeKey(key)}
                >
                  撤销
                </Button>
              {/if}
              
              <Button
                variant="ghost"
                size="xs"
                on:click={() => handleDeleteKey(key)}
              >
                删除
              </Button>
            </div>
          </div>
          
          <!-- 密钥显示 -->
          <div class="key-display">
            <div class="key-field">
              <label>API密钥</label>
              <div class="key-input-group">
                <Input
                  value={revealedKeys.has(key.id) ? key.key : maskKey(key.key)}
                  readonly
                  size="sm"
                  className="key-input"
                />
                
                <Button
                  variant="ghost"
                  size="xs"
                  on:click={() => toggleKeyVisibility(key.id)}
                  title={revealedKeys.has(key.id) ? '隐藏密钥' : '显示密钥'}
                >
                  {revealedKeys.has(key.id) ? '👁️‍🗨️' : '👁️'}
                </Button>
                
                <Button
                  variant="ghost"
                  size="xs"
                  on:click={() => copyToClipboard(key.key)}
                  title="复制密钥"
                >
                  📋
                </Button>
              </div>
            </div>
          </div>
          
          <!-- 使用统计 -->
          <div class="key-stats">
            <div class="stat-item">
              <span class="stat-label">使用次数</span>
              <span class="stat-value">{key.usageCount.toLocaleString()}</span>
            </div>
            
            <div class="stat-item">
              <span class="stat-label">速率限制</span>
              <span class="stat-value">{key.rateLimit}/小时</span>
            </div>
            
            <div class="stat-item">
              <span class="stat-label">最后使用</span>
              <span class="stat-value">{formatLastUsed(key.lastUsed)}</span>
            </div>
            
            <div class="stat-item">
              <span class="stat-label">过期时间</span>
              <span class="stat-value">{formatDate(key.expiresAt)}</span>
            </div>
          </div>
        </Card>
      {/each}
    </div>
  {:else}
    <Card variant="outlined" className="empty-state">
      <div class="empty-content">
        <div class="empty-icon">🔑</div>
        <h3>还没有API密钥</h3>
        <p>创建您的第一个API密钥来开始使用我们的服务</p>
        
        {#if canCreate}
          <Button
            variant="primary"
            size="default"
            on:click={() => showCreateForm = true}
          >
            创建第一个密钥
          </Button>
        {/if}
      </div>
    </Card>
  {/if}
</div>

<!-- Toast 消息 -->
{#if showToast}
  <Toast
    type={toastType}
    message={toastMessage}
    duration={5000}
    bind:visible={showToast}
  />
{/if}

<style>
  .api-key-manager {
    display: flex;
    flex-direction: column;
    gap: 24px;
    max-width: 1000px;
  }
  
  /* 头部 */
  .manager-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    gap: 16px;
  }
  
  .header-info h2 {
    margin: 0 0 4px 0;
    font-size: 24px;
    font-weight: 600;
    color: #111827;
  }
  
  .header-info p {
    margin: 0;
    color: #6b7280;
    font-size: 14px;
  }
  
  /* 创建表单 */
  .create-form {
    padding: 20px;
    background: #f9fafb;
    border-radius: 8px;
    border: 1px solid #e5e7eb;
    margin-top: 16px;
  }
  
  .create-form h3 {
    margin: 0 0 16px 0;
    font-size: 18px;
    font-weight: 600;
    color: #111827;
  }
  
  .form-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 16px;
    margin-bottom: 16px;
  }
  
  .form-group {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }
  
  .form-group label {
    font-size: 14px;
    font-weight: 500;
    color: #374151;
  }
  
  .description-input {
    width: 100%;
    padding: 8px 12px;
    border: 1px solid #d1d5db;
    border-radius: 6px;
    font-size: 14px;
    font-family: inherit;
    resize: vertical;
  }
  
  .description-input:focus {
    outline: none;
    border-color: #3b82f6;
    box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
  }
  
  .form-actions {
    display: flex;
    gap: 12px;
    padding-top: 16px;
    border-top: 1px solid #e5e7eb;
  }
  
  /* 密钥列表 */
  .keys-list {
    display: flex;
    flex-direction: column;
    gap: 16px;
  }
  
  .key-card {
    transition: all 0.2s ease;
  }
  
  .key-card:hover {
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
  }
  
  .key-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    margin-bottom: 16px;
  }
  
  .key-info h4 {
    margin: 0 0 4px 0;
    font-size: 16px;
    font-weight: 600;
    color: #111827;
  }
  
  .key-description {
    margin: 0 0 8px 0;
    color: #6b7280;
    font-size: 14px;
    line-height: 1.4;
  }
  
  .key-meta {
    display: flex;
    gap: 8px;
    align-items: center;
    flex-wrap: wrap;
  }
  
  .meta-text {
    font-size: 12px;
    color: #9ca3af;
  }
  
  .key-actions {
    display: flex;
    gap: 8px;
    flex-shrink: 0;
  }
  
  /* 密钥显示 */
  .key-display {
    margin-bottom: 16px;
  }
  
  .key-field label {
    display: block;
    font-size: 12px;
    font-weight: 500;
    color: #6b7280;
    margin-bottom: 4px;
  }
  
  .key-input-group {
    display: flex;
    gap: 4px;
    align-items: center;
  }
  
  .key-input-group :global(.key-input) {
    flex: 1;
    font-family: monospace;
    font-size: 13px;
  }
  
  /* 使用统计 */
  .key-stats {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(120px, 1fr));
    gap: 16px;
    padding: 12px 0;
    border-top: 1px solid #f3f4f6;
  }
  
  .stat-item {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }
  
  .stat-label {
    font-size: 12px;
    color: #6b7280;
    font-weight: 500;
  }
  
  .stat-value {
    font-size: 14px;
    color: #111827;
    font-weight: 600;
  }
  
  /* 空状态 */
  .empty-state {
    padding: 48px 24px;
  }
  
  .empty-content {
    text-align: center;
    max-width: 400px;
    margin: 0 auto;
  }
  
  .empty-icon {
    font-size: 48px;
    margin-bottom: 16px;
  }
  
  .empty-content h3 {
    margin: 0 0 8px 0;
    font-size: 18px;
    font-weight: 600;
    color: #111827;
  }
  
  .empty-content p {
    margin: 0 0 24px 0;
    color: #6b7280;
    line-height: 1.5;
  }
  
  /* 移动端适配 */
  @media (max-width: 768px) {
    .manager-header {
      flex-direction: column;
      align-items: stretch;
    }
    
    .form-grid {
      grid-template-columns: 1fr;
    }
    
    .form-actions {
      flex-direction: column;
    }
    
    .key-header {
      flex-direction: column;
      gap: 12px;
    }
    
    .key-actions {
      align-self: flex-start;
    }
    
    .key-stats {
      grid-template-columns: repeat(2, 1fr);
    }
    
    .key-input-group {
      flex-wrap: wrap;
    }
  }
  
  /* 深色模式 */
  @media (prefers-color-scheme: dark) {
    .header-info h2,
    .create-form h3,
    .key-info h4,
    .empty-content h3 {
      color: #f9fafb;
    }
    
    .header-info p,
    .key-description,
    .empty-content p {
      color: #d1d5db;
    }
    
    .create-form {
      background: #374151;
      border-color: #4b5563;
    }
    
    .form-group label {
      color: #f3f4f6;
    }
    
    .description-input {
      background: #1f2937;
      border-color: #4b5563;
      color: #f3f4f6;
    }
    
    .description-input:focus {
      border-color: #60a5fa;
    }
    
    .form-actions {
      border-top-color: #4b5563;
    }
    
    .key-stats {
      border-top-color: #374151;
    }
    
    .stat-label {
      color: #d1d5db;
    }
    
    .stat-value {
      color: #f9fafb;
    }
    
    .meta-text {
      color: #9ca3af;
    }
  }
  
  /* 高对比度模式 */
  @media (prefers-contrast: high) {
    .create-form,
    .key-card {
      border-width: 2px;
    }
    
    .form-group label {
      font-weight: 600;
    }
  }
</style> 