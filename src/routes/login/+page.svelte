<script>
  import { onMount } from 'svelte';
  import { page } from '$app/stores';
  import { signInWithGoogle, getSession, redirectToRoleDomain } from '$lib/auth';

  export let data;

  let loading = false;
  let error = data?.error || '';
  let message = data?.message || '';
  let backendStatus = data?.backendStatus || 'unknown';
  let canvas;

  onMount(async () => {
    // 检查URL参数中的错误信息
    const urlError = $page.url.searchParams.get('error');
    const urlMessage = $page.url.searchParams.get('message');
    
    if (urlError) {
      error = urlError;
    }
    if (urlMessage) {
      message = decodeURIComponent(urlMessage);
    }

    // 只有在后端服务可用时才检查登录状态
    if (backendStatus === 'available') {
      try {
        const session = await getSession();
        if (session) {
          redirectToRoleDomain(session.user.role);
        }
      } catch (err) {
        console.log('检查登录状态失败:', err);
      }
    }

    // 初始化星空背景
    initStarfield();
  });

  async function handleGoogleLogin() {
    if (backendStatus === 'unavailable') {
      error = 'backend_unavailable';
      message = '后端服务暂时不可用，无法进行登录。请等待服务部署完成后再试。';
      return;
    }

    try {
      loading = true;
      error = '';
      message = '';
      await signInWithGoogle();
    } catch (err) {
      error = 'login_failed';
      message = '登录过程中出现错误，请重试';
      console.error(err);
    } finally {
      loading = false;
    }
  }

  function initStarfield() {
    if (!canvas) return;
    
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    let width, height, centerX, centerY;
    const numDots = 100;
    const numStreaks = 300;
    const dots = [];
    const streaks = [];

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
</script>

<svelte:head>
  <title>百刀会 - 登录</title>
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css">
</svelte:head>

<canvas bind:this={canvas} class="starfield"></canvas>

{#if loading}
  <div class="loading">曲率引擎已启动！<br><br>[前往Google登录]</div>
{/if}

{#if error && !loading}
  <div class="error">{message || error}</div>
{/if}

<div class="login-container">
  <div class="login-card">
    <div class="logo">
      <img 
        src="/favicon.png" 
        alt="百刀会Logo" 
        class="logo-img"
        on:error={(e) => {
          e.currentTarget.style.display = 'none';
          e.currentTarget.nextElementSibling.style.display = 'block';
        }}
      />
      <div class="logo-fallback">百刀会</div>
    </div>
    
    <h1>欢迎来到百刀会</h1>
    <p class="subtitle">Everything Both Nothing</p>
    
    <!-- 后端服务状态显示 -->
    {#if backendStatus === 'unavailable'}
      <div class="status-warning">
        <i class="fas fa-exclamation-triangle"></i>
        <div>
          <strong>无法通信!!!</strong><br>
          <small>后端服务正在抢修中...</small>
        </div>
      </div>
    {:else if backendStatus === 'available'}
      <div class="status-success">
        <i class="fas fa-check-circle"></i>
        <span>通信正常!</span>
      </div>
    {/if}
    
    <button 
      on:click={handleGoogleLogin}
      disabled={loading || backendStatus === 'unavailable'}
      class="google-btn"
      class:disabled={backendStatus === 'unavailable'}
    >
      <div class="google-icon">
        <i class="fab fa-google" style="color: #4285f4; font-size: 12px;"></i>
      </div>
      {#if backendStatus === 'unavailable'}
        曲率引擎抢修中...
      {:else}
        点击启动曲率引擎!!!
      {/if}
    </button>
    
    <div class="footer">
      😍教主悄悄话💬｜🤑算命申请🔮｜🤩好物推荐🛍️<br><br>
      登录即表示您同意我们的<br>服务条款和隐私政策
    </div>
  </div>
</div>

<style>
  :global(body) {
    margin: 0;
    padding: 0;
    font-family: 'Arial', sans-serif;
    background: #000;
    overflow: hidden;
  }

  .starfield {
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    z-index: -1;
    background: radial-gradient(ellipse at center, #1a1a2e 0%, #16213e 50%, #0f0f23 100%);
  }

  .loading {
    position: fixed;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    color: #00ff88;
    font-size: 18px;
    text-align: center;
    z-index: 1000;
    background: rgba(0, 0, 0, 0.8);
    padding: 20px;
    border-radius: 10px;
    border: 2px solid #00ff88;
    animation: pulse 2s infinite;
  }

  .error {
    position: fixed;
    top: 20px;
    left: 50%;
    transform: translateX(-50%);
    color: #ff4444;
    background: rgba(0, 0, 0, 0.8);
    padding: 15px;
    border-radius: 8px;
    border: 1px solid #ff4444;
    z-index: 1000;
  }

  .login-container {
    position: fixed;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    z-index: 100;
    max-width: 400px;
    width: 70%;
    padding: 0 60px;
  }

  .login-card {
    background: white;
    border-radius: 16px;
    padding: 40px 30px;
    box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
    text-align: center;
    backdrop-filter: blur(10px);
    border: 1px solid rgba(255, 255, 255, 0.1);
  }

  .logo {
    margin-bottom: 20px;
  }

  .logo-img {
    width: 80px;
    height: 80px;
    border-radius: 50%;
    box-shadow: 0 0 20px rgba(0, 0, 0, 0.1);
    transition: transform 0.3s ease;
  }

  .logo-img:hover {
    transform: scale(1.1);
  }

  .logo-fallback {
    display: none;
    font-size: 24px;
    font-weight: bold;
    color: #667eea;
    text-shadow: 0 0 10px rgba(102, 126, 234, 0.3);
  }

  h1 {
    font-size: 28px;
    margin: 20px 0 10px 0;
    color: #333;
    font-weight: 600;
  }

  .subtitle {
    font-size: 16px;
    color: #666;
    margin-bottom: 20px;
    font-style: italic;
  }

  .status-warning {
    display: flex;
    width: 70%;
    align-items: center;
    justify-content: center;
    gap: 10px;
    background: rgba(255, 193, 7, 0.1);
    border: 1px solid #ffc107;
    border-radius: 8px;
    padding: 12px;
    margin-bottom: 30px;
    color: #856404;
    font-size: 14px;
    
  }

  .status-warning i {
    font-size: 18px;
    flex-shrink: 0;
    color: #ffc107;
  }

  .status-success {
    display: flex;
    width: 70%;
    align-items: center;
    justify-content: center;
    gap: 8px;
    background: rgba(40, 167, 69, 0.1);
    border: 1px solid #28a745;
    border-radius: 8px;
    padding: 8px 12px;
    margin-bottom: 30px;
    color: #155724;
    font-size: 14px;
    
  }

  .status-success i {
    font-size: 16px;
    color: #28a745;
  }

  .google-btn {
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    border: none;
    color: white;
    padding: 15px 30px;
    font-size: 16px;
    border-radius: 50px;
    cursor: pointer;
    transition: all 0.3s ease;
    box-shadow: 0 8px 25px rgba(102, 126, 234, 0.3);
    display: flex;
    align-items: center;
    justify-content: center;
    width: 100%;
    margin: 0 auto 40px auto;
    position: relative;
    overflow: hidden;
    font-weight: 500;
  }

  .google-btn:hover {
    transform: translateY(-2px);
    box-shadow: 0 12px 35px rgba(102, 126, 234, 0.4);
  }

  .google-btn:active {
    transform: translateY(0);
  }

  .google-btn:disabled {
    opacity: 0.7;
    cursor: not-allowed;
    transform: none;
  }

  .google-btn::before {
    content: '';
    position: absolute;
    top: 0;
    left: -100%;
    width: 100%;
    height: 100%;
    background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.2), transparent);
    transition: left 0.5s;
  }

  .google-btn:hover::before {
    left: 100%;
  }

  .google-icon {
    margin-right: 10px;
    background: white;
    border-radius: 50%;
    width: 24px;
    height: 24px;
    display: flex;
    align-items: center;
    justify-content: center;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
  }

  .footer {
    font-size: 12px;
    color: #888;
    line-height: 1.5;
  }

  @keyframes pulse {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.7; }
  }

  @media (max-width: 480px) {
    .login-container {
      width: 80%;
      padding: 0 10px;
    }
    
    .login-card {
      padding: 20px 20px;
    }
    
    h1 {
      font-size: 24px;
    }
    
    .google-btn {
      font-size: 14px;
      padding: 12px 25px;
    }
    
    .logo-img {
      width: 60px;
      height: 60px;
    }
  }
</style> 