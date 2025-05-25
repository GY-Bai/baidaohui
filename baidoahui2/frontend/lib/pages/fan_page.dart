import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import '../widgets/application_prompt.dart';

class FanPage extends StatefulWidget {
  const FanPage({super.key});

  @override
  State<FanPage> createState() => _FanPageState();
}

class _FanPageState extends State<FanPage> {
  bool _isAuthenticated = false; // 从后端API获取认证状态
  List<Map<String, dynamic>> _applicationHistory = []; // 申请历史

  @override
  void initState() {
    super.initState();
    _loadAuthStatus();
    _loadApplicationHistory();
  }

  Future<void> _loadAuthStatus() async {
    // TODO: 从后端API获取用户认证状态
    setState(() {
      _isAuthenticated = false; // 示例：未认证
    });
  }

  Future<void> _loadApplicationHistory() async {
    // TODO: 从后端API获取申请历史
    setState(() {
      _applicationHistory = [
        {
          'id': 1,
          'submitTime': '2024-01-15 10:30',
          'status': '审核中',
          'note': '申请成为百道会会员',
          'result': '-',
        },
        {
          'id': 2,
          'submitTime': '2024-01-10 15:20',
          'status': '已拒绝',
          'note': '第一次申请',
          'result': '资料不完整',
        },
      ];
    });
  }

  void _navigateToApplicationSubmit() {
    Navigator.pushNamed(context, '/application_submit');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('百道会 - 粉丝页面'),
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF6366F1),
              Color(0xFFF3F4F6),
            ],
            stops: [0.0, 0.3],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 认证状态提示
                if (!_isAuthenticated) ...[
                  ApplicationPrompt(
                    onSubmitApplication: _navigateToApplicationSubmit,
                    onViewHistory: () => _showApplicationHistory(),
                  ),
                  const SizedBox(height: 24),
                ],

                // 功能区域
                Text(
                  '可用功能',
                  style: context.theme.typography.xl.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // 功能卡片
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    children: [
                      _buildFeatureCard(
                        icon: Icons.shopping_cart,
                        title: '购物商城',
                        subtitle: '浏览商品',
                        onTap: () => _navigateToShopping(),
                      ),
                      _buildFeatureCard(
                        icon: Icons.person_add,
                        title: '申请认证',
                        subtitle: '成为会员',
                        onTap: _navigateToApplicationSubmit,
                      ),
                      _buildFeatureCard(
                        icon: Icons.history,
                        title: '申请历史',
                        subtitle: '查看记录',
                        onTap: () => _showApplicationHistory(),
                      ),
                      _buildFeatureCard(
                        icon: Icons.info,
                        title: '帮助中心',
                        subtitle: '常见问题',
                        onTap: () => _showHelp(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return FCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 48,
                color: context.theme.colors.primary,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: context.theme.typography.base.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: context.theme.typography.sm.copyWith(
                  color: context.theme.colors.mutedForeground,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showApplicationHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: context.theme.colors.border),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '申请历史',
                      style: context.theme.typography.lg.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('提交时间')),
                      DataColumn(label: Text('状态')),
                      DataColumn(label: Text('备注')),
                      DataColumn(label: Text('结果')),
                    ],
                    rows: _applicationHistory.map((app) => DataRow(
                      cells: [
                        DataCell(Text(app['submitTime'])),
                        DataCell(_buildStatusChip(app['status'])),
                        DataCell(Text(app['note'])),
                        DataCell(Text(app['result'])),
                      ],
                    )).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case '已通过':
        color = Colors.green;
        break;
      case '已拒绝':
        color = Colors.red;
        break;
      default:
        color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _navigateToShopping() {
    // TODO: 导航到购物页面
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('购物功能开发中...')),
    );
  }

  void _showHelp() {
    // TODO: 显示帮助信息
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('帮助中心'),
        content: const Text(
          '百道会是一个集聊天、购物、占卜功能于一体的平台。\n\n'
          '作为粉丝，您可以：\n'
          '• 浏览和购买商品\n'
          '• 申请成为认证会员\n'
          '• 查看申请历史\n\n'
          '如需更多帮助，请联系客服。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
} 