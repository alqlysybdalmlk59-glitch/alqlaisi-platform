import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../products/models/product.dart';
import '../products/product_catalog_page.dart';
import '../products/services/product_service.dart';

class CategoryPage extends StatefulWidget {
  const CategoryPage({super.key});
  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  late final ApiClient _api;
  late final ProductService _service;
  List<Product> _products = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _api = ApiClient();
    _service = ProductService(_api);
    _load();
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await _service.getPublishedProducts();
      if (mounted) setState(() => _products = result);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر تحميل التصنيفات.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = _products
        .map((product) => product.category.trim())
        .where((category) => category.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    Widget body;
    if (_loading && _products.isEmpty) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null && _products.isEmpty) {
      body = Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_error!),
        const SizedBox(height: 10),
        FilledButton(onPressed: _load, child: const Text('إعادة المحاولة')),
      ]));
    } else if (categories.isEmpty) {
      body = const Center(child: Text('لا توجد تصنيفات منشورة حالياً.'));
    } else {
      body = ListView(padding: const EdgeInsets.all(16), children: [
        const Text('اختر تصنيفاً لعرض المنتجات المتاحة.',
            style: TextStyle(color: AppTheme.muted)),
        const SizedBox(height: 12),
        ...categories.map((category) {
          final count = _products.where((p) => p.category == category && p.isAvailable).length;
          return Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.category_outlined)),
              title: Text(category),
              subtitle: Text('$count منتج متاح'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => ProductCatalogPage(title: category, category: category),
                ));
              },
            ),
          );
        }),
      ]);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('التصنيفات'),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      body: body,
    );
  }
}
