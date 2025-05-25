import 'package:flutter/material.dart';
import '../widgets/chat_module_simple.dart';

class ChatTestPage extends StatefulWidget {
  const ChatTestPage({super.key});

  @override
  State<ChatTestPage> createState() => _ChatTestPageState();
}

class _ChatTestPageState extends State<ChatTestPage> {
  UserRole selectedRole = UserRole.fan;
  bool showFanMessages = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('聊天模块测试'),
        backgroundColor: Colors.blue.shade100,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 角色选择器
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '选择用户角色:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: UserRole.values.map((role) {
                        return ChoiceChip(
                          label: Text(_getRoleDisplayName(role)),
                          selected: selectedRole == role,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                selectedRole = role;
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                    if (selectedRole == UserRole.firstmate) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Checkbox(
                            value: showFanMessages,
                            onChanged: (value) {
                              setState(() {
                                showFanMessages = value ?? true;
                              });
                            },
                          ),
                          const Text('显示粉丝消息'),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // 当前角色信息
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getRoleColor(selectedRole).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _getRoleColor(selectedRole)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '当前角色: ${_getRoleDisplayName(selectedRole)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _getRoleColor(selectedRole),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getRoleDescription(selectedRole),
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // 聊天模块
            Expanded(
              child: ChatModuleSimple(
                userRole: selectedRole,
                groupId: 'test_group',
                showFanMessages: showFanMessages,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getRoleDisplayName(UserRole role) {
    switch (role) {
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

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.fan:
        return Colors.grey;
      case UserRole.member:
        return Colors.green;
      case UserRole.master:
        return Colors.blue;
      case UserRole.firstmate:
        return Colors.purple;
    }
  }

  String _getRoleDescription(UserRole role) {
    switch (role) {
      case UserRole.fan:
        return '只能查看主播消息，无法发送消息';
      case UserRole.member:
        return '可以查看所有消息并发送消息';
      case UserRole.master:
        return '主播角色，可以查看和发送所有消息';
      case UserRole.firstmate:
        return '大副角色，可以控制是否显示粉丝消息';
    }
  }
} 