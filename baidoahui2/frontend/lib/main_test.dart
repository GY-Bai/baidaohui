import 'package:flutter/material.dart';
import 'pages/chat_test_page.dart';

void main() {
  runApp(const ChatTestApp());
}

class ChatTestApp extends StatelessWidget {
  const ChatTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '百道会聊天模块测试',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),

      home: const ChatTestPage(),
      debugShowCheckedModeBanner: false,
    );
  }
} 