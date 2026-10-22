import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../support/support_page.dart';

const String _googleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

class ProfilePage extends StatefulWidget{
  const ProfilePage({super.key,required this.token,required this.onLogout});
  final String token;final Future<void> Function() onLogout;
  @override State<ProfilePage> createState()=>_ProfilePageState();
}
class _ProfilePageState extends State<ProfilePage>{
  late final ApiClient _api;Map<String,dynamic>? _user;Map<String,dynamic>? _store;
  bool _loading=true,_applying=false,_linkingGoogle=false;String? _error;
  @override void initState(){super.initState();_api=ApiClient();_load();}
  @override void dispose(){_api.close();super.dispose();}
  Future<void> _load()async{
    setState(()=>_loading=true);
    try{
      final user=await _api.get('/auth/me',token:widget.token);
      final store=await _api.get('/vendors/mine',token:widget.token);
      if (mounted) {
        setState(() {
          _user = Map<String, dynamic>.from(user as Map);
          _store = store is Map ? Map<String, dynamic>.from(store) : null;
          _error = null;
        });
      }
    }on ApiException catch(e){if(mounted)setState(()=>_error=e.message);}
    catch(_){if(mounted)setState(()=>_error='تعذر تحميل الملف الشخصي.');}
    finally{if(mounted)setState(()=>_loading=false);}
  }
  Future<void> _linkGoogle() async {
    if (_linkingGoogle) return;
    if (_googleServerClientId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('إعداد Google OAuth غير موجود في نسخة التطبيق هذه.')),
      );
      return;
    }
    setState(() => _linkingGoogle = true);
    try {
      final account = await GoogleSignIn(serverClientId: _googleServerClientId).signIn();
      if (account == null) return;
      final authentication = await account.authentication;
      final idToken = authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const ApiException(message: 'لم يصل رمز Google. تحقق من إعداد OAuth.');
      }
      final response = await _api.post(
        '/auth/google/link',
        token: widget.token,
        body: {'id_token': idToken},
      );
      if (response is! Map || response['user'] is! Map) {
        throw const ApiException(message: 'استجابة ربط Google غير صحيحة.');
      }
      if (mounted) {
        setState(() => _user = Map<String, dynamic>.from(response['user'] as Map));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم التحقق من Google وربطه بهذا الحساب.')),
        );
      }
    } on ApiException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر ربط Google. لم يتم تعديل الحساب؛ تحقق من الإعدادات والاتصال.')),
      );
    } finally {
      if (mounted) setState(() => _linkingGoogle = false);
    }
  }

  Future<void> _applyStore()async{
    final key=GlobalKey<FormState>();final name=TextEditingController(),phone=TextEditingController(text:(_user?['phone']??'').toString()),description=TextEditingController();
    final submit=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('طلب فتح متجر'),
      content:Form(key:key,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextFormField(controller:name,decoration:const InputDecoration(labelText:'اسم المتجر'),validator:(v)=>v==null||v.trim().length<2?'أدخل اسم المتجر.':null),
        const SizedBox(height:10),TextFormField(controller:phone,decoration:const InputDecoration(labelText:'رقم التواصل'),validator:(v)=>v==null||v.trim().length<7?'تحقق من رقم الهاتف.':null),
        const SizedBox(height:10),TextField(controller:description,maxLines:3,decoration:const InputDecoration(labelText:'وصف المتجر')),
      ]))),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(ctx,key.currentState?.validate()==true),child:const Text('إرسال'))]));
    if(submit==true){
      setState(()=>_applying=true);
      try{await _api.post('/vendors/register',token:widget.token,body:{'store_name':name.text.trim(),'phone':phone.text.trim(),'description':description.text.trim()});
        if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تم إرسال طلب المتجر للمراجعة.')));await _load();
      }on ApiException catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.message)));}
      finally{if(mounted)setState(()=>_applying=false);}
    }
    name.dispose();phone.dispose();description.dispose();
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('حسابي'),actions:[IconButton(onPressed:_load,icon:const Icon(Icons.refresh))]),
    body:_loading&&_user==null?const Center(child:CircularProgressIndicator()):ListView(padding:const EdgeInsets.all(16),children:[
      Container(padding:const EdgeInsets.all(22),decoration:BoxDecoration(color:AppTheme.primary.withValues(alpha:.08),borderRadius:BorderRadius.circular(18)),
        child:Column(children:[const CircleAvatar(radius:34,child:Icon(Icons.person,size:36)),const SizedBox(height:12),
          Text((_user?['full_name']??_user?['name']??'المستخدم').toString(),style:Theme.of(context).textTheme.titleLarge),
          Text((_user?['phone']??'').toString()),Text((_user?['email']??'لا يوجد بريد مسجل').toString()),
          const SizedBox(height:8),Chip(label:Text('الدور: ${_user?['role']??'customer'}')),
        ])),
      if(_error!=null)Padding(padding:const EdgeInsets.all(8),child:Text(_error!,style:const TextStyle(color:AppTheme.error))),
      const SizedBox(height:10),
      Card(child:ListTile(
        leading:Icon((_user?['google_linked'] == true) ? Icons.verified_user : Icons.g_mobiledata,
          color: (_user?['google_linked'] == true) ? Colors.green : AppTheme.primary, size: 30),
        title:Text((_user?['google_linked'] == true) ? 'حساب Google موثّق' : 'ربط حساب Google'),
        subtitle:Text((_user?['google_linked'] == true)
          ? 'تم ربط هوية Google بهذا الحساب بعد التحقق من الخادم.'
          : 'يتطلب تسجيل الدخول الحالي ثم التحقق من رمز Google على الخادم.'),
        trailing: (_user?['google_linked'] == true)
          ? const Icon(Icons.check_circle, color: Colors.green)
          : (_linkingGoogle ? const SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2)) : const Icon(Icons.chevron_left)),
        onTap: (_user?['google_linked'] == true || _linkingGoogle) ? null : _linkGoogle,
      )),
      Card(child:ListTile(leading:const Icon(Icons.support_agent),title:const Text('الدعم الفني والشكاوى'),subtitle:const Text('إرسال تذكرة ومتابعة الردود'),trailing:const Icon(Icons.chevron_left),
        onTap:()=>Navigator.of(context).push(MaterialPageRoute<void>(builder:(_)=>SupportPage(token:widget.token))))),
      Card(child:ListTile(leading:const Icon(Icons.storefront),title:const Text('حساب البائع والمتجر'),
        subtitle:Text(_store==null?'لم تقدم طلب متجر بعد.': '${_store?['store_name']??''} · ${_store?['status']??'قيد المراجعة'}'),
        trailing:const Icon(Icons.chevron_left),
        onTap:(_store==null || _store?['status']=='مرفوض')&&!_applying?_applyStore:null)),
      if(_store==null || _store?['status']=='مرفوض')
        Padding(padding:const EdgeInsets.only(top:8),child:FilledButton.icon(
          onPressed:_applying?null:_applyStore,
          icon:const Icon(Icons.add_business),
          label:Text(_applying?'جارٍ الإرسال...':_store==null?'طلب فتح متجر':'إعادة تقديم طلب المتجر'))),
      const SizedBox(height:20),OutlinedButton.icon(onPressed:widget.onLogout,icon:const Icon(Icons.logout),label:const Text('تسجيل الخروج')),
    ]));
}
