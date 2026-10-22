import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';

class OrdersPage extends StatefulWidget{
  const OrdersPage({super.key,required this.token});
  final String token;
  @override State<OrdersPage> createState()=>_OrdersPageState();
}
class _OrdersPageState extends State<OrdersPage>{
  late final ApiClient _api;bool _loading=true;String? _error;List<Map<String,dynamic>> _orders=[];
  @override void initState(){super.initState();_api=ApiClient();_load();}
  @override void didUpdateWidget(covariant OrdersPage oldWidget){super.didUpdateWidget(oldWidget);if(oldWidget.token!=widget.token)_load();}
  @override void dispose(){_api.close();super.dispose();}
  Future<void> _load()async{
    setState(()=>_loading=true);
    try{
      final me=await _api.get('/auth/me',token:widget.token);
      if(me is! Map||(me['id']??'').toString().isEmpty)throw const FormatException();
      final result=await _api.get('/orders/client/${Uri.encodeComponent(me['id'].toString())}',token:widget.token);
      if(result is! List)throw const FormatException();
      if(mounted)setState(()=>_orders=result.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList());
    }on ApiException catch(e){if(mounted)setState(()=>_error=e.message);}
    catch(_){if(mounted)setState(()=>_error='تعذر تحميل الطلبات.');}
    finally{if(mounted)setState(()=>_loading=false);}
  }
  String _status(String value)=>value.isEmpty?'قيد المعالجة':value;
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('طلباتي'),actions:[IconButton(onPressed:_load,icon:const Icon(Icons.refresh))]),
    body:RefreshIndicator(onRefresh:_load,child:_loading&&_orders.isEmpty?const Center(child:CircularProgressIndicator())
      :_error!=null&&_orders.isEmpty?ListView(children:[const SizedBox(height:100),Center(child:Text(_error!)),const SizedBox(height:12),Center(child:FilledButton(onPressed:_load,child:const Text('إعادة المحاولة')))])
      :_orders.isEmpty?ListView(children:[const SizedBox(height:140),const Icon(Icons.receipt_long_outlined,size:58,color:AppTheme.muted),const SizedBox(height:12),const Center(child:Text('لا توجد طلبات حتى الآن.'))])
      :ListView.separated(padding:const EdgeInsets.all(14),itemCount:_orders.length,separatorBuilder:(_,__)=>const SizedBox(height:8),itemBuilder:(context,index){
        final o=_orders[index];List<dynamic> items=[];
        try{final parsed=jsonDecode((o['items_json']??'[]').toString());if(parsed is List)items=parsed;}catch(_){}
        final total=(o['total_price'] as num?)?.toDouble()??0;
        return Card(child:ExpansionTile(leading:const Icon(Icons.receipt_long,color:AppTheme.primary),
          title:Text('طلب ${o['id']??''}'),subtitle:Text('${_status((o['status']??'').toString())} · الإجمالي ${total.toStringAsFixed(0)} ريال'),
          childrenPadding:const EdgeInsets.all(16),children:[
            Align(alignment:Alignment.centerRight,child:Text('المتجر: ${o['vendor_name']??''}')),
            const SizedBox(height:6),
            ...items.whereType<Map>().map((item)=>ListTile(dense:true,title:Text((item['title']??'منتج').toString()),subtitle:Text('الكمية: ${item['quantity']??1}'),trailing:Text('${item['line_total']??0} ريال'))),
            const Divider(),Align(alignment:Alignment.centerRight,child:Text('التوصيل: ${o['delivery_fee']??0} ريال')),
            Align(alignment:Alignment.centerRight,child:Text('طريقة الدفع: ${o['payment_method']??'الدفع عند الاستلام'}')),
            Align(alignment:Alignment.centerRight,child:Text('العنوان: ${o['address']??''}')),
          ]));
      })));
}
