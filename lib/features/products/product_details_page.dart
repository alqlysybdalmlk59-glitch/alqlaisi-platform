import 'package:flutter/material.dart';

import '../../core/cart/cart_scope.dart';
import '../../core/theme/app_theme.dart';
import '../cart/services/cart_service.dart';
import 'models/product.dart';

class ProductDetailsPage extends StatelessWidget {
  const ProductDetailsPage({
    super.key,
    required this.product,
  });

  final Product product;

  String _formatPrice(int value) {
    return value.toString().replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (_) => ',',
        );
  }

  @override
  Widget build(BuildContext context) {
    final available = product.isAvailable;

    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل المنتج')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                color: const Color(0xFFF0F2EF),
                child: product.imageUrl == null
                    ? const Icon(
                        Icons.image_outlined,
                        size: 100,
                        color: AppTheme.muted,
                      )
                    : Image.network(
                        product.imageUrl!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.broken_image_outlined,
                          size: 80,
                          color: AppTheme.muted,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            product.name,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 10),
          Text(
            '${_formatPrice(product.price)} ريال',
            style: const TextStyle(
              color: AppTheme.primary,
              fontSize: 23,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.storefront_outlined,
              color: AppTheme.muted,
            ),
            title: Text(
              product.storeName.isEmpty ? 'المتجر' : product.storeName,
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              available
                  ? Icons.check_circle_outline
                  : Icons.remove_circle_outline,
              color: available ? AppTheme.primary : AppTheme.error,
            ),
            title: Text(
              available ? 'متوفر' : 'غير متوفر مؤقتًا',
              style: TextStyle(
                color: available ? AppTheme.primary : AppTheme.error,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'وصف المنتج',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            product.description.isEmpty
                ? 'لا يوجد وصف إضافي لهذا المنتج حاليًا.'
                : product.description,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: available ? () => _addToCart(context) : null,
            icon: const Icon(Icons.add_shopping_cart),
            label: const Text('إضافة إلى السلة'),
          ),
        ],
      ),
    );
  }

  void _addToCart(BuildContext context) {
    final CartService cart = CartScope.of(context);

    try {
      cart.add(product);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تمت إضافة "${product.name}" إلى السلة.'),
          action: SnackBarAction(
            label: 'عرض السلة',
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ),
      );
    } on StateError catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }
}
