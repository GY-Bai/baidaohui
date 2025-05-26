<script lang="ts">
  import { onMount } from 'svelte';
  import { page } from '$app/stores';
  import { supabase, getCurrentUser, redirectToRolePage, type AuthChangeEvent, type Session } from '$shared/supabase';
  
  let loading = false;
  let error = '';
  let canvas: HTMLCanvasElement;
  let inviteCode = '';
  let showInviteMessage = false;
  
  onMount(() => {
    // 检查URL中的邀请码参数
    const urlParams = new URLSearchParams(window.location.search);
    inviteCode = urlParams.get('invite') || '';
    
    if (inviteCode) {
      showInviteMessage = true;
      // 将邀请码保存到localStorage，登录后使用
      localStorage.setItem('pending_invite_code', inviteCode);
    }
    
    // 检查是否已经登录
    checkUser();
    
    // 初始化星空背景
    initStarfield();
  });
  
  async function checkUser() {
    try {
      const user = await getCurrentUser();
      if (user) {
        // 如果用户已登录且有待处理的邀请码，先处理邀请码
        const pendingInviteCode = localStorage.getItem('pending_invite_code');
        if (pendingInviteCode) {
          await handleInviteCode(pendingInviteCode, user);
        } else {
          redirectToRolePage(user);
        }
      }
    } catch (err) {
      console.error('检查用户状态失败:', err);
    }
  }
  
  async function handleInviteCode(inviteCode: string, user: any) {
    try {
      const response = await fetch(`/api/auth/consume_invite/${inviteCode}`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${user.access_token}`,
          'Content-Type': 'application/json'
        }
      });
      
      if (response.ok) {
        // 邀请码使用成功，清除localStorage中的邀请码
        localStorage.removeItem('pending_invite_code');
        // 刷新用户信息并跳转
        window.location.reload();
      } else {
        const data = await response.json();
        error = data.error || '邀请链接处理失败';
        localStorage.removeItem('pending_invite_code');
        // 即使邀请码失败，也要跳转到用户对应页面
        redirectToRolePage(user);
      }
    } catch (err) {
      console.error('处理邀请码失败:', err);
      localStorage.removeItem('pending_invite_code');
      redirectToRolePage(user);
    }
  }
  
  async function signInWithGoogle() {
    try {
      loading = true;
      error = '';
      
      const { data, error: authError } = await supabase.auth.signInWithOAuth({
        provider: 'google',
        options: {
          redirectTo: window.location.origin
        }
      });
      
      if (authError) {
        throw authError;
      }
      
    } catch (err) {
      error = '登录失败，请重试';
      console.error('Google 登录失败:', err);
    } finally {
      loading = false;
    }
  }
  
  function initStarfield() {
    if (!canvas) return;
    
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    let width: number, height: number, centerX: number, centerY: number;
    const numDots = 100;
    const numStreaks = 300;
    const dots: Array<{x: number, y: number, size: number, brightness: number}> = [];
    const streaks: Array<{angle: number, radius: number, speed: number, length: number, width: number}> = [];

    function resize() {
      width = canvas.width = window.innerWidth;
      height = canvas.height = window.innerHeight;
      centerX = width / 2;
      centerY = height / 2;
    }

    window.addEventListener('resize', resize);
    resize();

    for (let i = 0; i < numDots; i++) {
      dots.push({
        x: Math.random() * width,
        y: Math.random() * height,
        size: Math.random() * 1.5 + 0.3,
        brightness: Math.random() * 0.5 + 0.2
      });
    }

    function createStreak() {
      const angle = Math.random() * Math.PI * 2;
      return {
        angle,
        radius: 0,
        speed: Math.random() * 3 + 2,
        length: Math.random() * 60 + 40,
        width: Math.random() * 1.2 + 0.5
      };
    }

    for (let i = 0; i < numStreaks; i++) {
      streaks.push(createStreak());
    }

    function draw() {
      ctx.fillStyle = 'rgba(0, 0, 0, 0.3)';
      ctx.fillRect(0, 0, width, height);

      for (const dot of dots) {
        ctx.beginPath();
        ctx.arc(dot.x, dot.y, dot.size, 0, Math.PI * 2);
        ctx.fillStyle = `rgba(255,255,255,${dot.brightness})`;
        ctx.fill();
      }

      for (const star of streaks) {
        const x1 = centerX + Math.cos(star.angle) * (star.radius - star.length * 0.3);
        const y1 = centerY + Math.sin(star.angle) * (star.radius - star.length * 0.3);
        const x2 = centerX + Math.cos(star.angle) * (star.radius + star.length * 0.7);
        const y2 = centerY + Math.sin(star.angle) * (star.radius + star.length * 0.7);

        ctx.beginPath();
        ctx.moveTo(x1, y1);
        ctx.lineTo(x2, y2);
        ctx.strokeStyle = 'rgba(255, 255, 255, 0.9)';
        ctx.lineWidth = star.width;
        ctx.stroke();

        star.radius += star.speed;

        if (x2 < 0-0.1*width || x2 > 1.1*width || y2 < 0-0.1*height || y2 > 1.1*height) {
          Object.assign(star, createStreak());
        }
      }

      requestAnimationFrame(draw);
    }

    draw();
  }
  
  // 监听认证状态变化
  supabase.auth.onAuthStateChange(async (event: AuthChangeEvent, session: Session | null) => {
    if (event === 'SIGNED_IN' && session?.user) {
      // 检查是否有待处理的邀请码
      const pendingInviteCode = localStorage.getItem('pending_invite_code');
      if (pendingInviteCode) {
        await handleInviteCode(pendingInviteCode, session.user);
      } else {
        redirectToRolePage(session.user);
      }
    }
  });
</script>

<svelte:head>
  <title>百刀会 - 登录</title>
  <meta name="description" content="即将跃迁到百刀会" />
</svelte:head>

<style>
  :global(html, body) {
    margin: 0;
    padding: 0;
    height: 100%;
    background: transparent;
    overflow: hidden;
  }

  .starfield {
    position: fixed;
    top: 0;
    left: 0;
    width: 100vw;
    height: 100vh;
    z-index: -1;
    background: black;
  }

  .container {
    display: flex;
    min-height: 100vh;
    align-items: center;
    justify-content: center;
    padding: 1rem;
    background: transparent;
  }

  .login-container {
    background: rgba(255, 255, 255, 0.85);
    backdrop-filter: blur(10px);
    border: 1px solid rgba(255, 255, 255, 0.15);
    border-radius: 20px;
    box-shadow: 0 20px 40px rgba(0, 0, 0, 0.2), 0 0 60px rgba(135, 206, 235, 0.1);
    padding: 2.5rem;
    width: 100%;
    max-width: 400px;
    text-align: center;
    z-index: 10;
    animation: slideUp 0.6s cubic-bezier(0.25, 0.46, 0.45, 0.94);
  }

  @keyframes slideUp {
    from { 
      opacity: 0; 
      transform: translateY(30px); 
    }
    to { 
      opacity: 1; 
      transform: translateY(0); 
    }
  }

  .logo {
    width: 80px;
    height: 80px;
    background: linear-gradient(135deg, #667eea, #764ba2);
    border-radius: 50%;
    margin: 0 auto 2rem;
    display: flex;
    align-items: center;
    justify-content: center;
    box-shadow: 0 0 20px rgba(102, 126, 234, 0.5);
    overflow: hidden;
    position: relative;
  }

  .logo-img {
    width: 100%;
    height: 100%;
    object-fit: cover;
    border-radius: 50%;
  }

  .logo-fallback {
    color: white;
    font-size: 2rem;
    font-weight: bold;
    display: none;
  }

  .title {
    font-size: 1.75rem;
    font-weight: bold;
    color: #333;
    margin-bottom: 0.5rem;
  }

  .subtitle {
    font-size: 1rem;
    color: #666;
    margin-bottom: 2.5rem;
  }

  .google-btn {
    width: 100%;
    padding: 1rem;
    background: #4285f4;
    color: white;
    border: none;
    border-radius: 12px;
    font-size: 1rem;
    font-weight: 500;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 0.75rem;
    transition: all 0.2s;
    position: relative;
  }

  .google-btn:hover {
    background: #3367d6;
    transform: translateY(-1px);
  }

  .google-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
    transform: none;
  }

  .google-icon {
    width: 20px;
    height: 20px;
    background: white;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .footer {
    margin-top: 2rem;
    font-size: 0.75rem;
    color: #aaa;
    line-height: 1.5;
  }

  .footer a {
    color: #4285f4;
    text-decoration: none;
  }

  .footer a:hover {
    text-decoration: underline;
  }

  .invite-message {
    background: rgba(34, 197, 94, 0.1);
    border: 1px solid rgba(34, 197, 94, 0.3);
    color: #059669;
    padding: 1rem;
    border-radius: 12px;
    margin-bottom: 1.5rem;
    text-align: center;
  }

  .invite-message .invite-icon {
    font-size: 2rem;
    margin-bottom: 0.5rem;
  }

  .invite-message h3 {
    margin: 0 0 0.5rem 0;
    font-size: 1.1rem;
    font-weight: 600;
  }

  .invite-message p {
    margin: 0;
    font-size: 0.875rem;
    opacity: 0.8;
  }

  .error {
    background: rgba(255, 0, 0, 0.1);
    border: 1px solid rgba(255, 0, 0, 0.3);
    color: #dc2626;
    padding: 0.75rem;
    border-radius: 8px;
    margin-bottom: 1rem;
    font-size: 0.875rem;
  }

  .loading-spinner {
    width: 20px;
    height: 20px;
    border: 2px solid transparent;
    border-top: 2px solid currentColor;
    border-radius: 50%;
    animation: spin 1s linear infinite;
  }

  @keyframes spin {
    to {
      transform: rotate(360deg);
    }
  }
</style>

<canvas bind:this={canvas} class="starfield"></canvas>

<div class="container">
  <div class="login-container">
    <!-- Logo -->
    <div class="logo">
      <img 
        src="/assets/pic/favicon.png" 
        alt="百刀会Logo" 
        class="logo-img"
        on:error={(e) => {
          e.target.style.display = 'none';
          e.target.nextElementSibling.style.display = 'block';
        }}
      />
      <div class="logo-fallback">100</div>
    </div>
    
    <h1 class="title">即将跃迁到百刀会</h1>
    <p class="subtitle">Everything Both Nothing</p>
    
    {#if showInviteMessage}
      <div class="invite-message">
        <div class="invite-icon">🎉</div>
        <h3>您收到了升级邀请！</h3>
        <p>登录后将自动升级为 Member 用户</p>
      </div>
    {/if}
    
    {#if error}
      <div class="error">{error}</div>
    {/if}
    
    <button
      on:click={signInWithGoogle}
      disabled={loading}
      class="google-btn"
    >
      {#if loading}
        <div class="loading-spinner"></div>
      {:else}
        <div class="google-icon">
          <!-- Google Icon SVG -->
          <svg width="12" height="12" viewBox="0 0 24 24">
            <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/>
            <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>
            <path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"/>
            <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"/>
          </svg>
        </div>
      {/if}
      {loading ? '跃迁引擎启动中...' : '用谷歌登录启动跃迁引擎'}
    </button>
    
    <div class="footer">
      😍教主悄悄话💬｜🤑算命申请🔮｜🤩好物推荐🛍️<br><br>
      登录即表示您同意我们的
      <a href="/terms">服务条款</a>
      和
      <a href="/privacy">隐私政策</a>
    </div>
  </div>
</div> 