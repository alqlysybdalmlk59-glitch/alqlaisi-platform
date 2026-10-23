import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../products/product_catalog_page.dart';

class StoresPage extends StatefulWidget{
  const StoresPage({super.key});
  @override State<StoresPage> createState()=>_StoresPageState();
}
class _StoresPageState extends State<StoresPage>{
  late final ApiClient _api;bool _loading=true;String? _error;List<Map<String,dynamic>> _stores=[];
  @override void initState(){super.initState();_api=ApiClient();_load();}
  @override void dispose(){_api.close();super.dispose();}
  Future<void> _load()async{
    setState(()=>_loading=true);
    try{final data=await _api.get('/vendors/public');if(data is! List)throw const FormatException();
      if(mounted)setState(()=>_stores=data.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList());}
    on ApiException catch(e){if(mounted)setState(()=>_error=e.message);}
    catch(_){if(mounted)setState(()=>_error='تعذر تحميل المتاجر. تأكد من اتصال الخادم.');}
    finally{if(mounted)setState(()=>_loading=false);}
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('المتاجر المعتمدة'),actions:[IconButton(onPressed:_load,icon:const Icon(Icons.refresh))]),
    body:_loading&&_stores.isEmpty?const Center(child:CircularProgressIndicator())
      :_error!=null&&_stores.isEmpty?Center(child:Column(mainAxisSize:MainAxisSize.min,children:[Text(_error!),const SizedBox(height:10),FilledButton(onPressed:_load,child:const Text('إعادة المحاولة'))]))
      :_stores.isEmpty?const Center(child:Text('لا توجد متاجر معتمدة حالياً.'))
      :ListView.separated(padding:const EdgeInsets.all(16),itemCount:_stores.length,separatorBuilder:(_,__)=>const SizedBox(height:8),itemBuilder:(context,index){
        final store=_stores[index];
        return Card(child:ListTile(leading:const CircleAvatar(backgroundColor:Color(0xFFE0F0EA),child:Icon(Icons.storefront,color:AppTheme.primary)),
          title:Text((store['store_name']??'متجر القليسي').toString()),subtitle:Text('${store['description']??''}\nالتوصيل: يحسب لكل طلب وفق رسوم المتجر'),
          isThreeLine:true,trailing:const Icon(Icons.chevron_left),onTap:()=>Navigator.of(context).push(MaterialPageRoute<void>(
            builder:(_)=>ProductCatalogPage(title:(store['store_name']??'المنتجات').toString(),storeId:store['id']?.toString())))));
      }));
}
