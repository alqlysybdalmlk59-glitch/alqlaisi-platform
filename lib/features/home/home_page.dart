import 'package:flutter/material.dart';
import '../products/product_catalog_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override Widget build(BuildContext context)=>const ProductCatalogPage(title:'الرئيسية',showStoresShortcut:true);
}
