import 'package:flutter/material.dart';

import '../../core/cart/cart_scope.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../stores/stores_page.dart';
import '../favorites/favorites_page.dart';
import '../favorites/favorites_store.dart';
import '../notifications/notifications_page.dart';
import 'models/product.dart';
import 'product_details_page.dart';
import 'services/product_service.dart';

class ProductCatalogPage extends StatefulWidget {
  const ProductCatalogPage({super.key, required this.title, this.category, this.showStoresShortcut = false, this.accessToken});
  final String title;
  final String? category;
  final bool showStoresShortcut;
  final String? accessToken;
  @override State<ProductCatalogPage> createState() => _ProductCatalogPageState();
}

class _ProductCatalogPageState extends State<ProductCatalogPage> {
  late final ApiClient _api;
  late final ProductService _service;
  final _search = TextEditingController();
  List<Product> _products = [];
  bool _loading = true;
  String? _error;

  @override void initState() { super.initState(); _api=ApiClient(); _service=ProductService(_api); FavoritesStore.instance.load(); _load(); }
  @override void dispose() { _api.close(); _search.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() { _loading=true; _error=null; });
    try {
      final products=await _service.getPublishedProducts();
      if(mounted) setState(()=>_products=products);
    } on ApiException catch(e) {
      if(mounted)setState(()=>_error=e.message);
    } catch(_) {
      if(mounted)setState(()=>_error='تعذر تحميل المنتجات. تأكد من اتصال الخادم.');
    } finally { if(mounted)setState(()=>_loading=false); }
  }

  String _money(int value)=>value.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'),(_)=>',');

  @override Widget build(BuildContext context) {
    final query=_search.text.trim().toLowerCase();
    final visible=_products.where((p) {
      final matchCategory=widget.category==null||p.category==widget.category;
      final matchSearch=query.isEmpty||p.name.toLowerCase().contains(query)||p.storeName.toLowerCase().contains(query)||p.category.toLowerCase().contains(query);
      return matchCategory&&matchSearch;
    }).toList();
    return Scaffold(
      appBar: AppBar(title:Text(widget.title),actions:[
        if(widget.showStoresShortcut) IconButton(
          tooltip: 'المتاجر',
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const StoresPage())),
          icon: const Icon(Icons.storefront_outlined),
        ),
        if(widget.showStoresShortcut) IconButton(
          tooltip: 'المفضلة',
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const FavoritesPage())),
          icon: const Icon(Icons.favorite_border),
        ),
        if(widget.showStoresShortcut && widget.accessToken != null) IconButton(
          tooltip: 'تحديثات الطلبات',
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => NotificationsPage(token: widget.accessToken!),
          )),
          icon: const Icon(Icons.notifications_none),
        ),
        IconButton(tooltip:'تحديث المنتجات',onPressed:_load,icon:const Icon(Icons.refresh)),
      ]),
      body:RefreshIndicator(onRefresh:_load,child:ListView(padding:const EdgeInsets.all(16),children:[
        Container(
          padding:const EdgeInsets.all(18),
          decoration:BoxDecoration(color:AppTheme.primary.withValues(alpha:.08),borderRadius:BorderRadius.circular(18)),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Text('تسوّق من متاجر القليسي المعتمدة',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),
            const SizedBox(height:6),const Text('منتجات متاحة فقط، بأسعار معتمدة من إدارة المنصة.'),
            const SizedBox(height:14),TextField(controller:_search,onChanged:(_)=>setState(()=>{}),
              decoration:InputDecoration(hintText:'ابحث عن منتج أو متجر أو تصنيف',prefixIcon:const Icon(Icons.search),
                suffixIcon:_search.text.isEmpty?null:IconButton(onPressed:()=>setState(()=>_search.clear()),icon:const Icon(Icons.close)))),
          ]),
        ),
        const SizedBox(height:18),
        if(_loading&&_products.isEmpty) const Padding(padding:EdgeInsets.all(36),child:Center(child:CircularProgressIndicator()))
        else if(_error!=null&&_products.isEmpty) _ErrorBlock(message:_error!,onRetry:_load)
        else if(visible.isEmpty) Padding(padding:const EdgeInsets.all(30),child:Center(child:Text(query.isEmpty?'لا توجد منتجات منشورة ومتاحة حالياً.':'لا توجد نتائج مطابقة للبحث.')))
        else ...[
          Text(widget.category==null?'المنتجات المتاحة':'تصنيف: ${widget.category}',style:Theme.of(context).textTheme.titleLarge),
          const SizedBox(height:12),
          LayoutBuilder(builder:(context,constraints){
            final columns=constraints.maxWidth>900?4:constraints.maxWidth>600?3:2;
            return GridView.builder(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),
              itemCount:visible.length,gridDelegate:SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:columns,crossAxisSpacing:12,mainAxisSpacing:12,childAspectRatio:.67),
              itemBuilder:(context,index){
                final product=visible[index];
                return InkWell(borderRadius:BorderRadius.circular(16),onTap:()=>Navigator.of(context).push(MaterialPageRoute<void>(builder:(_)=>ProductDetailsPage(product:product))),
                  child:Card(clipBehavior:Clip.antiAlias,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                    Expanded(child:Container(width:double.infinity,color:const Color(0xFFF0F2EF),
                      child:product.imageUrl==null?const Center(child:Icon(Icons.image_outlined,size:52,color:AppTheme.muted)):
                        Image.network(product.imageUrl!,fit:BoxFit.cover,errorBuilder:(_,__,___)=>const Center(child:Icon(Icons.broken_image_outlined,size:42))))),
                    Padding(padding:const EdgeInsets.all(11),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                      Text(product.name,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.bold)),
                      const SizedBox(height:5),Text(product.storeName,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:AppTheme.muted,fontSize:11)),
                      const SizedBox(height:8),Text('${_money(product.price)} ريال',style:const TextStyle(color:AppTheme.primary,fontWeight:FontWeight.bold)),
                      const SizedBox(height:7),SizedBox(width:double.infinity,child:OutlinedButton.icon(
                        onPressed:product.isAvailable?()=>_add(product):null,icon:const Icon(Icons.add_shopping_cart,size:17),label:const Text('إضافة',maxLines:1))),
                    ])),
                  ])));
              });
          }),
        ],
      ])),
    );
  }

  void _add(Product product) {
    try {
      CartScope.of(context).add(product);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تمت إضافة «${product.name}» للسلة.')));
    } catch(e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));
    }
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.message,required this.onRetry});
  final String message; final VoidCallback onRetry;
  @override Widget build(BuildContext context)=>Center(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[
    const Icon(Icons.cloud_off_outlined,size:42,color:AppTheme.muted),const SizedBox(height:10),Text(message,textAlign:TextAlign.center),
    const SizedBox(height:12),FilledButton.icon(onPressed:onRetry,icon:const Icon(Icons.refresh),label:const Text('إعادة المحاولة')),
  ])));
}
