import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

class OrderManagement extends StatefulWidget {
  const OrderManagement({super.key});

  @override
  State<OrderManagement> createState() => _OrderManagementState();
}

class _OrderManagementState extends State<OrderManagement> {
  String _selectedFilter = '全部';
  final List<String> _filterOptions = ['全部', '待处理', '处理中', '已完成', '已取消'];
  
  List<Map<String, dynamic>> _orders = [];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  void _loadOrders() {
    // 示例订单数据
    setState(() {
      _orders = [
        {
          'id': 'FT20240115001',
          'customerName': '张三',
          'amount': 188.0,
          'currency': 'CAD',
          'status': '待处理',
          'submitTime': '2024-01-15 10:30',
          'queuePosition': 1,
          'isEmergency': true,
          'note': '希望了解近期感情运势，最近遇到了一些困惑...',
          'keywords': ['感情', '困惑', '运势', '近期', '关系'],
        },
        {
          'id': 'FT20240115002',
          'customerName': '李四',
          'amount': 268.0,
          'currency': 'CAD',
          'status': '处理中',
          'submitTime': '2024-01-15 09:15',
          'queuePosition': 2,
          'isEmergency': false,
          'note': '想了解事业发展方向，目前在考虑换工作...',
          'keywords': ['事业', '发展', '工作', '方向', '决策'],
        },
        {
          'id': 'FT20240115003',
          'customerName': '王五',
          'amount': 388.0,
          'currency': 'CAD',
          'status': '已完成',
          'submitTime': '2024-01-14 16:20',
          'queuePosition': 0,
          'isEmergency': false,
          'note': '关于家庭和睦的问题，希望得到指导...',
          'keywords': ['家庭', '和睦', '关系', '指导', '沟通'],
        },
      ];
    });
  }

  List<Map<String, dynamic>> get _filteredOrders {
    if (_selectedFilter == '全部') {
      return _orders;
    }
    return _orders.where((order) => order['status'] == _selectedFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题和统计
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
                  Icons.auto_awesome,
                  color: Color(0xFFEF4444),
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '占卜订单管理',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '管理和回复客户的占卜申请',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildOrderStats(),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 筛选器
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
                const Text(
                  '状态筛选:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FDropDown<String>(
                    items: _filterOptions.map((option) => 
                      FDropdownMenuItem(value: option, child: Text(option))
                    ).toList(),
                    value: _selectedFilter,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedFilter = value;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 订单列表
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
                  FTableColumn(label: Text('订单号')),
                  FTableColumn(label: Text('客户')),
                  FTableColumn(label: Text('金额')),
                  FTableColumn(label: Text('状态')),
                  FTableColumn(label: Text('优先级')),
                  FTableColumn(label: Text('操作')),
                ],
                children: _filteredOrders.map((order) => FTableRow(
                  cells: [
                    FTableCell(child: Text(order['id'])),
                    FTableCell(child: Text(order['customerName'])),
                    FTableCell(child: Text('${order['currency']} ${order['amount']}')),
                    FTableCell(child: _buildStatusChip(order['status'])),
                    FTableCell(child: _buildPriorityIndicator(order)),
                    FTableCell(
                      child: Row(
                        children: [
                          FButton(
                            onPress: () => _showOrderDetail(order),
                            style: FButtonStyle.outline,
                            child: const Text('查看'),
                          ),
                          const SizedBox(width: 8),
                          if (order['status'] == '待处理' || order['status'] == '处理中') ...[
                            FButton(
                              onPress: () => _replyToOrder(order),
                              style: FButtonStyle.primary,
                              child: const Text('回复'),
                            ),
                          ],
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

  Widget _buildOrderStats() {
    final pendingCount = _orders.where((o) => o['status'] == '待处理').length;
    final processingCount = _orders.where((o) => o['status'] == '处理中').length;
    
    return Column(
      children: [
        Row(
          children: [
            _buildStatItem('待处理', pendingCount, const Color(0xFFEF4444)),
            const SizedBox(width: 16),
            _buildStatItem('处理中', processingCount, const Color(0xFF3B82F6)),
          ],
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF6B7280),
          ),
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
      case '已取消':
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

  Widget _buildPriorityIndicator(Map<String, dynamic> order) {
    final isEmergency = order['isEmergency'] as bool;
    final queuePosition = order['queuePosition'] as int;
    
    return Row(
      children: [
        if (isEmergency) ...[
          const Icon(
            Icons.priority_high,
            color: Color(0xFFEF4444),
            size: 16,
          ),
          const SizedBox(width: 4),
        ],
        Text(
          queuePosition > 0 ? '队列 #$queuePosition' : '-',
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  void _showOrderDetail(Map<String, dynamic> order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('订单详情 - ${order['id']}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('客户姓名', order['customerName']),
              _buildDetailRow('订单金额', '${order['currency']} ${order['amount']}'),
              _buildDetailRow('提交时间', order['submitTime']),
              _buildDetailRow('订单状态', order['status']),
              if (order['queuePosition'] > 0)
                _buildDetailRow('队列位置', '第${order['queuePosition']}位'),
              if (order['isEmergency'])
                _buildDetailRow('优先级', '紧急', isHighlight: true),
              const SizedBox(height: 16),
              const Text(
                '客户描述:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(order['note']),
              const SizedBox(height: 16),
              const Text(
                'AI关键词:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: (order['keywords'] as List<String>).map((keyword) =>
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3)),
                    ),
                    child: Text(
                      keyword,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
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
          if (order['status'] == '待处理' || order['status'] == '处理中')
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _replyToOrder(order);
              },
              child: const Text('回复订单'),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isHighlight ? const Color(0xFFEF4444) : const Color(0xFF1F2937),
                fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _replyToOrder(Map<String, dynamic> order) {
    Navigator.pushNamed(
      context,
      '/order_reply',
      arguments: order,
    );
  }
} 