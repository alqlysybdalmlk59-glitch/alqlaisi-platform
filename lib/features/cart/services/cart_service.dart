import 'package:flutter/foundation.dart';

import '../../products/models/product.dart';
import '../models/cart_item.dart';

class CartService extends ChangeNotifier {
  final Map<String, CartItem> _items = {};

  List<CartItem> get items => List.unmodifiable(_items.values);

  int get itemCount =>
      _items.values.fold(0, (total, item) => total + item.quantity);

  int get subtotal =>
      _items.values.fold(0, (total, item) => total + item.lineTotal);

  bool get isEmpty => _items.isEmpty;

  bool get hasUnavailableItems =>
      _items.values.any((item) => !item.isAvailable);

  void add(Product product) {
    if (!product.isAvailable) {
      throw StateError('هذا المنتج غير متوفر حاليًا.');
    }

    final existing = _items[product.id];

    if (existing == null) {
      _items[product.id] = CartItem(product: product);
    } else {
      existing.increase();
    }

    notifyListeners();
  }

  void increase(String productId) {
    final item = _items[productId];
    if (item == null || !item.isAvailable) return;

    item.increase();
    notifyListeners();
  }

  void decrease(String productId) {
    final item = _items[productId];
    if (item == null) return;

    item.decrease();
    notifyListeners();
  }

  void remove(String productId) {
    _items.remove(productId);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }

  Map<String, List<CartItem>> get itemsByStore {
    final grouped = <String, List<CartItem>>{};

    for (final item in _items.values) {
      grouped.putIfAbsent(item.storeId, () => []).add(item);
    }

    return grouped;
  }
}
