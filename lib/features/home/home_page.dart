import 'package:flutter/material.dart';
import '../products/product_catalog_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.token});
  final String token;
  @override
  Widget build(BuildContext context) => ProductCatalogPage(
    title: 'الرئيسية',
    showStoresShortcut: true,
    accessToken: token,
  );
}
