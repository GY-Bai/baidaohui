<script lang="ts">
  import { onMount } from 'svelte';
  import { clientSideRouteGuard, signOut } from '$lib/auth';
  
  // 导入新的UI组件
  import ChatHeader from '$lib/components/business/ChatHeader.svelte';
  import Avatar from '$lib/components/ui/Avatar.svelte';
  import Button from '$lib/components/ui/Button.svelte';
  import Input from '$lib/components/ui/Input.svelte';
  import Card from '$lib/components/ui/Card.svelte';
  import Badge from '$lib/components/ui/Badge.svelte';
  import Alert from '$lib/components/ui/Alert.svelte';
  import MessageList from '$lib/components/business/MessageList.svelte';

  let loading = true;
  let authenticated = false;
  let newMessage = '';
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
      content: '欢迎来到百刀会！作为会员，您现在可以享受私信服务了。',
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

  // 转换 messages 格式以适应 MessageList 组件
  $: displayMessages = messages.map(msg => ({
    id: msg.id,
    sender: msg.sender.name,
    content: msg.content,
    timestamp: formatTime(msg.timestamp),
    isUser: msg.type === 'sent'
  }));

  // 模拟在线用户
  let onlineUsers = ['教主', '助理小王'];
  let typingUsers = [];

  onMount(async () => {
    // 使用客户端路由守卫
    authenticated = await clientSideRouteGuard('Member');
    loading = false;
    
    if (authenticated) {
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
    }, 2000);
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

  function formatTime(timestamp: Date) {
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
  <title>私信聊天 - 百刀会</title>
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
      <Alert type="info" showIcon>
        <p>您是会员，现在可以享受与教主的私信特权。</p>
      </Alert>
    </div>

    <!-- 聊天消息区域 -->
    <div class="chat-messages-container">
      <MessageList messages={displayMessages} />
    </div>

    <!-- 聊天输入区域 -->
    <div class="chat-input-container">
      <Input
        type="text"
        placeholder="输入消息..."
        bind:value={newMessage}
        on:keypress={handleKeyPress}
        on:input={handleInput}
        class="flex-1"
      />
      <Button on:click={handleSendMessage} disabled={!newMessage.trim()}>发送</Button>
    </div>
  </div>
{:else}
  <div class="not-authenticated-screen">
    <p>您未通过身份验证，请<a href="/login">登录</a>。</p>
    <Button on:click={handleSignOut}>注销</Button>
  </div>
{/if}

<style lang="postcss">
  /* @tailwind base; */
  /* @tailwind components; */
  /* @tailwind utilities; */

  .loading-screen,
  .not-authenticated-screen {
    display: flex;
    justify-content: center;
    align-items: center;
    min-height: 100vh;
    background-color: theme('colors.gray.100');
    flex-direction: column;
    gap: theme('spacing.4');
  }

  .loading-spinner {
    border: 4px solid theme('colors.gray.300');
    border-top: 4px solid theme('colors.blue.500');
    border-radius: 50%;
    width: theme('spacing.12');
    height: theme('spacing.12');
    animation: spin 1s linear infinite;
  }

  @keyframes spin {
    0% { transform: rotate(0deg); }
    100% { transform: rotate(360deg); }
  }

  .member-container {
    display: flex;
    flex-direction: column;
    height: 100vh;
    max-width: 600px; /* 模拟移动端或聊天应用宽度 */
    margin: 0 auto;
    border: 1px solid theme('colors.gray.200');
    box-shadow: theme('boxShadow.md');
    background-color: theme('colors.white');
  }

  .privilege-banner {
    padding: theme('spacing.4');
    border-bottom: 1px solid theme('colors.gray.200');
  }

  .chat-messages-container {
    flex: 1;
    overflow-y: auto;
    display: flex;
    flex-direction: column;
    background-color: theme('colors.gray.50');
  }

  .chat-input-container {
    display: flex;
    padding: theme('spacing.4');
    gap: theme('spacing.2');
    border-top: 1px solid theme('colors.gray.200');
    background-color: theme('colors.white');
  }

  .not-authenticated-screen a {
    color: theme('colors.blue.600');
    text-decoration: underline;
  }
</style> 