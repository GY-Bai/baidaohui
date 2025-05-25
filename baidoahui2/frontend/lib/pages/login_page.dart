import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/login_button.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isLoading = false;

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        Provider.google,
        redirectTo: 'https://baidaohui.com/auth/callback',
      );

      // Get user role and redirect to appropriate subdomain
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final userRole = await _getUserRole(user.id);
        _redirectToRoleSubdomain(userRole);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('登录失败: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<String> _getUserRole(String userId) async {
    // TODO: 从后端API获取用户角色
    // 这里先返回默认角色，实际应该调用后端API
    return 'fan'; // 默认为fan角色
  }

  void _redirectToRoleSubdomain(String role) {
    String subdomain;
    switch (role.toLowerCase()) {
      case 'member':
        subdomain = 'member.baidaohui.com';
        break;
      case 'master':
        subdomain = 'master.baidaohui.com';
        break;
      case 'firstmate':
        subdomain = 'firstmate.baidaohui.com';
        break;
      default:
        subdomain = 'fans.baidaohui.com';
    }
    
    // TODO: 实现重定向到子域名
    // 这里应该使用url_launcher或类似的包来重定向
  }

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF6366F1),
              Color(0xFF8B5CF6),
              Color(0xFFA855F7),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo and title
                  const Icon(
                    Icons.auto_awesome,
                    size: 80,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '百道会',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '聊天 · 购物 · 占卜',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 48),
                  
                  // Login form
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text(
                          '欢迎来到百道会',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '请使用Google账号登录',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(height: 32),
                        
                        // Google login button
                        LoginButton(
                          onPressed: _isLoading ? null : _signInWithGoogle,
                          isLoading: _isLoading,
                        ),
                        
                        const SizedBox(height: 16),
                        const Text(
                          '登录即表示您同意我们的服务条款和隐私政策',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9CA3AF),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
} 