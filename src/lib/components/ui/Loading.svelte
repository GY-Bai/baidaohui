<script lang="ts">
  export let type: 'spinner' | 'dots' | 'pulse' | 'bars' | 'ring' = 'spinner';
  export let size: 'sm' | 'md' | 'lg' | 'xl' = 'md';
  export let color: 'primary' | 'secondary' | 'success' | 'warning' | 'danger' | 'white' = 'primary';
  export let text: string = '';
  export let fullscreen: boolean = false;
  export let overlay: boolean = false;
  export let centered: boolean = true;
  
  $: loadingClasses = [
    'loading',
    `loading-${type}`,
    `loading-${size}`,
    `loading-${color}`,
    fullscreen ? 'loading-fullscreen' : '',
    overlay ? 'loading-overlay' : '',
    centered ? 'loading-centered' : ''
  ].filter(Boolean).join(' ');
</script>

{#if fullscreen}
  <div class="loading-backdrop">
    <div class={loadingClasses}>
      <div class="loading-animation">
        {#if type === 'spinner'}
          <div class="spinner"></div>
        {:else if type === 'dots'}
          <div class="dots">
            <div class="dot"></div>
            <div class="dot"></div>
            <div class="dot"></div>
          </div>
        {:else if type === 'pulse'}
          <div class="pulse"></div>
        {:else if type === 'bars'}
          <div class="bars">
            <div class="bar"></div>
            <div class="bar"></div>
            <div class="bar"></div>
            <div class="bar"></div>
          </div>
        {:else if type === 'ring'}
          <div class="ring">
            <div></div>
            <div></div>
            <div></div>
            <div></div>
          </div>
        {/if}
      </div>
      
      {#if text}
        <div class="loading-text">{text}</div>
      {/if}
    </div>
  </div>
{:else}
  <div class={loadingClasses}>
    <div class="loading-animation">
      {#if type === 'spinner'}
        <div class="spinner"></div>
      {:else if type === 'dots'}
        <div class="dots">
          <div class="dot"></div>
          <div class="dot"></div>
          <div class="dot"></div>
        </div>
      {:else if type === 'pulse'}
        <div class="pulse"></div>
      {:else if type === 'bars'}
        <div class="bars">
          <div class="bar"></div>
          <div class="bar"></div>
          <div class="bar"></div>
          <div class="bar"></div>
        </div>
      {:else if type === 'ring'}
        <div class="ring">
          <div></div>
          <div></div>
          <div></div>
          <div></div>
        </div>
      {/if}
    </div>
    
    {#if text}
      <div class="loading-text">{text}</div>
    {/if}
  </div>
{/if}

<style>
  .loading {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 8px;
  }
  
  .loading-centered {
    width: 100%;
    height: 100%;
    min-height: 100px;
  }
  
  .loading-backdrop {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(255, 255, 255, 0.9);
    backdrop-filter: blur(4px);
    z-index: 1000;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  
  .loading-overlay {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(255, 255, 255, 0.8);
    backdrop-filter: blur(2px);
    z-index: 10;
  }
  
  .loading-animation {
    display: flex;
    align-items: center;
    justify-content: center;
  }
  
  /* 尺寸变体 */
  .loading-sm .loading-animation {
    width: 20px;
    height: 20px;
  }
  
  .loading-md .loading-animation {
    width: 32px;
    height: 32px;
  }
  
  .loading-lg .loading-animation {
    width: 48px;
    height: 48px;
  }
  
  .loading-xl .loading-animation {
    width: 64px;
    height: 64px;
  }
  
  .loading-text {
    font-size: 14px;
    font-weight: 500;
    color: #6b7280;
    text-align: center;
    margin-top: 8px;
  }
  
  /* 颜色变体 */
  .loading-primary {
    color: #667eea;
  }
  
  .loading-secondary {
    color: #6b7280;
  }
  
  .loading-success {
    color: #10b981;
  }
  
  .loading-warning {
    color: #f59e0b;
  }
  
  .loading-danger {
    color: #ef4444;
  }
  
  .loading-white {
    color: white;
  }
  
  /* Spinner 动画 */
  .spinner {
    width: 100%;
    height: 100%;
    border: 2px solid transparent;
    border-top: 2px solid currentColor;
    border-radius: 50%;
    animation: spin 1s linear infinite;
  }
  
  @keyframes spin {
    0% { transform: rotate(0deg); }
    100% { transform: rotate(360deg); }
  }
  
  /* Dots 动画 */
  .dots {
    display: flex;
    gap: 4px;
    align-items: center;
    width: 100%;
    height: 100%;
    justify-content: center;
  }
  
  .dot {
    width: 20%;
    height: 20%;
    background: currentColor;
    border-radius: 50%;
    animation: dots 1.4s ease-in-out both infinite;
  }
  
  .dot:nth-child(1) { animation-delay: -0.32s; }
  .dot:nth-child(2) { animation-delay: -0.16s; }
  .dot:nth-child(3) { animation-delay: 0s; }
  
  @keyframes dots {
    0%, 80%, 100% {
      transform: scale(0);
      opacity: 0.5;
    }
    40% {
      transform: scale(1);
      opacity: 1;
    }
  }
  
  /* Pulse 动画 */
  .pulse {
    width: 100%;
    height: 100%;
    background: currentColor;
    border-radius: 50%;
    animation: pulse 1.5s ease-in-out infinite;
  }
  
  @keyframes pulse {
    0% {
      transform: scale(0);
      opacity: 1;
    }
    100% {
      transform: scale(1);
      opacity: 0;
    }
  }
  
  /* Bars 动画 */
  .bars {
    display: flex;
    gap: 2px;
    align-items: flex-end;
    width: 100%;
    height: 100%;
    justify-content: center;
  }
  
  .bar {
    width: 15%;
    height: 100%;
    background: currentColor;
    border-radius: 1px;
    animation: bars 1.2s ease-in-out infinite;
  }
  
  .bar:nth-child(1) { animation-delay: -1.1s; }
  .bar:nth-child(2) { animation-delay: -1.0s; }
  .bar:nth-child(3) { animation-delay: -0.9s; }
  .bar:nth-child(4) { animation-delay: -0.8s; }
  
  @keyframes bars {
    0%, 40%, 100% {
      transform: scaleY(0.4);
    }
    20% {
      transform: scaleY(1);
    }
  }
  
  /* Ring 动画 */
  .ring {
    position: relative;
    width: 100%;
    height: 100%;
  }
  
  .ring div {
    position: absolute;
    top: 50%;
    left: 50%;
    width: 90%;
    height: 90%;
    margin: -45% 0 0 -45%;
    border: 2px solid transparent;
    border-top-color: currentColor;
    border-radius: 50%;
    animation: ring 1.2s linear infinite;
  }
  
  .ring div:nth-child(1) { animation-delay: 0s; }
  .ring div:nth-child(2) { animation-delay: -0.3s; }
  .ring div:nth-child(3) { animation-delay: -0.6s; }
  .ring div:nth-child(4) { animation-delay: -0.9s; }
  
  @keyframes ring {
    0% {
      transform: rotate(0deg);
      opacity: 1;
    }
    100% {
      transform: rotate(360deg);
      opacity: 0;
    }
  }
  
  /* 深色模式 */
  @media (prefers-color-scheme: dark) {
    .loading-backdrop {
      background: rgba(17, 24, 39, 0.9);
    }
    
    .loading-overlay {
      background: rgba(17, 24, 39, 0.8);
    }
    
    .loading-text {
      color: #9ca3af;
    }
  }
  
  /* 无障碍优化 */
  @media (prefers-reduced-motion: reduce) {
    .spinner,
    .dot,
    .pulse,
    .bar,
    .ring div {
      animation: none;
    }
    
    .dots .dot {
      opacity: 0.6;
      transform: scale(1);
    }
    
    .bars .bar {
      transform: scaleY(0.8);
    }
    
    .ring div {
      opacity: 0.3;
    }
  }
  
  /* 移动端优化 */
  @media (max-width: 480px) {
    .loading-text {
      font-size: 12px;
    }
    
    .loading-backdrop {
      backdrop-filter: blur(2px);
    }
  }
</style> 