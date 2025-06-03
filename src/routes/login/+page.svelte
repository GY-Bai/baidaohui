<script lang="ts">
  import { onMount } from 'svelte';
  import { page } from '$app/stores';
  import { get } from 'svelte/store';
  import { signInWithGoogle, getSession, redirectToRolePath } from '$lib/auth';
  import { browser } from '$app/environment';
  import GoogleLoginButton from '$lib/components/ui/GoogleLoginButton.svelte';

  export let data;

  let loading = false;
  let error = data?.error || '';
  let message = data?.message || '';
  let canvas;
  let sessionChecked = false; // 防止重复检查会话

  onMount(async () => {
    try {
      // 防止重复检查
      if (sessionChecked) return;
      sessionChecked = true;
      
      // 检查URL参数中的错误信息
      const currentPage = get(page);
      const urlError = currentPage.url.searchParams.get('error');
      const urlMessage = currentPage.url.searchParams.get('message');
      
      if (urlError) {
        error = urlError;
        console.log('URL错误参数:', urlError);
      }
      if (urlMessage) {
        message = decodeURIComponent(urlMessage);
        console.log('URL消息参数:', message);
      }

      // 检查环境变量是否存在
      if (!import.meta.env.VITE_SUPABASE_URL || !import.meta.env.VITE_SUPABASE_ANON_KEY) {
        console.warn('Supabase环境变量未配置，跳过会话检查');
        initStarfield();
        return;
      }

      // 检查是否已登录，如果已登录则重定向到对应角色页面
      try {
        console.log('登录页面：检查现有登录状态...');
        const session = await getSession();
        if (session) {
          console.log('登录页面：发现现有会话，角色:', session.role);
          console.log('登录页面：重定向到角色页面');
          // 添加延迟避免与其他重定向冲突
          setTimeout(() => {
            redirectToRolePath(session.role);
          }, 200);
          return;
        } else {
          console.log('登录页面：未发现现有会话，用户未登录');
        }
      } catch (err) {
        console.log('登录页面：检查登录状态时出错（这是正常的）:', err.message);
        // 不要显示错误给用户，只是跳过检查
      }

      // 初始化星空背景
      initStarfield();
    } catch (err) {
      console.error('登录页面初始化错误:', err);
      // 确保页面仍然可以显示
      initStarfield();
    }
  });

  async function handleGoogleLogin() {
    try {
      loading = true;
      error = '';
      message = '';
      
      // 检查环境变量
      if (!import.meta.env.VITE_SUPABASE_URL || !import.meta.env.VITE_SUPABASE_ANON_KEY) {
        throw new Error('Supabase配置缺失，请联系管理员');
      }
      
      await signInWithGoogle();
      // 登录成功后会在callback页面处理重定向
    } catch (err) {
      error = 'login_failed';
      message = err.message || '登录过程中出现错误，请重试';
      console.error('登录错误:', err);
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

    // 初始化静态星点
    for (let i = 0; i < numDots; i++) {
      dots.push({
        x: Math.random() * width,
        y: Math.random() * height,
        size: Math.random() * 1.5 + 0.3,
        brightness: Math.random() * 0.5 + 0.2
      });
    }

    // 创建流星
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

    // 初始化流星
    for (let i = 0; i < numStreaks; i++) {
      streaks.push(createStreak());
    }

    function draw() {
      // 添加渐变淡化效果
      ctx.fillStyle = 'rgba(0, 0, 0, 0.3)';
      ctx.fillRect(0, 0, width, height);

      // 绘制静态星点
      for (const dot of dots) {
        ctx.beginPath();
        ctx.arc(dot.x, dot.y, dot.size, 0, Math.PI * 2);
        ctx.fillStyle = `rgba(255,255,255,${dot.brightness})`;
        ctx.fill();
      }

      // 绘制流星
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

        // 当流星飞出屏幕时重新创建
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
    
    <!-- 使用纯Supabase认证，不需要后端状态检查 -->
    <div class="status-success">
      <i class="fas fa-check-circle"></i>
      <span>🟢认证服务正常运行!</span>
    </div>
    
    <GoogleLoginButton 
      {loading}
      disabled={loading}
      on:click={handleGoogleLogin}
    />
    
    <div class="footer">
      教主悄悄话💬｜算命申请🔮｜好物推荐🛍️<br><br>
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
    background: black;
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
    width: 85px;
    height: 85px;
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

  .status-success {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 8px;
    background: rgba(255, 193, 7, 0);
    border: 1px rgba(255, 193, 7, 0);
    border-radius: 8px;
    padding: 8px 12px;
    margin-bottom: 20px;
    color: #155724;
    font-size: 14px;
    
  }

  .status-success i {
    font-size: 16px;
    color:rgb(18, 200, 60);
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
    
    .logo-img {
      width: 65px;
      height: 65px;
    }
  }
</style> 