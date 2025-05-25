import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

class ApplicationPrompt extends StatelessWidget {
  final VoidCallback onSubmitApplication;
  final VoidCallback onViewHistory;

  const ApplicationPrompt({
    super.key,
    required this.onSubmitApplication,
    required this.onViewHistory,
  });

  @override
  Widget build(BuildContext context) {
    return FAlert(
      icon: const Icon(
        Icons.info_outline,
        color: Color(0xFF3B82F6),
      ),
      title: const Text('认证提醒'),
      subtitle: const Text(
        '您当前未通过百道会会员认证。请提交申请以获得完整功能访问权限。',
      ),
      actions: [
        FButton(
          onPress: onSubmitApplication,
          style: FButtonStyle.primary,
          child: const Text('提交申请'),
        ),
        const SizedBox(width: 8),
        FButton(
          onPress: onViewHistory,
          style: FButtonStyle.secondary,
          child: const Text('查看历史'),
        ),
      ],
    );
  }
} 