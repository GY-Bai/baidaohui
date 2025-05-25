import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

class EcommerceModule extends StatefulWidget {
  final String? initialUrl;
  final List<String> supportedCurrencies;
  final Function(String)? onPaymentSuccess;
  final Function(String)? onPaymentFailure;

  const EcommerceModule({
    super.key,
    this.initialUrl,
    this.supportedCurrencies = const ['CNY', 'USD', 'CAD', 'SGD', 'AUD'],
    this.onPaymentSuccess,
    this.onPaymentFailure,
  });

  @override
  State<EcommerceModule> createState() => _EcommerceModuleState();
}

class _EcommerceModuleState extends State<EcommerceModule> {
  bool _isLoading = false;
  String _selectedCurrency = 'CAD';
  List<Map<String, dynamic>> _products = [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  void _loadProducts() {
    setState(() {
      _isLoading = true;
    });

    // 模拟加载商品数据
    Future.delayed(const Duration(seconds: 1), () {
      setState(() {
        _products = [
          {
            'id': '1',
            'name': '开运手链',
            'price': 88.0,
            'currency': _selectedCurrency,
            'image': 'assets/images/bracelet.jpg',
            'description': '精选天然水晶制作，助您开运转运',
          },
          {
            'id': '2',
            'name': '平安符',
            'price': 66.0,
            'currency': _selectedCurrency,
            'image': 'assets/images/amulet.jpg',
            'description': '大师亲自开光，保佑平安健康',
          },
          {
            'id': '3',
            'name': '招财摆件',
            'price': 168.0,
            'currency': _selectedCurrency,
            'image': 'assets/images/ornament.jpg',
            'description': '风水摆件，助您财运亨通',
          },
        ];
        _isLoading = false;
      });
    });
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _changeCurrency(String currency) {
    setState(() {
      _selectedCurrency = currency;
    });
    _loadProducts(); // 重新加载商品以更新价格
  }

  void _addToCart(Map<String, dynamic> product) {
    _showMessage('${product['name']} 已添加到购物车');
  }

  void _buyNow(Map<String, dynamic> product) {
    _showMessage('正在处理购买 ${product['name']}...');
    // TODO: 实现购买逻辑
  }

  @override
  Widget build(BuildContext context) {
    return FCard(
      child: Column(
        children: [
          // 工具栏
          _buildToolbar(),
          
          // 商品内容
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('正在加载商店...'),
                      ],
                    ),
                  )
                : _buildProductGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.theme.colors.muted,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
      ),
      child: Column(
        children: [
          // 第一行：标题和货币选择
          Row(
            children: [
              Icon(
                Icons.shopping_cart,
                size: 20,
                color: context.theme.colors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '百道会商店',
                style: context.theme.typography.base.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '货币: ',
                style: context.theme.typography.sm,
              ),
              DropdownButton<String>(
                value: _selectedCurrency,
                onChanged: (value) => _changeCurrency(value ?? 'CAD'),
                items: widget.supportedCurrencies.map((currency) =>
                  DropdownMenuItem(
                    value: currency,
                    child: Text(currency),
                  ),
                ).toList(),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // 第二行：操作按钮
          Row(
            children: [
              FButton(
                onPress: _loadProducts,
                style: FButtonStyle.secondary,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh, size: 16),
                    SizedBox(width: 4),
                    Text('刷新'),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FButton(
                onPress: () => _showMessage('查看购物车'),
                style: FButtonStyle.outline,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shopping_cart, size: 16),
                    SizedBox(width: 4),
                    Text('购物车'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductGrid() {
    if (_products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              size: 64,
              color: context.theme.colors.mutedForeground,
            ),
            const SizedBox(height: 16),
            Text(
              '暂无商品',
              style: context.theme.typography.lg.copyWith(
                color: context.theme.colors.mutedForeground,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: _products.length,
      itemBuilder: (context, index) {
        final product = _products[index];
        return _buildProductCard(product);
      },
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    return FCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 商品图片占位符
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: context.theme.colors.muted,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.image,
                  size: 48,
                  color: context.theme.colors.mutedForeground,
                ),
              ),
            ),
            
            const SizedBox(height: 8),
            
            // 商品名称
            Text(
              product['name'],
              style: context.theme.typography.sm.copyWith(
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            
            const SizedBox(height: 4),
            
            // 商品描述
            Text(
              product['description'],
              style: context.theme.typography.xs.copyWith(
                color: context.theme.colors.mutedForeground,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            
            const SizedBox(height: 8),
            
            // 价格
            Text(
              '${product['price']} ${product['currency']}',
              style: context.theme.typography.sm.copyWith(
                color: context.theme.colors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 8),
            
            // 操作按钮
            Row(
              children: [
                Expanded(
                  child: FButton(
                    onPress: () => _addToCart(product),
                    style: FButtonStyle.secondary,
                    child: const Text('加购物车'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FButton(
                    onPress: () => _buyNow(product),
                    style: FButtonStyle.primary,
                    child: const Text('立即购买'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class EcommercePaymentResult {
  final bool success;
  final String? orderId;
  final String? transactionId;
  final double? amount;
  final String? currency;
  final String? errorMessage;

  EcommercePaymentResult({
    required this.success,
    this.orderId,
    this.transactionId,
    this.amount,
    this.currency,
    this.errorMessage,
  });

  factory EcommercePaymentResult.fromUrl(String url) {
    final uri = Uri.parse(url);
    final params = uri.queryParameters;
    
    if (url.contains('payment_success')) {
      return EcommercePaymentResult(
        success: true,
        orderId: params['order_id'],
        transactionId: params['transaction_id'],
        amount: double.tryParse(params['amount'] ?? ''),
        currency: params['currency'],
      );
    } else {
      return EcommercePaymentResult(
        success: false,
        errorMessage: params['error'] ?? '支付失败',
      );
    }
  }
}

// 简化的电商模块，用于快速集成
class SimpleEcommerceModule extends StatelessWidget {
  final List<EcommerceProduct> products;
  final Function(EcommerceProduct)? onProductTap;

  const SimpleEcommerceModule({
    super.key,
    required this.products,
    this.onProductTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.shopping_bag, size: 20),
                SizedBox(width: 8),
                Text(
                  '推荐商品',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          
          // 商品列表
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.image, color: Colors.grey),
                    ),
                    title: Text(product.name),
                    subtitle: Text(product.description),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${product.price} ${product.currency}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        if (product.originalPrice != null)
                          Text(
                            '${product.originalPrice} ${product.currency}',
                            style: const TextStyle(
                              decoration: TextDecoration.lineThrough,
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                    onTap: () => onProductTap?.call(product),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class EcommerceProduct {
  final String id;
  final String name;
  final String description;
  final double price;
  final double? originalPrice;
  final String currency;
  final String? imageUrl;

  EcommerceProduct({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.originalPrice,
    this.currency = 'CAD',
    this.imageUrl,
  });
} 