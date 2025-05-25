import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import '../widgets/order_management.dart';

class FirstmatePage extends StatefulWidget {
  const FirstmatePage({super.key});

  @override
  State<FirstmatePage> createState() => _FirstmatePageState();
}

class _FirstmatePageState extends State<FirstmatePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); // 只有2个标签
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      header: FHeader(
        title: const Text('百道会 - 副手页面'),
      ),
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(icon: Icon(Icons.chat), text: '群聊'),
              Tab(icon: Icon(Icons.auto_awesome), text: '订单管理'),
            ],
          ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF8B5CF6),
                    Color(0xFFF3F4F6),
                  ],
                  stops: [0.0, 0.3],
                ),
              ),
              child: TabBarView(
                controller: _tabController,
                children: [
                  // 群聊页面 - 限制粉丝私信视图
                  _buildRestrictedChatView(),
                  
                  // 订单管理页面 - 与Master功能相同
                  const OrderManagement(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestrictedChatView() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // 权限提示
          FCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: const Color(0xFFD97706),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '副手权限说明',
                          style: context.theme.typography.base.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFD97706),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '作为副手，您可以查看群聊内容，但无法查看粉丝的私信消息',
                          style: context.theme.typography.sm.copyWith(
                            color: context.theme.colors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 限制版聊天视图
          Expanded(
            child: _buildRestrictedChatWidget(),
          ),
        ],
      ),
    );
  }

  Widget _buildRestrictedChatWidget() {
    // 过滤掉粉丝私信的聊天数据
    final restrictedMessages = [
      {
        'id': 1,
        'sender': '大师李',
        'message': '欢迎来到百道会聊天室！',
        'time': '10:30',
        'isAnchor': true,
      },
      {
        'id': 2,
        'sender': '大师李',
        'message': '今日宜静心思考，避免冲动决策。',
        'time': '10:32',
        'isAnchor': true,
      },
      {
        'id': 3,
        'sender': '副手张',
        'message': '大师说得对，大家要保持理性。',
        'time': '10:33',
        'isAnchor': false,
      },
    ];

    return FCard(
      child: Column(
        children: [
          // 聊天室标题
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: context.theme.colors.border),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  color: context.theme.colors.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  '百道会群聊（副手视图）',
                  style: context.theme.typography.lg.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          // 消息列表
          Expanded(
            child: ListView(
              children: restrictedMessages.map((message) => _buildMessageItem(message)).toList(),
            ),
          ),
          
          // 消息输入框
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: context.theme.colors.border),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: FTextField(
                    hint: '输入群聊消息...',
                    maxLines: 3,
                  ),
                ),
                const SizedBox(width: 12),
                FButton(
                  onPress: () => _sendGroupMessage(),
                  style: FButtonStyle.primary,
                  child: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(Map<String, dynamic> message) {
    final isAnchor = message['isAnchor'] as bool;
    final isMyMessage = message['sender'] == '副手张';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        mainAxisAlignment: isMyMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMyMessage) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: isAnchor ? context.theme.colors.destructive : context.theme.colors.primary,
              child: Text(
                message['sender'].toString()[0],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isMyMessage 
                    ? context.theme.colors.primary
                    : isAnchor 
                        ? const Color(0xFFFEF3C7)
                        : context.theme.colors.muted,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMyMessage) ...[
                    Row(
                      children: [
                        Text(
                          message['sender'],
                          style: context.theme.typography.xs.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isAnchor ? const Color(0xFFD97706) : context.theme.colors.mutedForeground,
                          ),
                        ),
                        if (isAnchor) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: context.theme.colors.destructive,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              '大师',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ] else if (message['sender'] == '副手张') ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: context.theme.colors.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              '副手',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    message['message'],
                    style: context.theme.typography.sm.copyWith(
                      color: isMyMessage ? Colors.white : context.theme.colors.foreground,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message['time'],
                    style: context.theme.typography.xs.copyWith(
                      color: isMyMessage 
                          ? Colors.white70 
                          : context.theme.colors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          if (isMyMessage) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: context.theme.colors.primary,
              child: const Icon(
                Icons.person,
                size: 16,
                color: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _sendGroupMessage() {
    // TODO: 发送群聊消息到服务器
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('消息已发送到群聊')),
    );
  }
} 