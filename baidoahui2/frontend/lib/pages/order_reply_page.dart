import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:forui_hooks/forui_hooks.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class OrderReplyPage extends HookWidget {
  final String orderId;
  
  const OrderReplyPage({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    final replyController = useTextEditingController();
    final selectedImages = useState<List<File>>([]);
    final isLoading = useState(false);
    final hasDraft = useState(false);
    final orderData = useState<Map<String, dynamic>?>(null);

    // 模拟订单数据
    useEffect(() {
      orderData.value = {
        'id': orderId,
        'customerName': '张三',
        'amount': 100.0,
        'currency': 'CAD',
        'note': '请帮我看看事业运势，最近工作上遇到了一些困难，不知道该如何选择。希望能得到一些指导。',
        'isChildEmergency': true,
        'submitTime': DateTime.now().subtract(const Duration(hours: 2)),
        'images': ['image1.jpg', 'image2.jpg'],
        'keywords': ['事业', '选择', '困难', '指导', '工作'],
      };
      return null;
    }, []);

    // 实时保存草稿
    useEffect(() {
      final timer = Timer.periodic(const Duration(seconds: 5), (timer) {
        if (replyController.text.isNotEmpty) {
          _saveDraft(replyController.text, selectedImages.value);
          hasDraft.value = true;
        }
      });
      return timer.cancel;
    }, []);

    Future<void> pickImage() async {
      if (selectedImages.value.length >= 5) {
        _showMessage(context, '最多只能上传5张图片');
        return;
      }

      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      
      if (pickedFile != null) {
        selectedImages.value = [...selectedImages.value, File(pickedFile.path)];
      }
    }

    Future<void> removeImage(int index) async {
      final newList = List<File>.from(selectedImages.value);
      newList.removeAt(index);
      selectedImages.value = newList;
    }

    Future<void> _saveDraft(String content, List<File> images) async {
      // 模拟保存草稿到服务器
      try {
        await Future.delayed(const Duration(milliseconds: 500));
        // 实际实现中会调用API保存草稿
      } catch (e) {
        // 静默处理错误
      }
    }

    Future<void> submitReply() async {
      if (replyController.text.trim().isEmpty) {
        _showMessage(context, '请输入回复内容');
        return;
      }

      isLoading.value = true;
      try {
        // 模拟API调用
        await Future.delayed(const Duration(seconds: 2));
        
        if (context.mounted) {
          _showMessage(context, '回复提交成功');
          Navigator.pop(context);
        }
      } catch (e) {
        if (context.mounted) {
          _showMessage(context, '提交失败，请重试');
        }
      } finally {
        isLoading.value = false;
      }
    }

    Future<void> saveDraft() async {
      isLoading.value = true;
      try {
        await _saveDraft(replyController.text, selectedImages.value);
        hasDraft.value = true;
        
        if (context.mounted) {
          _showMessage(context, '草稿保存成功');
        }
      } catch (e) {
        if (context.mounted) {
          _showMessage(context, '保存失败，请重试');
        }
      } finally {
        isLoading.value = false;
      }
    }

    if (orderData.value == null) {
      return const FScaffold(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final order = orderData.value!;

    return FScaffold(
      header: FHeader(
        title: Text('回复订单 #${order['id']}'),
        actions: [
          if (hasDraft.value)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange),
              ),
              child: const Text(
                '有草稿',
                style: TextStyle(color: Colors.orange, fontSize: 12),
              ),
            ),
        ],
      ),
      child: FResponsive(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWideScreen = constraints.maxWidth > 800;
            
            if (isWideScreen) {
              // PC端：左右布局
              return Row(
                children: [
                  // 左侧：订单详情
                  Expanded(
                    flex: 1,
                    child: _buildOrderDetails(order),
                  ),
                  const VerticalDivider(),
                  // 右侧：回复区域
                  Expanded(
                    flex: 1,
                    child: _buildReplyArea(
                      replyController,
                      selectedImages,
                      isLoading,
                      pickImage,
                      removeImage,
                      submitReply,
                      saveDraft,
                    ),
                  ),
                ],
              );
            } else {
              // 移动端：上下布局
              return Column(
                children: [
                  // 上方：订单详情
                  Expanded(
                    flex: 1,
                    child: _buildOrderDetails(order),
                  ),
                  const Divider(),
                  // 下方：回复区域
                  Expanded(
                    flex: 1,
                    child: _buildReplyArea(
                      replyController,
                      selectedImages,
                      isLoading,
                      pickImage,
                      removeImage,
                      submitReply,
                      saveDraft,
                    ),
                  ),
                ],
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildOrderDetails(Map<String, dynamic> order) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '订单详情',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('客户: ${order['customerName']}'),
                  const SizedBox(height: 8),
                  Text('金额: ${order['amount']} ${order['currency']}'),
                  const SizedBox(height: 8),
                  if (order['isChildEmergency'])
                    const Text(
                      '子女紧急',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  const SizedBox(height: 8),
                  Text('提交时间: ${_formatDateTime(order['submitTime'])}'),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          const Text(
            '客户备注',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(order['note']),
            ),
          ),
          
          if (order['keywords'] != null) ...[
            const SizedBox(height: 16),
            const Text(
              'AI关键词',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: (order['keywords'] as List<String>).map((keyword) =>
                Chip(
                  label: Text(keyword),
                  backgroundColor: Colors.blue.withOpacity(0.1),
                ),
              ).toList(),
            ),
          ],
          
          if (order['images'] != null && (order['images'] as List).isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              '客户上传的图片',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: (order['images'] as List).length,
              itemBuilder: (context, index) {
                return Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Icon(Icons.image, size: 50, color: Colors.grey),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReplyArea(
    TextEditingController replyController,
    ValueNotifier<List<File>> selectedImages,
    ValueNotifier<bool> isLoading,
    VoidCallback pickImage,
    Function(int) removeImage,
    VoidCallback submitReply,
    VoidCallback saveDraft,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '回复内容',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          FTextField(
            controller: replyController,
            maxLines: 8,
            decoration: const InputDecoration(
              hintText: '请输入您的回复...',
              border: OutlineInputBorder(),
            ),
          ),
          
          const SizedBox(height: 16),
          const Text(
            '上传图片 (最多5张)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...selectedImages.value.asMap().entries.map((entry) {
                final index = entry.key;
                final image = entry.value;
                return Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          image,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => removeImage(index),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }),
              if (selectedImages.value.length < 5)
                GestureDetector(
                  onTap: pickImage,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey, style: BorderStyle.solid),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate, size: 32, color: Colors.grey),
                        Text('添加图片', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: FButton(
                  style: FButtonStyle.outline,
                  onPress: isLoading.value ? null : saveDraft,
                  child: isLoading.value 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('保存草稿'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FButton(
                  onPress: isLoading.value ? null : submitReply,
                  child: isLoading.value 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('提交回复'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
           '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
} 