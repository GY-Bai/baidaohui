import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pages/login_page.dart';
import 'pages/fan_page.dart';
import 'pages/member_page.dart';
import 'pages/master_page.dart';
import 'pages/firstmate_page.dart';
import 'pages/application_submit_page.dart';
import 'pages/fortune_submit_page.dart';
import 'pages/fortune_history_page.dart';
import 'pages/order_reply_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化Supabase
  await Supabase.initialize(
    url: 'YOUR_SUPABASE_URL',
    anonKey: 'YOUR_SUPABASE_ANON_KEY',
  );
  
  runApp(const BaidaohuiApp());
}

class BaidaohuiApp extends StatelessWidget {
  const BaidaohuiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FTheme(
      data: FThemes.zinc.light, // 先用默认主题
      child: MaterialApp(
        title: '百道会',
        theme: ThemeData(
          useMaterial3: true,
        ),
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginPage(),
        '/fan': (context) => const FanPage(),
        '/member': (context) => const MemberPage(),
        '/master': (context) => const MasterPage(),
        '/firstmate': (context) => const FirstmatePage(),
        '/application_submit': (context) => const ApplicationSubmitPage(),
        '/fortune_submit': (context) => const FortuneSubmitPage(),
        '/fortune_history': (context) => const FortuneHistoryPage(),
      },
      onGenerateRoute: (settings) {
        // 处理带参数的路由
        if (settings.name?.startsWith('/order_reply/') == true) {
          final orderId = settings.name!.split('/').last;
          return MaterialPageRoute(
            builder: (context) => OrderReplyPage(orderId: orderId),
          );
        }
        return null;
      },
      debugShowCheckedModeBanner: false,
      ),
    );
  }
} 