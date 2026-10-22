import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../products/models/product.dart';

class FavoritesStore extends ChangeNotifier {
  FavoritesStore._();
  static final FavoritesStore instance = FavoritesStore._();
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _key = 'alqlaisi_favorite_products_v1';
  final Map<String, Product> _products = {};
  bool _loaded = false;
  Future<void>? _loading;

  List<Product> get products => List<Product>.unmodifiable(_products.values);
  bool contains(String id) => _products.containsKey(id);

  Future<void> load() async {
    if (_loaded) return;
    final pending = _loading;
    if (pending != null) return pending;
    final future = _readStorage();
    _loading = future;
    try { await future; } finally { _loading = null; }
  }

  Future<void> _readStorage() async {
    final raw = await _storage.read(key: _key);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final row in decoded.whereType<Map>()) {
            final item = Product.fromJson(Map<String, dynamic>.from(row));
            if (item.id.isNotEmpty) _products[item.id] = item;
          }
        }
      } on FormatException {
        await _storage.delete(key: _key);
      }
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> toggle(Product product) async {
    await load();
    if (_products.containsKey(product.id)) {
      _products.remove(product.id);
    } else {
      _products[product.id] = product;
    }
    await _save();
    notifyListeners();
  }

  Future<void> remove(String productId) async {
    await load();
    _products.remove(productId);
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    final rows = _products.values.map((p) => <String, dynamic>{
      'id': p.id,
      'title': p.name,
      'description': p.description,
      'price': p.price,
      'image_url': p.imageUrl,
      'vendor_id': p.storeId,
      'vendor_name': p.storeName,
      'is_available': p.isAvailable,
      'category': p.category,
    }).toList();
    await _storage.write(key: _key, value: jsonEncode(rows));
  }
}
