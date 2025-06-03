<script lang="ts">
  import { onMount } from 'svelte';
  import Button from '$lib/components/ui/Button.svelte';
  import Input from '$lib/components/ui/Input.svelte';
  import Select from '$lib/components/ui/Select.svelte';
  import TextArea from '$lib/components/ui/TextArea.svelte';
  import Switch from '$lib/components/ui/Switch.svelte';
  import Modal from '$lib/components/ui/Modal.svelte';
  import ProductCard from '$lib/components/ui/ProductCard.svelte';
  import BottomDock from '$lib/components/ui/BottomDock.svelte';
  import TabNavigation from '$lib/components/ui/TabNavigation.svelte';
  import Checkbox from '$lib/components/ui/Checkbox.svelte';
  import Radio from '$lib/components/ui/Radio.svelte';
  import Badge from '$lib/components/ui/Badge.svelte';
  import Avatar from '$lib/components/ui/Avatar.svelte';
  import Loading from '$lib/components/ui/Loading.svelte';
  import Card from '$lib/components/ui/Card.svelte';
  import Skeleton from '$lib/components/ui/Skeleton.svelte';
  import DataTable from '$lib/components/ui/DataTable.svelte';
  import Pagination from '$lib/components/ui/Pagination.svelte';
  import Toast from '$lib/components/ui/Toast.svelte';
  import Alert from '$lib/components/ui/Alert.svelte';
  import Progress from '$lib/components/ui/Progress.svelte';
  import Tooltip from '$lib/components/ui/Tooltip.svelte';

  // 状态管理
  let showModal = false;
  let showProductModal = false;
  let activeDockItem = 'components';
  let activeTab = 'buttons';
  
  // 表单数据
  let inputValue = '';
  let emailValue = '';
  let passwordValue = '';
  let searchValue = '';
  let textareaValue = '';
  let selectValue = '';
  let currencyValue = '';
  let switchValue = false;
  let notificationSwitch = true;
  let premiumSwitch = false;
  
  // 新增表单状态
  let checkboxValue = false;
  let checkboxIndeterminate = false;
  let radioValue = '';
  let loadingDemo = false;
  
  // 新增演示状态
  let tableData = [];
  let tableLoading = false;
  let selectedTableRows = [];
  let currentPage = 1;
  let totalPages = 10;
  let progressValue = 65;
  let showToast = false;
  let showAlert = true;
  
  // 错误状态演示
  let inputError = '';
  let emailError = '';

  // Select选项
  const countryOptions = [
    { value: 'cn', label: '中国' },
    { value: 'us', label: '美国' },
    { value: 'ca', label: '加拿大' },
    { value: 'au', label: '澳大利亚' },
    { value: 'sg', label: '新加坡' }
  ];

  const currencyOptions = [
    { value: 'CNY', label: '人民币 (¥)', group: '亚洲' },
    { value: 'USD', label: '美元 ($)', group: '美洲' },
    { value: 'CAD', label: '加元 (C$)', group: '美洲' },
    { value: 'AUD', label: '澳元 (A$)', group: '大洋洲' },
    { value: 'SGD', label: '新加坡元 (S$)', group: '亚洲' },
    { value: 'EUR', label: '欧元 (€)', group: '欧洲' },
    { value: 'GBP', label: '英镑 (£)', group: '欧洲' }
  ];

  // Dock 配置
  const dockItems = [
    { 
      id: 'components', 
      label: '组件展示', 
      icon: '🧩',
      activeIcon: '✨',
      description: '查看所有UI组件'
    },
    { 
      id: 'forms', 
      label: '表单元素', 
      icon: '📝',
      activeIcon: '📋',
      description: '输入框和表单组件'
    },
    { 
      id: 'products', 
      label: '商品卡片', 
      icon: '🛍️',
      activeIcon: '🛒',
      description: '电商商品展示'
    },
    { 
      id: 'modals', 
      label: '弹窗组件', 
      icon: '🔲',
      activeIcon: '📱',
      description: '模态框和弹窗'
    }
  ];

  // 标签配置
  const tabs = [
    { id: 'buttons', label: '按钮', icon: '🔘' },
    { id: 'inputs', label: '输入框', icon: '📝' },
    { id: 'forms', label: '表单组件', icon: '📋' },
    { id: 'navigation', label: '导航', icon: '🧭' },
    { id: 'feedback', label: '反馈', icon: '💬' }
  ];

  // 模拟商品数据
  const sampleProducts = [
    {
      id: '1',
      title: 'Instagram风格手机壳 - 简约时尚设计',
      description: '高品质硅胶材质，完美保护您的手机，同时保持时尚外观。',
      price: 29.99,
      originalPrice: 39.99,
      currency: 'USD',
      images: [
        'https://images.unsplash.com/photo-1556656793-08538906a9f8?ixlib=rb-4.0.3&w=400',
        'https://images.unsplash.com/photo-1556656793-08538906a9f8?ixlib=rb-4.0.3&w=400'
      ],
      store: {
        name: '时尚数码',
        badge: '推荐'
      }
    },
    {
      id: '2',
      title: '北欧简约台灯',
      description: '现代简约设计，适合办公室和家庭使用。',
      price: 89.99,
      currency: 'USD',
      images: [
        'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?ixlib=rb-4.0.3&w=400'
      ],
      store: {
        name: '家居生活',
        badge: '热卖'
      }
    }
  ];

  // 按钮事件处理
  function handleButtonClick(type: string) {
    console.log(`${type} 按钮被点击`);
  }

  function handleModalOpen() {
    showModal = true;
  }

  function handleModalClose() {
    showModal = false;
  }

  function handleDockChange(event: CustomEvent) {
    activeDockItem = event.detail.id;
  }

  function handleTabChange(event: CustomEvent) {
    activeTab = event.detail.activeTab;
  }

  function handleProductClick(event: CustomEvent) {
    console.log('商品被点击:', event.detail.product);
    showProductModal = true;
  }

  function handleProductPurchase(event: CustomEvent) {
    console.log('购买商品:', event.detail.product);
    alert(`准备购买: ${event.detail.product.title}`);
  }

  function handleProductFavorite(event: CustomEvent) {
    console.log('收藏商品:', event.detail.product);
    alert(`已收藏: ${event.detail.product.title}`);
  }

  // 表单验证
  function validateInput() {
    if (inputValue.length < 3) {
      inputError = '至少输入3个字符';
    } else {
      inputError = '';
    }
  }

  function validateEmail() {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(emailValue)) {
      emailError = '请输入有效的邮箱地址';
    } else {
      emailError = '';
    }
  }

  // 新增事件处理
  function handleSelectChange(event: CustomEvent) {
    console.log('Select changed:', event.detail);
  }

  function handleSwitchChange(event: CustomEvent) {
    console.log('Switch changed:', event.detail);
  }

  function handleCheckboxChange(event: CustomEvent) {
    console.log('Checkbox changed:', event.detail);
  }

  // 全屏加载演示
  function startLoadingDemo() {
    loadingDemo = true;
    setTimeout(() => {
      loadingDemo = false;
    }, 3000);
  }

  onMount(() => {
    console.log('组件架构演示页面加载完成');
  });
</script>

<svelte:head>
  <title>组件架构演示 - 百道慧</title>
</svelte:head>

<div class="architecture-demo">
  <!-- 页面头部 -->
  <header class="demo-header">
    <h1 class="demo-title">🏗️ 组件架构演示</h1>
    <p class="demo-subtitle">基于Instagram风格的现代化移动端组件库</p>
  </header>

  <!-- 二级导航 -->
  <div class="demo-navigation">
    <TabNavigation 
      {tabs}
      {activeTab}
      variant="pills"
      size="md"
      on:change={handleTabChange}
    />
  </div>

  <!-- 主要内容区域 -->
  <main class="demo-content">
    
    <!-- 按钮组件展示 -->
    {#if activeTab === 'buttons'}
      <section class="demo-section">
        <h2 class="section-title">按钮组件变体</h2>
        
        <div class="component-showcase">
          <h3>基础按钮</h3>
          <div class="button-grid">
            <Button 
              variant="primary" 
              on:click={() => handleButtonClick('Primary')}
            >
              主要按钮
            </Button>
            
            <Button 
              variant="secondary" 
              on:click={() => handleButtonClick('Secondary')}
            >
              次要按钮
            </Button>
            
            <Button 
              variant="text" 
              on:click={() => handleButtonClick('Text')}
            >
              文字按钮
            </Button>
            
            <Button 
              variant="danger" 
              on:click={() => handleButtonClick('Danger')}
            >
              危险操作
            </Button>
          </div>
        </div>

        <div class="component-showcase">
          <h3>尺寸变体</h3>
          <div class="button-grid">
            <Button size="sm" variant="primary">小号按钮</Button>
            <Button size="md" variant="primary">中号按钮</Button>
            <Button size="lg" variant="primary">大号按钮</Button>
          </div>
        </div>

        <div class="component-showcase">
          <h3>状态演示</h3>
          <div class="button-grid">
            <Button 
              variant="primary" 
              icon="📧" 
              iconPosition="left"
            >
              带图标
            </Button>
            
            <Button 
              variant="primary" 
              loading={true}
              disabled={false}
            >
              加载中
            </Button>
            
            <Button 
              variant="primary" 
              disabled={true}
            >
              禁用状态
            </Button>
            
            <Button 
              variant="primary" 
              fullWidth={true}
            >
              全宽按钮
            </Button>
          </div>
        </div>
      </section>
    {/if}

    <!-- 输入框组件展示 -->
    {#if activeTab === 'inputs'}
      <section class="demo-section">
        <h2 class="section-title">输入框组件</h2>
        
        <div class="form-showcase">
          <div class="form-row">
            <Input
              id="demo-input"
              label="用户名"
              placeholder="请输入用户名"
              bind:value={inputValue}
              error={inputError}
              hint="至少3个字符"
              required
              on:blur={validateInput}
            />
          </div>

          <div class="form-row">
            <Input
              id="demo-email"
              type="email"
              label="邮箱地址"
              placeholder="example@domain.com"
              bind:value={emailValue}
              error={emailError}
              leftIcon="📧"
              required
              on:blur={validateEmail}
            />
          </div>

          <div class="form-row">
            <Input
              id="demo-password"
              type="password"
              label="密码"
              placeholder="请输入密码"
              bind:value={passwordValue}
              leftIcon="🔒"
              hint="密码将被安全加密"
            />
          </div>

          <div class="form-row">
            <Input
              id="demo-search"
              type="search"
              placeholder="搜索商品..."
              bind:value={searchValue}
              leftIcon="🔍"
              variant="filled"
              size="lg"
            />
          </div>

          <div class="form-row">
            <Input
              id="demo-counter"
              label="商品描述"
              placeholder="请描述您的商品..."
              maxlength={100}
              showCounter={true}
              hint="简洁明了的描述有助于销售"
            />
          </div>
        </div>
      </section>
    {/if}

    <!-- 表单组件展示 -->
    {#if activeTab === 'forms'}
      <section class="demo-section">
        <h2 class="section-title">表单组件</h2>
        
        <div class="component-showcase">
          <h3>下拉选择器</h3>
          <div class="form-grid">
            <Select
              id="country-select"
              label="选择国家"
              placeholder="请选择国家"
              options={countryOptions}
              bind:value={selectValue}
              clearable
              hint="选择您所在的国家"
              on:change={handleSelectChange}
            />
            
            <Select
              id="currency-select"
              label="货币类型"
              placeholder="搜索货币..."
              options={currencyOptions}
              bind:value={currencyValue}
              searchable
              clearable
              size="lg"
              variant="filled"
              on:change={handleSelectChange}
            />
          </div>
        </div>

        <div class="component-showcase">
          <h3>多行文本框</h3>
          <div class="form-grid">
            <TextArea
              id="description"
              label="商品描述"
              placeholder="请详细描述您的商品..."
              bind:value={textareaValue}
              rows={4}
              maxlength={500}
              showCounter
              hint="详细的描述有助于商品销售"
            />
            
            <TextArea
              id="auto-resize"
              label="自动高度调整"
              placeholder="输入内容试试自动调整高度..."
              autoResize
              variant="outlined"
              size="sm"
            />
          </div>
        </div>

        <div class="component-showcase">
          <h3>开关切换器</h3>
          <div class="form-grid">
            <Switch
              id="notifications"
              label="推送通知"
              description="接收重要消息和更新通知"
              bind:checked={notificationSwitch}
              on:change={handleSwitchChange}
            />
            
            <Switch
              id="premium"
              label="高级功能"
              description="启用高级算命功能和专属服务"
              bind:checked={premiumSwitch}
              variant="success"
              size="lg"
              on:change={handleSwitchChange}
            />
            
            <Switch
              id="switch-left"
              label="左侧标签"
              description="标签在开关左侧的样式"
              labelPosition="left"
              bind:checked={switchValue}
              variant="warning"
              on:change={handleSwitchChange}
            />
          </div>
        </div>

        <div class="component-showcase">
          <h3>完整表单示例</h3>
          <form class="demo-form">
            <div class="form-row">
              <Input
                id="form-name"
                label="姓名"
                placeholder="请输入您的姓名"
                required
                leftIcon="👤"
              />
            </div>
            
            <div class="form-row">
              <Select
                id="form-country"
                label="国家/地区"
                options={countryOptions}
                required
                placeholder="选择国家"
              />
            </div>
            
            <div class="form-row">
              <TextArea
                id="form-message"
                label="留言"
                placeholder="请留下您的问题或建议..."
                rows={3}
                maxlength={200}
                showCounter
              />
            </div>
            
            <div class="form-row">
              <Switch
                id="form-agreement"
                label="同意服务条款"
                description="我已阅读并同意服务条款和隐私政策"
                required
              />
            </div>
            
            <div class="form-actions">
              <Button variant="secondary" size="lg">
                重置
              </Button>
              <Button variant="primary" size="lg" fullWidth>
                提交表单
              </Button>
            </div>
          </form>
        </div>

        <div class="component-showcase">
          <h3>复选框组件</h3>
          <div class="form-grid">
            <Checkbox
              id="checkbox-basic"
              label="基础复选框"
              description="这是一个基础的复选框示例"
              bind:checked={checkboxValue}
              on:change={handleCheckboxChange}
            />
            
            <Checkbox
              id="checkbox-indeterminate"
              label="半选中状态"
              description="展示半选中的中间状态"
              bind:indeterminate={checkboxIndeterminate}
              variant="success"
              size="lg"
              on:change={handleCheckboxChange}
            />
            
            <Checkbox
              id="checkbox-required"
              label="必填选项"
              description="带有必填标记的复选框"
              required
              variant="danger"
              removable
              on:change={handleCheckboxChange}
            />
          </div>
        </div>

        <div class="component-showcase">
          <h3>单选按钮组</h3>
          <div class="form-grid">
            <div class="radio-group">
              <h4>选择您的偏好</h4>
              <Radio
                id="radio-1"
                name="preference"
                value="option1"
                label="选项一"
                description="这是第一个选项的描述"
                checked={radioValue === 'option1'}
                on:change={() => radioValue = 'option1'}
              />
              <Radio
                id="radio-2"
                name="preference"
                value="option2"
                label="选项二"
                description="这是第二个选项的描述"
                variant="success"
                checked={radioValue === 'option2'}
                on:change={() => radioValue = 'option2'}
              />
              <Radio
                id="radio-3"
                name="preference"
                value="option3"
                label="选项三"
                description="这是第三个选项的描述"
                variant="warning"
                size="lg"
                checked={radioValue === 'option3'}
                on:change={() => radioValue = 'option3'}
              />
            </div>
          </div>
        </div>

        <div class="component-showcase">
          <h3>徽章组件</h3>
          <div class="badge-showcase">
            <h4>基础徽章</h4>
            <div class="badge-grid">
              <Badge variant="default">默认</Badge>
              <Badge variant="primary">主要</Badge>
              <Badge variant="success">成功</Badge>
              <Badge variant="warning">警告</Badge>
              <Badge variant="danger">危险</Badge>
              <Badge variant="info">信息</Badge>
            </div>
            
            <h4>不同尺寸</h4>
            <div class="badge-grid">
              <Badge size="sm">小号</Badge>
              <Badge size="md">中号</Badge>
              <Badge size="lg">大号</Badge>
            </div>
            
            <h4>特殊样式</h4>
            <div class="badge-grid">
              <Badge pill>药丸形状</Badge>
              <Badge outlined variant="primary">描边样式</Badge>
              <Badge icon="🔥" variant="danger">带图标</Badge>
              <Badge count={5} variant="warning" />
              <Badge count={99} variant="success" />
              <Badge count={999} maxCount={99} variant="info" />
              <Badge dot pulse variant="danger" />
              <Badge removable variant="secondary" on:remove={() => alert('徽章被移除')}>可移除</Badge>
            </div>
          </div>
        </div>

        <div class="component-showcase">
          <h3>头像组件</h3>
          <div class="avatar-showcase">
            <h4>不同尺寸</h4>
            <div class="avatar-grid">
              <Avatar size="xs" fallback="小" />
              <Avatar size="sm" fallback="中小" />
              <Avatar size="md" fallback="中等" />
              <Avatar size="lg" fallback="大" />
              <Avatar size="xl" fallback="特大" />
              <Avatar size="2xl" fallback="超大" />
            </div>
            
            <h4>不同形状</h4>
            <div class="avatar-grid">
              <Avatar shape="circle" fallback="圆形" />
              <Avatar shape="square" fallback="方形" />
              <Avatar shape="rounded" fallback="圆角" />
            </div>
            
            <h4>在线状态</h4>
            <div class="avatar-grid">
              <Avatar fallback="在线" online={true} bordered />
              <Avatar fallback="离线" online={false} bordered />
              <Avatar fallback="可点击" clickable bordered on:click={() => alert('头像被点击')} />
              <Avatar loading placeholder />
            </div>
          </div>
        </div>

        <div class="component-showcase">
          <h3>加载指示器</h3>
          <div class="loading-showcase">
            <h4>不同类型</h4>
            <div class="loading-grid">
              <div class="loading-item">
                <Loading type="spinner" />
                <span>旋转器</span>
              </div>
              <div class="loading-item">
                <Loading type="dots" color="success" />
                <span>点状</span>
              </div>
              <div class="loading-item">
                <Loading type="pulse" color="warning" />
                <span>脉冲</span>
              </div>
              <div class="loading-item">
                <Loading type="bars" color="danger" />
                <span>条状</span>
              </div>
              <div class="loading-item">
                <Loading type="ring" color="info" />
                <span>环形</span>
              </div>
            </div>
            
            <h4>不同尺寸</h4>
            <div class="loading-grid">
              <Loading size="sm" text="小号" />
              <Loading size="md" text="中号" />
              <Loading size="lg" text="大号" />
              <Loading size="xl" text="特大" />
            </div>
            
            <div class="loading-actions">
              <Button 
                variant="primary" 
                on:click={startLoadingDemo}
                disabled={loadingDemo}
              >
                {loadingDemo ? '加载中...' : '演示全屏加载'}
              </Button>
            </div>
          </div>
        </div>

        <div class="component-showcase">
          <h3>卡片组件</h3>
          <div class="card-showcase">
            <div class="card-grid">
              <Card variant="default" header="默认卡片">
                <p>这是一个默认样式的卡片组件，适用于大多数场景。</p>
              </Card>
              
              <Card variant="elevated" clickable hoverable>
                <div slot="header">
                  <div style="display: flex; align-items: center; gap: 8px;">
                    <Avatar size="sm" fallback="用户" />
                    <span>可点击卡片</span>
                  </div>
                </div>
                <p>这是一个带有阴影和悬停效果的卡片。</p>
                <div slot="actions">
                  <Button variant="text" size="sm">取消</Button>
                  <Button variant="primary" size="sm">确认</Button>
                </div>
              </Card>
              
              <Card variant="gradient" size="lg">
                <div slot="header">
                  <h4 style="color: white; margin: 0;">渐变卡片</h4>
                </div>
                <p>这是一个带有渐变背景的卡片组件。</p>
                <div slot="footer">
                  <p style="margin: 0; font-size: 12px;">特殊样式</p>
                </div>
              </Card>
            </div>
          </div>
        </div>

        <div class="component-showcase">
          <h3>骨架屏组件</h3>
          <div class="skeleton-showcase">
            <h4>不同类型</h4>
            <div class="skeleton-grid">
              <div class="skeleton-item">
                <Skeleton variant="text" lines={3} />
                <span>文本骨架</span>
              </div>
              <div class="skeleton-item">
                <Skeleton variant="avatar" />
                <span>头像骨架</span>
              </div>
              <div class="skeleton-item">
                <Skeleton variant="rectangle" width="200px" height="120px" />
                <span>矩形骨架</span>
              </div>
              <div class="skeleton-item">
                <Skeleton variant="card" />
                <span>卡片骨架</span>
              </div>
            </div>
            
            <h4>不同动画</h4>
            <div class="skeleton-grid">
              <Skeleton variant="text" animation="pulse" />
              <Skeleton variant="text" animation="wave" />
              <Skeleton variant="text" animation="none" />
            </div>
          </div>
        </div>

        <div class="component-showcase">
          <h3>数据表格组件</h3>
          <div class="table-showcase">
            <DataTable
              data={[
                { id: 1, name: '张三', email: 'zhang@example.com', status: 'active', role: '管理员' },
                { id: 2, name: '李四', email: 'li@example.com', status: 'inactive', role: '用户' },
                { id: 3, name: '王五', email: 'wang@example.com', status: 'active', role: '编辑' }
              ]}
              columns={[
                { key: 'id', title: 'ID', width: '80px', sortable: true },
                { key: 'name', title: '姓名', sortable: true },
                { key: 'email', title: '邮箱' },
                { 
                  key: 'status', 
                  title: '状态', 
                  render: (value) => value === 'active' 
                    ? '<span style="color: #10b981;">●</span> 活跃' 
                    : '<span style="color: #ef4444;">●</span> 非活跃'
                },
                { key: 'role', title: '角色' }
              ]}
              selectable
              hoverable
              bind:selectedRows={selectedTableRows}
              on:sort={(e) => console.log('排序:', e.detail)}
              on:row-click={(e) => console.log('行点击:', e.detail.row)}
            />
            
            <div style="margin-top: 16px;">
              <Pagination
                {currentPage}
                {totalPages}
                totalItems={156}
                pageSize={10}
                showQuickJumper
                on:page-change={(e) => currentPage = e.detail.page}
                on:page-size-change={(e) => console.log('页大小变更:', e.detail)}
              />
            </div>
          </div>
        </div>

        <div class="component-showcase">
          <h3>进度条组件</h3>
          <div class="progress-showcase">
            <h4>基础进度条</h4>
            <div class="progress-grid">
              <Progress value={progressValue} label="下载进度" />
              <Progress value={85} variant="success" label="成功率" />
              <Progress value={45} variant="warning" label="警告阈值" striped animated />
              <Progress value={20} variant="danger" label="错误率" />
            </div>
            
            <h4>特殊效果</h4>
            <div class="progress-grid">
              <Progress value={progressValue} variant="gradient" animated label="渐变进度" />
              <Progress indeterminate variant="default" label="加载中..." />
              <Progress value={90} size="lg" label="大尺寸" showPercentage={false} />
            </div>
            
            <div class="progress-controls">
              <Button 
                variant="text" 
                size="sm"
                on:click={() => progressValue = Math.max(0, progressValue - 10)}
              >
                -10%
              </Button>
              <Button 
                variant="text" 
                size="sm"
                on:click={() => progressValue = Math.min(100, progressValue + 10)}
              >
                +10%
              </Button>
            </div>
          </div>
        </div>

        <div class="component-showcase">
          <h3>提醒组件</h3>
          <div class="alert-showcase">
            <h4>不同类型</h4>
            <div class="alert-grid">
              <Alert 
                type="info" 
                title="信息提示" 
                message="这是一个信息提醒，用于向用户展示普通信息。"
                closable
              />
              <Alert 
                type="success" 
                title="操作成功" 
                message="您的操作已成功完成。"
                variant="soft"
              />
              <Alert 
                type="warning" 
                title="注意事项" 
                message="请注意这个重要的警告信息。"
                variant="outlined"
              />
              <Alert 
                type="error" 
                title="错误提示" 
                message="操作失败，请检查输入信息。"
                variant="filled"
                actions={[
                  { label: '重试', variant: 'primary', handler: () => alert('重试') },
                  { label: '取消', variant: 'text', handler: () => {} }
                ]}
              />
            </div>
          </div>
        </div>

        <div class="component-showcase">
          <h3>工具提示组件</h3>
          <div class="tooltip-showcase">
            <h4>不同位置</h4>
            <div class="tooltip-grid">
              <Tooltip content="顶部提示信息" position="top">
                <Button variant="secondary">顶部</Button>
              </Tooltip>
              <Tooltip content="底部提示信息" position="bottom">
                <Button variant="secondary">底部</Button>
              </Tooltip>
              <Tooltip content="左侧提示信息" position="left">
                <Button variant="secondary">左侧</Button>
              </Tooltip>
              <Tooltip content="右侧提示信息" position="right">
                <Button variant="secondary">右侧</Button>
              </Tooltip>
            </div>
            
            <h4>不同触发方式</h4>
            <div class="tooltip-grid">
              <Tooltip content="悬停显示提示" trigger="hover">
                <Button variant="text">悬停</Button>
              </Tooltip>
              <Tooltip content="点击显示提示" trigger="click">
                <Button variant="text">点击</Button>
              </Tooltip>
              <Tooltip content="聚焦显示提示" trigger="focus">
                <Button variant="text">聚焦</Button>
              </Tooltip>
            </div>
          </div>
        </div>

        <div class="component-showcase">
          <h3>Toast消息提示</h3>
          <div class="toast-showcase">
            <div class="toast-controls">
              <Button 
                variant="primary" 
                size="sm"
                on:click={() => showToast = true}
              >
                显示Toast
              </Button>
            </div>
          </div>
        </div>
      </section>
    {/if}

    <!-- 导航组件展示 -->
    {#if activeTab === 'navigation'}
      <section class="demo-section">
        <h2 class="section-title">导航组件</h2>
        
        <div class="component-showcase">
          <h3>标签导航 - Default 样式</h3>
          <TabNavigation 
            tabs={[
              { id: 'home', label: '首页', icon: '🏠' },
              { id: 'explore', label: '发现', icon: '🔍', count: 5 },
              { id: 'notifications', label: '通知', icon: '🔔', count: 12 },
              { id: 'profile', label: '我的', icon: '👤' }
            ]}
            activeTab="explore"
            variant="default"
          />
        </div>

        <div class="component-showcase">
          <h3>标签导航 - Pills 样式</h3>
          <TabNavigation 
            tabs={[
              { id: 'all', label: '全部' },
              { id: 'pending', label: '待处理', count: 3 },
              { id: 'completed', label: '已完成' },
              { id: 'archived', label: '已归档' }
            ]}
            activeTab="pending"
            variant="pills"
            size="sm"
          />
        </div>

        <div class="component-showcase">
          <h3>标签导航 - Minimal 样式</h3>
          <TabNavigation 
            tabs={[
              { id: 'overview', label: '概览' },
              { id: 'analytics', label: '分析' },
              { id: 'settings', label: '设置', disabled: true }
            ]}
            activeTab="overview"
            variant="minimal"
          />
        </div>
      </section>
    {/if}

    <!-- 反馈组件展示 -->
    {#if activeTab === 'feedback'}
      <section class="demo-section">
        <h2 class="section-title">反馈组件</h2>
        
        <div class="component-showcase">
          <h3>模态框组件</h3>
          <div class="button-grid">
            <Button variant="primary" on:click={handleModalOpen}>
              打开基础模态框
            </Button>
            
            <Button variant="secondary" on:click={() => showProductModal = true}>
              商品详情模态框
            </Button>
          </div>
        </div>

        <div class="component-showcase">
          <h3>商品卡片组件</h3>
          <div class="product-grid">
            {#each sampleProducts as product}
              <ProductCard 
                {product}
                layout="grid"
                showBadge={true}
                showDescription={true}
                on:click={handleProductClick}
                on:purchase={handleProductPurchase}
                on:favorite={handleProductFavorite}
              />
            {/each}
          </div>
        </div>
      </section>
    {/if}

  </main>

  <!-- 底部导航 -->
  <BottomDock 
    items={dockItems}
    activeId={activeDockItem}
    theme="default"
    on:change={handleDockChange}
  />

  <!-- 全屏加载演示 -->
  {#if loadingDemo}
    <Loading 
      fullscreen 
      type="spinner" 
      text="正在加载组件演示..." 
      size="lg" 
    />
  {/if}

  <!-- 模态框演示 -->
  <Modal
    isOpen={showModal}
    title="组件演示"
    subtitle="这是一个基础模态框组件"
    size="md"
    on:close={handleModalClose}
  >
    <div class="modal-demo-content">
      <p>这个模态框展示了以下特性：</p>
      <ul>
        <li>✨ 平滑的动画效果</li>
        <li>🎯 焦点陷阱和键盘导航</li>
        <li>📱 移动端优化的响应式设计</li>
        <li>🎨 Instagram风格的视觉设计</li>
        <li>♿ 完整的无障碍支持</li>
      </ul>
      
      <div class="modal-actions">
        <Button variant="secondary" on:click={handleModalClose}>
          取消
        </Button>
        <Button variant="primary" on:click={handleModalClose}>
          确认
        </Button>
      </div>
    </div>
    
    <div slot="footer">
      <Button variant="text" size="sm">
        帮助文档
      </Button>
    </div>
  </Modal>

  <!-- 商品详情模态框 -->
  <Modal
    isOpen={showProductModal}
    title="商品详情"
    size="lg"
    variant="drawer"
    on:close={() => showProductModal = false}
  >
    <div class="product-detail-content">
      {#if sampleProducts[0]}
        <div class="product-detail-image">
          <img 
            src={sampleProducts[0].images[0]} 
            alt={sampleProducts[0].title}
            class="detail-image"
          />
        </div>
        
        <div class="product-detail-info">
          <h3>{sampleProducts[0].title}</h3>
          <p>{sampleProducts[0].description}</p>
          
          <div class="price-section">
            <span class="current-price">${sampleProducts[0].price}</span>
            {#if sampleProducts[0].originalPrice}
              <span class="original-price">${sampleProducts[0].originalPrice}</span>
            {/if}
          </div>
          
          <div class="store-section">
            <span class="store-label">商店：</span>
            <span class="store-name">{sampleProducts[0].store.name}</span>
          </div>
        </div>
      {/if}
    </div>
    
    <div slot="footer">
      <Button variant="secondary" fullWidth on:click={() => showProductModal = false}>
        关闭
      </Button>
      <Button variant="primary" fullWidth icon="🛒">
        立即购买
      </Button>
    </div>
  </Modal>

  {#if showToast}
    <Toast
      type="success"
      title="操作成功"
      message="您的设置已保存"
      bind:visible={showToast}
      duration={3000}
      action="撤销"
      on:action={() => alert('撤销操作')}
    />
  {/if}
</div>

<style>
  .architecture-demo {
    min-height: 100vh;
    background: #fafafa;
    padding-bottom: 80px; /* 为底部dock栏留空间 */
  }

  .demo-header {
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    color: white;
    padding: 32px 20px;
    text-align: center;
  }

  .demo-title {
    margin: 0 0 8px 0;
    font-size: 28px;
    font-weight: 700;
  }

  .demo-subtitle {
    margin: 0;
    font-size: 16px;
    opacity: 0.9;
  }

  .demo-navigation {
    background: white;
    padding: 16px 20px;
    border-bottom: 1px solid #e5e7eb;
    position: sticky;
    top: 0;
    z-index: 100;
  }

  .demo-content {
    max-width: 800px;
    margin: 0 auto;
    padding: 24px 20px;
  }

  .demo-section {
    margin-bottom: 40px;
  }

  .section-title {
    margin: 0 0 24px 0;
    font-size: 24px;
    font-weight: 600;
    color: #374151;
  }

  .component-showcase {
    background: white;
    border-radius: 12px;
    padding: 24px;
    margin-bottom: 24px;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  }

  .component-showcase h3 {
    margin: 0 0 16px 0;
    font-size: 18px;
    font-weight: 600;
    color: #374151;
  }

  .button-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(120px, 1fr));
    gap: 16px;
    align-items: start;
  }

  .form-showcase {
    background: white;
    border-radius: 12px;
    padding: 24px;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  }

  .form-row {
    margin-bottom: 24px;
  }

  .product-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
    gap: 20px;
  }

  .modal-demo-content {
    padding: 20px 0;
  }

  .modal-demo-content ul {
    margin: 16px 0;
    padding-left: 20px;
  }

  .modal-demo-content li {
    margin-bottom: 8px;
    line-height: 1.5;
  }

  .modal-actions {
    display: flex;
    gap: 12px;
    margin-top: 24px;
    justify-content: flex-end;
  }

  .product-detail-content {
    display: flex;
    flex-direction: column;
    gap: 20px;
  }

  .product-detail-image {
    width: 100%;
    aspect-ratio: 1;
    overflow: hidden;
    border-radius: 8px;
  }

  .detail-image {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }

  .product-detail-info h3 {
    margin: 0 0 12px 0;
    font-size: 20px;
    font-weight: 600;
    color: #374151;
  }

  .product-detail-info p {
    margin: 0 0 16px 0;
    color: #6b7280;
    line-height: 1.5;
  }

  .price-section {
    display: flex;
    align-items: baseline;
    gap: 8px;
    margin-bottom: 16px;
  }

  .current-price {
    font-size: 24px;
    font-weight: 700;
    color: #ef4444;
  }

  .original-price {
    font-size: 16px;
    color: #9ca3af;
    text-decoration: line-through;
  }

  .store-section {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .store-label {
    font-size: 14px;
    color: #6b7280;
  }

  .store-name {
    font-size: 14px;
    font-weight: 600;
    color: #374151;
    background: #f3f4f6;
    padding: 4px 8px;
    border-radius: 4px;
  }

  /* 响应式优化 */
  @media (max-width: 768px) {
    .demo-header {
      padding: 24px 16px;
    }

    .demo-title {
      font-size: 24px;
    }

    .demo-content {
      padding: 20px 16px;
    }

    .component-showcase {
      padding: 20px 16px;
    }

    .button-grid {
      grid-template-columns: 1fr;
    }

    .product-grid {
      grid-template-columns: 1fr;
    }
    
    .form-grid {
      grid-template-columns: 1fr;
    }

    .modal-actions {
      flex-direction: column;
    }
  }
  
  /* 表单布局 */
  .form-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
    gap: 20px;
    align-items: start;
  }
  
  .demo-form {
    background: #f9fafb;
    border-radius: 12px;
    padding: 24px;
    border: 1px solid #e5e7eb;
  }
  
  .form-actions {
    display: flex;
    gap: 12px;
    margin-top: 24px;
    align-items: center;
  }

  /* 新组件样式 */
  .radio-group {
    display: flex;
    flex-direction: column;
    gap: 16px;
  }
  
  .radio-group h4 {
    margin: 0 0 8px 0;
    font-size: 16px;
    font-weight: 600;
    color: #374151;
  }
  
  .badge-showcase h4 {
    margin: 20px 0 12px 0;
    font-size: 14px;
    font-weight: 600;
    color: #6b7280;
  }
  
  .badge-showcase h4:first-child {
    margin-top: 0;
  }
  
  .badge-grid {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
    align-items: center;
    margin-bottom: 16px;
  }
  
  .avatar-showcase h4 {
    margin: 20px 0 12px 0;
    font-size: 14px;
    font-weight: 600;
    color: #6b7280;
  }
  
  .avatar-showcase h4:first-child {
    margin-top: 0;
  }
  
  .avatar-grid {
    display: flex;
    flex-wrap: wrap;
    gap: 12px;
    align-items: center;
    margin-bottom: 16px;
  }
  
  .loading-showcase h4 {
    margin: 20px 0 12px 0;
    font-size: 14px;
    font-weight: 600;
    color: #6b7280;
  }
  
  .loading-showcase h4:first-child {
    margin-top: 0;
  }
  
  .loading-grid {
    display: flex;
    flex-wrap: wrap;
    gap: 20px;
    align-items: center;
    margin-bottom: 20px;
  }
  
  .loading-item {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 8px;
    min-width: 80px;
  }
  
  .loading-item span {
    font-size: 12px;
    color: #6b7280;
    text-align: center;
  }
  
  .loading-actions {
    display: flex;
    justify-content: center;
    margin-top: 20px;
  }

  @media (max-width: 480px) {
    .demo-navigation {
      padding: 12px 16px;
    }

    .component-showcase {
      padding: 16px 12px;
    }

    .form-showcase {
      padding: 20px 16px;
    }
    
    .form-grid {
      gap: 16px;
    }
    
    .demo-form {
      padding: 20px 16px;
    }
    
    .form-actions {
      flex-direction: column;
      gap: 8px;
    }
  }

  .card-showcase h4 {
    margin: 20px 0 12px 0;
    font-size: 14px;
    font-weight: 600;
    color: #6b7280;
  }
  
  .card-showcase h4:first-child {
    margin-top: 0;
  }
  
  .card-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
    gap: 16px;
    margin-bottom: 16px;
  }
  
  .skeleton-showcase h4 {
    margin: 20px 0 12px 0;
    font-size: 14px;
    font-weight: 600;
    color: #6b7280;
  }
  
  .skeleton-showcase h4:first-child {
    margin-top: 0;
  }
  
  .skeleton-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 16px;
    margin-bottom: 20px;
  }
  
  .skeleton-item {
    display: flex;
    flex-direction: column;
    gap: 8px;
    align-items: center;
  }
  
  .skeleton-item span {
    font-size: 12px;
    color: #6b7280;
    text-align: center;
  }
  
  .table-showcase {
    background: #f9fafb;
    padding: 16px;
    border-radius: 8px;
  }
  
  .progress-showcase h4 {
    margin: 20px 0 12px 0;
    font-size: 14px;
    font-weight: 600;
    color: #6b7280;
  }
  
  .progress-showcase h4:first-child {
    margin-top: 0;
  }
  
  .progress-grid {
    display: flex;
    flex-direction: column;
    gap: 16px;
    margin-bottom: 20px;
  }
  
  .progress-controls {
    display: flex;
    gap: 8px;
    justify-content: center;
    margin-top: 16px;
  }
  
  .alert-showcase h4 {
    margin: 20px 0 12px 0;
    font-size: 14px;
    font-weight: 600;
    color: #6b7280;
  }
  
  .alert-showcase h4:first-child {
    margin-top: 0;
  }
  
  .alert-grid {
    display: flex;
    flex-direction: column;
    gap: 12px;
  }
  
  .tooltip-showcase h4 {
    margin: 20px 0 12px 0;
    font-size: 14px;
    font-weight: 600;
    color: #6b7280;
  }
  
  .tooltip-showcase h4:first-child {
    margin-top: 0;
  }
  
  .tooltip-grid {
    display: flex;
    gap: 12px;
    flex-wrap: wrap;
    margin-bottom: 20px;
    justify-content: center;
  }
  
  .toast-showcase {
    text-align: center;
  }
  
  .toast-controls {
    display: flex;
    gap: 8px;
    justify-content: center;
  }

  @media (max-width: 480px) {
    .card-grid {
      grid-template-columns: 1fr;
    }
    
    .skeleton-grid {
      grid-template-columns: 1fr;
    }
    
    .table-showcase {
      padding: 12px;
    }
    
    .tooltip-grid {
      flex-direction: column;
      align-items: center;
    }
  }
</style> 