import 'package:flutter/material.dart';
import '../../core/cart/cart_scope.dart';
import '../../core/theme/app_theme.dart';
import '../products/models/product.dart';
import '../products/product_details_page.dart';
import 'favorites_store.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});
  @override State<FavoritesPage> createState() => _FavoritesPageState();
}
class _FavoritesPageState extends State<FavoritesPage> {
  bool _loading = true;
  String? _error;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try { await FavoritesStore.instance.load(); }
    catch (_) { if (mounted) setState(() => _error = 'تعذر تحميل المفضلة من الجهاز.'); }
    finally { if (mounted) setState(() => _loading = false); }
  }
  String _money(int value) => value.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('المفضلة'),
      actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
    body: _loading ? const Center(child: CircularProgressIndicator())
      : _error != null ? Center(child: Text(_error!))
      : AnimatedBuilder(
        animation: FavoritesStore.instance,
        builder: (context, _) {
          final items = FavoritesStore.instance.products;
          if (items.isEmpty) {
            return const Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.favorite_border, size: 56, color: AppTheme.muted),
                SizedBox(height: 12),
                Text('لم تضف منتجات إلى المفضلة بعد.'),
                SizedBox(height: 6),
                Text('افتح تفاصيل منتج واضغط على القلب لحفظه هنا.'),
              ]),
            ));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _card(context, items[index]),
          );
        },
      ),
  );
  Widget _card(BuildContext context, Product product) => Card(
    child: ListTile(
      leading: SizedBox(
        width: 52, height: 52,
        child: product.imageUrl == null
          ? const Icon(Icons.image_outlined)
          : Image.network(product.imageUrl!, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined)),
      ),
      title: Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text('${_money(product.price)} ريال · ${product.storeName}'),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => ProductDetailsPage(product: product))),
      trailing: PopupMenuButton<String>(
        onSelected: (value) async {
          if (value == 'remove') await FavoritesStore.instance.remove(product.id);
          if (value == 'cart') {
            try {
              CartScope.of(context).add(product);
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تمت إضافة المنتج إلى السلة.')));
            } catch (error) {
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(error.toString())));
            }
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'cart', child: Text('إضافة إلى السلة')),
          PopupMenuItem(value: 'remove', child: Text('إزالة من المفضلة')),
        ],
      ),
    ),
  );
}
