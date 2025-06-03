<script lang="ts">
  import { onMount } from 'svelte';
  import { clientSideRouteGuard, signOut } from '$lib/auth';
  
  // 导入新的UI组件
  import ChatHeader from '$lib/components/ui/ChatHeader.svelte';
  import Avatar from '$lib/components/ui/Avatar.svelte';
  import Button from '$lib/components/ui/Button.svelte';
  import Input from '$lib/components/ui/Input.svelte';
  import Card from '$lib/components/ui/Card.svelte';
  import Badge from '$lib/components/ui/Badge.svelte';
  import Alert from '$lib/components/ui/Alert.svelte';

  let loading = true;
  let authenticated = false;
  let newMessage = '';
  let chatContainer;
  let typing = false;
  let typingTimeout;

  // 模拟用户数据
  const currentUser = {
    id: '1',
    name: '张三',
    username: 'zhangsan',
    avatar: 'https://api.dicebear.com/7.x/avataaars/svg?seed=zhang',
    status: 'online'
  };

  const masterUser = {
    id: 'master',
    name: '教主',
    username: 'master',
    avatar: 'https://api.dicebear.com/7.x/avataaars/svg?seed=master',
    status: 'online',
    verified: true,
    role: 'Master'
  };

  // 模拟消息数据
  let messages = [
    {
      id: '1',
      type: 'received',
      content: '欢迎来到百道慧！作为会员，您现在可以享受私信服务了。',
      timestamp: new Date(Date.now() - 300000),
      sender: masterUser,
      status: 'read'
    },
    {
      id: '2',
      type: 'sent',
      content: '谢谢教主！我想了解一下算命服务的详细流程。',
      timestamp: new Date(Date.now() - 240000),
      sender: currentUser,
      status: 'delivered'
    },
    {
      id: '3',
      type: 'received',
      content: '当然可以！算命服务分为三个等级：基础算命、深度解析和全面指导。每个等级的价格和详细程度都不同。',
      timestamp: new Date(Date.now() - 180000),
      sender: masterUser,
      status: 'read'
    },
    {
      id: '4',
      type: 'sent',
      content: '我比较感兴趣深度解析，能详细介绍一下吗？',
      timestamp: new Date(Date.now() - 120000),
      sender: currentUser,
      status: 'delivered'
    },
    {
      id: '5',
      type: 'received',
      content: '深度解析包括：事业运势、感情状况、财运分析、健康指导。我会根据您提供的信息进行详细解读，并给出具体的建议和时间节点。',
      timestamp: new Date(Date.now() - 60000),
      sender: masterUser,
      status: 'read'
    }
  ];

  // 模拟在线用户
  let onlineUsers = ['教主', '助理小王'];
  let typingUsers = [];

  onMount(async () => {
    // 使用客户端路由守卫
    authenticated = await clientSideRouteGuard('Member');
    loading = false;
    
    if (authenticated) {
      scrollToBottom();
      // 模拟教主正在输入
      setTimeout(() => {
        typingUsers = ['教主'];
        setTimeout(() => {
          typingUsers = [];
        }, 3000);
      }, 2000);
    }
  });

  async function handleSignOut() {
    await signOut();
  }

  function handleSendMessage() {
    if (!newMessage.trim()) return;
    
    const message = {
      id: Date.now().toString(),
      type: 'sent',
      content: newMessage.trim(),
      timestamp: new Date(),
      sender: currentUser,
      status: 'sending'
    };
    
    messages = [...messages, message];
    newMessage = '';
    
    // 模拟发送状态更新
    setTimeout(() => {
      messages = messages.map(msg => 
        msg.id === message.id 
          ? { ...msg, status: 'delivered' }
          : msg
      );
    }, 1000);
    
    // 模拟自动回复
    setTimeout(() => {
      const autoReply = {
        id: (Date.now() + 1).toString(),
        type: 'received',
        content: '收到您的消息，我会尽快回复您。',
        timestamp: new Date(),
        sender: masterUser,
        status: 'delivered'
      };
      messages = [...messages, autoReply];
      scrollToBottom();
    }, 2000);
    
    scrollToBottom();
  }

  function handleKeyPress(event) {
    if (event.key === 'Enter' && !event.shiftKey) {
      event.preventDefault();
      handleSendMessage();
    }
  }

  function handleInput() {
    typing = true;
    clearTimeout(typingTimeout);
    typingTimeout = setTimeout(() => {
      typing = false;
    }, 1000);
  }

  function scrollToBottom() {
    setTimeout(() => {
      if (chatContainer) {
        chatContainer.scrollTop = chatContainer.scrollHeight;
      }
    }, 100);
  }

  function formatTime(timestamp) {
    return timestamp.toLocaleTimeString('zh-CN', {
      hour: '2-digit',
      minute: '2-digit'
    });
  }

  function getMessageStatus(status) {
    switch (status) {
      case 'sending': return '发送中...';
      case 'delivered': return '已送达';
      case 'read': return '已读';
      default: return '';
    }
  }

  // 聊天头部操作
  const chatActions = [
    {
      id: 'voice-call',
      label: '语音通话',
      icon: '📞',
      shortcut: 'V'
    },
    {
      id: 'video-call',
      label: '视频通话',
      icon: '📹',
      shortcut: 'C'
    },
    {
      id: 'file-share',
      label: '文件分享',
      icon: '📎',
      shortcut: 'F'
    }
  ];

  function handleChatAction(event) {
    const action = event.detail.action;
    console.log('执行聊天操作:', action.label);
    // 这里可以实现具体的操作逻辑
  }

  function handleBack() {
    console.log('返回聊天列表');
    // 可以导航回聊天列表页面
  }
</script>

<svelte:head>
  <title>私信聊天 - 百道慧</title>
</svelte:head>

{#if loading}
  <div class="loading-screen">
    <div class="loading-content">
      <div class="loading-spinner"></div>
      <p>正在验证身份...</p>
    </div>
  </div>
{:else if authenticated}
  <div class="member-container">
    <!-- 聊天头部 -->
    <ChatHeader
      user={masterUser}
      chatTitle="与教主的私信"
      subtitle="24小时内回复"
      typing={typingUsers.length > 0}
      typingUsers={typingUsers}
      onlineCount={onlineUsers.length}
      actions={chatActions}
      on:back={handleBack}
      on:action={handleChatAction}
    />

    <!-- 会员特权提示 -->
    <div class="privilege-banner">
      <Alert type="success" showIcon closable={false}>
        <strong>会员特权激活：</strong>您现在可以与教主进行私信交流，享受专属指导服务！
      </Alert>
    </div>

    <!-- 聊天消息区域 -->
    <div class="chat-container">
      <div class="messages-container" bind:this={chatContainer}>
        <div class="messages-list">
          {#each messages as message}
            <div class="message {message.type}">
              <div class="message-content">
                {#if message.type === 'received'}
                  <Avatar 
                    src={message.sender.avatar} 
                    alt={message.sender.name}
                    size="sm"
                    showStatus={false}
                  />
                {/if}
                
                <div class="message-bubble">
                  <div class="message-text">{message.content}</div>
                  <div class="message-meta">
                    <span class="message-time">{formatTime(message.timestamp)}</span>
                    {#if message.type === 'sent'}
                      <span class="message-status">{getMessageStatus(message.status)}</span>
                    {/if}
                  </div>
                </div>
                
                {#if message.type === 'sent'}
                  <Avatar 
                    src={message.sender.avatar} 
                    alt={message.sender.name}
                    size="sm"
                    showStatus={false}
                  />
                {/if}
              </div>
            </div>
          {/each}
          
          <!-- 输入指示器 -->
          {#if typingUsers.length > 0}
            <div class="typing-indicator">
              <Avatar 
                src={masterUser.avatar} 
                alt={masterUser.name}
                size="sm"
                showStatus={false}
              />
              <div class="typing-bubble">
                <div class="typing-dots">
                  <span></span>
                  <span></span>
                  <span></span>
                </div>
                <div class="typing-text">{typingUsers.join(', ')} 正在输入...</div>
              </div>
            </div>
          {/if}
        </div>
      </div>
    </div>

    <!-- 消息输入区域 -->
    <div class="input-container">
      <div class="input-wrapper">
        <Input
          bind:value={newMessage}
          placeholder="输入消息... (Enter 发送)"
          on:keydown={handleKeyPress}
          on:input={handleInput}
          maxlength={500}
        />
        <Button 
          variant="primary" 
          size="sm"
          disabled={!newMessage.trim()}
          on:click={handleSendMessage}
        >
          发送
        </Button>
      </div>
      
      <!-- 快捷操作 -->
      <div class="quick-actions">
        <button class="quick-action" title="表情">😊</button>
        <button class="quick-action" title="图片">🖼️</button>
        <button class="quick-action" title="文件">📎</button>
        <button class="quick-action" title="语音">🎤</button>
      </div>
    </div>

    <!-- 在线状态栏 -->
    <div class="status-bar">
      <div class="online-users">
        <span class="status-label">在线用户：</span>
        {#each onlineUsers as user}
          <Badge variant="success" size="xs">{user}</Badge>
        {/each}
      </div>
      
      <Button variant="ghost" size="xs" on:click={handleSignOut}>
        🚪 退出登录
      </Button>
    </div>
  </div>
{/if}

<style>
  .loading-screen {
    min-height: 100vh;
    display: flex;
    align-items: center;
    justify-content: center;
    background: linear-gradient(135deg, #34d399 0%, #10b981 100%);
  }

  .loading-content {
    text-align: center;
    color: white;
  }

  .loading-spinner {
    width: 40px;
    height: 40px;
    border: 4px solid rgba(255, 255, 255, 0.3);
    border-top: 4px solid white;
    border-radius: 50%;
    animation: spin 1s linear infinite;
    margin: 0 auto 16px auto;
  }

  @keyframes spin {
    0% { transform: rotate(0deg); }
    100% { transform: rotate(360deg); }
  }

  .member-container {
    min-height: 100vh;
    background: #f8fafc;
    display: flex;
    flex-direction: column;
    max-width: 768px;
    margin: 0 auto;
    box-shadow: 0 0 20px rgba(0, 0, 0, 0.1);
  }

  /* 会员特权提示 */
  .privilege-banner {
    padding: 12px 16px;
    background: #f0fdf4;
  }

  /* 聊天容器 */
  .chat-container {
    flex: 1;
    background: white;
    display: flex;
    flex-direction: column;
    min-height: 0;
  }

  .messages-container {
    flex: 1;
    overflow-y: auto;
    padding: 16px;
    scroll-behavior: smooth;
  }

  .messages-list {
    display: flex;
    flex-direction: column;
    gap: 12px;
  }

  /* 消息样式 */
  .message {
    width: 100%;
  }

  .message-content {
    display: flex;
    gap: 8px;
    align-items: flex-end;
  }

  .message.sent .message-content {
    flex-direction: row-reverse;
    justify-content: flex-start;
  }

  .message-bubble {
    max-width: 75%;
    min-width: 120px;
    padding: 12px 16px;
    border-radius: 18px;
    position: relative;
  }

  .message.received .message-bubble {
    background: #f3f4f6;
    color: #374151;
    border-bottom-left-radius: 6px;
  }

  .message.sent .message-bubble {
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    color: white;
    border-bottom-right-radius: 6px;
  }

  .message-text {
    line-height: 1.4;
    word-break: break-word;
  }

  .message-meta {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-top: 4px;
    font-size: 11px;
    opacity: 0.7;
  }

  .message-time {
    flex-shrink: 0;
  }

  .message-status {
    margin-left: 8px;
  }

  /* 输入指示器 */
  .typing-indicator {
    display: flex;
    gap: 8px;
    align-items: flex-end;
  }

  .typing-bubble {
    background: #f3f4f6;
    padding: 12px 16px;
    border-radius: 18px;
    border-bottom-left-radius: 6px;
  }

  .typing-dots {
    display: flex;
    gap: 3px;
    margin-bottom: 4px;
  }

  .typing-dots span {
    width: 6px;
    height: 6px;
    background: #9ca3af;
    border-radius: 50%;
    animation: typingDot 1.4s infinite ease-in-out;
  }

  .typing-dots span:nth-child(1) { animation-delay: 0s; }
  .typing-dots span:nth-child(2) { animation-delay: 0.2s; }
  .typing-dots span:nth-child(3) { animation-delay: 0.4s; }

  @keyframes typingDot {
    0%, 80%, 100% { 
      transform: scale(0.8); 
      opacity: 0.5; 
    }
    40% { 
      transform: scale(1); 
      opacity: 1; 
    }
  }

  .typing-text {
    font-size: 12px;
    color: #6b7280;
    font-style: italic;
  }

  /* 输入区域 */
  .input-container {
    background: white;
    border-top: 1px solid #e5e7eb;
    padding: 16px;
  }

  .input-wrapper {
    display: flex;
    gap: 8px;
    margin-bottom: 8px;
  }

  .quick-actions {
    display: flex;
    gap: 8px;
    justify-content: center;
  }

  .quick-action {
    width: 32px;
    height: 32px;
    border: none;
    background: #f3f4f6;
    border-radius: 8px;
    font-size: 16px;
    cursor: pointer;
    transition: all 0.2s ease;
  }

  .quick-action:hover {
    background: #e5e7eb;
    transform: scale(1.05);
  }

  /* 状态栏 */
  .status-bar {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 8px 16px;
    background: #f9fafb;
    border-top: 1px solid #e5e7eb;
    font-size: 12px;
  }

  .online-users {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .status-label {
    color: #6b7280;
    font-weight: 500;
  }

  /* 移动端适配 */
  @media (max-width: 768px) {
    .member-container {
      max-width: 100%;
      box-shadow: none;
    }

    .messages-container {
      padding: 12px;
    }

    .message-bubble {
      max-width: 85%;
    }

    .input-container {
      padding: 12px;
    }

    .quick-actions {
      gap: 6px;
    }

    .quick-action {
      width: 28px;
      height: 28px;
      font-size: 14px;
    }

    .status-bar {
      flex-direction: column;
      gap: 8px;
      padding: 12px;
    }
  }

  /* 深色模式 */
  @media (prefers-color-scheme: dark) {
    .member-container {
      background: #111827;
    }

    .privilege-banner {
      background: #064e3b;
    }

    .chat-container {
      background: #1f2937;
    }

    .message.received .message-bubble {
      background: #374151;
      color: #e5e7eb;
    }

    .typing-bubble {
      background: #374151;
    }

    .typing-text {
      color: #d1d5db;
    }

    .input-container {
      background: #1f2937;
      border-top-color: #374151;
    }

    .quick-action {
      background: #374151;
    }

    .quick-action:hover {
      background: #4b5563;
    }

    .status-bar {
      background: #374151;
      border-top-color: #4b5563;
    }

    .status-label {
      color: #d1d5db;
    }
  }

  /* 无障碍支持 */
  @media (prefers-reduced-motion: reduce) {
    .loading-spinner {
      animation: none;
    }

    .typing-dots span {
      animation: none;
    }

    .quick-action {
      transition: none;
    }

    .messages-container {
      scroll-behavior: auto;
    }
  }
</style> 