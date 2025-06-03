<script lang="ts">
  import { createEventDispatcher, onMount, tick } from 'svelte';
  import { fly, scale, fade } from 'svelte/transition';
  import { cubicOut, backOut } from 'svelte/easing';
  import { trapFocus } from '$lib/utils/focus-trap';
  
  export let isOpen: boolean = false;
  export let title: string = '新建算命申请';
  export let subtitle: string = '填写您的需求，获得专业算命服务';
  
  const dispatch = createEventDispatcher();
  
  // 表单数据
  let formData = {
    title: '',
    description: '',
    category: '',
    urgency: 'normal',
    budget: '',
    preferredDate: '',
    contactMethod: 'platform',
    additionalInfo: ''
  };
  
  // 表单状态
  let currentStep = 1;
  let totalSteps = 3;
  let isSubmitting = false;
  let errors: Record<string, string> = {};
  
  // 元素引用
  let modalElement: HTMLElement;
  let formElement: HTMLFormElement;
  
  // 类别选项
  const categories = [
    { id: 'career', label: '事业运势', icon: '💼', description: '工作发展、投资理财' },
    { id: 'love', label: '感情姻缘', icon: '💕', description: '恋爱、婚姻、感情问题' },
    { id: 'health', label: '健康养生', icon: '🏥', description: '身体健康、疾病预防' },
    { id: 'family', label: '家庭和睦', icon: '🏠', description: '家庭关系、子女教育' },
    { id: 'study', label: '学业考试', icon: '📚', description: '考试运势、学习发展' },
    { id: 'fortune', label: '财运分析', icon: '💰', description: '财富运势、投资建议' }
  ];
  
  // 紧急程度选项
  const urgencyOptions = [
    { id: 'low', label: '不着急', color: 'green', description: '一周内回复即可' },
    { id: 'normal', label: '一般', color: 'blue', description: '3天内回复' },
    { id: 'high', label: '比较急', color: 'orange', description: '24小时内回复' },
    { id: 'urgent', label: '非常急', color: 'red', description: '当天回复' }
  ];
  
  $: canProceedToStep2 = formData.title.trim() && formData.category && formData.description.trim();
  $: canProceedToStep3 = formData.urgency && formData.budget;
  $: canSubmit = formData.contactMethod && currentStep === totalSteps;
  
  // 监听 ESC 键关闭
  function handleKeydown(event: KeyboardEvent) {
    if (event.key === 'Escape' && isOpen) {
      handleClose();
    }
  }
  
  onMount(() => {
    document.addEventListener('keydown', handleKeydown);
    return () => {
      document.removeEventListener('keydown', handleKeydown);
    };
  });
  
  // 关闭模态框
  function handleClose() {
    if (isSubmitting) return;
    
    dispatch('close');
    resetForm();
  }
  
  // 重置表单
  function resetForm() {
    formData = {
      title: '',
      description: '',
      category: '',
      urgency: 'normal',
      budget: '',
      preferredDate: '',
      contactMethod: 'platform',
      additionalInfo: ''
    };
    currentStep = 1;
    errors = {};
  }
  
  // 下一步
  function nextStep() {
    if (currentStep < totalSteps) {
      currentStep++;
    }
  }
  
  // 上一步
  function prevStep() {
    if (currentStep > 1) {
      currentStep--;
    }
  }
  
  // 验证表单
  function validateForm() {
    errors = {};
    
    if (!formData.title.trim()) {
      errors.title = '请输入申请标题';
    }
    
    if (!formData.description.trim()) {
      errors.description = '请描述您的需求';
    }
    
    if (!formData.category) {
      errors.category = '请选择算命类别';
    }
    
    if (!formData.budget) {
      errors.budget = '请设定预算范围';
    }
    
    return Object.keys(errors).length === 0;
  }
  
  // 提交表单
  async function handleSubmit() {
    if (!validateForm()) return;
    
    isSubmitting = true;
    
    try {
      await new Promise(resolve => setTimeout(resolve, 2000)); // 模拟 API 调用
      
      dispatch('submit', { 
        formData: { ...formData },
        success: true 
      });
      
      handleClose();
    } catch (error) {
      console.error('提交失败:', error);
      dispatch('submit', { 
        formData: { ...formData }, 
        success: false, 
        error: error.message 
      });
    } finally {
      isSubmitting = false;
    }
  }
  
  // 点击遮罩关闭
  function handleBackdropClick(event: MouseEvent) {
    if (event.target === event.currentTarget) {
      handleClose();
    }
  }
  
  // 获取步骤标题
  function getStepTitle(step: number) {
    switch (step) {
      case 1: return '基本信息';
      case 2: return '详细需求';
      case 3: return '联系方式';
      default: return '';
    }
  }
</script>

{#if isOpen}
  <!-- 模态框遮罩 -->
  <div 
    class="modal-backdrop"
    on:click={handleBackdropClick}
    in:fade={{ duration: 200 }}
    out:fade={{ duration: 150 }}
    use:trapFocus
  >
    <!-- 模态框容器 -->
    <div 
      class="modal-container"
      bind:this={modalElement}
      in:fly={{ y: 50, duration: 300, easing: backOut }}
      out:fly={{ y: 30, duration: 200, easing: cubicOut }}
      role="dialog"
      aria-modal="true"
      aria-labelledby="modal-title"
      aria-describedby="modal-description"
    >
      <!-- 头部 -->
      <header class="modal-header">
        <div class="header-content">
          <button 
            class="close-button"
            on:click={handleClose}
            aria-label="关闭"
            disabled={isSubmitting}
          >
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
              <path d="M18 6L6 18M6 6l12 12" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
            </svg>
          </button>
          
          <div class="title-section">
            <h2 id="modal-title" class="modal-title">{title}</h2>
            <p id="modal-description" class="modal-subtitle">{subtitle}</p>
          </div>
          
          <div class="action-button">
            {#if currentStep < totalSteps}
              <button 
                class="next-button"
                on:click={nextStep}
                disabled={currentStep === 1 ? !canProceedToStep2 : !canProceedToStep3}
              >
                下一步
              </button>
            {:else}
              <button 
                class="submit-button"
                on:click={handleSubmit}
                disabled={!canSubmit || isSubmitting}
              >
                {#if isSubmitting}
                  <span class="loading-spinner"></span>
                  提交中...
                {:else}
                  提交申请
                {/if}
              </button>
            {/if}
          </div>
        </div>
        
        <!-- 进度指示器 -->
        <div class="progress-section">
          <div class="step-indicator">
            {#each Array(totalSteps) as _, i}
              <div 
                class="step-dot"
                class:active={i + 1 <= currentStep}
                class:current={i + 1 === currentStep}
              ></div>
            {/each}
          </div>
          <div class="step-info">
            <span class="step-title">{getStepTitle(currentStep)}</span>
            <span class="step-counter">{currentStep} / {totalSteps}</span>
          </div>
        </div>
      </header>
      
      <!-- 内容区域 -->
      <main class="modal-content">
        <form bind:this={formElement} on:submit|preventDefault={handleSubmit}>
          
          <!-- 第一步：基本信息 -->
          {#if currentStep === 1}
            <div class="form-section" in:fly={{ x: 20, duration: 300, easing: cubicOut }}>
              <div class="form-group">
                <label for="title" class="form-label">申请标题 *</label>
                <input
                  id="title"
                  type="text"
                  class="form-input"
                  class:error={errors.title}
                  bind:value={formData.title}
                  placeholder="简要描述您的算命需求"
                  maxlength="50"
                  autocomplete="off"
                />
                {#if errors.title}
                  <span class="error-message" in:fly={{ y: -5, duration: 200 }}>{errors.title}</span>
                {/if}
              </div>
              
              <div class="form-group">
                <label class="form-label">选择类别 *</label>
                <div class="category-grid">
                  {#each categories as category}
                    <button
                      type="button"
                      class="category-card"
                      class:selected={formData.category === category.id}
                      on:click={() => formData.category = category.id}
                    >
                      <div class="category-icon">{category.icon}</div>
                      <div class="category-info">
                        <div class="category-label">{category.label}</div>
                        <div class="category-desc">{category.description}</div>
                      </div>
                    </button>
                  {/each}
                </div>
                {#if errors.category}
                  <span class="error-message" in:fly={{ y: -5, duration: 200 }}>{errors.category}</span>
                {/if}
              </div>
              
              <div class="form-group">
                <label for="description" class="form-label">详细描述 *</label>
                <textarea
                  id="description"
                  class="form-textarea"
                  class:error={errors.description}
                  bind:value={formData.description}
                  placeholder="请详细描述您遇到的问题或想了解的情况..."
                  rows="4"
                  maxlength="500"
                ></textarea>
                <div class="char-count">{formData.description.length}/500</div>
                {#if errors.description}
                  <span class="error-message" in:fly={{ y: -5, duration: 200 }}>{errors.description}</span>
                {/if}
              </div>
            </div>
          {/if}
          
          <!-- 第二步：详细需求 -->
          {#if currentStep === 2}
            <div class="form-section" in:fly={{ x: 20, duration: 300, easing: cubicOut }}>
              <div class="form-group">
                <label class="form-label">紧急程度 *</label>
                <div class="urgency-options">
                  {#each urgencyOptions as option}
                    <button
                      type="button"
                      class="urgency-card {option.color}"
                      class:selected={formData.urgency === option.id}
                      on:click={() => formData.urgency = option.id}
                    >
                      <div class="urgency-label">{option.label}</div>
                      <div class="urgency-desc">{option.description}</div>
                    </button>
                  {/each}
                </div>
              </div>
              
              <div class="form-group">
                <label for="budget" class="form-label">预算范围 *</label>
                <select
                  id="budget"
                  class="form-select"
                  class:error={errors.budget}
                  bind:value={formData.budget}
                >
                  <option value="">请选择预算范围</option>
                  <option value="50-100">$50 - $100</option>
                  <option value="100-200">$100 - $200</option>
                  <option value="200-500">$200 - $500</option>
                  <option value="500+">$500以上</option>
                </select>
                {#if errors.budget}
                  <span class="error-message" in:fly={{ y: -5, duration: 200 }}>{errors.budget}</span>
                {/if}
              </div>
              
              <div class="form-group">
                <label for="preferredDate" class="form-label">希望完成时间</label>
                <input
                  id="preferredDate"
                  type="date"
                  class="form-input"
                  bind:value={formData.preferredDate}
                  min={new Date().toISOString().split('T')[0]}
                />
              </div>
            </div>
          {/if}
          
          <!-- 第三步：联系方式 -->
          {#if currentStep === 3}
            <div class="form-section" in:fly={{ x: 20, duration: 300, easing: cubicOut }}>
              <div class="form-group">
                <label class="form-label">联系方式 *</label>
                <div class="contact-options">
                  <label class="contact-option">
                    <input
                      type="radio"
                      name="contactMethod"
                      value="platform"
                      bind:group={formData.contactMethod}
                    />
                    <div class="contact-card">
                      <div class="contact-icon">💬</div>
                      <div class="contact-info">
                        <div class="contact-label">平台内联系</div>
                        <div class="contact-desc">通过百道慧平台内消息系统</div>
                      </div>
                    </div>
                  </label>
                  
                  <label class="contact-option">
                    <input
                      type="radio"
                      name="contactMethod"
                      value="email"
                      bind:group={formData.contactMethod}
                    />
                    <div class="contact-card">
                      <div class="contact-icon">📧</div>
                      <div class="contact-info">
                        <div class="contact-label">邮件联系</div>
                        <div class="contact-desc">通过电子邮件回复</div>
                      </div>
                    </div>
                  </label>
                </div>
              </div>
              
              <div class="form-group">
                <label for="additionalInfo" class="form-label">补充信息</label>
                <textarea
                  id="additionalInfo"
                  class="form-textarea"
                  bind:value={formData.additionalInfo}
                  placeholder="其他需要说明的情况..."
                  rows="3"
                  maxlength="200"
                ></textarea>
                <div class="char-count">{formData.additionalInfo.length}/200</div>
              </div>
            </div>
          {/if}
          
        </form>
      </main>
      
      <!-- 底部操作栏 -->
      <footer class="modal-footer">
        {#if currentStep > 1}
          <button 
            class="prev-button"
            on:click={prevStep}
            disabled={isSubmitting}
          >
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
              <path d="M19 12H5M12 19l-7-7 7-7" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
            </svg>
            上一步
          </button>
        {/if}
        
        <div class="footer-spacer"></div>
        
        <div class="form-hints">
          <p class="hint-text">💡 提示：填写详细信息有助于获得更准确的算命结果</p>
        </div>
      </footer>
    </div>
  </div>
{/if}

<style>
  .modal-backdrop {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.6);
    backdrop-filter: blur(4px);
    -webkit-backdrop-filter: blur(4px);
    z-index: 9999;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 16px;
  }
  
  .modal-container {
    background: white;
    border-radius: 16px;
    box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
    width: 100%;
    max-width: 480px;
    max-height: 90vh;
    display: flex;
    flex-direction: column;
    overflow: hidden;
  }
  
  .modal-header {
    border-bottom: 1px solid #e5e7eb;
    background: #fafafa;
  }
  
  .header-content {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 16px 20px;
    gap: 16px;
  }
  
  .close-button {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 32px;
    height: 32px;
    border: none;
    background: none;
    color: #6b7280;
    cursor: pointer;
    border-radius: 8px;
    transition: all 0.2s;
    flex-shrink: 0;
  }
  
  .close-button:hover {
    background: #f3f4f6;
    color: #374151;
  }
  
  .title-section {
    flex: 1;
    text-align: center;
  }
  
  .modal-title {
    margin: 0;
    font-size: 18px;
    font-weight: 600;
    color: #111827;
    line-height: 1.4;
  }
  
  .modal-subtitle {
    margin: 4px 0 0 0;
    font-size: 14px;
    color: #6b7280;
    line-height: 1.4;
  }
  
  .action-button {
    flex-shrink: 0;
  }
  
  .next-button,
  .submit-button {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 8px 16px;
    background: #667eea;
    color: white;
    border: none;
    border-radius: 8px;
    font-weight: 600;
    font-size: 14px;
    cursor: pointer;
    transition: all 0.2s;
  }
  
  .next-button:hover:not(:disabled),
  .submit-button:hover:not(:disabled) {
    background: #5a67d8;
    transform: translateY(-1px);
  }
  
  .next-button:disabled,
  .submit-button:disabled {
    opacity: 0.5;
    cursor: not-allowed;
    transform: none;
  }
  
  .loading-spinner {
    width: 16px;
    height: 16px;
    border: 2px solid rgba(255, 255, 255, 0.3);
    border-top: 2px solid white;
    border-radius: 50%;
    animation: spin 1s linear infinite;
  }
  
  @keyframes spin {
    0% { transform: rotate(0deg); }
    100% { transform: rotate(360deg); }
  }
  
  .progress-section {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 12px 20px;
    background: white;
  }
  
  .step-indicator {
    display: flex;
    gap: 8px;
  }
  
  .step-dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    background: #d1d5db;
    transition: all 0.3s;
  }
  
  .step-dot.active {
    background: #667eea;
  }
  
  .step-dot.current {
    transform: scale(1.2);
    box-shadow: 0 0 0 4px rgba(102, 126, 234, 0.1);
  }
  
  .step-info {
    display: flex;
    flex-direction: column;
    align-items: flex-end;
    gap: 2px;
  }
  
  .step-title {
    font-size: 14px;
    font-weight: 600;
    color: #374151;
  }
  
  .step-counter {
    font-size: 12px;
    color: #6b7280;
  }
  
  .modal-content {
    flex: 1;
    overflow-y: auto;
    padding: 24px 20px;
  }
  
  .form-section {
    display: flex;
    flex-direction: column;
    gap: 20px;
  }
  
  .form-group {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }
  
  .form-label {
    font-size: 14px;
    font-weight: 600;
    color: #374151;
  }
  
  .form-input,
  .form-select,
  .form-textarea {
    padding: 12px 16px;
    border: 1px solid #d1d5db;
    border-radius: 8px;
    font-size: 16px;
    transition: all 0.2s;
    background: white;
  }
  
  .form-input:focus,
  .form-select:focus,
  .form-textarea:focus {
    outline: none;
    border-color: #667eea;
    box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
  }
  
  .form-input.error,
  .form-select.error,
  .form-textarea.error {
    border-color: #ef4444;
  }
  
  .form-textarea {
    resize: vertical;
    min-height: 100px;
    font-family: inherit;
  }
  
  .char-count {
    text-align: right;
    font-size: 12px;
    color: #9ca3af;
  }
  
  .category-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
    gap: 12px;
  }
  
  .category-card {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 8px;
    padding: 16px 12px;
    border: 2px solid #e5e7eb;
    border-radius: 12px;
    background: white;
    cursor: pointer;
    transition: all 0.2s;
    text-align: center;
  }
  
  .category-card:hover {
    border-color: #667eea;
    transform: translateY(-2px);
    box-shadow: 0 4px 12px rgba(102, 126, 234, 0.15);
  }
  
  .category-card.selected {
    border-color: #667eea;
    background: rgba(102, 126, 234, 0.05);
  }
  
  .category-icon {
    font-size: 24px;
    line-height: 1;
  }
  
  .category-info {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }
  
  .category-label {
    font-size: 14px;
    font-weight: 600;
    color: #374151;
  }
  
  .category-desc {
    font-size: 12px;
    color: #6b7280;
  }
  
  .urgency-options {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(120px, 1fr));
    gap: 12px;
  }
  
  .urgency-card {
    display: flex;
    flex-direction: column;
    gap: 4px;
    padding: 12px;
    border: 2px solid #e5e7eb;
    border-radius: 8px;
    background: white;
    cursor: pointer;
    transition: all 0.2s;
    text-align: center;
  }
  
  .urgency-card.selected {
    border-color: #667eea;
    background: rgba(102, 126, 234, 0.05);
  }
  
  .urgency-card.green.selected { border-color: #10b981; background: rgba(16, 185, 129, 0.05); }
  .urgency-card.blue.selected { border-color: #3b82f6; background: rgba(59, 130, 246, 0.05); }
  .urgency-card.orange.selected { border-color: #f59e0b; background: rgba(245, 158, 11, 0.05); }
  .urgency-card.red.selected { border-color: #ef4444; background: rgba(239, 68, 68, 0.05); }
  
  .urgency-label {
    font-size: 14px;
    font-weight: 600;
    color: #374151;
  }
  
  .urgency-desc {
    font-size: 12px;
    color: #6b7280;
  }
  
  .contact-options {
    display: flex;
    flex-direction: column;
    gap: 12px;
  }
  
  .contact-option {
    display: block;
    cursor: pointer;
  }
  
  .contact-option input[type="radio"] {
    display: none;
  }
  
  .contact-card {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 16px;
    border: 2px solid #e5e7eb;
    border-radius: 12px;
    background: white;
    transition: all 0.2s;
  }
  
  .contact-option input[type="radio"]:checked + .contact-card {
    border-color: #667eea;
    background: rgba(102, 126, 234, 0.05);
  }
  
  .contact-icon {
    font-size: 24px;
    line-height: 1;
  }
  
  .contact-info {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }
  
  .contact-label {
    font-size: 16px;
    font-weight: 600;
    color: #374151;
  }
  
  .contact-desc {
    font-size: 14px;
    color: #6b7280;
  }
  
  .error-message {
    font-size: 14px;
    color: #ef4444;
    display: flex;
    align-items: center;
    gap: 4px;
  }
  
  .modal-footer {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 16px 20px;
    border-top: 1px solid #e5e7eb;
    background: #fafafa;
  }
  
  .prev-button {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 8px 12px;
    background: none;
    color: #6b7280;
    border: 1px solid #d1d5db;
    border-radius: 8px;
    font-weight: 500;
    font-size: 14px;
    cursor: pointer;
    transition: all 0.2s;
  }
  
  .prev-button:hover:not(:disabled) {
    background: #f9fafb;
    color: #374151;
    border-color: #9ca3af;
  }
  
  .footer-spacer {
    flex: 1;
  }
  
  .form-hints {
    text-align: center;
  }
  
  .hint-text {
    margin: 0;
    font-size: 12px;
    color: #6b7280;
    line-height: 1.4;
  }
  
  /* 响应式优化 */
  @media (max-width: 480px) {
    .modal-backdrop {
      padding: 8px;
    }
    
    .modal-container {
      max-height: 95vh;
    }
    
    .header-content {
      padding: 12px 16px;
    }
    
    .modal-content {
      padding: 20px 16px;
    }
    
    .category-grid {
      grid-template-columns: 1fr;
    }
    
    .urgency-options {
      grid-template-columns: repeat(2, 1fr);
    }
    
    .modal-footer {
      padding: 12px 16px;
    }
  }
  
  /* 深色模式适配 */
  @media (prefers-color-scheme: dark) {
    .modal-container {
      background: #1f2937;
    }
    
    .modal-header {
      background: #111827;
      border-bottom-color: #374151;
    }
    
    .modal-title {
      color: #f9fafb;
    }
    
    .modal-subtitle {
      color: #9ca3af;
    }
    
    .close-button {
      color: #9ca3af;
    }
    
    .close-button:hover {
      background: #374151;
      color: #f3f4f6;
    }
    
    .progress-section {
      background: #1f2937;
    }
    
    .step-title {
      color: #f3f4f6;
    }
    
    .form-label {
      color: #f3f4f6;
    }
    
    .form-input,
    .form-select,
    .form-textarea {
      background: #374151;
      border-color: #4b5563;
      color: #f9fafb;
    }
    
    .category-card,
    .urgency-card,
    .contact-card {
      background: #374151;
      border-color: #4b5563;
    }
    
    .category-label,
    .urgency-label,
    .contact-label {
      color: #f3f4f6;
    }
    
    .modal-footer {
      background: #111827;
      border-top-color: #374151;
    }
    
    .prev-button {
      background: #374151;
      border-color: #4b5563;
      color: #d1d5db;
    }
  }
</style> 