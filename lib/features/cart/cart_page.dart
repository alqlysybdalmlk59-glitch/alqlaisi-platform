import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../products/models/product.dart';
import 'models/cart_item.dart';
import 'services/cart_service.dart';

class CartPage extends StatefulWidget {
  const CartPage({
    super.key,
    required this.cartService,
    required this.onCheckout,
  });

  final CartService cartService;
  final VoidCallback onCheckout;

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  @override
  void initState() {
    super.initState();
    widget.cartService.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant CartPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.cartService != widget.cartService) {
      oldWidget.cartService.removeListener(_refresh);
      widget.cartService.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    widget.cartService.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  String _money(int amount) {
    return '${amount.toString().replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (_) => ',',
        )} ريال';
  }

  @override
  Widget build(BuildContext context) {
    final cart = widget.cartService;
    final items = cart.items;

    return Scaffold(
      appBar: AppBar(
        title: const Text('سلة المشتريات'),
        actions: [
          if (items.isNotEmpty)
            IconButton(
              tooltip: 'إفراغ السلة',
              onPressed: () => _confirmClear(context),
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: items.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 64,
                    color: AppTheme.muted,
                  ),
                  SizedBox(height: 12),
                  Text('سلتك فارغة حاليًا.'),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ...items.map((item) => _CartItemTile(
                      item: item,
                      money: _money,
                      onIncrease: () => cart.increase(item.product.id),
                      onDecrease: () => cart.decrease(item.product.id),
                      onRemove: () => cart.remove(item.product.id),
                    )),
                const SizedBox(height: 20),
                _StoreBreakdown(cart: cart, money: _money),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'المجموع الفرعي',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          _money(cart.subtotal),
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (cart.hasUnavailableItems) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'توجد منتجات غير متوفرة. أزلها أو انتظر حتى تتوفر قبل متابعة الطلب.',
                    style: TextStyle(color: AppTheme.error),
                  ),
                ],
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed:
                      cart.hasUnavailableItems ? null : widget.onCheckout,
                  child: const Text('متابعة إتمام الطلب'),
                ),
                const SizedBox(height: 12),
                const Text(
                  'رسوم التوصيل تُحدد لكل طلب تابع لمتجر على حدة، '
                  'وتُضاف بعد حساب الرسوم الفعلية.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إفراغ السلة؟'),
        content: const Text('سيتم حذف جميع العناصر من سلتك.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('إفراغ'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      widget.cartService.clear();
    }
  }
}

class _CartItemTile extends StatelessWidget {
  const _CartItemTile({
    required this.item,
    required this.money,
    required this.onIncrease,
    required this.onDecrease,
    required this.onRemove,
  });

  final CartItem item;
  final String Function(int) money;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final Product product = item.product;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 76,
              height: 86,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F2EF),
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: product.imageUrl == null
                  ? const Icon(
                      Icons.image_outlined,
                      color: AppTheme.muted,
                    )
                  : Image.network(
                      product.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.broken_image_outlined,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    product.storeName,
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    money(product.price),
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _QuantityButton(
                        icon: Icons.remove,
                        onPressed: onDecrease,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('${item.quantity}'),
                      ),
                      _QuantityButton(
                        icon: Icons.add,
                        onPressed: onIncrease,
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'حذف المنتج',
                        onPressed: onRemove,
                        icon: const Icon(
                          Icons.delete_outline,
                          color: AppTheme.error,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: IconButton.filledTonal(
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        icon: Icon(icon, size: 17),
      ),
    );
  }
}

class _StoreBreakdown extends StatelessWidget {
  const _StoreBreakdown({
    required this.cart,
    required this.money,
  });

  final CartService cart;
  final String Function(int) money;

  @override
  Widget build(BuildContext context) {
    final groups = cart.itemsByStore;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ملخص حسب المتجر',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ...groups.entries.map((entry) {
              final storeItems = entry.value;
              final storeName = storeItems.first.product.storeName;
              final total = storeItems.fold<int>(
                0,
                (sum, item) => sum + item.lineTotal,
              );

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        storeName.isEmpty ? 'متجر' : storeName,
                      ),
                    ),
                    Text(money(total)),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            const Text(
              'سيُنشأ طلب مستقل لكل متجر عند إتمام الشراء.',
              style: TextStyle(
                color: AppTheme.muted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
