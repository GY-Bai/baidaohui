<script>
  import { createEventDispatcher } from 'svelte';
  import Input from '$lib/components/ui/Input.svelte';
  import TextArea from '$lib/components/ui/TextArea.svelte';
  import Select from '$lib/components/ui/Select.svelte';
  import Button from '$lib/components/ui/Button.svelte';
  import Progress from '$lib/components/ui/Progress.svelte';
  
  export let isOpen = false;
  export let initialData = {};
  
  const dispatch = createEventDispatcher();
  
  let currentStep = 1;
  const totalSteps = 3;
  
  // 表单数据
  let formData = {
    title: '',
    category: '',
    description: '',
    urgency: 'normal',
    budget: '',
    expectedTime: '',
    contactMethod: 'chat',
    additionalInfo: '',
    ...initialData
  };
  
  let errors = {};
  let isSubmitting = false;

  // 类别选项
  const categories = [
    { value: 'career', label: '事业运程' },
    { value: 'love', label: '感情婚姻' },
    { value: 'health', label: '健康运势' },
    { value: 'wealth', label: '财运分析' },
    { value: 'study', label: '学业考试' },
    { value: 'family', label: '家庭关系' },
    { value: 'other', label: '其他问题' }
  ];
  
  // 紧急程度选项
  const urgencyOptions = [
    { value: 'low', label: '不急 - 一周内' },
    { value: 'normal', label: '一般 - 3天内' },
    { value: 'high', label: '急需 - 24小时内' }
  ];
  
  // 预算选项
  const budgetOptions = [
    { value: '50-100', label: '¥50-100' },
    { value: '100-200', label: '¥100-200' },
    { value: '200-500', label: '¥200-500' },
    { value: '500+', label: '¥500以上' }
  ];
  
  // 联系方式选项
  const contactMethods = [
    { value: 'chat', label: '站内聊天' },
    { value: 'wechat', label: '微信联系' },
    { value: 'phone', label: '电话联系' }
  ];

  function validateStep(step) {
    errors = {};
    
    switch (step) {
      case 1:
        if (!formData.title.trim()) {
          errors.title = '请输入申请标题';
        }
        if (!formData.category) {
          errors.category = '请选择算命类别';
        }
        if (!formData.description.trim()) {
          errors.description = '请描述您的具体需求';
        } else if (formData.description.length < 20) {
          errors.description = '请详细描述您的需求（至少20字）';
        }
        break;
        
      case 2:
        if (!formData.urgency) {
          errors.urgency = '请选择紧急程度';
        }
        if (!formData.budget) {
          errors.budget = '请选择预算范围';
        }
        break;
        
      case 3:
        if (!formData.contactMethod) {
          errors.contactMethod = '请选择联系方式';
        }
        break;
    }
    
    return Object.keys(errors).length === 0;
  }

  function nextStep() {
    if (validateStep(currentStep)) {
      currentStep++;
    }
  }

  function prevStep() {
    currentStep--;
  }

  async function handleSubmit() {
    if (!validateStep(currentStep)) return;
    
    isSubmitting = true;
    
    try {
      // 模拟提交延迟
      await new Promise(resolve => setTimeout(resolve, 1000));
      
      dispatch('submit', {
        formData,
        success: true
      });
      
      // 重置表单
      currentStep = 1;
      formData = {
        title: '',
        category: '',
        description: '',
        urgency: 'normal',
        budget: '',
        expectedTime: '',
        contactMethod: 'chat',
        additionalInfo: ''
      };
      
    } catch (error) {
      dispatch('submit', {
        formData,
        success: false,
        error: error.message
      });
    } finally {
      isSubmitting = false;
    }
  }

  function handleClose() {
    dispatch('close');
  }
</script>

{#if isOpen}
  <div class="modal-overlay" on:click={handleClose}>
    <div class="modal-content" on:click|stopPropagation>
      <!-- 头部 -->
      <header class="modal-header">
        <div class="header-content">
          <h2 class="modal-title">新建算命申请</h2>
          <p class="modal-subtitle">填写您的需求，获得专业的算命服务</p>
        </div>
        <button class="close-btn" on:click={handleClose}>
          <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
            <path d="M18 6L6 18M6 6L18 18" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
          </svg>
        </button>
      </header>

      <!-- 进度指示器 -->
      <div class="progress-section">
        <Progress 
          value={(currentStep / totalSteps) * 100} 
          size="sm"
          showPercentage={false}
        />
        <div class="step-info">
          <span class="step-text">第 {currentStep} 步，共 {totalSteps} 步</span>
        </div>
      </div>

      <!-- 表单内容 -->
      <form class="form-content" on:submit|preventDefault={handleSubmit}>
        {#if currentStep === 1}
          <div class="step-section">
            <h3 class="step-title">📝 基本信息</h3>
            <p class="step-description">请填写您的算命申请基本信息</p>
            
            <div class="form-group">
              <Input
                label="申请标题"
                placeholder="例如：求测近期事业发展"
                bind:value={formData.title}
                error={errors.title}
                required
              />
            </div>
            
            <div class="form-group">
              <Select
                label="算命类别"
                placeholder="请选择您要咨询的类别"
                options={categories}
                bind:value={formData.category}
                error={errors.category}
                required
              />
            </div>
            
            <div class="form-group">
              <TextArea
                label="详细描述"
                placeholder="请详细描述您的具体情况和想要了解的问题..."
                bind:value={formData.description}
                error={errors.description}
                rows={4}
                maxlength={500}
                showCount={true}
                required
              />
            </div>
          </div>
        {:else if currentStep === 2}
          <div class="step-section">
            <h3 class="step-title">⚡ 需求详情</h3>
            <p class="step-description">请选择您的紧急程度和预算范围</p>
            
            <div class="form-group">
              <Select
                label="紧急程度"
                placeholder="请选择处理时间要求"
                options={urgencyOptions}
                bind:value={formData.urgency}
                error={errors.urgency}
                required
              />
            </div>
            
            <div class="form-group">
              <Select
                label="预算范围"
                placeholder="请选择您的预算范围"
                options={budgetOptions}
                bind:value={formData.budget}
                error={errors.budget}
                required
              />
            </div>
            
            <div class="form-group">
              <Input
                label="期望完成时间（可选）"
                type="datetime-local"
                bind:value={formData.expectedTime}
                help="如有特定时间要求请填写"
              />
            </div>
          </div>
        {:else if currentStep === 3}
          <div class="step-section">
            <h3 class="step-title">📞 联系信息</h3>
            <p class="step-description">请选择您的联系方式</p>
            
            <div class="form-group">
              <Select
                label="联系方式"
                placeholder="请选择首选联系方式"
                options={contactMethods}
                bind:value={formData.contactMethod}
                error={errors.contactMethod}
                required
              />
            </div>
            
            <div class="form-group">
              <TextArea
                label="补充信息（可选）"
                placeholder="如有其他特殊要求或信息，请在这里补充..."
                bind:value={formData.additionalInfo}
                rows={3}
                maxlength={200}
                showCount={true}
              />
            </div>
            
            <!-- 提交前确认 -->
            <div class="confirmation-box">
              <h4 class="confirmation-title">✅ 请确认您的申请信息</h4>
              <div class="confirmation-item">
                <span class="label">标题：</span>
                <span class="value">{formData.title}</span>
              </div>
              <div class="confirmation-item">
                <span class="label">类别：</span>
                <span class="value">{categories.find(c => c.value === formData.category)?.label}</span>
              </div>
              <div class="confirmation-item">
                <span class="label">预算：</span>
                <span class="value">{budgetOptions.find(b => b.value === formData.budget)?.label}</span>
              </div>
              <div class="confirmation-item">
                <span class="label">紧急程度：</span>
                <span class="value">{urgencyOptions.find(u => u.value === formData.urgency)?.label}</span>
              </div>
            </div>
          </div>
        {/if}

        <!-- 操作按钮 -->
        <div class="form-actions">
          {#if currentStep > 1}
            <Button
              variant="outline"
              on:click={prevStep}
              disabled={isSubmitting}
            >
              上一步
            </Button>
          {/if}
          
          <div class="spacer"></div>
          
          {#if currentStep < totalSteps}
            <Button
              variant="primary"
              on:click={nextStep}
            >
              下一步
            </Button>
          {:else}
            <Button
              variant="primary"
              type="submit"
              loading={isSubmitting}
              disabled={isSubmitting}
            >
              {isSubmitting ? '提交中...' : '提交申请'}
            </Button>
          {/if}
        </div>
      </form>
    </div>
  </div>
{/if}

<style>
  .modal-overlay {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.5);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 1000;
    padding: 20px;
  }

  .modal-content {
    background: white;
    border-radius: 20px;
    width: 100%;
    max-width: 480px;
    max-height: 90vh;
    overflow-y: auto;
    box-shadow: 0 20px 40px rgba(0, 0, 0, 0.15);
  }

  /* 头部 */
  .modal-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    padding: 24px 24px 0 24px;
    margin-bottom: 20px;
  }

  .header-content {
    flex: 1;
  }

  .modal-title {
    font-size: 24px;
    font-weight: 700;
    color: #111827;
    margin: 0 0 8px 0;
  }

  .modal-subtitle {
    font-size: 14px;
    color: #6b7280;
    margin: 0;
  }

  .close-btn {
    background: none;
    border: none;
    padding: 8px;
    cursor: pointer;
    color: #6b7280;
    border-radius: 8px;
    transition: all 0.2s ease;
  }

  .close-btn:hover {
    color: #111827;
    background: #f3f4f6;
  }

  /* 进度指示器 */
  .progress-section {
    padding: 0 24px 20px 24px;
  }

  .step-info {
    display: flex;
    justify-content: center;
    margin-top: 8px;
  }

  .step-text {
    font-size: 12px;
    color: #6b7280;
  }

  /* 表单内容 */
  .form-content {
    padding: 0 24px 24px 24px;
  }

  .step-section {
    margin-bottom: 24px;
  }

  .step-title {
    font-size: 18px;
    font-weight: 600;
    color: #111827;
    margin: 0 0 8px 0;
  }

  .step-description {
    font-size: 14px;
    color: #6b7280;
    margin: 0 0 24px 0;
  }

  .form-group {
    margin-bottom: 20px;
  }

  /* 确认框 */
  .confirmation-box {
    background: #f8fafc;
    border: 1px solid #e2e8f0;
    border-radius: 12px;
    padding: 16px;
    margin-top: 20px;
  }

  .confirmation-title {
    font-size: 16px;
    font-weight: 600;
    color: #1e293b;
    margin: 0 0 12px 0;
  }

  .confirmation-item {
    display: flex;
    justify-content: space-between;
    margin-bottom: 8px;
    font-size: 14px;
  }

  .confirmation-item:last-child {
    margin-bottom: 0;
  }

  .confirmation-item .label {
    color: #64748b;
    font-weight: 500;
  }

  .confirmation-item .value {
    color: #1e293b;
    font-weight: 600;
    text-align: right;
    max-width: 60%;
    word-break: break-word;
  }

  /* 操作按钮 */
  .form-actions {
    display: flex;
    gap: 12px;
    margin-top: 32px;
    align-items: center;
  }

  .spacer {
    flex: 1;
  }

  /* 移动端适配 */
  @media (max-width: 640px) {
    .modal-overlay {
      padding: 0;
    }

    .modal-content {
      border-radius: 20px 20px 0 0;
      height: 100vh;
      max-height: none;
      margin-top: auto;
    }

    .modal-header {
      padding: 20px 20px 0 20px;
    }

    .modal-title {
      font-size: 20px;
    }

    .progress-section {
      padding: 0 20px 16px 20px;
    }

    .form-content {
      padding: 0 20px 20px 20px;
    }

    .step-title {
      font-size: 16px;
    }

    .form-actions {
      flex-direction: column-reverse;
      gap: 12px;
      margin-top: 24px;
    }

    .form-actions > :global(button) {
      width: 100%;
    }

    .spacer {
      display: none;
    }
  }
</style> 