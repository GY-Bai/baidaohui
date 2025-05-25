import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

class ChatView extends StatefulWidget {
  const ChatView({super.key});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _loadMessages() {
    // 示例聊天数据
    setState(() {
      _messages.addAll([
        {
          'id': 1,
          'sender': '大师李',
          'message': '欢迎来到百道会聊天室！',
          'time': '10:30',
          'isAnchor': true,
        },
        {
          'id': 2,
          'sender': '小明',
          'message': '大师好，请问今天运势如何？',
          'time': '10:31',
          'isAnchor': false,
        },
        {
          'id': 3,
          'sender': '大师李',
          'message': '今日宜静心思考，避免冲动决策。',
          'time': '10:32',
          'isAnchor': true,
        },
      ]);
    });
  }

  void _sendMessage() {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

    setState(() {
      _messages.add({
        'id': _messages.length + 1,
        'sender': '我',
        'message': messageText,
        'time': _getCurrentTime(),
        'isAnchor': false,
      });
    });

    _messageController.clear();
    // TODO: 发送消息到服务器
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // 聊天室标题
          FCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        color: context.theme.colors.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '百道会聊天室',
                        style: context.theme.typography.lg.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '与大师和其他会员交流，获得指导和建议',
                    style: context.theme.typography.sm.copyWith(
                      color: context.theme.colors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 消息列表
          Expanded(
            child: FCard(
              child: ListView(
                children: _messages.map((message) => _buildMessageItem(message)).toList(),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 消息输入框
          FCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: FTextField(
                      controller: _messageController,
                      hint: '输入消息...',
                      maxLines: 3,
                    ),
                  ),
                  const SizedBox(width: 12),
                  FButton(
                    onPress: _sendMessage,
                    style: FButtonStyle.primary,
                    child: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(Map<String, dynamic> message) {
    final isAnchor = message['isAnchor'] as bool;
    final isMyMessage = message['sender'] == '我';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        mainAxisAlignment: isMyMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMyMessage) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: isAnchor ? context.theme.colors.primary : context.theme.colors.mutedForeground,
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
                              color: const Color(0xFFD97706),
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
} 