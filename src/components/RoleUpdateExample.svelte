<script lang="ts">
  import { onMount } from 'svelte';
  import { 
    updateUserRoleAndRefreshSession, 
    adminUpdateUserRole, 
    getSession,
    syncCurrentUserRole,
    type UserRole 
  } from '$lib/auth';
  
  let currentUser: any = null;
  let loading = false;
  let message = '';
  let error = '';
  
  // 可选的角色列表
  const availableRoles: UserRole[] = ['Fan', 'Member', 'Master', 'Firstmate', 'Seller'];
  let selectedRole: UserRole = 'Member';
  
  // 管理员功能相关
  let targetUserId = '';
  let adminSelectedRole: UserRole = 'Member';
  let updateReason = '';

  onMount(async () => {
    currentUser = await getSession();
  });

  /**
   * 示例1：用户自己更新角色（例如通过邀请链接升级）
   */
  async function handleSelfRoleUpdate() {
    if (!currentUser) {
      error = '用户未登录';
      return;
    }

    loading = true;
    error = '';
    message = '';

    try {
      console.log('🚀 开始用户自己的角色更新流程...');
      
      // 调用角色更新函数
      const result = await updateUserRoleAndRefreshSession(
        currentUser.id,
        selectedRole,
        { 
          upgrade_reason: 'user_self_upgrade',
          previous_role: currentUser.role,
          timestamp: new Date().toISOString()
        }
      );

      if (result.success) {
        message = `🎉 角色更新成功！从 ${currentUser.role} 升级到 ${selectedRole}`;
        currentUser = result.user; // 更新本地用户信息
        console.log('✅ 角色更新完成，新用户信息:', result.user);
      } else {
        error = result.error || '角色更新失败';
        console.error('❌ 角色更新失败:', result.error);
      }
    } catch (err) {
      error = `更新过程中发生错误: ${err instanceof Error ? err.message : '未知错误'}`;
      console.error('❌ 角色更新异常:', err);
    } finally {
      loading = false;
    }
  }

  /**
   * 示例2：管理员更新其他用户角色
   */
  async function handleAdminRoleUpdate() {
    if (!currentUser) {
      error = '用户未登录';
      return;
    }

    if (!targetUserId.trim()) {
      error = '请输入目标用户ID';
      return;
    }

    loading = true;
    error = '';
    message = '';

    try {
      console.log('👑 开始管理员角色更新流程...');
      
      // 调用管理员角色更新函数
      const result = await adminUpdateUserRole(
        targetUserId.trim(),
        adminSelectedRole,
        updateReason.trim() || '管理员手动更新'
      );

      if (result.success) {
        message = result.message || '管理员角色更新成功！';
        console.log('✅ 管理员角色更新完成');
        
        // 清空表单
        targetUserId = '';
        updateReason = '';
      } else {
        error = result.error || '管理员角色更新失败';
        console.error('❌ 管理员角色更新失败:', result.error);
      }
    } catch (err) {
      error = `管理员更新过程中发生错误: ${err instanceof Error ? err.message : '未知错误'}`;
      console.error('❌ 管理员角色更新异常:', err);
    } finally {
      loading = false;
    }
  }

  /**
   * 示例3：手动同步JWT角色信息
   */
  async function handleManualSync() {
    loading = true;
    error = '';
    message = '';

    try {
      console.log('🔄 开始手动同步JWT角色...');
      
      const result = await syncCurrentUserRole();

      if (result.success) {
        if (result.oldRole !== result.newRole) {
          message = `🎉 角色同步成功！从 ${result.oldRole} 同步到 ${result.newRole}`;
          // 刷新当前用户信息
          currentUser = await getSession();
        } else {
          message = `✅ 角色已同步，无需更新 (${result.newRole})`;
        }
        console.log('✅ 手动同步完成');
      } else {
        error = result.error || '角色同步失败';
        console.error('❌ 手动同步失败:', result.error);
      }
    } catch (err) {
      error = `同步过程中发生错误: ${err instanceof Error ? err.message : '未知错误'}`;
      console.error('❌ 手动同步异常:', err);
    } finally {
      loading = false;
    }
  }

  /**
   * 清除消息
   */
  function clearMessages() {
    message = '';
    error = '';
  }
</script>

<div class="role-update-container">
  <h2>🔄 用户角色更新示例</h2>
  
  <!-- 当前用户信息 -->
  {#if currentUser}
    <div class="user-info">
      <h3>当前用户信息</h3>
      <p><strong>用户ID:</strong> {currentUser.id}</p>
      <p><strong>邮箱:</strong> {currentUser.email}</p>
      <p><strong>当前角色:</strong> <span class="role-badge role-{currentUser.role.toLowerCase()}">{currentUser.role}</span></p>
      <p><strong>昵称:</strong> {currentUser.nickname || '未设置'}</p>
    </div>
  {:else}
    <div class="error">用户未登录，请先登录</div>
  {/if}

  <!-- 消息显示 -->
  {#if message}
    <div class="message success">{message}</div>
  {/if}
  
  {#if error}
    <div class="message error">{error}</div>
  {/if}

  <!-- 示例1：用户自己更新角色 -->
  <div class="section">
    <h3>📈 示例1：用户自己更新角色</h3>
    <p class="description">
      模拟用户通过邀请链接或其他方式升级自己的角色。
      这会先更新数据库，然后刷新JWT Session。
    </p>
    
    <div class="form-group">
      <label for="self-role">选择新角色:</label>
      <select id="self-role" bind:value={selectedRole} disabled={loading}>
        {#each availableRoles as role}
          <option value={role}>{role}</option>
        {/each}
      </select>
    </div>
    
    <button 
      class="btn btn-primary" 
      on:click={handleSelfRoleUpdate}
      disabled={loading || !currentUser}
    >
      {loading ? '更新中...' : '更新我的角色'}
    </button>
  </div>

  <!-- 示例2：管理员更新其他用户角色 -->
  <div class="section">
    <h3>👑 示例2：管理员更新其他用户角色</h3>
    <p class="description">
      管理员（Master/Firstmate）可以更新其他用户的角色。
      这会调用数据库函数，包含权限验证和审计日志。
    </p>
    
    <div class="form-group">
      <label for="target-user">目标用户ID:</label>
      <input 
        id="target-user"
        type="text" 
        bind:value={targetUserId}
        placeholder="输入要更新的用户ID"
        disabled={loading}
      />
    </div>
    
    <div class="form-group">
      <label for="admin-role">新角色:</label>
      <select id="admin-role" bind:value={adminSelectedRole} disabled={loading}>
        {#each availableRoles as role}
          <option value={role}>{role}</option>
        {/each}
      </select>
    </div>
    
    <div class="form-group">
      <label for="reason">更新原因:</label>
      <input 
        id="reason"
        type="text" 
        bind:value={updateReason}
        placeholder="输入更新原因（可选）"
        disabled={loading}
      />
    </div>
    
    <button 
      class="btn btn-secondary" 
      on:click={handleAdminRoleUpdate}
      disabled={loading || !currentUser || !['Master', 'Firstmate'].includes(currentUser?.role)}
    >
      {loading ? '更新中...' : '管理员更新角色'}
    </button>
    
    {#if currentUser && !['Master', 'Firstmate'].includes(currentUser.role)}
      <p class="warning">⚠️ 只有Master或Firstmate可以使用管理员功能</p>
    {/if}
  </div>

  <!-- 示例3：手动同步JWT角色信息 -->
  <div class="section">
    <h3>🔄 示例3：手动同步JWT角色信息</h3>
    <p class="description">
      手动同步JWT角色信息，确保前端和后端角色一致。
    </p>
    
    <button 
      class="btn btn-outline" 
      on:click={handleManualSync}
      disabled={loading || !currentUser}
    >
      {loading ? '同步中...' : '手动同步角色信息'}
    </button>
  </div>

  <!-- 清除消息按钮 -->
  {#if message || error}
    <button class="btn btn-outline" on:click={clearMessages}>
      清除消息
    </button>
  {/if}

  <!-- 技术说明 -->
  <div class="tech-notes">
    <h3>🔧 技术说明</h3>
    <ul>
      <li><strong>数据库优先:</strong> 先更新数据库中的角色信息，确保数据一致性</li>
      <li><strong>JWT刷新:</strong> 使用 <code>supabase.auth.refreshSession()</code> 获取包含最新角色的JWT</li>
      <li><strong>权限验证:</strong> 管理员功能包含前端和后端双重权限验证</li>
      <li><strong>错误处理:</strong> 完整的异步错误处理和用户反馈</li>
      <li><strong>自动重定向:</strong> 角色更新成功后自动重定向到对应页面</li>
    </ul>
  </div>
</div>

<style>
  .role-update-container {
    max-width: 800px;
    margin: 0 auto;
    padding: 20px;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  }

  .user-info {
    background: #f8f9fa;
    border: 1px solid #e9ecef;
    border-radius: 8px;
    padding: 16px;
    margin-bottom: 20px;
  }

  .section {
    background: white;
    border: 1px solid #e9ecef;
    border-radius: 8px;
    padding: 20px;
    margin-bottom: 20px;
  }

  .form-group {
    margin-bottom: 16px;
  }

  .form-group label {
    display: block;
    margin-bottom: 4px;
    font-weight: 500;
  }

  .form-group input,
  .form-group select {
    width: 100%;
    padding: 8px 12px;
    border: 1px solid #ced4da;
    border-radius: 4px;
    font-size: 14px;
  }

  .btn {
    padding: 10px 20px;
    border: none;
    border-radius: 4px;
    font-size: 14px;
    font-weight: 500;
    cursor: pointer;
    transition: all 0.2s;
    margin-right: 10px;
    margin-bottom: 10px;
  }

  .btn:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }

  .btn-primary {
    background: #007bff;
    color: white;
  }

  .btn-primary:hover:not(:disabled) {
    background: #0056b3;
  }

  .btn-secondary {
    background: #6c757d;
    color: white;
  }

  .btn-secondary:hover:not(:disabled) {
    background: #545b62;
  }

  .btn-outline {
    background: transparent;
    color: #6c757d;
    border: 1px solid #6c757d;
  }

  .btn-outline:hover:not(:disabled) {
    background: #6c757d;
    color: white;
  }

  .message {
    padding: 12px 16px;
    border-radius: 4px;
    margin-bottom: 20px;
    font-weight: 500;
  }

  .message.success {
    background: #d4edda;
    color: #155724;
    border: 1px solid #c3e6cb;
  }

  .message.error {
    background: #f8d7da;
    color: #721c24;
    border: 1px solid #f5c6cb;
  }

  .warning {
    color: #856404;
    background: #fff3cd;
    border: 1px solid #ffeaa7;
    padding: 8px 12px;
    border-radius: 4px;
    font-size: 14px;
    margin-top: 8px;
  }

  .role-badge {
    padding: 4px 8px;
    border-radius: 12px;
    font-size: 12px;
    font-weight: 600;
    text-transform: uppercase;
  }

  .role-fan { background: #e3f2fd; color: #1565c0; }
  .role-member { background: #f3e5f5; color: #7b1fa2; }
  .role-master { background: #fff3e0; color: #ef6c00; }
  .role-firstmate { background: #e8f5e8; color: #2e7d32; }
  .role-seller { background: #fce4ec; color: #c2185b; }

  .description {
    color: #6c757d;
    font-size: 14px;
    margin-bottom: 16px;
    line-height: 1.5;
  }

  .tech-notes {
    background: #f8f9fa;
    border-left: 4px solid #007bff;
    padding: 16px;
    margin-top: 20px;
  }

  .tech-notes ul {
    margin: 0;
    padding-left: 20px;
  }

  .tech-notes li {
    margin-bottom: 8px;
    line-height: 1.5;
  }

  .tech-notes code {
    background: #e9ecef;
    padding: 2px 4px;
    border-radius: 3px;
    font-family: 'Monaco', 'Consolas', monospace;
    font-size: 13px;
  }

  h2, h3 {
    color: #343a40;
    margin-bottom: 16px;
  }

  h2 {
    border-bottom: 2px solid #e9ecef;
    padding-bottom: 8px;
  }
</style> 