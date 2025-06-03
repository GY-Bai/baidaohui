<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  
  const dispatch = createEventDispatcher();
  
  export let loading = false;
  export let disabled = false;
  
  function handleClick() {
    dispatch('click');
  }
</script>

<button 
  on:click={handleClick}
  {disabled}
  class="google-btn"
  class:loading
>
  <div class="google-icon">
    <i class="fab fa-google" style="color: #4285f4; font-size: 12px;"></i>
  </div>
  点击启动曲率引擎!!!<br>一键直达谷歌登录
</button>

<style>
  .google-btn {
    width: 100%;
    padding: 16px 24px;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    color: white;
    border: none;
    border-radius: 12px;
    font-size: 16px;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.3s ease;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 12px;
    text-align: center;
    line-height: 1.4;
    box-shadow: 0 4px 15px rgba(102, 126, 234, 0.4);
  }
  
  .google-btn:hover:not(:disabled) {
    transform: translateY(-2px);
    box-shadow: 0 8px 25px rgba(102, 126, 234, 0.6);
  }
  
  .google-btn:active:not(:disabled) {
    transform: translateY(0);
  }
  
  .google-btn:disabled {
    opacity: 0.7;
    cursor: not-allowed;
    transform: none;
  }
  
  .google-btn.loading {
    opacity: 0.8;
    cursor: wait;
  }
  
  .google-icon {
    width: 24px;
    height: 24px;
    background: white;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
  }
  
  /* 移动端适配 */
  @media (max-width: 480px) {
    .google-btn {
      font-size: 14px;
      padding: 14px 20px;
    }
  }
</style> 