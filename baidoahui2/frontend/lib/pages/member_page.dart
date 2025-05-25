import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import '../widgets/chat_view.dart';

class MemberPage extends StatefulWidget {
  const MemberPage({super.key});

  @override
  State<MemberPage> createState() => _MemberPageState();
}

class _MemberPageState extends State<MemberPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

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
        title: const Text('百道会 - 会员页面'),
        backgroundColor: const Color(0xFF10B981),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.chat), text: '聊天'),
            Tab(icon: Icon(Icons.auto_awesome), text: '占卜'),
            Tab(icon: Icon(Icons.shopping_cart), text: '购物'),
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
              Color(0xFF10B981),
              Color(0xFFF3F4F6),
            ],
            stops: [0.0, 0.3],
          ),
        ),
        child: TabBarView(
          controller: _tabController,
          children: [
            // 聊天页面
            const ChatView(),
            
            // 占卜页面
            _buildFortuneTab(),
            
            // 购物页面
            _buildShoppingTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildFortuneTab() {
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      color: Color(0xFF10B981),
                      size: 28,
                    ),
                    SizedBox(width: 8),
                    Text(
                      '占卜服务',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  '获得大师级占卜指导，了解您的未来走向',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FButton(
                        onPress: () => _navigateToFortuneSubmit(),
                        style: FButtonStyle.primary,
                        child: const Text('提交占卜申请'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FButton(
                        onPress: () => _navigateToFortuneHistory(),
                        style: FButtonStyle.secondary,
                        child: const Text('查看历史'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // 当前订单状态
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '当前订单',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 12),
                _buildOrderStatus(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderStatus() {
    // 示例数据
    final hasActiveOrder = true;
    final orderData = {
      'id': 'FT20240115001',
      'status': '排队中',
      'queuePosition': 5,
      'estimatedWait': '约30分钟',
      'amount': '￥188',
    };

    if (!hasActiveOrder) {
      return const Text(
        '暂无进行中的订单',
        style: TextStyle(
          fontSize: 14,
          color: Color(0xFF6B7280),
        ),
      );
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '订单号: ${orderData['id']}',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF374151),
              ),
            ),
            _buildStatusChip(orderData['status'] as String),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '队列位置: 第${orderData['queuePosition']}位',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF374151),
              ),
            ),
            Text(
              orderData['estimatedWait'] as String,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF10B981),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '订单金额: ${orderData['amount']}',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF374151),
              ),
            ),
            FButton(
              onPress: () => _showOrderDetails(orderData),
              style: FButtonStyle.outline,
              child: const Text('查看详情'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case '已完成':
        color = Colors.green;
        break;
      case '处理中':
        color = Colors.blue;
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

  Widget _buildShoppingTab() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 64,
            color: Color(0xFF6B7280),
          ),
          SizedBox(height: 16),
          Text(
            '购物功能开发中...',
            style: TextStyle(
              fontSize: 18,
              color: Color(0xFF6B7280),
            ),
          ),
          SizedBox(height: 8),
          Text(
            '敬请期待',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToFortuneSubmit() {
    Navigator.pushNamed(context, '/fortune_submit');
  }

  void _navigateToFortuneHistory() {
    Navigator.pushNamed(context, '/fortune_history');
  }

  void _showOrderDetails(Map<String, dynamic> orderData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('订单详情 - ${orderData['id']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('状态: ${orderData['status']}'),
            const SizedBox(height: 8),
            Text('队列位置: 第${orderData['queuePosition']}位'),
            const SizedBox(height: 8),
            Text('预计等待: ${orderData['estimatedWait']}'),
            const SizedBox(height: 8),
            Text('订单金额: ${orderData['amount']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showCancelConfirmation(orderData['id'] as String);
            },
            child: const Text('取消订单'),
          ),
        ],
      ),
    );
  }

  void _showCancelConfirmation(String orderId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认取消'),
        content: Text('您确定要取消订单 $orderId 吗？\n\n取消后款项将原路退回。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('不取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _cancelOrder(orderId);
            },
            child: const Text('确认取消'),
          ),
        ],
      ),
    );
  }

  void _cancelOrder(String orderId) {
    // TODO: 调用取消订单API
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('订单 $orderId 已取消')),
    );
  }
} 