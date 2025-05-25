import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

class FortuneOrder {
  final String id;
  final double amount;
  final String currency;
  final String status;
  final String note;
  final bool isChildEmergency;
  final int queuePosition;
  final DateTime submitTime;
  final String? replyContent;

  const FortuneOrder({
    required this.id,
    required this.amount,
    required this.currency,
    required this.status,
    required this.note,
    required this.isChildEmergency,
    required this.queuePosition,
    required this.submitTime,
    this.replyContent,
  });

  FortuneOrder copyWith({
    String? id,
    double? amount,
    String? currency,
    String? status,
    String? note,
    bool? isChildEmergency,
    int? queuePosition,
    DateTime? submitTime,
    String? replyContent,
  }) {
    return FortuneOrder(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      note: note ?? this.note,
      isChildEmergency: isChildEmergency ?? this.isChildEmergency,
      queuePosition: queuePosition ?? this.queuePosition,
      submitTime: submitTime ?? this.submitTime,
      replyContent: replyContent ?? this.replyContent,
    );
  }
}

class FortuneHistoryPage extends StatefulWidget {
  const FortuneHistoryPage({super.key});

  @override
  State<FortuneHistoryPage> createState() => _FortuneHistoryPageState();
}

class _FortuneHistoryPageState extends State<FortuneHistoryPage> {
  bool isLoading = false;
  List<FortuneOrder> fortuneOrders = [
    FortuneOrder(
      id: '1',
      amount: 50.0,
      currency: 'CAD',
      status: 'pending',
      note: '请帮我看看事业运势',
      isChildEmergency: false,
      queuePosition: 15,
      submitTime: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    FortuneOrder(
      id: '2',
      amount: 100.0,
      currency: 'CAD',
      status: 'completed',
      note: '想了解感情方面的问题',
      isChildEmergency: true,
      queuePosition: 0,
      submitTime: DateTime.now().subtract(const Duration(days: 1)),
      replyContent: '根据您的情况，建议...',
    ),
    FortuneOrder(
      id: '3',
      amount: 30.0,
      currency: 'USD',
      status: 'refunded',
      note: '家庭关系咨询',
      isChildEmergency: false,
      queuePosition: 0,
      submitTime: DateTime.now().subtract(const Duration(days: 3)),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    Future<void> modifyOrder(FortuneOrder order) async {
      if (order.status != 'pending') {
        _showMessage(context, '只能修改待处理的订单');
        return;
      }

      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => _ModifyOrderDialog(order: order),
      );

      if (result != null) {
        setState(() {
          isLoading = true;
        });
        try {
          // 模拟API调用
          await Future.delayed(const Duration(seconds: 1));
          
          final updatedOrders = fortuneOrders.map((o) {
            if (o.id == order.id) {
              return o.copyWith(
                amount: result['amount'],
                note: result['note'],
                isChildEmergency: result['isChildEmergency'],
              );
            }
            return o;
          }).toList();
          
          setState(() {
            fortuneOrders = updatedOrders;
          });
          
          if (mounted) {
            _showMessage(context, '订单修改成功');
          }
        } catch (e) {
          if (mounted) {
            _showMessage(context, '修改失败，请重试');
          }
        } finally {
          setState(() {
            isLoading = false;
          });
        }
      }
    }

    Future<void> requestRefund(FortuneOrder order) async {
      if (order.status != 'pending' && order.status != 'completed') {
        _showMessage(context, '该订单无法申请退款');
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => FDialog(
          title: const Text('确认退款'),
          body: const Text('确定要申请退款吗？退款申请提交后将由管理员审核。'),
          actions: [
            FButton(
              onPress: () => Navigator.pop(context, false),
              style: FButtonStyle.outline,
              child: const Text('取消'),
            ),
            FButton(
              onPress: () => Navigator.pop(context, true),
              child: const Text('确认'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        setState(() {
          isLoading = true;
        });
        try {
          // 模拟API调用
          await Future.delayed(const Duration(seconds: 1));
          
          final updatedOrders = fortuneOrders.map((o) {
            if (o.id == order.id) {
              return o.copyWith(status: 'refund_requested');
            }
            return o;
          }).toList();
          
          setState(() {
            fortuneOrders = updatedOrders;
          });
          
          if (mounted) {
            _showMessage(context, '退款申请已提交');
          }
        } catch (e) {
          if (mounted) {
            _showMessage(context, '申请失败，请重试');
          }
        } finally {
          setState(() {
            isLoading = false;
          });
        }
      }
    }

    return FScaffold(
      header: FHeader(
        title: const Text('算命历史'),
      ),
      child: isLoading
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: fortuneOrders.length,
            itemBuilder: (context, index) {
              final order = fortuneOrders[index];
              return FCard(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '订单 #${order.id}',
                            style: context.theme.typography.base.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          _buildStatusChip(order.status),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('金额: ${order.amount} ${order.currency}'),
                      if (order.isChildEmergency)
                        Text(
                          '子女紧急',
                          style: TextStyle(color: context.theme.colors.destructive),
                        ),
                      if (order.status == 'pending')
                        Text('排队位置: 前${order.queuePosition}%'),
                      const SizedBox(height: 8),
                      Text(
                        '备注: ${order.note}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (order.replyContent != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          '回复:',
                          style: context.theme.typography.sm.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          order.replyContent!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (order.status == 'pending') ...[
                            Expanded(
                              child: FButton(
                                onPress: () => modifyOrder(order),
                                style: FButtonStyle.secondary,
                                child: const Text('修改订单'),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (order.status == 'pending' || order.status == 'completed')
                            Expanded(
                              child: FButton(
                                onPress: () => requestRefund(order),
                                style: FButtonStyle.outline,
                                child: const Text('申请退款'),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String text;
    switch (status) {
      case 'pending':
        color = Colors.orange;
        text = '待处理';
        break;
      case 'completed':
        color = Colors.green;
        text = '已完成';
        break;
      case 'refunded':
        color = Colors.blue;
        text = '已退款';
        break;
      case 'refund_requested':
        color = Colors.purple;
        text = '退款申请中';
        break;
      default:
        color = Colors.grey;
        text = '未知';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _ModifyOrderDialog extends StatefulWidget {
  final FortuneOrder order;

  const _ModifyOrderDialog({required this.order});

  @override
  State<_ModifyOrderDialog> createState() => _ModifyOrderDialogState();
}

class _ModifyOrderDialogState extends State<_ModifyOrderDialog> {
  late TextEditingController _amountController;
  late TextEditingController _noteController;
  late bool _isChildEmergency;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: widget.order.amount.toString());
    _noteController = TextEditingController(text: widget.order.note);
    _isChildEmergency = widget.order.isChildEmergency;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FDialog(
      title: const Text('修改订单'),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FTextField(
            controller: _amountController,
            label: const Text('金额'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          FTextField(
            controller: _noteController,
            label: const Text('备注'),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              FCheckbox(
                value: _isChildEmergency,
                onChanged: (value) {
                  setState(() {
                    _isChildEmergency = value;
                  });
                },
              ),
              const SizedBox(width: 8),
              const Text('子女紧急'),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () {
            final amount = double.tryParse(_amountController.text);
            if (amount == null || amount <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('请输入有效金额')),
              );
              return;
            }
            
            Navigator.pop(context, {
              'amount': amount,
              'note': _noteController.text,
              'isChildEmergency': _isChildEmergency,
            });
          },
          child: const Text('确认'),
        ),
      ],
    );
  }
} 