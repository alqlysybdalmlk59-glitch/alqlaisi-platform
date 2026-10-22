import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';

class SupportPage extends StatefulWidget{
  const SupportPage({super.key,required this.token});
  final String token;
  @override State<SupportPage> createState()=>_SupportPageState();
}
class _SupportPageState extends State<SupportPage>{
  late final ApiClient _api;final _subject=TextEditingController(),_details=TextEditingController();
  List<Map<String,dynamic>> _tickets=[];bool _loading=true,_submitting=false;String? _error;
  @override void initState(){super.initState();_api=ApiClient();_load();}
  @override void dispose(){_api.close();_subject.dispose();_details.dispose();super.dispose();}
  Future<void> _load()async{
    setState(()=>_loading=true);
    try{final result=await _api.get('/support/mine',token:widget.token);
      if(result is! List)throw const FormatException();
      if(mounted)setState(()=>_tickets=result.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList());
    }on ApiException catch(e){if(mounted)setState(()=>_error=e.message);}
    catch(_){if(mounted)setState(()=>_error='تعذر تحميل تذاكر الدعم.');}
    finally{if(mounted)setState(()=>_loading=false);}
  }
  Future<void> _submit()async{
    if(_subject.text.trim().length<2||_details.text.trim().length<5){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('أدخل عنواناً وتفاصيل واضحة للمشكلة.')));return;}
    setState(()=>_submitting=true);
    try{await _api.post('/support/',token:widget.token,body:{'subject':_subject.text.trim(),'details':_details.text.trim()});
      _subject.clear();_details.clear();if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تم إرسال تذكرتك.')));await _load();
    }on ApiException catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.message)));}
    finally{if(mounted)setState(()=>_submitting=false);}
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('الدعم الفني'),actions:[IconButton(onPressed:_load,icon:const Icon(Icons.refresh))]),
    body:ListView(padding:const EdgeInsets.all(16),children:[
      const Text('أرسل استفسارك أو شكواك، وستتمكن من متابعة رد فريق المنصة.',style:TextStyle(color:AppTheme.muted)),
      const SizedBox(height:14),TextField(controller:_subject,decoration:const InputDecoration(labelText:'عنوان المشكلة')),
      const SizedBox(height:10),TextField(controller:_details,maxLines:4,decoration:const InputDecoration(labelText:'التفاصيل')),
      const SizedBox(height:10),FilledButton.icon(onPressed:_submitting?null:_submit,icon:const Icon(Icons.send),label:Text(_submitting?'جارٍ الإرسال...':'إرسال التذكرة')),
      const SizedBox(height:24),Text('تذاكري السابقة',style:Theme.of(context).textTheme.titleLarge),
      if(_loading&&_tickets.isEmpty)const Padding(padding:EdgeInsets.all(20),child:Center(child:CircularProgressIndicator()))
      else if(_error!=null&&_tickets.isEmpty)Text(_error!)
      else if(_tickets.isEmpty)const Padding(padding:EdgeInsets.all(20),child:Text('لا توجد تذاكر سابقة.'))
      else ..._tickets.map((t)=>Card(child:ListTile(leading:const Icon(Icons.support_agent,color:AppTheme.primary),
        title:Text((t['subject']??'تذكرة دعم').toString()),subtitle:Text('${t['details']??''}\nالحالة: ${t['status']??'مفتوحة'}\nرد المنصة: ${(t['response']??'').toString().isEmpty?'لم يتم الرد بعد':t['response']}'),isThreeLine:true))),
    ]));
}
