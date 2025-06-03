<script lang="ts">
  import { onMount } from 'svelte';
  import { getSession } from '$lib/auth';

  let user = null;
  let loading = true;

  onMount(async () => {
    try {
      user = await getSession();
    } catch (error) {
      console.error('获取用户信息失败:', error);
    } finally {
      loading = false;
    }
  });
</script>

<div class="profile-container">
  {#if loading}
    <div class="loading">
      <div class="loading-spinner"></div>
      <p>加载中...</p>
    </div>
  {:else if user}
    <div class="profile-content">
      <div class="profile-header">
        <div class="avatar">
          <div class="avatar-circle">
            {user.nickname?.charAt(0) || user.email.charAt(0).toUpperCase()}
          </div>
        </div>
        <div class="user-info">
          <h2>{user.nickname || '大副'}</h2>
          <p class="email">{user.email}</p>
          <span class="role-badge">Firstmate</span>
        </div>
      </div>

      <div class="profile-sections">
        <div class="section">
          <h3>🎯 职责范围</h3>
          <ul class="responsibility-list">
            <li>协助处理算命申请和订单</li>
            <li>管理聊天室和用户交流</li>
            <li>协助教主维护系统运营</li>
            <li>监督用户互动和内容质量</li>
          </ul>
        </div>

        <div class="section">
          <h3>⚡ 权限说明</h3>
          <div class="permissions">
            <div class="permission-item">
              <span class="permission-icon">✅</span>
              <span>算命订单管理</span>
            </div>
            <div class="permission-item">
              <span class="permission-icon">✅</span>
              <span>聊天室管理</span>
            </div>
            <div class="permission-item">
              <span class="permission-icon">❌</span>
              <span>用户私信查看</span>
            </div>
            <div class="permission-item">
              <span class="permission-icon">❌</span>
              <span>系统核心设置</span>
            </div>
          </div>
        </div>

        <div class="section">
          <h3>📊 工作统计</h3>
          <div class="stats-grid">
            <div class="stat-card">
              <div class="stat-number">--</div>
              <div class="stat-label">处理订单</div>
            </div>
            <div class="stat-card">
              <div class="stat-number">--</div>
              <div class="stat-label">管理消息</div>
            </div>
            <div class="stat-card">
              <div class="stat-number">--</div>
              <div class="stat-label">在线时长</div>
            </div>
          </div>
        </div>
      </div>
    </div>
  {:else}
    <div class="error">
      <p>无法加载用户信息</p>
    </div>
  {/if}
</div>

<style>
  .profile-container {
    padding: 20px;
    max-width: 800px;
    margin: 0 auto;
  }

  .loading {
    text-align: center;
    padding: 40px;
  }

  .loading-spinner {
    width: 40px;
    height: 40px;
    border: 4px solid #f3f3f3;
    border-top: 4px solid #ff8a00;
    border-radius: 50%;
    animation: spin 1s linear infinite;
    margin: 0 auto 16px;
  }

  @keyframes spin {
    0% { transform: rotate(0deg); }
    100% { transform: rotate(360deg); }
  }

  .profile-content {
    background: white;
    border-radius: 12px;
    overflow: hidden;
  }

  .profile-header {
    background: linear-gradient(135deg, #ff8a00 0%, #e52e71 100%);
    color: white;
    padding: 30px;
    text-align: center;
  }

  .avatar {
    margin-bottom: 20px;
  }

  .avatar-circle {
    width: 80px;
    height: 80px;
    background: rgba(255, 255, 255, 0.2);
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 32px;
    font-weight: bold;
    margin: 0 auto;
    border: 3px solid rgba(255, 255, 255, 0.3);
  }

  .user-info h2 {
    margin: 0 0 8px 0;
    font-size: 28px;
    font-weight: 600;
  }

  .email {
    margin: 0 0 12px 0;
    opacity: 0.9;
    font-size: 16px;
  }

  .role-badge {
    background: rgba(255, 255, 255, 0.2);
    padding: 6px 16px;
    border-radius: 20px;
    font-size: 14px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }

  .profile-sections {
    padding: 30px;
  }

  .section {
    margin-bottom: 30px;
  }

  .section h3 {
    margin: 0 0 16px 0;
    font-size: 20px;
    color: #333;
    border-bottom: 2px solid #ff8a00;
    padding-bottom: 8px;
  }

  .responsibility-list {
    list-style: none;
    padding: 0;
    margin: 0;
  }

  .responsibility-list li {
    padding: 12px 0;
    border-bottom: 1px solid #f0f0f0;
    font-size: 16px;
    color: #666;
  }

  .responsibility-list li:before {
    content: "▸ ";
    color: #ff8a00;
    font-weight: bold;
    margin-right: 8px;
  }

  .permissions {
    display: grid;
    gap: 12px;
  }

  .permission-item {
    display: flex;
    align-items: center;
    padding: 12px;
    background: #f8f9fa;
    border-radius: 8px;
    font-size: 16px;
  }

  .permission-icon {
    margin-right: 12px;
    font-size: 18px;
  }

  .stats-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
    gap: 16px;
  }

  .stat-card {
    background: #f8f9fa;
    padding: 20px;
    border-radius: 8px;
    text-align: center;
    border: 2px solid transparent;
    transition: border-color 0.3s ease;
  }

  .stat-card:hover {
    border-color: #ff8a00;
  }

  .stat-number {
    font-size: 32px;
    font-weight: bold;
    color: #ff8a00;
    margin-bottom: 8px;
  }

  .stat-label {
    font-size: 14px;
    color: #666;
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }

  .error {
    text-align: center;
    padding: 40px;
    color: #666;
  }

  /* 移动端优化 */
  @media (max-width: 768px) {
    .profile-container {
      padding: 16px;
    }

    .profile-header {
      padding: 20px;
    }

    .avatar-circle {
      width: 60px;
      height: 60px;
      font-size: 24px;
    }

    .user-info h2 {
      font-size: 24px;
    }

    .profile-sections {
      padding: 20px;
    }

    .stats-grid {
      grid-template-columns: 1fr;
    }
  }
</style> 