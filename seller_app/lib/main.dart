import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8000/api');
const brand = Color(0xFF145B4D);

void main() => runApp(const SellerApp());

class ApiFailure implements Exception {
  const ApiFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class PlatformApi {
  PlatformApi({http.Client? client, this.baseUrl = apiBaseUrl}) : _client = client ?? http.Client();
  final http.Client _client;
  final String baseUrl;
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'alqlaisi_seller_token';

  Future<String?> readToken() => _storage.read(key: _tokenKey);
  Future<void> saveToken(String token) => _storage.write(key: _tokenKey, value: token);
  Future<void> clearToken() => _storage.delete(key: _tokenKey);

  Future<dynamic> request(String path, {String method = 'GET', String? token, Map<String, dynamic>? body}) async {
    final uri = Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}$path');
    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if ((token ?? '').isNotEmpty) 'Authorization': 'Bearer $token',
    };
    late http.Response response;
    try {
      if (method == 'POST') {
        response = await _client.post(uri, headers: headers, body: body == null ? null : jsonEncode(body));
      } else if (method == 'PUT') {
        response = await _client.put(uri, headers: headers, body: body == null ? null : jsonEncode(body));
      } else {
        response = await _client.get(uri, headers: headers);
      }
    } catch (_) {
      throw const ApiFailure('تعذر الاتصال بالخادم. تحقق من تشغيل API وعنوان الاتصال.');
    }
    dynamic data;
    try { data = response.body.isEmpty ? null : jsonDecode(response.body); } catch (_) {}
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = data is Map ? (data['detail'] ?? data['message']) : null;
      throw ApiFailure(detail?.toString() ?? 'حدث خطأ من الخادم (${response.statusCode}).');
    }
    return data;
  }

  Future<Map<String, dynamic>> login(String phone, String password) async {
    final result = await request('/auth/login', method: 'POST', body: {'phone': phone.trim(), 'password': password});
    if (result is! Map || (result['access_token'] ?? '').toString().isEmpty) throw const ApiFailure('لم يُرجع الخادم جلسة دخول صالحة.');
    final token = result['access_token'].toString();
    await saveToken(token);
    return me(token);
  }
  Future<Map<String, dynamic>> me(String token) async {
    final result = await request('/auth/me', token: token);
    if (result is! Map) throw const ApiFailure('استجابة الحساب غير صالحة.');
    return Map<String, dynamic>.from(result);
  }
  Future<Map<String, dynamic>?> myStore(String token) async {
    final result = await request('/vendors/mine', token: token);
    if (result == null) return null;
    if (result is! Map) throw const ApiFailure('بيانات المتجر غير صالحة.');
    return Map<String, dynamic>.from(result);
  }
  Future<Map<String, dynamic>> applyStore(String token, String name, String phone, String description) async {
    final result = await request('/vendors/register', method: 'POST', token: token,
      body: {'store_name': name.trim(), 'phone': phone.trim(), 'description': description.trim()});
    if (result is! Map) throw const ApiFailure('لم يتم استلام بيانات طلب المتجر.');
    return Map<String, dynamic>.from(result);
  }
  Future<List<Map<String, dynamic>>> products(String token, String storeId) async =>
      _list(await request('/products/vendor/${Uri.encodeComponent(storeId)}', token: token));
  Future<List<Map<String, dynamic>>> orders(String token, String storeId) async =>
      _list(await request('/orders/vendor/${Uri.encodeComponent(storeId)}', token: token));
  Future<void> createProduct(String token, String title, String description, String imageUrl, String category) async {
    await request('/products/', method: 'POST', token: token, body: {
      'title': title.trim(), 'description': description.trim(), 'image_url': imageUrl.trim(),
      'category': category.trim().isEmpty ? 'عام' : category.trim(),
    });
  }
  Future<void> setAvailability(String token, String productId, bool available) async {
    await request('/products/${Uri.encodeComponent(productId)}/availability',
      method: 'PUT', token: token, body: {'is_available': available});
  }
  Future<void> changeOrderStatus(String token, String orderId, String status) async {
    await request('/orders/${Uri.encodeComponent(orderId)}/status?status=${Uri.encodeQueryComponent(status)}',
      method: 'PUT', token: token);
  }
  static List<Map<String, dynamic>> _list(dynamic value) {
    if (value is! List) throw const ApiFailure('صيغة قائمة البيانات القادمة من الخادم غير صحيحة.');
    return value.whereType<Map>().map((v) => Map<String, dynamic>.from(v)).toList();
  }
  void dispose() => _client.close();
}

class SellerApp extends StatefulWidget {
  const SellerApp({super.key});
  @override State<SellerApp> createState() => _SellerAppState();
}
class _SellerAppState extends State<SellerApp> {
  final _api = PlatformApi();
  String? _token;
  Map<String, dynamic>? _user, _store;
  bool _starting = true;
  @override void initState() { super.initState(); _restore(); }
  @override void dispose() { _api.dispose(); super.dispose(); }
  Future<void> _restore() async {
    try {
      final token = await _api.readToken();
      if (token != null && token.isNotEmpty) {
        final user = await _api.me(token);
        if (mounted) {
          setState(() { _token = token; _user = user; });
          await _loadStore();
        }
      }
    } catch (_) {
      await _api.clearToken();
      if (mounted) setState(() { _token = null; _user = null; _store = null; });
    }
    finally { if (mounted) setState(() => _starting = false); }
  }
  Future<void> _login(String phone, String password) async {
    final user = await _api.login(phone, password);
    final token = await _api.readToken();
    if (!mounted) return;
    if (token == null) throw const ApiFailure('تعذر حفظ الجلسة الآمنة.');
    setState(() { _token = token; _user = user; _store = null; });
    await _loadStore();
  }
  Future<void> _loadStore() async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    final store = await _api.myStore(token);
    if (mounted) setState(() => _store = store);
  }
  Future<void> _logout() async {
    await _api.clearToken();
    if (mounted) setState(() { _token = null; _user = null; _store = null; });
  }
  @override Widget build(BuildContext context) => MaterialApp(
    title: 'Alqlaisi Seller', debugShowCheckedModeBanner: false,
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: brand), useMaterial3: true,
      inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder())),
    builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child ?? const SizedBox()),
    home: _starting ? const Scaffold(body: Center(child: CircularProgressIndicator()))
      : (_token == null || _user == null ? LoginScreen(onLogin: _login)
      : (_store == null ? StoreApplicationScreen(user: _user!, api: _api, token: _token!,
          onApplied: (store) => setState(() => _store = store), onLogout: _logout)
      : (_store!['status'] != 'مفعل' ? PendingStoreScreen(store: _store!, onRefresh: _loadStore, onLogout: _logout)
      : SellerDashboard(api: _api, token: _token!, user: _user!, store: _store!, onLogout: _logout)))),
  );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onLogin});
  final Future<void> Function(String phone, String password) onLogin;
  @override State<LoginScreen> createState() => _LoginScreenState();
}
class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController(), _password = TextEditingController();
  bool _busy = false; String? _error;
  @override void dispose() { _phone.dispose(); _password.dispose(); super.dispose(); }
  Future<void> _submit() async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try { await widget.onLogin(_phone.text, _password.text); }
    catch (e) { if (mounted) setState(() => _error = e is ApiFailure ? e.message : 'تعذر تسجيل الدخول.'); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  @override Widget build(BuildContext context) => Scaffold(body: Center(child: SingleChildScrollView(
    padding: const EdgeInsets.all(24), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 430),
    child: Card(child: Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Icon(Icons.storefront, size: 58, color: brand), const SizedBox(height: 12),
      Text('Alqlaisi', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8), const Text('بوابة البائعين المعتمدين', textAlign: TextAlign.center),
      const SizedBox(height: 24),
      TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الهاتف', prefixIcon: Icon(Icons.phone))),
      const SizedBox(height: 12), TextField(controller: _password, obscureText: true,
        decoration: const InputDecoration(labelText: 'كلمة المرور', prefixIcon: Icon(Icons.lock_outline)),
        onSubmitted: (_) => _submit()),
      if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: Colors.red))),
      const SizedBox(height: 18), FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? 'جارٍ التحقق...' : 'تسجيل الدخول')),
      const SizedBox(height: 10), Text('يجب اعتماد المتجر من الإدارة قبل إضافة المنتجات ونشرها.', style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
    ])))))));

class StoreApplicationScreen extends StatefulWidget {
  const StoreApplicationScreen({super.key, required this.user, required this.api, required this.token, required this.onApplied, required this.onLogout});
  final Map<String, dynamic> user; final PlatformApi api; final String token;
  final ValueChanged<Map<String, dynamic>> onApplied; final VoidCallback onLogout;
  @override State<StoreApplicationScreen> createState() => _StoreApplicationScreenState();
}
class _StoreApplicationScreenState extends State<StoreApplicationScreen> {
  final _name = TextEditingController(), _phone = TextEditingController(), _description = TextEditingController();
  bool _busy = false; String? _error;
  @override void initState() { super.initState(); _name.text=(widget.user['full_name']??widget.user['name']??'').toString(); _phone.text=(widget.user['phone']??'').toString(); }
  @override void dispose() { _name.dispose(); _phone.dispose(); _description.dispose(); super.dispose(); }
  Future<void> _apply() async {
    if (_name.text.trim().length < 2 || _phone.text.trim().length < 7) { setState(()=>_error='أدخل اسم متجر ورقم هاتف صحيحين.'); return; }
    setState(() { _busy=true; _error=null; });
    try { final store=await widget.api.applyStore(widget.token,_name.text,_phone.text,_description.text); widget.onApplied(store); }
    catch(e){if(mounted)setState(()=>_error=e is ApiFailure?e.message:'تعذر إرسال الطلب.');}
    finally{if(mounted)setState(()=>_busy=false);}
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('طلب فتح متجر'),actions:[TextButton(onPressed:widget.onLogout,child:const Text('خروج'))]),
    body:Center(child:SingleChildScrollView(padding:const EdgeInsets.all(20),child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:520),
    child:Card(child:Padding(padding:const EdgeInsets.all(22),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      const Icon(Icons.store_mall_directory_outlined,size:48,color:brand),
      Text('مرحباً ${widget.user['name']??widget.user['full_name']??''}',style:Theme.of(context).textTheme.titleLarge),
      const SizedBox(height:8),const Text('قدّم طلبك؛ ستتمكن من إدارة المنتجات بعد اعتماد المتجر من الإدارة.'),
      const SizedBox(height:18),TextField(controller:_name,decoration:const InputDecoration(labelText:'اسم المتجر')),
      const SizedBox(height:12),TextField(controller:_phone,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'رقم التواصل')),
      const SizedBox(height:12),TextField(controller:_description,maxLines:3,decoration:const InputDecoration(labelText:'وصف المتجر')),
      if(_error!=null)Padding(padding:const EdgeInsets.only(top:12),child:Text(_error!,style:const TextStyle(color:Colors.red))),
      const SizedBox(height:16),FilledButton(onPressed:_busy?null:_apply,child:Text(_busy?'جارٍ إرسال الطلب...':'إرسال طلب اعتماد المتجر')),
    ])))))));
}

class PendingStoreScreen extends StatelessWidget {
  const PendingStoreScreen({super.key,required this.store,required this.onRefresh,required this.onLogout});
  final Map<String,dynamic> store; final Future<void> Function() onRefresh; final VoidCallback onLogout;
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('حالة طلب المتجر'),actions:[TextButton(onPressed:onLogout,child:const Text('خروج'))]),
    body:Center(child:Padding(padding:const EdgeInsets.all(24),child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:500),
    child:Card(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[
      const Icon(Icons.hourglass_top_rounded,size:60,color:Colors.orange),const SizedBox(height:12),
      Text((store['store_name']??'متجرك').toString(),style:Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height:10),Text('حالة الطلب: ${store['status']??'قيد المراجعة'}'),
      const SizedBox(height:8),const Text('ستظهر إدارة المنتجات والطلبات بعد اعتماد المتجر.',textAlign:TextAlign.center),
      const SizedBox(height:18),FilledButton.icon(onPressed:onRefresh,icon:const Icon(Icons.refresh),label:const Text('تحديث حالة الاعتماد')),
    ])))))));
}

class SellerDashboard extends StatefulWidget {
  const SellerDashboard({super.key,required this.api,required this.token,required this.user,required this.store,required this.onLogout});
  final PlatformApi api; final String token; final Map<String,dynamic> user,store; final VoidCallback onLogout;
  @override State<SellerDashboard> createState()=>_SellerDashboardState();
}
class _SellerDashboardState extends State<SellerDashboard> {
  int _tab=0; bool _busy=false; String? _error;
  List<Map<String,dynamic>> _products=[],_orders=[];
  @override void initState(){super.initState();_refresh();}
  Future<void> _refresh() async {
    setState(()=>_busy=true);
    try{
      final products=await widget.api.products(widget.token,widget.store['id'].toString());
      final orders=await widget.api.orders(widget.token,widget.store['id'].toString());
      if (mounted) setState(() { _products = products; _orders = orders; _error = null; });
    }catch(e){if(mounted)setState(()=>_error=e is ApiFailure?e.message:'تعذر تحميل بيانات المتجر.');}
    finally{if(mounted)setState(()=>_busy=false);}
  }
  void _notify(String message){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(message)));}
  Future<void> _addProduct() async {
    final form=GlobalKey<FormState>();
    final title=TextEditingController(),description=TextEditingController(),image=TextEditingController(),category=TextEditingController(text:'قرطاسية');
    final submit=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('إضافة منتج للمراجعة'),
      content:SizedBox(width:440,child:Form(key:form,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextFormField(controller:title,decoration:const InputDecoration(labelText:'اسم المنتج'),validator:(v)=>v==null||v.trim().length<2?'أدخل اسم المنتج.':null),
        const SizedBox(height:10),TextFormField(controller:description,maxLines:2,decoration:const InputDecoration(labelText:'الوصف')),
        const SizedBox(height:10),TextFormField(controller:category,decoration:const InputDecoration(labelText:'التصنيف')),
        const SizedBox(height:10),TextFormField(controller:image,decoration:const InputDecoration(labelText:'رابط الصورة (اختياري)')),
        const SizedBox(height:8),const Text('السعر النهائي تحدده الإدارة قبل النشر.',style:TextStyle(fontSize:12)),
      ]))),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,form.currentState?.validate()==true),child:const Text('إرسال للمراجعة'))]));
    if(submit==true){try{await widget.api.createProduct(widget.token,title.text,description.text,image.text,category.text);_notify('أُرسل المنتج للمراجعة. ستحدد الإدارة سعر البيع.');await _refresh();}
      catch(e){_notify(e is ApiFailure?e.message:'تعذر إضافة المنتج.');}}
    title.dispose();description.dispose();image.dispose();category.dispose();
  }
  Future<void> _setAvailable(Map<String,dynamic> p,bool value) async {
    try{await widget.api.setAvailability(widget.token,p['id'].toString(),value);_notify('تم تحديث التوافر.');await _refresh();}
    catch(e){_notify(e is ApiFailure?e.message:'تعذر تحديث التوافر.');}
  }
  Future<void> _updateOrder(Map<String,dynamic> o,String value) async {
    try{await widget.api.changeOrderStatus(widget.token,o['id'].toString(),value);_notify('تم تحديث الطلب.');await _refresh();}
    catch(e){_notify(e is ApiFailure?e.message:'تعذر تحديث الطلب.');}
  }
  @override Widget build(BuildContext context){
    final name=(widget.store['store_name']??'Alqlaisi').toString();
    final pages=[_overview(name),_productList(),_orderList(),_settings(name)];
    return Scaffold(appBar:AppBar(title:Text(name),actions:[IconButton(tooltip:'تحديث',onPressed:_refresh,icon:const Icon(Icons.refresh))]),
      body:Column(children:[if(_error!=null)MaterialBanner(content:Text(_error!),actions:[TextButton(onPressed:_refresh,child:const Text('إعادة المحاولة'))]),
        if(_busy)const LinearProgressIndicator(),Expanded(child:IndexedStack(index:_tab,children:pages))]),
      floatingActionButton:_tab==1?FloatingActionButton.extended(onPressed:_addProduct,icon:const Icon(Icons.add),label:const Text('إضافة منتج')):null,
      bottomNavigationBar:NavigationBar(selectedIndex:_tab,onDestinationSelected:(i)=>setState(()=>_tab=i),destinations:const[
        NavigationDestination(icon:Icon(Icons.dashboard_outlined),selectedIcon:Icon(Icons.dashboard),label:'الرئيسية'),
        NavigationDestination(icon:Icon(Icons.inventory_2_outlined),selectedIcon:Icon(Icons.inventory_2),label:'المنتجات'),
        NavigationDestination(icon:Icon(Icons.receipt_long_outlined),selectedIcon:Icon(Icons.receipt_long),label:'الطلبات'),
        NavigationDestination(icon:Icon(Icons.settings_outlined),selectedIcon:Icon(Icons.settings),label:'الإعدادات'),
      ]));
  }
  Widget _overview(String storeName)=>RefreshIndicator(onRefresh:_refresh,child:ListView(padding:const EdgeInsets.all(16),children:[
    Text('مرحباً، ${widget.user['name']??''}',style:Theme.of(context).textTheme.headlineSmall),
    const SizedBox(height:6),Text('متجر ${storeName} · معتمد',style:const TextStyle(color:Colors.green)),
    const SizedBox(height:18),Wrap(spacing:12,runSpacing:12,children:[
      _MetricCard(title:'المنتجات',value:'${_products.length}',icon:Icons.inventory_2),
      _MetricCard(title:'بانتظار المراجعة',value:'${_products.where((p)=>p['review_status']=='قيد المراجعة').length}',icon:Icons.pending_actions),
      _MetricCard(title:'الطلبات',value:'${_orders.length}',icon:Icons.receipt_long),
      const _MetricCard(title:'نظام المخزون',value:'توافر يدوي',icon:Icons.toggle_on),
    ]),
    const SizedBox(height:18),const Card(child:ListTile(leading:Icon(Icons.info_outline),title:Text('سياسة التسعير'),subtitle:Text('ترسل المنتجات للإدارة للمراجعة. السعر النهائي يحدده مدير المنصة.'))),
    const Card(child:ListTile(leading:Icon(Icons.inventory_outlined),title:Text('التوافر اليدوي'),subtitle:Text('لا توجد كميات مخزون؛ حدد هل المنتج متاح أو غير متاح مؤقتاً.'))),
  ]));
  Widget _productList(){
    if(_products.isEmpty)return const Center(child:Text('لا توجد منتجات بعد. أضف منتجاً لإرساله إلى مراجعة الإدارة.'));
    return RefreshIndicator(onRefresh:_refresh,child:ListView.builder(padding:const EdgeInsets.all(12),itemCount:_products.length,itemBuilder:(context,index){
      final p=_products[index];final status=(p['review_status']??'قيد المراجعة').toString();
      final price=(p['price']??0).toString();final approved=status=='منشور'&&(p['price'] as num? ?? 0)>0;
      return Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text((p['title']??'منتج').toString(),style:Theme.of(context).textTheme.titleMedium),
        const SizedBox(height:6),Text('السعر المعتمد: $price ريال'),Text('حالة المراجعة: $status'),
        Row(children:[const Expanded(child:Text('متاح للعملاء')),Switch(value:p['is_available']==true&&approved,onChanged:approved?(v)=>_setAvailable(p,v):null)]),
        if(!approved)const Text('ينتظر اعتماد الإدارة وتحديد السعر.',style:TextStyle(color:Colors.orange)),
      ])));
    }));
  }
  Widget _orderList(){
    if(_orders.isEmpty)return const Center(child:Text('لا توجد طلبات جديدة لهذا المتجر.'));
    return RefreshIndicator(onRefresh:_refresh,child:ListView.builder(padding:const EdgeInsets.all(12),itemCount:_orders.length,itemBuilder:(context,index){
      final o=_orders[index];final status=(o['status']??'بانتظار القبول').toString();final total=(o['total_price']??0).toString();
      final allowed=status=='بانتظار القبول'?['قيد التجهيز','ملغي']:status=='قيد التجهيز'?['جاهز للتوصيل','ملغي']:<String>[];
      return Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('طلب ${o['id']}',style:Theme.of(context).textTheme.titleMedium),const SizedBox(height:5),
        Text('الإجمالي شامل التوصيل: $total ريال'),Text('طريقة الدفع: ${o['payment_method']??'الدفع عند الاستلام'}'),
        Text('العنوان: ${o['address']??'—'}'),Text('الحالة: $status'),
        if(allowed.isNotEmpty) Wrap(
          spacing: 8,
          children: allowed.map((s) => OutlinedButton(
            onPressed: () => _updateOrder(o, s),
            child: Text(s),
          )).toList(),
        ),
      ])));
    }));
  }
  Widget _settings(String name)=>ListView(padding:const EdgeInsets.all(16),children:[
    Card(child:ListTile(leading:const Icon(Icons.storefront),title:Text(name),subtitle:Text('معرّف المتجر: ${widget.store['id']}'))),
    Card(child:ListTile(leading:const Icon(Icons.person_outline),title:Text((widget.user['name']??'البائع').toString()),subtitle:Text((widget.user['phone']??'').toString()))),
    const Card(child:ListTile(leading:Icon(Icons.local_shipping_outlined),title:Text('التوصيل'),subtitle:Text('تنسق المنصة التوصيل الداخلي وتحديث حالة الطلب.'))),
    const Card(child:ListTile(leading:Icon(Icons.payments_outlined),title:Text('المحاسبة'),subtitle:Text('الدفع عند الاستلام فقط في الإصدار الأول.'))),
    FilledButton.icon(onPressed:widget.onLogout,icon:const Icon(Icons.logout),label:const Text('تسجيل الخروج')),
  ]);
}
class _MetricCard extends StatelessWidget{
  const _MetricCard({required this.title,required this.value,required this.icon});
  final String title,value;final IconData icon;
  @override Widget build(BuildContext context)=>SizedBox(width:MediaQuery.sizeOf(context).width>700?220:(MediaQuery.sizeOf(context).width-44)/2,
    child:Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Icon(icon,color:brand),const SizedBox(height:10),Text(title),Text(value,style:Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight:FontWeight.bold)),
    ]))));
}
