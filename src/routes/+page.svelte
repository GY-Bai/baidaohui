<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import Button from '$lib/components/ui/Button.svelte';
  import Select from '$lib/components/ui/Select.svelte';
  import { signInWithGoogle, setCurrentUser, getCurrentUser, getDefaultPath } from '$lib/utils/auth';
  import type { UserRole } from '$lib/utils/auth';
  
  let loading = false;
  let selectedRole: UserRole = 'fan';
  
  const roleOptions = [
    { value: 'fan', label: 'Fan 用户 - 基础功能' },
    { value: 'member', label: 'Member 会员 - 私聊功能' },
    { value: 'master', label: 'Master 主播 - 管理功能' },
    { value: 'firstmate', label: 'Firstmate 助理 - 协助功能' },
    { value: 'seller', label: 'Seller 商户 - 电商功能' }
  ];
  
  async function handleGoogleLogin() {
    loading = true;
    
    try {
      const user = await signInWithGoogle();
      
      // 设置用户角色为选择的角色（模拟）
      const mockUser = {
        ...user,
        role: selectedRole
      };
      
      setCurrentUser(mockUser);
      
      // 重定向到对应角色的页面
      const defaultPath = getDefaultPath(selectedRole);
      await goto(defaultPath);
      
    } catch (error) {
      console.error('登录失败:', error);
      alert('登录失败，请重试');
    } finally {
      loading = false;
    }
  }
  
  function handleDemoAccess() {
    goto('/demo/architecture');
  }
  
  onMount(() => {
    // 检查是否已经登录
    const currentUser = getCurrentUser();
    if (currentUser) {
      const defaultPath = getDefaultPath(currentUser.role);
      goto(defaultPath);
    }
  });
</script>

<svelte:head>
  <title>百道慧 - 智能算命平台</title>
  <meta name="description" content="专业的在线算命和电商平台，为您提供精准的运势预测和开运商品。" />
</svelte:head>

<div class="login-page">
  <div class="login-container">
    <!-- 应用Logo和标题 -->
    <header class="app-header">
      <div class="app-logo">🔮</div>
      <h1 class="app-title">百道慧</h1>
      <p class="app-subtitle">智能算命 · 精准预测 · 开运商城</p>
    </header>
    
    <!-- 登录表单 -->
    <div class="login-form">
      <h2 class="form-title">欢迎使用百道慧</h2>
      <p class="form-subtitle">选择您的角色体验不同功能</p>
      
      <!-- 角色选择 -->
      <div class="role-selector">
        <Select
          id="role-select"
          label="选择体验角色"
          placeholder="请选择角色"
          options={roleOptions}
          bind:value={selectedRole}
          hint="不同角色拥有不同的功能权限"
        />
      </div>
      
      <!-- 登录按钮 -->
      <div class="login-actions">
        <Button
          variant="primary"
          size="lg"
          fullWidth
          {loading}
          icon="🔐"
          on:click={handleGoogleLogin}
        >
          {loading ? '登录中...' : 'Google 账号登录'}
        </Button>
        
        <div class="divider">
          <span>或</span>
        </div>
        
        <Button
          variant="secondary"
          size="lg"
          fullWidth
          icon="🧩"
          on:click={handleDemoAccess}
        >
          查看组件演示
        </Button>
      </div>
      
      <!-- 功能介绍 -->
      <div class="features-preview">
        <h3>平台功能</h3>
        <div class="feature-grid">
          <div class="feature-item">
            <span class="feature-icon">🔮</span>
            <span class="feature-text">专业算命</span>
          </div>
          <div class="feature-item">
            <span class="feature-icon">💬</span>
            <span class="feature-text">在线咨询</span>
          </div>
          <div class="feature-item">
            <span class="feature-icon">🛍️</span>
            <span class="feature-text">开运商城</span>
          </div>
          <div class="feature-item">
            <span class="feature-icon">📱</span>
            <span class="feature-text">移动优先</span>
          </div>
        </div>
      </div>
    </div>
    
    <!-- 页脚信息 -->
    <footer class="login-footer">
      <p>登录即表示您同意我们的服务条款和隐私政策</p>
    </footer>
  </div>
</div>

<style>
  .login-page {
    min-height: 100vh;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 20px;
  }
  
  .login-container {
    background: white;
    border-radius: 20px;
    box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
    max-width: 480px;
    width: 100%;
    overflow: hidden;
  }
  
  /* 应用头部 */
  .app-header {
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    color: white;
    text-align: center;
    padding: 40px 24px;
  }
  
  .app-logo {
    font-size: 64px;
    margin-bottom: 16px;
  }
  
  .app-title {
    margin: 0 0 8px 0;
    font-size: 32px;
    font-weight: 700;
  }
  
  .app-subtitle {
    margin: 0;
    opacity: 0.9;
    font-size: 16px;
  }
  
  /* 登录表单 */
  .login-form {
    padding: 32px 24px;
  }
  
  .form-title {
    margin: 0 0 8px 0;
    font-size: 24px;
    font-weight: 600;
    color: #374151;
    text-align: center;
  }
  
  .form-subtitle {
    margin: 0 0 32px 0;
    color: #6b7280;
    text-align: center;
    font-size: 14px;
  }
  
  .role-selector {
    margin-bottom: 24px;
  }
  
  .login-actions {
    display: flex;
    flex-direction: column;
    gap: 16px;
    margin-bottom: 32px;
  }
  
  .divider {
    position: relative;
    text-align: center;
    color: #9ca3af;
    font-size: 14px;
  }
  
  .divider::before {
    content: '';
    position: absolute;
    top: 50%;
    left: 0;
    right: 0;
    height: 1px;
    background: #e5e7eb;
    z-index: 1;
  }
  
  .divider span {
    background: white;
    padding: 0 16px;
    position: relative;
    z-index: 2;
  }
  
  /* 功能预览 */
  .features-preview {
    border-top: 1px solid #e5e7eb;
    padding-top: 24px;
  }
  
  .features-preview h3 {
    margin: 0 0 16px 0;
    font-size: 18px;
    font-weight: 600;
    color: #374151;
    text-align: center;
  }
  
  .feature-grid {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: 16px;
  }
  
  .feature-item {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 12px;
    background: #f9fafb;
    border-radius: 8px;
  }
  
  .feature-icon {
    font-size: 20px;
  }
  
  .feature-text {
    font-size: 14px;
    font-weight: 500;
    color: #374151;
  }
  
  /* 页脚 */
  .login-footer {
    padding: 20px 24px;
    background: #f9fafb;
    border-top: 1px solid #e5e7eb;
  }
  
  .login-footer p {
    margin: 0;
    font-size: 12px;
    color: #6b7280;
    text-align: center;
    line-height: 1.4;
  }
  
  /* 响应式优化 */
  @media (max-width: 768px) {
    .login-page {
      padding: 12px;
    }
    
    .login-container {
      border-radius: 16px;
    }
    
    .app-header {
      padding: 32px 20px;
    }
    
    .app-logo {
      font-size: 48px;
    }
    
    .app-title {
      font-size: 28px;
    }
    
    .login-form {
      padding: 28px 20px;
    }
    
    .form-title {
      font-size: 20px;
    }
    
    .login-footer {
      padding: 16px 20px;
    }
  }
  
  @media (max-width: 480px) {
    .feature-grid {
      grid-template-columns: 1fr;
    }
    
    .feature-item {
      justify-content: center;
    }
  }
  
  /* 深色模式 */
  @media (prefers-color-scheme: dark) {
    .login-container {
      background: #1f2937;
    }
    
    .form-title {
      color: #f3f4f6;
    }
    
    .form-subtitle {
      color: #9ca3af;
    }
    
    .features-preview {
      border-top-color: #374151;
    }
    
    .features-preview h3 {
      color: #f3f4f6;
    }
    
    .feature-item {
      background: #374151;
    }
    
    .feature-text {
      color: #f3f4f6;
    }
    
    .login-footer {
      background: #111827;
      border-top-color: #374151;
    }
    
    .divider::before {
      background: #374151;
    }
    
    .divider span {
      background: #1f2937;
    }
  }
</style> 