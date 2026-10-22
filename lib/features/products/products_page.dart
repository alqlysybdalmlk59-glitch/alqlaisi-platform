import 'package:flutter/material.dart';
import 'product_catalog_page.dart';

class ProductsPage extends StatelessWidget {
  const ProductsPage({super.key,this.category});
  final String? category;
  @override Widget build(BuildContext context)=>ProductCatalogPage(title:category==null?'المنتجات':'منتجات التصنيف',category:category);
}
