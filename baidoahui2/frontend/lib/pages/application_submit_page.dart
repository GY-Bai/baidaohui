import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

class ApplicationSubmitPage extends StatefulWidget {
  const ApplicationSubmitPage({super.key});

  @override
  State<ApplicationSubmitPage> createState() => _ApplicationSubmitPageState();
}

class _ApplicationSubmitPageState extends State<ApplicationSubmitPage> {
  final TextEditingController _noteController = TextEditingController();
  final List<String> _uploadedImages = [];
  bool _isSubmitting = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('提交认证申请'),
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
                // 说明信息
                FCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: context.theme.colors.primary,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '申请须知',
                              style: context.theme.typography.xl.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '为了成为百道会的认证会员，请按照以下要求提交申请：',
                          style: context.theme.typography.sm.copyWith(
                            color: context.theme.colors.mutedForeground,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• 最多上传3张相关截图或证明材料\n'
                          '• 详细说明您的申请理由和背景\n'
                          '• 申请提交后将由大师进行审核\n'
                          '• 审核结果将在24-48小时内通知',
                          style: context.theme.typography.sm.copyWith(
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // 表单内容
                Expanded(
                  child: FCard(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 截图上传区域
                            Text(
                              '上传截图或证明材料',
                              style: context.theme.typography.base.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '最多上传3张图片，支持 JPG、PNG 格式',
                              style: context.theme.typography.sm.copyWith(
                                color: context.theme.colors.mutedForeground,
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            _buildImageUploadSection(),
                            
                            const SizedBox(height: 32),
                            
                            // 申请说明
                            Text(
                              '申请说明',
                              style: context.theme.typography.base.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '请详细说明您申请成为百道会会员的理由和相关背景',
                              style: context.theme.typography.sm.copyWith(
                                color: context.theme.colors.mutedForeground,
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            FTextField(
                              controller: _noteController,
                              label: const Text('申请理由'),
                              hint: '请输入您的申请理由...',
                              maxLines: 6,
                            ),
                            
                            const SizedBox(height: 32),
                            
                            // 提交按钮
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
                                    onPress: _isSubmitting ? null : _submitApplication,
                                    style: FButtonStyle.primary,
                                    child: _isSubmitting
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
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
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageUploadSection() {
    return Column(
      children: [
        // 已上传的图片
        if (_uploadedImages.isNotEmpty) ...[
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _uploadedImages.asMap().entries.map((entry) {
              final index = entry.key;
              final imagePath = entry.value;
              return _buildImageItem(imagePath, index);
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],
        
        // 上传按钮
        if (_uploadedImages.length < 3) ...[
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: double.infinity,
              height: 120,
              decoration: BoxDecoration(
                border: Border.all(
                  color: context.theme.colors.primary,
                  width: 2,
                  style: BorderStyle.solid,
                ),
                borderRadius: BorderRadius.circular(12),
                color: context.theme.colors.primary.withOpacity(0.05),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_upload_outlined,
                    size: 48,
                    color: context.theme.colors.primary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '点击上传图片',
                    style: context.theme.typography.base.copyWith(
                      color: context.theme.colors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '支持 JPG、PNG 格式',
                    style: context.theme.typography.xs.copyWith(
                      color: context.theme.colors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildImageItem(String imagePath, int index) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.theme.colors.border),
      ),
      child: Stack(
        children: [
          // 图片预览 (这里使用占位符)
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: context.theme.colors.muted,
            ),
            child: Icon(
              Icons.image,
              size: 32,
              color: context.theme.colors.mutedForeground,
            ),
          ),
          
          // 删除按钮
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => _removeImage(index),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: context.theme.colors.destructive,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _pickImage() {
    // TODO: 实现图片选择逻辑
    // 这里模拟添加图片
    if (_uploadedImages.length < 3) {
      setState(() {
        _uploadedImages.add('image_${_uploadedImages.length + 1}.jpg');
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('图片上传成功')),
      );
    }
  }

  void _removeImage(int index) {
    setState(() {
      _uploadedImages.removeAt(index);
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('图片已删除')),
    );
  }

  Future<void> _submitApplication() async {
    if (_noteController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写申请说明')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // TODO: 调用提交申请的API
      await Future.delayed(const Duration(seconds: 2)); // 模拟网络请求
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('申请提交成功！审核结果将在24-48小时内通知您'),
            backgroundColor: Colors.green,
          ),
        );
        
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('提交失败: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
} 