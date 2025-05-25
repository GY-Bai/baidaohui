import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import '../widgets/chat_view.dart';
import '../widgets/order_management.dart';

class MasterPage extends StatefulWidget {
  const MasterPage({super.key});

  @override
  State<MasterPage> createState() => _MasterPageState();
}

class _MasterPageState extends State<MasterPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _fortuneEnabled = true; // 占卜开关状态
  double _minAmount = 188.0; // 最低金额

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('百道会 - 大师页面'),
        backgroundColor: const Color(0xFFEF4444),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettings,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.chat), text: '群聊'),
            Tab(icon: Icon(Icons.people), text: '申请审核'),
            Tab(icon: Icon(Icons.auto_awesome), text: '订单管理'),
          ],
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFEF4444),
              Color(0xFFF3F4F6),
            ],
            stops: [0.0, 0.3],
          ),
        ),
        child: TabBarView(
          controller: _tabController,
          children: [
            // 群聊页面
            const ChatView(),
            
            // 申请审核页面
            _buildApplicationReviewTab(),
            
            // 订单管理页面
            const OrderManagement(),
          ],
        ),
      ),
    );
  }

  Widget _buildApplicationReviewTab() {
    final applications = [
      {
        'id': 'APP001',
        'userId': 'user123',
        'userName': '张三',
        'submitTime': '2024-01-15 10:30',
        'status': '待审核',
        'note': '希望成为百道会会员，已有多年占卜经验',
        'screenshots': ['img1.jpg', 'img2.jpg'],
      },
      {
        'id': 'APP002',
        'userId': 'user456',
        'userName': '李四',
        'submitTime': '2024-01-15 09:15',
        'status': '待审核',
        'note': '对占卜文化很感兴趣，希望能学习更多',
        'screenshots': ['img3.jpg'],
      },
    ];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.people_outline,
                  color: Color(0xFFEF4444),
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '会员申请审核',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '审核粉丝的会员申请',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '待审核: ${applications.length}',
                    style: const TextStyle(
                      color: Color(0xFFEF4444),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: FTable(
                columns: const [
                  FTableColumn(label: Text('申请人')),
                  FTableColumn(label: Text('提交时间')),
                  FTableColumn(label: Text('状态')),
                  FTableColumn(label: Text('操作')),
                ],
                children: applications.map((app) => FTableRow(
                  cells: [
                    FTableCell(child: Text(app['userName'] as String)),
                    FTableCell(child: Text(app['submitTime'] as String)),
                    FTableCell(child: _buildStatusChip(app['status'] as String)),
                    FTableCell(
                      child: Row(
                        children: [
                          FButton(
                            onPress: () => _showApplicationDetail(app),
                            style: FButtonStyle.outline,
                            child: const Text('查看'),
                          ),
                          const SizedBox(width: 8),
                          FButton(
                            onPress: () => _approveApplication(app['id'] as String),
                            style: FButtonStyle.primary,
                            child: const Text('通过'),
                          ),
                          const SizedBox(width: 8),
                          FButton(
                            onPress: () => _rejectApplication(app['id'] as String),
                            style: FButtonStyle.destructive,
                            child: const Text('拒绝'),
                          ),
                        ],
                      ),
                    ),
                  ],
                )).toList(),
              ),
            ),
          ),
        ],
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

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '大师设置',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 24),
            
            // 占卜开关
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '占卜服务',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    Text(
                      '开启/关闭占卜申请功能',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
                FSwitch(
                  value: _fortuneEnabled,
                  onChanged: (value) {
                    setState(() {
                      _fortuneEnabled = value;
                    });
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // 最低金额设置
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '最低占卜金额 (CAD)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 8),
                FTextField(
                  initialValue: _minAmount.toString(),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    final amount = double.tryParse(value);
                    if (amount != null) {
                      _minAmount = amount;
                    }
                  },
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            Row(
              children: [
                Expanded(
                  child: FButton(
                    onPress: () => Navigator.pop(context),
                    style: FButtonStyle.secondary,
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FButton(
                    onPress: () {
                      Navigator.pop(context);
                      _saveSettings();
                    },
                    style: FButtonStyle.primary,
                    child: const Text('保存'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showApplicationDetail(Map<String, dynamic> application) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('申请详情 - ${application['userName']}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('申请人: ${application['userName']}'),
              const SizedBox(height: 8),
              Text('提交时间: ${application['submitTime']}'),
              const SizedBox(height: 8),
              Text('状态: ${application['status']}'),
              const SizedBox(height: 16),
              const Text(
                '申请说明:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(application['note'] as String),
              const SizedBox(height: 16),
              const Text(
                '附件截图:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: (application['screenshots'] as List<String>).map((img) =>
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.image),
                  ),
                ).toList(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _approveApplication(application['id'] as String);
            },
            child: const Text('通过申请'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _rejectApplication(application['id'] as String);
            },
            child: const Text('拒绝申请'),
          ),
        ],
      ),
    );
  }

  void _approveApplication(String applicationId) {
    // TODO: 调用API通过申请
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('申请 $applicationId 已通过')),
    );
  }

  void _rejectApplication(String applicationId) {
    // TODO: 调用API拒绝申请
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('申请 $applicationId 已拒绝')),
    );
  }

  void _saveSettings() {
    // TODO: 保存设置到服务器
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('设置已保存')),
    );
  }
} 