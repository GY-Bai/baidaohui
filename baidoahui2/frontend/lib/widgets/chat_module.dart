import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:forui_hooks/forui_hooks.dart';

enum UserRole { fan, member, master, firstmate }

class ChatModule extends HookWidget {
  final UserRole userRole;
  final String? groupId;
  final bool showFanMessages;

  const ChatModule({
    super.key,
    required this.userRole,
    this.groupId,
    this.showFanMessages = true,
  });

  @override
  Widget build(BuildContext context) {
    final messageController = useTextEditingController();
    final messages = useState<List<ChatMessage>>([
      ChatMessage(
        id: '1',
        senderId: 'master1',
        senderName: '大师',
        content: '欢迎来到百道会聊天室',
        timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
        messageType: MessageType.anchor,
      ),
      ChatMessage(
        id: '2',
        senderId: 'fan1',
        senderName: '粉丝1',
        content: '请问大师在吗？',
        timestamp: DateTime.now().subtract(const Duration(minutes: 25)),
        messageType: MessageType.fan,
      ),
      ChatMessage(
        id: '3',
        senderId: 'member1',
        senderName: '会员1',
        content: '我想咨询一下事业方面的问题',
        timestamp: DateTime.now().subtract(const Duration(minutes: 20)),
        messageType: MessageType.member,
      ),
    ]);
    final isLoading = useState(false);

    // 根据用户角色过滤消息
    List<ChatMessage> getFilteredMessages() {
      switch (userRole) {
        case UserRole.fan:
          // 粉丝只能看到主播消息
          return messages.value.where((msg) => msg.messageType == MessageType.anchor).toList();
        case UserRole.member:
          // 会员可以看到所有消息
          return messages.value;
        case UserRole.master:
          // 大师可以看到所有消息
          return messages.value;
        case UserRole.firstmate:
          // 大副根据设置决定是否显示粉丝消息
          if (showFanMessages) {
            return messages.value;
          } else {
            return messages.value.where((msg) => msg.messageType != MessageType.fan).toList();
          }
      }
    }

    Future<void> sendMessage() async {
      if (messageController.text.trim().isEmpty) return;

      final content = messageController.text.trim();
      messageController.clear();

      isLoading.value = true;
      try {
        // 模拟API调用
        await Future.delayed(const Duration(milliseconds: 500));

        final newMessage = ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          senderId: 'current_user',
          senderName: _getUserDisplayName(),
          content: content,
          timestamp: DateTime.now(),
          messageType: _getUserMessageType(),
        );

        messages.value = [...messages.value, newMessage];
      } catch (e) {
        // 处理错误
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('发送失败，请重试')),
          );
        }
      } finally {
        isLoading.value = false;
      }
    }

    String _getUserDisplayName() {
      switch (userRole) {
        case UserRole.fan:
          return '粉丝';
        case UserRole.member:
          return '会员';
        case UserRole.master:
          return '大师';
        case UserRole.firstmate:
          return '大副';
      }
    }

    MessageType _getUserMessageType() {
      switch (userRole) {
        case UserRole.fan:
          return MessageType.fan;
        case UserRole.member:
          return MessageType.member;
        case UserRole.master:
        case UserRole.firstmate:
          return MessageType.anchor;
      }
    }

    final filteredMessages = getFilteredMessages();

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // 聊天标题栏
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.chat, size: 20),
                const SizedBox(width: 8),
                Text(
                  '聊天室',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (userRole == UserRole.fan)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: const Text(
                      '仅可查看主播消息',
                      style: TextStyle(color: Colors.orange, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          
          // 消息列表
          Expanded(
            child: FListView(
              padding: const EdgeInsets.all(8),
              children: filteredMessages.map((message) => _buildMessageItem(message)).toList(),
            ),
          ),
          
          // 输入区域
          if (userRole != UserRole.fan) ...[
            const Divider(height: 1),
            Container(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: FTextField(
                      controller: messageController,
                      decoration: const InputDecoration(
                        hintText: '输入消息...',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onSubmitted: (_) => sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FButton(
                    onPress: isLoading.value ? null : sendMessage,
                    child: isLoading.value
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send, size: 20),
                  ),
                ],
              ),
            ),
          ] else ...[
            const Divider(height: 1),
            Container(
              padding: const EdgeInsets.all(12),
              child: const Text(
                '粉丝需要认证后才能发送消息',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageItem(ChatMessage message) {
    Color backgroundColor;
    Color textColor = Colors.black;
    
    switch (message.messageType) {
      case MessageType.anchor:
        backgroundColor = Colors.blue.shade50;
        break;
      case MessageType.member:
        backgroundColor = Colors.green.shade50;
        break;
      case MessageType.fan:
        backgroundColor = Colors.grey.shade50;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                message.senderName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 8),
              _buildMessageTypeChip(message.messageType),
              const Spacer(),
              Text(
                _formatTime(message.timestamp),
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            message.content,
            style: TextStyle(color: textColor),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageTypeChip(MessageType type) {
    String text;
    Color color;
    
    switch (type) {
      case MessageType.anchor:
        text = '主播';
        color = Colors.blue;
        break;
      case MessageType.member:
        text = '会员';
        color = Colors.green;
        break;
      case MessageType.fan:
        text = '粉丝';
        color = Colors.grey;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return '刚刚';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}小时前';
    } else {
      return '${dateTime.month}-${dateTime.day} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }
}

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime timestamp;
  final MessageType messageType;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.timestamp,
    required this.messageType,
  });
}

enum MessageType { anchor, member, fan } 