import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';

import '../../core/cart/cart_scope.dart';
import '../../core/theme/app_theme.dart';
import '../cart/services/cart_service.dart';
import '../favorites/favorites_store.dart';
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
      appBar: AppBar(
        title: const Text('تفاصيل المنتج'),
        actions: [
          AnimatedBuilder(
            animation: FavoritesStore.instance,
            builder: (context, _) {
              final saved = FavoritesStore.instance.contains(product.id);
              return IconButton(
                tooltip: saved ? 'إزالة من المفضلة' : 'إضافة إلى المفضلة',
                icon: Icon(saved ? Icons.favorite : Icons.favorite_border),
                onPressed: () async {
                  try {
                    await FavoritesStore.instance.toggle(product);
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تعذر حفظ المفضلة على الجهاز.')),
                      );
                    }
                  }
                },
              );
            },
          ),
        ],
      ),
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
          const SizedBox(height: 20),
          _ProductReviews(productId: product.id),
          const SizedBox(height: 16),
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


class _ProductReviews extends StatefulWidget {
  const _ProductReviews({required this.productId});
  final String productId;

  @override
  State<_ProductReviews> createState() => _ProductReviewsState();
}

class _ProductReviewsState extends State<_ProductReviews> {
  late final ApiClient _api;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _reviews = [];

  @override
  void initState() {
    super.initState();
    _api = ApiClient();
    _load();
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _ProductReviews oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.productId != widget.productId) _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await _api.get(
        '/products/${Uri.encodeComponent(widget.productId)}/reviews',
      );
      if (result is! List) throw const FormatException('Invalid reviews response.');
      if (mounted) {
        setState(() => _reviews = result.whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row)).toList());
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر تحميل تقييمات المنتج.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _reviews.length;
    final average = total == 0
        ? 0.0
        : _reviews.fold<double>(
              0,
              (sum, review) => sum + ((review['rating'] as num?)?.toDouble() ?? 0),
            ) /
            total;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('تقييمات العملاء', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            if (!_loading && _error == null)
              Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber),
                  const SizedBox(width: 6),
                  Text(total == 0 ? 'لا توجد تقييمات بعد' : '${average.toStringAsFixed(1)} من 5 · $total تقييم'),
                ],
              ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_error!, style: const TextStyle(color: AppTheme.error)),
                  TextButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('إعادة المحاولة'),
                  ),
                ],
              )
            else if (_reviews.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('ستظهر هنا تقييمات العملاء الذين استلموا المنتج.'),
              )
            else
              ..._reviews.map((review) {
                final rating = (review['rating'] as num?)?.toInt() ?? 0;
                final comment = (review['comment'] ?? '').toString();
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                  title: Text((review['reviewer_name'] ?? 'عميل').toString()),
                  subtitle: comment.isEmpty ? null : Text(comment),
                  trailing: Text('${rating.clamp(0, 5)} ★',
                      style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                );
              }),
          ],
        ),
      ),
    );
  }
}
