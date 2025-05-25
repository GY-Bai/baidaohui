import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:forui_hooks/forui_hooks.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class FortuneSubmitPage extends HookWidget {
  const FortuneSubmitPage({super.key});

  @override
  Widget build(BuildContext context) {
    final noteController = useTextEditingController();
    final amountController = useTextEditingController();
    final selectedCurrency = useState('CAD');
    final isChildEmergency = useState(false);
    final selectedImages = useState<List<File>>([]);
    final isLoading = useState(false);
    final estimatedPosition = useState<String?>(null);

    final currencies = ['CAD', 'CNY', 'USD', 'SGD', 'AUD'];

    Future<void> pickImage() async {
      if (selectedImages.value.length >= 3) {
        _showMessage(context, '最多只能上传3张图片');
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

    Future<void> estimateQueue() async {
      if (amountController.text.isEmpty) {
        _showMessage(context, '请先输入金额');
        return;
      }

      isLoading.value = true;
      try {
        // 模拟API调用
        await Future.delayed(const Duration(seconds: 1));
        final amount = double.tryParse(amountController.text) ?? 0;
        final position = _calculateEstimatedPosition(amount, isChildEmergency.value);
        estimatedPosition.value = position;
        
        if (context.mounted) {
          _showEstimateDialog(context, position);
        }
      } catch (e) {
        if (context.mounted) {
          _showMessage(context, '估算失败，请重试');
        }
      } finally {
        isLoading.value = false;
      }
    }

    Future<void> submitApplication() async {
      if (noteController.text.isEmpty || amountController.text.isEmpty) {
        _showMessage(context, '请填写完整信息');
        return;
      }

      if (noteController.text.length > 800) {
        _showMessage(context, '备注不能超过800字');
        return;
      }

      isLoading.value = true;
      try {
        // 模拟API调用
        await Future.delayed(const Duration(seconds: 2));
        
        if (context.mounted) {
          _showMessage(context, '申请提交成功');
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

    return FScaffold(
      header: FHeader(
        title: const Text('算命申请'),
      ),
      child: FResponsive(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 图片上传区域
              const Text(
                '上传截图 (最多3张)',
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
                  if (selectedImages.value.length < 3)
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
                            Text('添加图片', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),

              // 备注输入
              const Text(
                '详细备注 (最多800字)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              FTextField(
                controller: noteController,
                maxLines: 8,
                maxLength: 800,
                decoration: const InputDecoration(
                  hintText: '请详细描述您的情况...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              // 子女紧急切换
              Row(
                children: [
                  const Text(
                    '子女紧急情况',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 16),
                  FSwitch(
                    value: isChildEmergency.value,
                    onChanged: (value) => isChildEmergency.value = value,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 货币选择和金额输入
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '货币',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        FSelect<String>(
                          initialSelection: selectedCurrency.value,
                          onChanged: (value) => selectedCurrency.value = value ?? 'CAD',
                          children: currencies.map((currency) => 
                            FSelectOption(
                              value: currency,
                              child: Text(currency),
                            ),
                          ).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '金额',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        FTextField(
                          controller: amountController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: '请输入金额',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 预排队估算按钮
              FButton(
                onPress: isLoading.value ? null : estimateQueue,
                child: isLoading.value 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('预估排队位置'),
              ),
              const SizedBox(height: 24),

              // 提交和取消按钮
              Row(
                children: [
                  Expanded(
                    child: FButton(
                      style: FButtonStyle.outline,
                      onPress: () => Navigator.pop(context),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FButton(
                      onPress: isLoading.value ? null : submitApplication,
                      child: isLoading.value 
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('提交申请'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showEstimateDialog(BuildContext context, String position) {
    showDialog(
      context: context,
      builder: (context) => FDialog(
        title: const Text('排队位置估算'),
        content: Text('根据您的金额和紧急情况，预估排队位置：$position'),
        actions: [
          FButton(
            onPress: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  String _calculateEstimatedPosition(double amount, bool isEmergency) {
    // 简单的排队位置估算逻辑
    int basePosition = 50;
    
    if (isEmergency) {
      basePosition -= 20;
    }
    
    if (amount >= 100) {
      basePosition -= 15;
    } else if (amount >= 50) {
      basePosition -= 10;
    } else if (amount >= 20) {
      basePosition -= 5;
    }
    
    basePosition = basePosition.clamp(1, 100);
    return '前${basePosition}%';
  }
} 