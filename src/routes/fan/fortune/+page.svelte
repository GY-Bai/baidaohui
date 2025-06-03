<script lang="ts">
  import { onMount } from 'svelte';
  import Button from '$lib/components/ui/Button.svelte';
  import FortuneRequestItem from '$lib/components/business/FortuneRequestItem.svelte';
  import CreateFortuneModal from '$lib/components/business/CreateFortuneModal.svelte';
  import PaymentChoiceModal from '$lib/components/business/PaymentChoiceModal.svelte';
  import QueuePositionCard from '$lib/components/business/QueuePositionCard.svelte';
  
  // 状态管理
  let showCreateModal = false;
  let showPaymentModal = false;
  let selectedRequest: any = null;
  let paymentAmount = 0;
  let paymentOrderId = '';
  
  // 模拟算命申请数据
  let fortuneRequests = [
    {
      id: 'fr001',
      title: '事业发展咨询',
      category: '事业运程',
      description: '希望了解近期事业发展方向和机遇，目前工作遇到瓶颈，想知道是否应该换工作或者创业',
      status: 'pending',
      urgency: 'high',
      budget: '200-500',
      createdAt: '2024-01-15T10:30:00Z',
      userAvatar: '',
      userName: '张三',
      queuePosition: 3,
      estimatedTime: '2小时',
      orderId: 'ORD20240115001'
    },
    {
      id: 'fr002', 
      title: '感情运势分析',
      category: '感情婚姻',
      description: '想了解感情方面的发展趋势，最近和对象有些摩擦，希望了解未来的走向',
      status: 'processing',
      urgency: 'normal',
      budget: '100-200',
      createdAt: '2024-01-12T14:20:00Z',
      userAvatar: '',
      userName: '李四',
      queuePosition: 1,
      estimatedTime: '30分钟',
      orderId: 'ORD20240112002'
    },
    {
      id: 'fr003',
      title: '财运预测',
      category: '财运分析',
      description: '希望了解投资和理财方向，手上有一笔资金想要投资，但不确定方向',
      status: 'completed',
      urgency: 'low',
      budget: '50-100',
      createdAt: '2024-01-10T09:15:00Z',
      userAvatar: '',
      userName: '王五',
      queuePosition: null,
      estimatedTime: null,
      orderId: 'ORD20240110003'
    }
  ];
  
  // 当前排队的申请（用于显示队列卡片）
  $: currentQueueRequest = fortuneRequests.find(req => req.status === 'pending' || req.status === 'processing');
  
  function handleCreateFortune() {
    selectedRequest = null;
    showCreateModal = true;
  }
  
  function handleFortuneSubmit(event: CustomEvent) {
    const { formData, success } = event.detail;
    
    if (success) {
      if (selectedRequest) {
        // 更新现有申请
        const index = fortuneRequests.findIndex(r => r.id === selectedRequest.id);
        if (index !== -1) {
          fortuneRequests[index] = {
            ...fortuneRequests[index],
            title: formData.title,
            category: formData.category,
            description: formData.description,
            urgency: formData.urgency,
            budget: formData.budget
          };
          fortuneRequests = [...fortuneRequests];
        }
      } else {
        // 创建新申请
        const newRequest = {
          id: `fr${Date.now()}`,
          title: formData.title,
          category: formData.category,
          description: formData.description,
          status: 'pending',
          urgency: formData.urgency,
          budget: formData.budget,
          createdAt: new Date().toISOString(),
          userAvatar: '',
          userName: '当前用户',
          queuePosition: fortuneRequests.filter(r => r.status === 'pending').length + 1,
          estimatedTime: '1小时',
          orderId: `ORD${Date.now()}`
        };
        fortuneRequests = [...fortuneRequests, newRequest];
        
        // 显示支付modal
        paymentAmount = getBudgetAmount(formData.budget);
        paymentOrderId = newRequest.orderId;
        showPaymentModal = true;
      }
    }
    
    showCreateModal = false;
  }
  
  function handleFortuneAction(event: CustomEvent) {
    const { id, action } = event.detail;
    const request = fortuneRequests.find(r => r.id === id);
    
    if (!request) return;
    
    switch (action) {
      case 'edit':
        selectedRequest = request;
        showCreateModal = true;
        break;
      case 'cancel':
        if (confirm('确定要取消这个算命申请吗？')) {
          request.status = 'cancelled';
          fortuneRequests = [...fortuneRequests];
        }
        break;
      case 'view':
        alert('查看算命结果功能开发中...');
        break;
      case 'contact':
        alert('联系大师功能开发中...');
        break;
    }
  }
  
  function handleFortuneClick(event: CustomEvent) {
    const { id } = event.detail;
    const request = fortuneRequests.find(r => r.id === id);
    if (request) {
      alert(`查看申请详情: ${request.title}`);
    }
  }
  
  function handlePayment(event: CustomEvent) {
    const { method, amount, orderId, success } = event.detail;
    
    if (success) {
      alert(`支付成功！支付方式: ${method}, 金额: ¥${amount}`);
      // 更新申请状态
      const request = fortuneRequests.find(r => r.orderId === orderId);
      if (request && request.status === 'pending') {
        request.status = 'processing';
        fortuneRequests = [...fortuneRequests];
      }
    } else {
      alert('支付失败，请重试');
    }
    
    showPaymentModal = false;
  }
  
  function handleQueueRefresh(event: CustomEvent) {
    const { orderId } = event.detail;
    // 模拟刷新队列状态
    const request = fortuneRequests.find(r => r.orderId === orderId);
    if (request && request.queuePosition > 1) {
      request.queuePosition -= 1;
      request.estimatedTime = `${Math.max(15, (request.queuePosition - 1) * 30)}分钟`;
      fortuneRequests = [...fortuneRequests];
    }
  }
  
  function handleQueueCancel(event: CustomEvent) {
    const { orderId } = event.detail;
    if (confirm('确定要取消排队吗？')) {
      const request = fortuneRequests.find(r => r.orderId === orderId);
      if (request) {
        request.status = 'cancelled';
        fortuneRequests = [...fortuneRequests];
      }
    }
  }
  
  function handleQueueContact(event: CustomEvent) {
    const { masterName, orderId } = event.detail;
    alert(`联系${masterName}功能开发中...`);
  }
  
  function getBudgetAmount(budget: string): number {
    const budgetMap = {
      '50-100': 75,
      '100-200': 150,
      '200-500': 350,
      '500+': 800
    };
    return budgetMap[budget] || 100;
  }
  
  function handleCloseModal() {
    showCreateModal = false;
    selectedRequest = null;
  }
  
  function handleClosePaymentModal() {
    showPaymentModal = false;
    paymentAmount = 0;
    paymentOrderId = '';
  }
  
  onMount(() => {
    console.log('算命页面加载完成');
  });
</script>

<svelte:head>
  <title>算命服务 - 百刀会</title>
</svelte:head>

<div class="fortune-view">
  <!-- 页面头部 -->
  <header class="fortune-header">
    <div class="header-content">
      <h1 class="page-title">🔮 算命服务</h1>
      <p class="page-subtitle">专业大师为您解答人生疑惑</p>
    </div>
    <Button 
      variant="primary"
      size="lg"
      on:click={handleCreateFortune}
    >
      ✨ 新建申请
    </Button>
  </header>
  
  <!-- 排队状态卡片 -->
  {#if currentQueueRequest}
    <div class="queue-section">
      <QueuePositionCard
        position={currentQueueRequest.queuePosition}
        totalQueue={10}
        estimatedWaitTime={currentQueueRequest.estimatedTime}
        masterName="慧眼大师"
        masterAvatar=""
        orderId={currentQueueRequest.orderId}
        canCancel={currentQueueRequest.status === 'pending'}
        on:refresh={handleQueueRefresh}
        on:cancel={handleQueueCancel}
        on:contact={handleQueueContact}
      />
    </div>
  {/if}
  
  <!-- 申请列表 -->
  <div class="fortune-content">
    <div class="content-header">
      <h2 class="section-title">我的申请</h2>
      <span class="request-count">{fortuneRequests.length} 个申请</span>
    </div>
    
    {#if fortuneRequests.length === 0}
      <div class="empty-state">
        <div class="empty-icon">🔮</div>
        <h3 class="empty-title">暂无算命申请</h3>
        <p class="empty-description">点击"新建申请"开始您的第一次算命咨询</p>
        <Button variant="primary" size="lg" on:click={handleCreateFortune}>
          立即开始
        </Button>
      </div>
    {:else}
      <div class="request-list">
        {#each fortuneRequests as request (request.id)}
          <FortuneRequestItem
            id={request.id}
            title={request.title}
            category={request.category}
            description={request.description}
            status={request.status}
            urgency={request.urgency}
            budget={request.budget}
            createdAt={request.createdAt}
            userAvatar={request.userAvatar}
            userName={request.userName}
            queuePosition={request.queuePosition}
            estimatedTime={request.estimatedTime}
            on:click={handleFortuneClick}
            on:action={handleFortuneAction}
          />
        {/each}
      </div>
    {/if}
  </div>
</div>

<!-- 新建/编辑申请模态框 -->
<CreateFortuneModal
  isOpen={showCreateModal}
  initialData={selectedRequest}
  on:submit={handleFortuneSubmit}
  on:close={handleCloseModal}
/>

<!-- 支付选择模态框 -->
<PaymentChoiceModal
  isOpen={showPaymentModal}
  amount={paymentAmount}
  title="完成算命申请支付"
  description="选择支付方式完成您的算命申请"
  orderId={paymentOrderId}
  on:pay={handlePayment}
  on:close={handleClosePaymentModal}
/>

<style>
  .fortune-view {
    padding: 20px;
    max-width: 800px;
    margin: 0 auto;
    min-height: 100vh;
    background: #f8fafc;
  }
  
  /* 页面头部 */
  .fortune-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-end;
    margin-bottom: 32px;
    padding: 24px;
    background: white;
    border-radius: 20px;
    box-shadow: 0 4px 20px rgba(0, 0, 0, 0.08);
  }
  
  .header-content {
    flex: 1;
  }
  
  .page-title {
    font-size: 28px;
    font-weight: 700;
    color: #111827;
    margin: 0 0 8px 0;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
  }
  
  .page-subtitle {
    font-size: 16px;
    color: #6b7280;
    margin: 0;
  }
  
  /* 排队状态部分 */
  .queue-section {
    margin-bottom: 24px;
  }
  
  /* 内容区域 */
  .fortune-content {
    background: white;
    border-radius: 20px;
    padding: 24px;
    box-shadow: 0 4px 20px rgba(0, 0, 0, 0.08);
  }
  
  .content-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 24px;
    padding-bottom: 16px;
    border-bottom: 1px solid #e5e7eb;
  }
  
  .section-title {
    font-size: 20px;
    font-weight: 600;
    color: #111827;
    margin: 0;
  }
  
  .request-count {
    font-size: 14px;
    color: #6b7280;
    background: #f3f4f6;
    padding: 4px 12px;
    border-radius: 12px;
  }
  
  /* 空状态 */
  .empty-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 60px 20px;
    text-align: center;
  }
  
  .empty-icon {
    font-size: 64px;
    margin-bottom: 24px;
    opacity: 0.5;
  }
  
  .empty-title {
    font-size: 24px;
    font-weight: 600;
    color: #111827;
    margin: 0 0 12px 0;
  }
  
  .empty-description {
    font-size: 16px;
    color: #6b7280;
    margin: 0 0 32px 0;
    max-width: 400px;
    line-height: 1.5;
  }
  
  /* 申请列表 */
  .request-list {
    display: flex;
    flex-direction: column;
    gap: 16px;
  }
  
  /* 移动端适配 */
  @media (max-width: 640px) {
    .fortune-view {
      padding: 12px;
    }
    
    .fortune-header {
      flex-direction: column;
      gap: 16px;
      align-items: stretch;
      padding: 20px;
      margin-bottom: 20px;
    }
    
    .page-title {
      font-size: 24px;
    }
    
    .page-subtitle {
      font-size: 14px;
    }
    
    .fortune-content {
      padding: 20px;
      border-radius: 16px;
    }
    
    .content-header {
      flex-direction: column;
      gap: 8px;
      align-items: flex-start;
    }
    
    .section-title {
      font-size: 18px;
    }
    
    .empty-state {
      padding: 40px 16px;
    }
    
    .empty-icon {
      font-size: 48px;
    }
    
    .empty-title {
      font-size: 20px;
    }
    
    .empty-description {
      font-size: 14px;
    }
    
    .request-list {
      gap: 12px;
    }
  }
</style> 