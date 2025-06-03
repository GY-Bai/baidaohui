<script lang="ts">
  import { onMount } from 'svelte';
  import { getSession, refreshUserRole } from '$lib/auth';
  import { supabase } from '$lib/auth';

  let loading = true;
  let sessionData = null;
  let profileData = null;
  let error = '';
  let refreshing = false;

  async function loadDebugInfo() {
    loading = true;
    error = '';
    
    try {
      console.log('🔍 调试页面：开始加载调试信息...');
      
      // 1. 获取原始Supabase会话
      const { data: { session }, error: sessionError } = await supabase.auth.getSession();
      if (sessionError) throw sessionError;
      
      sessionData = session;
      
      if (session) {
        // 2. 直接查询profiles表
        const { data: profile, error: profileError } = await supabase
          .from('profiles')
          .select('*')
          .eq('id', session.user.id)
          .single();
          
        if (profileError) {
          console.error('查询profile失败:', profileError);
          error = '查询profile失败: ' + profileError.message;
        } else {
          profileData = profile;
        }
      }
      
      console.log('✅ 调试信息加载完成');
    } catch (err) {
      console.error('❌ 加载调试信息失败:', err);
      error = '加载失败: ' + err.message;
    } finally {
      loading = false;
    }
  }

  async function handleRefreshRole() {
    refreshing = true;
    try {
      console.log('🔄 强制刷新用户角色...');
      const refreshedUser = await refreshUserRole();
      console.log('刷新结果:', refreshedUser);
      
      // 重新加载调试信息
      await loadDebugInfo();
    } catch (err) {
      console.error('刷新角色失败:', err);
      error = '刷新失败: ' + err.message;
    } finally {
      refreshing = false;
    }
  }

  async function handleGetSession() {
    try {
      console.log('🔍 测试getSession函数...');
      const user = await getSession();
      console.log('getSession结果:', user);
      alert('请查看控制台输出');
    } catch (err) {
      console.error('getSession失败:', err);
      alert('getSession失败: ' + err.message);
    }
  }

  onMount(() => {
    loadDebugInfo();
  });
</script>

<svelte:head>
  <title>角色调试 - 百刀会</title>
</svelte:head>

<div class="debug-container">
  <div class="header">
    <h1>🔍 角色调试工具</h1>
    <p>用于诊断和解决角色同步问题</p>
  </div>

  {#if loading}
    <div class="loading">
      <div class="spinner"></div>
      <p>正在加载调试信息...</p>
    </div>
  {:else}
    <div class="debug-sections">
      
      <!-- 操作按钮 -->
      <div class="section">
        <h2>🔧 操作工具</h2>
        <div class="actions">
          <button on:click={handleRefreshRole} disabled={refreshing} class="btn btn-primary">
            {refreshing ? '刷新中...' : '🔄 强制刷新角色'}
          </button>
          <button on:click={handleGetSession} class="btn btn-secondary">
            🧪 测试 getSession
          </button>
          <button on:click={loadDebugInfo} class="btn btn-secondary">
            📊 重新加载信息
          </button>
        </div>
      </div>

      <!-- 会话信息 -->
      <div class="section">
        <h2>🎫 Supabase 会话信息</h2>
        {#if sessionData}
          <div class="info-grid">
            <div class="info-item">
              <strong>用户ID:</strong>
              <code>{sessionData.user.id}</code>
            </div>
            <div class="info-item">
              <strong>邮箱:</strong>
              <code>{sessionData.user.email}</code>
            </div>
            <div class="info-item">
              <strong>元数据角色:</strong>
              <code>{sessionData.user.user_metadata?.role || '未设置'}</code>
            </div>
            <div class="info-item">
              <strong>昵称:</strong>
              <code>{sessionData.user.user_metadata?.nickname || sessionData.user.user_metadata?.full_name || '未设置'}</code>
            </div>
            <div class="info-item">
              <strong>创建时间:</strong>
              <code>{new Date(sessionData.user.created_at).toLocaleString()}</code>
            </div>
          </div>
          
          <details class="raw-data">
            <summary>查看原始会话数据</summary>
            <pre>{JSON.stringify(sessionData, null, 2)}</pre>
          </details>
        {:else}
          <p class="no-data">❌ 未找到会话信息</p>
        {/if}
      </div>

      <!-- Profile信息 -->
      <div class="section">
        <h2>👤 数据库 Profile 信息</h2>
        {#if profileData}
          <div class="info-grid">
            <div class="info-item">
              <strong>用户ID:</strong>
              <code>{profileData.id}</code>
            </div>
            <div class="info-item">
              <strong>数据库角色:</strong>
              <code class="role-{profileData.role?.toLowerCase()}">{profileData.role}</code>
            </div>
            <div class="info-item">
              <strong>昵称:</strong>
              <code>{profileData.nickname || '未设置'}</code>
            </div>
            <div class="info-item">
              <strong>创建时间:</strong>
              <code>{new Date(profileData.created_at).toLocaleString()}</code>
            </div>
            <div class="info-item">
              <strong>更新时间:</strong>
              <code>{new Date(profileData.updated_at).toLocaleString()}</code>
            </div>
          </div>
          
          <details class="raw-data">
            <summary>查看原始Profile数据</summary>
            <pre>{JSON.stringify(profileData, null, 2)}</pre>
          </details>
        {:else}
          <p class="no-data">❌ 未找到Profile信息</p>
        {/if}
      </div>

      <!-- 角色对比 -->
      {#if sessionData && profileData}
        <div class="section">
          <h2>⚖️ 角色对比分析</h2>
          <div class="comparison">
            <div class="comparison-item">
              <h3>元数据角色</h3>
              <div class="role-value role-{sessionData.user.user_metadata?.role?.toLowerCase()}">
                {sessionData.user.user_metadata?.role || '未设置'}
              </div>
            </div>
            <div class="vs">VS</div>
            <div class="comparison-item">
              <h3>数据库角色</h3>
              <div class="role-value role-{profileData.role?.toLowerCase()}">
                {profileData.role}
              </div>
            </div>
          </div>
          
          {#if sessionData.user.user_metadata?.role !== profileData.role}
            <div class="alert alert-warning">
              ⚠️ <strong>检测到角色不同步！</strong><br>
              元数据角色（{sessionData.user.user_metadata?.role || '未设置'}）与数据库角色（{profileData.role}）不一致。<br>
              系统会使用数据库中的角色（{profileData.role}）作为最终角色。
            </div>
          {:else}
            <div class="alert alert-success">
              ✅ <strong>角色同步正常</strong><br>
              元数据角色与数据库角色一致。
            </div>
          {/if}
        </div>
      {/if}

      <!-- 错误信息 -->
      {#if error}
        <div class="section">
          <h2>❌ 错误信息</h2>
          <div class="alert alert-error">
            {error}
          </div>
        </div>
      {/if}

    </div>
  {/if}
</div>

<style>
  .debug-container {
    max-width: 1200px;
    margin: 0 auto;
    padding: 20px;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  }

  .header {
    text-align: center;
    margin-bottom: 30px;
    padding: 20px;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    color: white;
    border-radius: 12px;
  }

  .header h1 {
    margin: 0 0 8px 0;
    font-size: 28px;
  }

  .header p {
    margin: 0;
    opacity: 0.9;
  }

  .loading {
    text-align: center;
    padding: 40px;
  }

  .spinner {
    width: 40px;
    height: 40px;
    border: 4px solid #f3f3f3;
    border-top: 4px solid #667eea;
    border-radius: 50%;
    animation: spin 1s linear infinite;
    margin: 0 auto 16px;
  }

  @keyframes spin {
    0% { transform: rotate(0deg); }
    100% { transform: rotate(360deg); }
  }

  .debug-sections {
    display: flex;
    flex-direction: column;
    gap: 20px;
  }

  .section {
    background: white;
    padding: 20px;
    border-radius: 8px;
    box-shadow: 0 2px 8px rgba(0,0,0,0.1);
    border: 1px solid #e0e0e0;
  }

  .section h2 {
    margin: 0 0 16px 0;
    color: #333;
    border-bottom: 2px solid #667eea;
    padding-bottom: 8px;
  }

  .actions {
    display: flex;
    gap: 12px;
    flex-wrap: wrap;
  }

  .btn {
    padding: 10px 20px;
    border: none;
    border-radius: 6px;
    cursor: pointer;
    font-weight: 600;
    transition: all 0.2s;
  }

  .btn:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }

  .btn-primary {
    background: #667eea;
    color: white;
  }

  .btn-primary:hover:not(:disabled) {
    background: #5a67d8;
  }

  .btn-secondary {
    background: #f7fafc;
    color: #4a5568;
    border: 1px solid #e2e8f0;
  }

  .btn-secondary:hover:not(:disabled) {
    background: #edf2f7;
  }

  .info-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
    gap: 12px;
    margin-bottom: 16px;
  }

  .info-item {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 8px 12px;
    background: #f8f9fa;
    border-radius: 4px;
  }

  .info-item strong {
    color: #495057;
  }

  .info-item code {
    background: #e9ecef;
    padding: 4px 8px;
    border-radius: 4px;
    font-family: 'Monaco', 'Consolas', monospace;
    font-size: 14px;
  }

  .role-fan { background: #e7d4ff !important; color: #6b46c1; }
  .role-member { background: #bfdbfe !important; color: #1e40af; }
  .role-master { background: #fef3c7 !important; color: #d97706; }
  .role-firstmate { background: #fed7cc !important; color: #dc2626; }
  .role-seller { background: #d1fae5 !important; color: #059669; }

  .raw-data {
    margin-top: 12px;
  }

  .raw-data summary {
    cursor: pointer;
    padding: 8px;
    background: #f1f3f4;
    border-radius: 4px;
    font-weight: 600;
  }

  .raw-data pre {
    background: #f8f9fa;
    padding: 16px;
    border-radius: 4px;
    overflow: auto;
    max-height: 300px;
    font-size: 12px;
    margin: 8px 0 0 0;
  }

  .no-data {
    text-align: center;
    padding: 20px;
    color: #6c757d;
    font-style: italic;
  }

  .comparison {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 20px;
    margin-bottom: 20px;
  }

  .comparison-item {
    text-align: center;
    flex: 1;
  }

  .comparison-item h3 {
    margin: 0 0 8px 0;
    color: #6c757d;
    font-size: 14px;
    text-transform: uppercase;
  }

  .role-value {
    padding: 12px 20px;
    border-radius: 8px;
    font-weight: bold;
    font-size: 18px;
    text-transform: uppercase;
    letter-spacing: 1px;
  }

  .vs {
    font-weight: bold;
    color: #6c757d;
    font-size: 18px;
  }

  .alert {
    padding: 16px;
    border-radius: 8px;
    margin-top: 16px;
  }

  .alert-warning {
    background: #fff3cd;
    border: 1px solid #ffeaa7;
    color: #856404;
  }

  .alert-success {
    background: #d4edda;
    border: 1px solid #c3e6cb;
    color: #155724;
  }

  .alert-error {
    background: #f8d7da;
    border: 1px solid #f5c6cb;
    color: #721c24;
  }

  /* 移动端优化 */
  @media (max-width: 768px) {
    .debug-container {
      padding: 16px;
    }

    .info-grid {
      grid-template-columns: 1fr;
    }

    .comparison {
      flex-direction: column;
      gap: 12px;
    }

    .vs {
      transform: rotate(90deg);
    }

    .actions {
      flex-direction: column;
    }
  }
</style> 