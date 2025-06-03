<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import Button from './Button.svelte';
  import Input from './Input.svelte';
  import Select from './Select.svelte';
  import Card from './Card.svelte';
  import Badge from './Badge.svelte';
  import Toast from './Toast.svelte';
  
  export let organization = {
    id: '',
    name: '',
    domain: ''
  };
  export let user = {
    id: '',
    name: '',
    role: 'admin'
  };
  export let showAdvanced = false;
  export let className = '';
  
  const dispatch = createEventDispatcher();
  
  // 邀请设置
  let inviteSettings = {
    type: 'member', // member, admin, viewer
    expiresIn: '7d', // 1d, 3d, 7d, 30d, never
    maxUses: 0, // 0 = unlimited
    requireApproval: false,
    allowSignup: true,
    customMessage: ''
  };
  
  // 生成的邀请链接
  let generatedLinks = [];
  let isGenerating = false;
  let showToast = false;
  let toastMessage = '';
  
  // 配置选项
  const roleOptions = [
    { value: 'viewer', label: '访客', description: '只能查看内容' },
    { value: 'member', label: '成员', description: '可以查看和编辑内容' },
    { value: 'admin', label: '管理员', description: '拥有完整管理权限' }
  ];
  
  const expiryOptions = [
    { value: '1d', label: '1天' },
    { value: '3d', label: '3天' },
    { value: '7d', label: '7天' },
    { value: '30d', label: '30天' },
    { value: 'never', label: '永不过期' }
  ];
  
  function generateInviteLink() {
    isGenerating = true;
    
    // 模拟API调用
    setTimeout(() => {
      const linkId = Date.now().toString(36);
      const baseUrl = organization.domain || 'https://app.baidaohui.com';
      const inviteCode = Math.random().toString(36).substring(2, 10).toUpperCase();
      
      const newLink = {
        id: linkId,
        code: inviteCode,
        url: `${baseUrl}/invite/${inviteCode}`,
        type: inviteSettings.type,
        expiresAt: inviteSettings.expiresIn === 'never' ? null : 
          new Date(Date.now() + parseInt(inviteSettings.expiresIn) * 24 * 60 * 60 * 1000),
        maxUses: inviteSettings.maxUses,
        currentUses: 0,
        createdAt: new Date(),
        createdBy: user.name,
        isActive: true
      };
      
      generatedLinks = [newLink, ...generatedLinks];
      isGenerating = false;
      
      dispatch('linkGenerated', { link: newLink });
      showToast = true;
      toastMessage = '邀请链接已生成';
    }, 1000);
  }
  
  async function copyToClipboard(text) {
    try {
      await navigator.clipboard.writeText(text);
      showToast = true;
      toastMessage = '链接已复制到剪贴板';
      dispatch('linkCopied', { url: text });
    } catch (err) {
      console.error('复制失败:', err);
      showToast = true;
      toastMessage = '复制失败，请手动复制';
    }
  }
  
  function shareLink(link) {
    if (navigator.share) {
      navigator.share({
        title: `加入 ${organization.name}`,
        text: inviteSettings.customMessage || `${user.name} 邀请您加入 ${organization.name}`,
        url: link.url
      });
    } else {
      copyToClipboard(link.url);
    }
    
    dispatch('linkShared', { link });
  }
  
  function revokeLink(link) {
    generatedLinks = generatedLinks.map(l => 
      l.id === link.id ? { ...l, isActive: false } : l
    );
    
    dispatch('linkRevoked', { link });
    showToast = true;
    toastMessage = '邀请链接已撤销';
  }
  
  function deleteLink(link) {
    generatedLinks = generatedLinks.filter(l => l.id !== link.id);
    
    dispatch('linkDeleted', { link });
    showToast = true;
    toastMessage = '邀请链接已删除';
  }
  
  function formatDate(date) {
    if (!date) return '永不过期';
    return new Date(date).toLocaleDateString('zh-CN', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  }
  
  function getRoleColor(role) {
    switch (role) {
      case 'admin': return 'error';
      case 'member': return 'primary';
      case 'viewer': return 'secondary';
      default: return 'default';
    }
  }
  
  function getStatusColor(link) {
    if (!link.isActive) return 'secondary';
    if (link.expiresAt && new Date() > new Date(link.expiresAt)) return 'warning';
    if (link.maxUses > 0 && link.currentUses >= link.maxUses) return 'warning';
    return 'success';
  }
  
  function getStatusText(link) {
    if (!link.isActive) return '已撤销';
    if (link.expiresAt && new Date() > new Date(link.expiresAt)) return '已过期';
    if (link.maxUses > 0 && link.currentUses >= link.maxUses) return '已用完';
    return '有效';
  }
</script>

<div class="invite-generator {className}">
  <Card variant="elevated" padding="lg">
    <h2 slot="header">生成邀请链接</h2>
    
    <!-- 邀请设置 -->
    <div class="invite-settings">
      <div class="settings-grid">
        <!-- 角色选择 -->
        <div class="setting-item">
          <label class="setting-label">邀请角色</label>
          <Select
            bind:value={inviteSettings.type}
            options={roleOptions}
            placeholder="选择角色"
          />
        </div>
        
        <!-- 过期时间 -->
        <div class="setting-item">
          <label class="setting-label">有效期</label>
          <Select
            bind:value={inviteSettings.expiresIn}
            options={expiryOptions}
            placeholder="选择有效期"
          />
        </div>
        
        <!-- 使用次数限制 -->
        <div class="setting-item">
          <label class="setting-label">使用次数</label>
          <Input
            type="number"
            bind:value={inviteSettings.maxUses}
            placeholder="0 = 不限制"
            min="0"
          />
        </div>
      </div>
      
      <!-- 高级设置 -->
      {#if showAdvanced}
        <div class="advanced-settings">
          <h4>高级设置</h4>
          
          <div class="setting-item">
            <label class="checkbox-label">
              <input 
                type="checkbox" 
                bind:checked={inviteSettings.requireApproval}
              />
              需要管理员审批
            </label>
          </div>
          
          <div class="setting-item">
            <label class="checkbox-label">
              <input 
                type="checkbox" 
                bind:checked={inviteSettings.allowSignup}
              />
              允许新用户注册
            </label>
          </div>
          
          <div class="setting-item">
            <label class="setting-label">自定义消息</label>
            <textarea
              bind:value={inviteSettings.customMessage}
              placeholder="添加个人化的邀请消息..."
              rows="3"
              class="custom-message"
            ></textarea>
          </div>
        </div>
      {/if}
      
      <!-- 生成按钮 -->
      <div class="generate-section">
        <Button
          variant="primary"
          size="default"
          on:click={generateInviteLink}
          loading={isGenerating}
          disabled={isGenerating}
        >
          {isGenerating ? '生成中...' : '🔗 生成邀请链接'}
        </Button>
        
        <Button
          variant="ghost"
          size="default"
          on:click={() => showAdvanced = !showAdvanced}
        >
          {showAdvanced ? '隐藏' : '显示'}高级选项
        </Button>
      </div>
    </div>
  </Card>
  
  <!-- 已生成的链接列表 -->
  {#if generatedLinks.length > 0}
    <Card variant="outlined" className="links-section">
      <h3 slot="header">
        已生成的邀请链接
        <Badge variant="secondary" size="sm">{generatedLinks.length}</Badge>
      </h3>
      
      <div class="links-list">
        {#each generatedLinks as link}
          <div class="link-item" class:inactive={!link.isActive}>
            <div class="link-header">
              <div class="link-info">
                <Badge variant={getRoleColor(link.type)} size="xs">
                  {roleOptions.find(r => r.value === link.type)?.label}
                </Badge>
                <Badge variant={getStatusColor(link)} size="xs">
                  {getStatusText(link)}
                </Badge>
              </div>
              
              <div class="link-meta">
                <span class="creation-info">
                  {link.createdBy} · {formatDate(link.createdAt)}
                </span>
              </div>
            </div>
            
            <div class="link-url">
              <Input
                value={link.url}
                readonly
                size="sm"
              >
                <Button
                  slot="suffix"
                  variant="ghost"
                  size="xs"
                  on:click={() => copyToClipboard(link.url)}
                  title="复制链接"
                >
                  📋
                </Button>
              </Input>
            </div>
            
            <div class="link-stats">
              <div class="stat">
                <span class="stat-label">使用次数:</span>
                <span class="stat-value">
                  {link.currentUses}
                  {#if link.maxUses > 0}
                    / {link.maxUses}
                  {/if}
                </span>
              </div>
              
              <div class="stat">
                <span class="stat-label">过期时间:</span>
                <span class="stat-value">{formatDate(link.expiresAt)}</span>
              </div>
            </div>
            
            <div class="link-actions">
              <Button
                variant="outline"
                size="xs"
                on:click={() => shareLink(link)}
                disabled={!link.isActive}
              >
                📤 分享
              </Button>
              
              {#if link.isActive}
                <Button
                  variant="outline"
                  size="xs"
                  on:click={() => revokeLink(link)}
                >
                  🚫 撤销
                </Button>
              {/if}
              
              <Button
                variant="ghost"
                size="xs"
                on:click={() => deleteLink(link)}
              >
                🗑️ 删除
              </Button>
            </div>
          </div>
        {/each}
      </div>
    </Card>
  {/if}
</div>

<!-- Toast 消息 -->
{#if showToast}
  <Toast
    type="success"
    message={toastMessage}
    duration={3000}
    bind:visible={showToast}
  />
{/if}

<style>
  .invite-generator {
    display: flex;
    flex-direction: column;
    gap: 24px;
    max-width: 800px;
  }
  
  /* 邀请设置 */
  .invite-settings {
    display: flex;
    flex-direction: column;
    gap: 20px;
  }
  
  .settings-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 16px;
  }
  
  .setting-item {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }
  
  .setting-label {
    font-size: 14px;
    font-weight: 500;
    color: #374151;
  }
  
  .checkbox-label {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 14px;
    color: #374151;
    cursor: pointer;
  }
  
  .checkbox-label input[type="checkbox"] {
    width: 16px;
    height: 16px;
    accent-color: #3b82f6;
  }
  
  /* 高级设置 */
  .advanced-settings {
    padding: 16px;
    background: #f9fafb;
    border-radius: 8px;
    border: 1px solid #e5e7eb;
  }
  
  .advanced-settings h4 {
    margin: 0 0 12px 0;
    font-size: 14px;
    font-weight: 600;
    color: #374151;
  }
  
  .custom-message {
    width: 100%;
    padding: 8px 12px;
    border: 1px solid #d1d5db;
    border-radius: 6px;
    font-size: 14px;
    font-family: inherit;
    resize: vertical;
    min-height: 60px;
  }
  
  .custom-message:focus {
    outline: none;
    border-color: #3b82f6;
    box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
  }
  
  /* 生成按钮区域 */
  .generate-section {
    display: flex;
    gap: 12px;
    align-items: center;
    padding-top: 8px;
  }
  
  /* 链接列表 */
  .links-section {
    margin-top: 0;
  }
  
  .links-list {
    display: flex;
    flex-direction: column;
    gap: 16px;
  }
  
  .link-item {
    padding: 16px;
    border: 1px solid #e5e7eb;
    border-radius: 8px;
    transition: all 0.2s ease;
  }
  
  .link-item:hover {
    border-color: #d1d5db;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  }
  
  .link-item.inactive {
    opacity: 0.6;
    background: #f9fafb;
  }
  
  .link-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    margin-bottom: 12px;
  }
  
  .link-info {
    display: flex;
    gap: 8px;
    flex-wrap: wrap;
  }
  
  .link-meta {
    text-align: right;
  }
  
  .creation-info {
    font-size: 12px;
    color: #6b7280;
  }
  
  .link-url {
    margin-bottom: 12px;
  }
  
  .link-stats {
    display: flex;
    gap: 24px;
    margin-bottom: 12px;
    padding: 8px 0;
    border-top: 1px solid #f3f4f6;
    border-bottom: 1px solid #f3f4f6;
  }
  
  .stat {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }
  
  .stat-label {
    font-size: 12px;
    color: #6b7280;
  }
  
  .stat-value {
    font-size: 14px;
    font-weight: 500;
    color: #374151;
  }
  
  .link-actions {
    display: flex;
    gap: 8px;
    flex-wrap: wrap;
  }
  
  /* 移动端适配 */
  @media (max-width: 768px) {
    .settings-grid {
      grid-template-columns: 1fr;
    }
    
    .generate-section {
      flex-direction: column;
      align-items: stretch;
    }
    
    .link-header {
      flex-direction: column;
      gap: 8px;
    }
    
    .link-meta {
      text-align: left;
    }
    
    .link-stats {
      flex-direction: column;
      gap: 8px;
    }
    
    .link-actions {
      justify-content: stretch;
    }
    
    .link-actions :global(.btn) {
      flex: 1;
    }
  }
  
  /* 深色模式 */
  @media (prefers-color-scheme: dark) {
    .setting-label {
      color: #f3f4f6;
    }
    
    .checkbox-label {
      color: #e5e7eb;
    }
    
    .advanced-settings {
      background: #374151;
      border-color: #4b5563;
    }
    
    .advanced-settings h4 {
      color: #f3f4f6;
    }
    
    .custom-message {
      background: #1f2937;
      border-color: #4b5563;
      color: #f3f4f6;
    }
    
    .custom-message:focus {
      border-color: #60a5fa;
    }
    
    .link-item {
      border-color: #374151;
    }
    
    .link-item:hover {
      border-color: #4b5563;
    }
    
    .link-item.inactive {
      background: #374151;
    }
    
    .creation-info {
      color: #d1d5db;
    }
    
    .link-stats {
      border-color: #374151;
    }
    
    .stat-label {
      color: #d1d5db;
    }
    
    .stat-value {
      color: #f3f4f6;
    }
  }
  
  /* 高对比度模式 */
  @media (prefers-contrast: high) {
    .link-item {
      border-width: 2px;
    }
    
    .setting-label,
    .checkbox-label {
      color: #000;
      font-weight: 600;
    }
  }
</style> 