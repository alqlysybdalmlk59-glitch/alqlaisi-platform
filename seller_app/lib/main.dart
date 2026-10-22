import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

const _brand = Color(0xFF145B4D);
const _googleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
bool get _googleOAuthConfigured => RegExp(
  r'^[0-9]+-[A-Za-z0-9_-]+\\.apps\\.googleusercontent\\.com
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8000/api',
);

void main() => runApp(const SellerApp());

class SellerApiException implements Exception {
  const SellerApiException(this.message);
  final String message;
}

class SellerApi {
  SellerApi({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'alqlaisi_seller_token';

  Future<String?> loadToken() => _storage.read(key: _tokenKey);
  Future<void> saveToken(String token) => _storage.write(key: _tokenKey, value: token);
  Future<void> clearToken() => _storage.delete(key: _tokenKey);

  Future<dynamic> request(
    String path, {
    String method = 'GET',
    String? token,
    Map<String, dynamic>? body,
  }) async {
    final root = _apiBase.replaceAll(RegExp(r'/+$'), '');
    final baseUri = Uri.tryParse(root);
    if (baseUri == null || baseUri.host.isEmpty) {
      throw const SellerApiException('عنوان API غير صالح.');
    }
    if (kReleaseMode &&
        (baseUri.scheme != 'https' || baseUri.userInfo.isNotEmpty)) {
      throw const SellerApiException(
        'نسخة الإنتاج تمنع إرسال بيانات الدخول عبر HTTP. '
        'أعد البناء بعنوان API_BASE_URL يبدأ بـ https://.',
      );
    }

    final uri = Uri.parse(root + path);
    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    late http.Response response;
    try {
      if (method == 'POST') {
        response = await _client.post(
          uri,
          headers: headers,
          body: body == null ? null : jsonEncode(body),
        );
      } else if (method == 'PUT') {
        response = await _client.put(
          uri,
          headers: headers,
          body: body == null ? null : jsonEncode(body),
        );
      } else {
        response = await _client.get(uri, headers: headers);
      }
    } catch (_) {
      throw const SellerApiException('تعذر الاتصال بالخادم. تحقق من عنوان API.');
    }

    dynamic decoded;
    try {
      if (response.body.isNotEmpty) decoded = jsonDecode(response.body);
    } catch (_) {}

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = decoded is Map ? (decoded['detail'] ?? decoded['message']) : null;
      final message = detail?.toString() ??
          'فشل الطلب (${response.statusCode}).';
      throw SellerApiException(message);
    }
    return decoded;
  }

  Future<Map<String, dynamic>> login(String phone, String password) async {
    final result = await request('/auth/login', method: 'POST', body: {'phone': phone.trim(), 'password': password});
    if (result is! Map || (result['access_token'] ?? '').toString().isEmpty) {
      throw const SellerApiException('استجابة تسجيل الدخول غير صالحة.');
    }
    final token = result['access_token'].toString();
    await saveToken(token);
    return me(token);
  }

  Future<Map<String, dynamic>> loginWithGoogle(String idToken) async {
    final result = await request('/auth/google/seller', method: 'POST',
      body: {'id_token': idToken});
    if (result is! Map || (result['access_token'] ?? '').toString().isEmpty) {
      throw const SellerApiException('لم يُرجع الخادم جلسة Google صالحة.');
    }
    final token = result['access_token'].toString();
    await saveToken(token);
    return me(token);
  }

  Future<void> linkGoogle(String token, String idToken) async {
    await request('/auth/google/link', method: 'POST', token: token,
      body: {'id_token': idToken});
  }

  Future<Map<String, dynamic>> me(String token) async {
    final result = await request('/auth/me', token: token);
    if (result is! Map) throw const SellerApiException('بيانات الحساب غير صحيحة.');
    return Map<String, dynamic>.from(result);
  }

  Future<Map<String, dynamic>?> myStore(String token) async {
    final result = await request('/vendors/mine', token: token);
    if (result == null) return null;
    if (result is! Map) throw const SellerApiException('بيانات المتجر غير صحيحة.');
    return Map<String, dynamic>.from(result);
  }

  Future<Map<String, dynamic>> applyStore(String token, String name, String phone, String description) async {
    final result = await request('/vendors/register', method: 'POST', token: token, body: {
      'store_name': name.trim(), 'phone': phone.trim(), 'description': description.trim(),
    });
    if (result is! Map) throw const SellerApiException('لم يستلم الخادم بيانات المتجر.');
    return Map<String, dynamic>.from(result);
  }

  Future<List<Map<String, dynamic>>> products(String token, String storeId) async =>
      _asList(await request('/products/vendor/${Uri.encodeComponent(storeId)}', token: token));

  Future<List<Map<String, dynamic>>> orders(String token, String storeId) async =>
      _asList(await request('/orders/vendor/${Uri.encodeComponent(storeId)}', token: token));

  Future<List<Map<String, dynamic>>> myTickets(String token) async =>
      _asList(await request('/support/mine', token: token));

  Future<void> createTicket(String token, String subject, String details) async {
    await request('/support/', method: 'POST', token: token, body: {
      'subject': subject.trim(),
      'details': details.trim(),
    });
  }

  Future<Map<String, dynamic>> salesSummary(String token, String storeId) async {
    final result = await request(
      '/orders/vendor/${Uri.encodeComponent(storeId)}/summary',
      token: token,
    );
    if (result is! Map) {
      throw const SellerApiException('استجابة تقرير المبيعات غير صحيحة.');
    }
    return Map<String, dynamic>.from(result);
  }

  Future<void> addProduct(String token, String name, String description, String image, String category) async {
    await request('/products/', method: 'POST', token: token, body: {
      'title': name.trim(), 'description': description.trim(), 'image_url': image.trim(),
      'category': category.trim().isEmpty ? 'عام' : category.trim(),
    });
  }

  Future<void> updateProduct(
    String token,
    String productId,
    String title,
    String description,
    String imageUrl,
    String category,
  ) async {
    await request('/products/${Uri.encodeComponent(productId)}', method: 'PUT',
      token: token, body: {
        'title': title.trim(),
        'description': description.trim(),
        'image_url': imageUrl.trim(),
        'category': category.trim().isEmpty ? 'عام' : category.trim(),
      });
  }

  Future<void> setAvailability(String token, String id, bool available) async {
    await request('/products/${Uri.encodeComponent(id)}/availability', method: 'PUT',
      token: token, body: {'is_available': available});
  }

  Future<void> setOrderStatus(String token, String id, String status) async {
    await request('/orders/${Uri.encodeComponent(id)}/status?status=${Uri.encodeQueryComponent(status)}',
      method: 'PUT', token: token);
  }

  Future<List<Map<String, dynamic>>> orderHistory(String token, String id) async =>
      _asList(await request('/orders/${Uri.encodeComponent(id)}/history', token: token));

  static List<Map<String, dynamic>> _asList(dynamic value) {
    if (value is! List) throw const SellerApiException('قائمة البيانات غير صالحة.');
    return value.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }

  void dispose() => _client.close();
}

class SellerApp extends StatefulWidget {
  const SellerApp({super.key});
  @override State<SellerApp> createState() => _SellerAppState();
}

class _SellerAppState extends State<SellerApp> {
  final _api = SellerApi();
  String? _token;
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _store;
  bool _loading = true;

  @override void initState() { super.initState(); _restore(); }
  @override void dispose() { _api.dispose(); super.dispose(); }

  Future<void> _restore() async {
    try {
      final token = await _api.loadToken();
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
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _login(String phone, String password) async {
    final user = await _api.login(phone, password);
    final token = await _api.loadToken();
    if (!mounted) return;
    if (token == null) throw const SellerApiException('تعذر حفظ جلسة الدخول.');
    setState(() { _token = token; _user = user; _store = null; });
    await _loadStore();
  }

  Future<void> _loginWithGoogle() async {
    if (!_googleOAuthConfigured) {
      throw const SellerApiException(
        'تسجيل Google غير مهيأ. أعد بناء التطبيق باستخدام معرّف Web OAuth الحقيقي في GOOGLE_SERVER_CLIENT_ID.',
      );
    }
    final googleUser = await GoogleSignIn(serverClientId: _googleServerClientId).signIn();
    if (googleUser == null) return;
    final auth = await googleUser.authentication;
    final idToken = auth.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const SellerApiException('لم يصل رمز Google؛ تحقق من OAuth وبصمة SHA-1.');
    }
    final user = await _api.loginWithGoogle(idToken);
    final token = await _api.loadToken();
    if (!mounted) return;
    if (token == null) throw const SellerApiException('تعذر حفظ جلسة الدخول.');
    setState(() { _token = token; _user = user; _store = null; });
    await _loadStore();
  }

  Future<void> _loadStore() async {
    final token = _token;
    if (token == null) return;
    final store = await _api.myStore(token);
    if (mounted) setState(() => _store = store);
  }

  Future<void> _logout() async {
    await _api.clearToken();
    if (mounted) setState(() { _token = null; _user = null; _store = null; });
  }

  @override
  Widget build(BuildContext context) {
    Widget page;
    if (_loading) {
      page = const Scaffold(body: Center(child: CircularProgressIndicator()));
    } else if (_token == null || _user == null) {
      page = LoginPage(onLogin: _login, onGoogleLogin: _loginWithGoogle);
    } else if (_store == null || _store!['status'] == 'مرفوض') {
      page = ApplyStorePage(api: _api, token: _token!, user: _user!,
        existingStore: _store,
        onApplied: (value) => setState(() => _store = value), onLogout: _logout);
    } else if (_store!['status'] != 'مفعل') {
      page = StorePendingPage(store: _store!, onRefresh: _loadStore, onLogout: _logout);
    } else {
      page = SellerHomePage(api: _api, token: _token!, user: _user!, store: _store!, onLogout: _logout);
    }
    return MaterialApp(
      title: 'Alqlaisi Seller',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: _brand), useMaterial3: true),
      builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child ?? const SizedBox()),
      home: page,
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.onLogin, required this.onGoogleLogin});
  final Future<void> Function(String phone, String password) onLogin;
  final Future<void> Function() onGoogleLogin;
  @override State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;
  @override void dispose() { _phone.dispose(); _password.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      await widget.onLogin(_phone.text, _password.text);
    } catch (error) {
      if (mounted) setState(() => _error = error is SellerApiException ? error.message : 'تعذر تسجيل الدخول.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitGoogle() async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      await widget.onGoogleLogin();
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is SellerApiException
            ? error.message
            : 'تعذر تسجيل الدخول بواسطة Google. تحقق من الإعدادات.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fields = <Widget>[
      const Icon(Icons.storefront, size: 56, color: _brand),
      const SizedBox(height: 12),
      Text('Alqlaisi', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 8),
      const Text('بوابة البائعين المعتمدين', textAlign: TextAlign.center),
      const SizedBox(height: 24),
      TextField(controller: _phone, keyboardType: TextInputType.phone,
        decoration: const InputDecoration(labelText: 'رقم الهاتف')),
      const SizedBox(height: 12),
      TextField(controller: _password, obscureText: true,
        decoration: const InputDecoration(labelText: 'كلمة المرور'), onSubmitted: (_) => _submit()),
      if (_error != null) Padding(padding: const EdgeInsets.only(top: 10),
        child: Text(_error!, style: const TextStyle(color: Colors.red))),
      const SizedBox(height: 16),
      FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? 'جارٍ التحقق...' : 'تسجيل الدخول')),
      const SizedBox(height: 10),
      const Text('يجب اعتماد المتجر من الإدارة قبل نشر المنتجات.', textAlign: TextAlign.center),
    ];
    return Scaffold(body: Center(
      child: SingleChildScrollView(padding: const EdgeInsets.all(24),
        child: SizedBox(width: 440, child: Card(child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: fields),
        ))),
      ),
    ));
  }
}

class ApplyStorePage extends StatefulWidget {
  const ApplyStorePage({super.key, required this.api, required this.token, required this.user,
    this.existingStore, required this.onApplied, required this.onLogout});
  final SellerApi api;
  final String token;
  final Map<String, dynamic> user;
  final Map<String, dynamic>? existingStore;
  final ValueChanged<Map<String, dynamic>> onApplied;
  final VoidCallback onLogout;
  @override State<ApplyStorePage> createState() => _ApplyStorePageState();
}

class _ApplyStorePageState extends State<ApplyStorePage> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _description = TextEditingController();
  bool _busy = false;
  String? _error;
  @override void initState() {
    super.initState();
    _name.text = (widget.existingStore?['store_name'] ?? widget.user['name'] ?? widget.user['full_name'] ?? '').toString();
    _phone.text = (widget.existingStore?['phone'] ?? widget.user['phone'] ?? '').toString();
    _description.text = (widget.existingStore?['description'] ?? '').toString();
  }
  @override void dispose() { _name.dispose(); _phone.dispose(); _description.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (_name.text.trim().length < 2 || _phone.text.trim().length < 7) {
      setState(() => _error = 'أدخل اسم المتجر ورقم هاتف صحيحين.');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      final store = await widget.api.applyStore(widget.token, _name.text, _phone.text, _description.text);
      widget.onApplied(store);
    } catch (error) {
      if (mounted) setState(() => _error = error is SellerApiException ? error.message : 'تعذر إرسال الطلب.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fields = <Widget>[
      const Icon(Icons.store_mall_directory_outlined, size: 48, color: _brand),
      Text('مرحباً ${widget.user['name'] ?? widget.user['full_name'] ?? ''}',
        style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      Text(widget.existingStore == null
        ? 'قدّم طلبك؛ ستتمكن من إدارة المنتجات بعد اعتماد المتجر.'
        : 'أعد تقديم طلب المتجر بعد معالجة ملاحظات المراجعة.'),
      const SizedBox(height: 18),
      TextField(controller: _name, decoration: const InputDecoration(labelText: 'اسم المتجر')),
      const SizedBox(height: 12),
      TextField(controller: _phone, keyboardType: TextInputType.phone,
        decoration: const InputDecoration(labelText: 'رقم التواصل')),
      const SizedBox(height: 12),
      TextField(controller: _description, maxLines: 3,
        decoration: const InputDecoration(labelText: 'وصف المتجر')),
      if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
      const SizedBox(height: 16),
      FilledButton(onPressed: _busy ? null : _submit,
        child: Text(_busy ? 'جارٍ الإرسال...' : widget.existingStore == null ? 'إرسال طلب اعتماد المتجر' : 'إعادة تقديم الطلب')),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('طلب فتح متجر'),
        actions: [TextButton(onPressed: widget.onLogout, child: const Text('خروج'))]),
      body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(20),
        child: SizedBox(width: 520, child: Card(child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: fields),
        ))),
      )),
    );
  }
}

class StorePendingPage extends StatelessWidget {
  const StorePendingPage({super.key, required this.store, required this.onRefresh, required this.onLogout});
  final Map<String, dynamic> store;
  final Future<void> Function() onRefresh;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final content = <Widget>[
      const Icon(Icons.hourglass_top_rounded, size: 60, color: Colors.orange),
      const SizedBox(height: 12),
      Text((store['store_name'] ?? 'متجرك').toString(), style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 10),
      Text('حالة الطلب: ${store['status'] ?? 'قيد المراجعة'}'),
      const SizedBox(height: 8),
      const Text('ستظهر إدارة المنتجات والطلبات بعد اعتماد المتجر.', textAlign: TextAlign.center),
      const SizedBox(height: 18),
      FilledButton.icon(onPressed: onRefresh, icon: const Icon(Icons.refresh), label: const Text('تحديث الحالة')),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('حالة طلب المتجر'),
        actions: [TextButton(onPressed: onLogout, child: const Text('خروج'))]),
      body: Center(child: Padding(padding: const EdgeInsets.all(24),
        child: SizedBox(width: 500, child: Card(child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: content),
        ))),
      )),
    );
  }
}

class SellerHomePage extends StatefulWidget {
  const SellerHomePage({super.key, required this.api, required this.token, required this.user,
    required this.store, required this.onLogout});
  final SellerApi api;
  final String token;
  final Map<String, dynamic> user;
  final Map<String, dynamic> store;
  final VoidCallback onLogout;
  @override State<SellerHomePage> createState() => _SellerHomePageState();
}

class _SellerHomePageState extends State<SellerHomePage> {
  int _tab = 0;
  bool _busy = false;
  String? _error;
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _orders = [];
  Map<String, dynamic>? _summary;

  @override void initState() { super.initState(); _refresh(); }

  Future<void> _refresh() async {
    setState(() => _busy = true);
    try {
      final storeId = widget.store['id'].toString();
      final products = await widget.api.products(widget.token, storeId);
      final orders = await widget.api.orders(widget.token, storeId);
      final summary = await widget.api.salesSummary(widget.token, storeId);
      if (mounted) {
        setState(() {
          _products = products;
          _orders = orders;
          _summary = summary;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error is SellerApiException ? error.message : 'تعذر تحميل البيانات.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String value) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> _createProduct() async {
    final key = GlobalKey<FormState>();
    final title = TextEditingController();
    final description = TextEditingController();
    final image = TextEditingController();
    final category = TextEditingController(text: 'قرطاسية');
    final accepted = await showDialog<bool>(context: context, builder: (dialogContext) {
      final fields = <Widget>[
        TextFormField(controller: title, decoration: const InputDecoration(labelText: 'اسم المنتج'),
          validator: (v) => v == null || v.trim().length < 2 ? 'أدخل اسم المنتج.' : null),
        const SizedBox(height: 10),
        TextFormField(controller: description, decoration: const InputDecoration(labelText: 'الوصف'), maxLines: 2),
        const SizedBox(height: 10),
        TextFormField(controller: category, decoration: const InputDecoration(labelText: 'التصنيف')),
        const SizedBox(height: 10),
        TextFormField(controller: image, decoration: const InputDecoration(labelText: 'رابط الصورة (اختياري)')),
        const SizedBox(height: 8),
        const Text('السعر النهائي تحدده الإدارة قبل النشر.', style: TextStyle(fontSize: 12)),
      ];
      return AlertDialog(
        title: const Text('إضافة منتج للمراجعة'),
        content: SizedBox(width: 420, child: Form(key: key,
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: fields)))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, key.currentState?.validate() == true),
            child: const Text('إرسال للمراجعة')),
        ],
      );
    });
    if (accepted == true) {
      try {
        await widget.api.addProduct(widget.token, title.text, description.text, image.text, category.text);
        _message('تم إرسال المنتج للمراجعة. ستحدد الإدارة سعر البيع.');
        await _refresh();
      } catch (error) {
        _message(error is SellerApiException ? error.message : 'تعذر إضافة المنتج.');
      }
    }
    title.dispose(); description.dispose(); image.dispose(); category.dispose();
  }

  Future<void> _editProduct(Map<String, dynamic> product) async {
    final key = GlobalKey<FormState>();
    final title = TextEditingController(text: (product['title'] ?? '').toString());
    final description = TextEditingController(text: (product['description'] ?? '').toString());
    final image = TextEditingController(text: (product['image_url'] ?? '').toString());
    final category = TextEditingController(text: (product['category'] ?? 'عام').toString());
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تعديل بيانات المنتج'),
        content: SizedBox(
          width: 440,
          child: Form(
            key: key,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'اسم المنتج'),
                  validator: (value) => value == null || value.trim().length < 2
                      ? 'أدخل اسم المنتج.'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: description,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'الوصف'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: category,
                  decoration: const InputDecoration(labelText: 'التصنيف'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: image,
                  decoration: const InputDecoration(labelText: 'رابط الصورة'),
                ),
                const SizedBox(height: 8),
                const Text(
                  'سيعود المنتج إلى المراجعة وسيتوقف عرضه حتى تعتمد الإدارة السعر والنشر مجدداً.',
                  style: TextStyle(fontSize: 12),
                ),
              ]),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, key.currentState?.validate() == true),
            child: const Text('حفظ وإرسال للمراجعة'),
          ),
        ],
      ),
    );
    if (accepted == true) {
      try {
        await widget.api.updateProduct(
          widget.token,
          product['id'].toString(),
          title.text,
          description.text,
          image.text,
          category.text,
        );
        _message('تم حفظ التعديلات وإرسال المنتج إلى مراجعة الإدارة.');
        await _refresh();
      } catch (error) {
        _message(error is SellerApiException ? error.message : 'تعذر تعديل المنتج.');
      }
    }
    title.dispose();
    description.dispose();
    image.dispose();
    category.dispose();
  }

  Future<void> _availability(Map<String, dynamic> product, bool value) async {
    try {
      await widget.api.setAvailability(widget.token, product['id'].toString(), value);
      _message('تم تحديث التوافر.');
      await _refresh();
    } catch (error) {
      _message(error is SellerApiException ? error.message : 'تعذر تحديث التوافر.');
    }
  }

  Future<void> _orderStatus(Map<String, dynamic> order, String value) async {
    try {
      await widget.api.setOrderStatus(widget.token, order['id'].toString(), value);
      _message('تم تحديث حالة الطلب.');
      await _refresh();
    } catch (error) {
      _message(error is SellerApiException ? error.message : 'تعذر تحديث حالة الطلب.');
    }
  }

  Future<void> _linkGoogleToSellerAccount() async {
    if (!_googleOAuthConfigured) {
      _message('اربط Google بعد إعداد معرّف Web OAuth الحقيقي في GOOGLE_SERVER_CLIENT_ID.');
      return;
    }
    try {
      final selected = await GoogleSignIn(serverClientId: _googleServerClientId).signIn();
      if (selected == null) return;
      final googleAuth = await selected.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const SellerApiException('لم يصل رمز Google؛ تحقق من إعداد OAuth.');
      }
      await widget.api.linkGoogle(widget.token, idToken);
      final refreshedUser = await widget.api.me(widget.token);
      widget.user.addAll(refreshedUser);
      if (mounted) setState(() {});
      _message('تم ربط Google بهذا الحساب بعد التحقق من الخادم.');
    } catch (error) {
      _message(error is SellerApiException
          ? error.message
          : 'تعذر ربط Google. لم يتم تأكيد أي تغيير.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final storeName = (widget.store['store_name'] ?? 'Alqlaisi').toString();
    final pages = <Widget>[
      _overview(storeName),
      _productPage(),
      _orderPage(),
      _reportPage(),
      _settings(storeName),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(storeName),
        actions: [IconButton(tooltip: 'تحديث', onPressed: _refresh, icon: const Icon(Icons.refresh))]),
      body: Column(children: [
        if (_error != null) MaterialBanner(content: Text(_error!), actions: [
          TextButton(onPressed: _refresh, child: const Text('إعادة المحاولة')),
        ]),
        if (_busy) const LinearProgressIndicator(),
        Expanded(child: IndexedStack(index: _tab, children: pages)),
      ]),
      floatingActionButton: _tab == 1
          ? FloatingActionButton.extended(onPressed: _createProduct, icon: const Icon(Icons.add), label: const Text('إضافة منتج'))
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'المنتجات'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'الطلبات'),
          NavigationDestination(icon: Icon(Icons.analytics_outlined), selectedIcon: Icon(Icons.analytics), label: 'التقارير'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'الإعدادات'),
        ],
      ),
    );
  }

  Widget _overview(String storeName) {
    final pending = _products.where((p) => p['review_status'] == 'قيد المراجعة').length;
    final metrics = <Widget>[
      _MetricCard('المنتجات', _products.length.toString(), Icons.inventory_2),
      _MetricCard('قيد المراجعة', pending.toString(), Icons.pending_actions),
      _MetricCard('الطلبات', _orders.length.toString(), Icons.receipt_long),
      const _MetricCard('التوافر', 'يدوي', Icons.toggle_on),
    ];
    return RefreshIndicator(onRefresh: _refresh, child: ListView(padding: const EdgeInsets.all(16), children: [
      Text('مرحباً، ${widget.user['name'] ?? ''}', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 6),
      Text('متجر $storeName · معتمد', style: const TextStyle(color: Colors.green)),
      const SizedBox(height: 18),
      Wrap(spacing: 12, runSpacing: 12, children: metrics),
      const SizedBox(height: 18),
      const Card(child: ListTile(leading: Icon(Icons.info_outline), title: Text('سياسة التسعير'),
        subtitle: Text('ترسل المنتجات للإدارة للمراجعة؛ السعر النهائي يحدده مدير المنصة.'))),
      const Card(child: ListTile(leading: Icon(Icons.inventory_outlined), title: Text('التوافر اليدوي'),
        subtitle: Text('لا توجد كميات مخزون. حدد هل المنتج متاح أم غير متاح مؤقتاً.'))),
    ]));
  }

  Widget _productPage() {
    if (_products.isEmpty) return const Center(child: Text('لا توجد منتجات بعد. أضف منتجاً لإرساله للمراجعة.'));
    return RefreshIndicator(onRefresh: _refresh, child: ListView.builder(
      padding: const EdgeInsets.all(12), itemCount: _products.length,
      itemBuilder: (context, index) {
        final product = _products[index];
        final status = (product['review_status'] ?? 'قيد المراجعة').toString();
        final price = (product['price'] as num?)?.toString() ?? '0';
        final approved = status == 'منشور' && ((product['price'] as num?) ?? 0) > 0;
        final children = <Widget>[
          Row(
            children: [
              Expanded(
                child: Text(
                  (product['title'] ?? 'منتج').toString(),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'تعديل بيانات المنتج',
                onPressed: () => _editProduct(product),
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('السعر المعتمد: $price ريال'),
          Text('الحالة: $status'),
          Row(children: [
            const Expanded(child: Text('متاح للعملاء')),
            Switch(value: product['is_available'] == true && approved,
              onChanged: approved ? (value) => _availability(product, value) : null),
          ]),
          if (!approved) const Text('ينتظر اعتماد الإدارة وتحديد السعر.', style: TextStyle(color: Colors.orange)),
        ];
        return Card(child: Padding(padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children)));
      },
    ));
  }

  Widget _orderPage() {
    if (_orders.isEmpty) return const Center(child: Text('لا توجد طلبات جديدة لهذا المتجر.'));
    return RefreshIndicator(onRefresh: _refresh, child: ListView.builder(
      padding: const EdgeInsets.all(12), itemCount: _orders.length,
      itemBuilder: (context, index) {
        final order = _orders[index];
        final status = (order['status'] ?? 'بانتظار القبول').toString();
        final total = (order['total_price'] as num?)?.toString() ?? '0';
        final allowed = status == 'بانتظار القبول'
            ? ['قيد التجهيز', 'ملغي']
            : status == 'قيد التجهيز' ? ['جاهز للتوصيل', 'ملغي'] : <String>[];
        final children = <Widget>[
          Text('طلب ${order['id']}', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 5),
          Text('الإجمالي شامل التوصيل: $total ريال'),
          Text('طريقة الدفع: ${order['payment_method'] ?? 'الدفع عند الاستلام'}'),
          Text('العنوان: ${order['address'] ?? '—'}'),
          Text('الحالة: $status'),
          if (allowed.isNotEmpty) Wrap(spacing: 8,
            children: allowed.map((next) => OutlinedButton(
              onPressed: () => _orderStatus(order, next), child: Text(next))).toList()),
        ];
        return Card(child: Padding(padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children)));
      },
    ));
  }

  Widget _reportPage() {
    final summary = _summary;
    if (summary == null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('تعذر تحميل تقرير المبيعات من الخادم.'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة'),
          ),
        ]),
      );
    }

    final deliveredValue = summary['delivered_gross_value'];
    final commissionConfigured = summary['commission_configured'] == true;
    final currency = (summary['currency'] ?? 'YER').toString();
    String valueOf(String key) => (summary[key] ?? 0).toString();
    final statusCounts = summary['status_counts'];
    final statuses = statusCounts is Map
        ? Map<String, dynamic>.from(statusCounts)
        : <String, dynamic>{};

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('تقرير المتجر', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            'تقرير من الخادم للمتجر: ${summary['store_name'] ?? widget.store['store_name'] ?? ''}',
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MetricCard('كل الطلبات', valueOf('order_count'), Icons.receipt_long),
              _MetricCard('قيد المعالجة', valueOf('pending_count'), Icons.pending_actions),
              _MetricCard('تم التسليم', valueOf('delivered_count'), Icons.task_alt),
              _MetricCard('ملغاة', valueOf('cancelled_count'), Icons.cancel_outlined),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'إجمالي قيمة الطلبات المسلّمة',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${deliveredValue ?? 0} ريال',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: _brand,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'هذا إجمالي قيمة الطلبات التي وصلت إلى حالة "تم التسليم"، ويشمل رسوم التوصيل؛ '
                    'ليس صافي ربح البائع أو تسوية مالية.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('الطلبات حسب الحالة', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (statuses.isEmpty)
                    const Text('لا توجد بيانات حالة حالياً.')
                  else
                    ...statuses.entries.map((entry) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(entry.key),
                      trailing: Text(entry.value.toString()),
                    )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: Icon(
                commissionConfigured ? Icons.verified_outlined : Icons.info_outline,
                color: commissionConfigured ? Colors.green : Colors.orange,
              ),
              title: Text(commissionConfigured ? 'العمولة مهيأة' : 'العمولة غير محددة'),
              subtitle: Text(
                commissionConfigured
                    ? 'نسبة العمولة: ${summary['commission_percent'] ?? '—'}%'
                    : (summary['commission_note'] ??
                      'لم تحدد نسبة العمولة؛ لا يتم احتساب عمولة أو تسوية مالية.').toString(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'العملة المعلنة من الخادم: $currency · حدّث الصفحة لجلب أرقام أحدث.',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _settings(String storeName) => ListView(padding: const EdgeInsets.all(16), children: [
    Card(
      child: ListTile(
        leading: const Icon(Icons.support_agent, color: _brand),
        title: const Text('الدعم الفني للبائعين'),
        subtitle: const Text('إرسال استفسار ومتابعة ردود فريق المنصة'),
        trailing: const Icon(Icons.chevron_left),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SellerSupportPage(api: widget.api, token: widget.token),
          ),
        ),
      ),
    ),
    Card(child: ListTile(leading: const Icon(Icons.storefront), title: Text(storeName),
      subtitle: Text('معرّف المتجر: ${widget.store['id']}'))),
    Card(child: ListTile(leading: const Icon(Icons.person_outline),
      title: Text((widget.user['name'] ?? 'البائع').toString()),
      subtitle: Text((widget.user['phone'] ?? '').toString()))),
    const Card(child: ListTile(leading: Icon(Icons.local_shipping_outlined), title: Text('التوصيل'),
      subtitle: Text('تنسق المنصة التوصيل الداخلي وتحديث حالة الطلب.'))),
    const Card(child: ListTile(leading: Icon(Icons.payments_outlined), title: Text('المحاسبة'),
      subtitle: Text('الدفع عند الاستلام فقط في الإصدار الأول.'))),
    if (widget.user['google_linked'] == true)
      const ListTile(leading: Icon(Icons.verified_user, color: Colors.green),
        title: Text('حساب Google موثّق'), subtitle: Text('هوية Google مرتبطة بهذا الحساب من الخادم.'))
    else
      ListTile(leading: const Icon(Icons.g_mobiledata, size: 30),
        title: const Text('ربط حساب Google'),
        subtitle: const Text('يمكن ربط الحساب بعد التحقق من ملكيته.'),
        trailing: const Icon(Icons.chevron_left),
        onTap: _linkGoogleToSellerAccount),
    FilledButton.icon(onPressed: widget.onLogout, icon: const Icon(Icons.logout), label: const Text('تسجيل الخروج')),
  ]);
}

class SellerSupportPage extends StatefulWidget {
  const SellerSupportPage({
    super.key,
    required this.api,
    required this.token,
  });

  final SellerApi api;
  final String token;

  @override
  State<SellerSupportPage> createState() => _SellerSupportPageState();
}

class _SellerSupportPageState extends State<SellerSupportPage> {
  final _formKey = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _details = TextEditingController();
  List<Map<String, dynamic>> _tickets = [];
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _subject.dispose();
    _details.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tickets = await widget.api.myTickets(widget.token);
      if (mounted) setState(() => _tickets = tickets);
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is SellerApiException
            ? error.message
            : 'تعذر تحميل تذاكر الدعم.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.api.createTicket(
        widget.token,
        _subject.text,
        _details.text,
      );
      _subject.clear();
      _details.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إرسال تذكرة الدعم.')),
        );
      }
      await _load();
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is SellerApiException
            ? error.message
            : 'تعذر إرسال التذكرة.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الدعم الفني للبائعين'),
        actions: [
          IconButton(
            tooltip: 'تحديث التذاكر',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'تُحفظ التذكرة على حسابك الحالي، ولا يستطيع حساب آخر الاطلاع عليها.',
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _subject,
                      maxLength: 180,
                      decoration: const InputDecoration(labelText: 'عنوان المشكلة'),
                      validator: (value) => value == null || value.trim().length < 2
                          ? 'اكتب عنواناً واضحاً.'
                          : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _details,
                      maxLength: 5000,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: 'التفاصيل'),
                      validator: (value) => value == null || value.trim().length < 5
                          ? 'اكتب تفاصيل المشكلة.'
                          : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                    ],
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                      label: Text(_submitting ? 'جارٍ الإرسال...' : 'إرسال التذكرة'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('تذاكري السابقة', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (_loading && _tickets.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_tickets.isEmpty && _error == null)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text('لا توجد تذاكر سابقة.'),
              ),
            )
          else
            ..._tickets.map((ticket) => Card(
              child: ExpansionTile(
                leading: const Icon(Icons.support_agent, color: _brand),
                title: Text((ticket['subject'] ?? 'تذكرة دعم').toString()),
                subtitle: Text('الحالة: ${ticket['status'] ?? 'مفتوحة'}'),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text((ticket['details'] ?? '').toString()),
                  ),
                  const Divider(),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'رد المنصة: ${(ticket['response'] ?? '').toString().isEmpty
                          ? 'لم يتم الرد بعد'
                          : ticket['response']}',
                    ),
                  ),
                ],
              ),
            )),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(this.title, this.value, this.icon);
  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width > 700 ? 220.0 : (MediaQuery.sizeOf(context).width - 44) / 2;
    return SizedBox(width: width, child: Card(child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: _brand),
        const SizedBox(height: 10),
        Text(title),
        Text(value, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
      ]),
    )));
  }
}
,
).hasMatch(_googleServerClientId.trim());

const _apiBase = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8000/api',
);

void main() => runApp(const SellerApp());

class SellerApiException implements Exception {
  const SellerApiException(this.message);
  final String message;
}

class SellerApi {
  SellerApi({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'alqlaisi_seller_token';

  Future<String?> loadToken() => _storage.read(key: _tokenKey);
  Future<void> saveToken(String token) => _storage.write(key: _tokenKey, value: token);
  Future<void> clearToken() => _storage.delete(key: _tokenKey);

  Future<dynamic> request(
    String path, {
    String method = 'GET',
    String? token,
    Map<String, dynamic>? body,
  }) async {
    final root = _apiBase.replaceAll(RegExp(r'/+$'), '');
    final baseUri = Uri.tryParse(root);
    if (baseUri == null || baseUri.host.isEmpty) {
      throw const SellerApiException('عنوان API غير صالح.');
    }
    if (kReleaseMode &&
        (baseUri.scheme != 'https' || baseUri.userInfo.isNotEmpty)) {
      throw const SellerApiException(
        'نسخة الإنتاج تمنع إرسال بيانات الدخول عبر HTTP. '
        'أعد البناء بعنوان API_BASE_URL يبدأ بـ https://.',
      );
    }

    final uri = Uri.parse(root + path);
    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    late http.Response response;
    try {
      if (method == 'POST') {
        response = await _client.post(
          uri,
          headers: headers,
          body: body == null ? null : jsonEncode(body),
        );
      } else if (method == 'PUT') {
        response = await _client.put(
          uri,
          headers: headers,
          body: body == null ? null : jsonEncode(body),
        );
      } else {
        response = await _client.get(uri, headers: headers);
      }
    } catch (_) {
      throw const SellerApiException('تعذر الاتصال بالخادم. تحقق من عنوان API.');
    }

    dynamic decoded;
    try {
      if (response.body.isNotEmpty) decoded = jsonDecode(response.body);
    } catch (_) {}

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = decoded is Map ? (decoded['detail'] ?? decoded['message']) : null;
      final message = detail?.toString() ??
          'فشل الطلب (${response.statusCode}).';
      throw SellerApiException(message);
    }
    return decoded;
  }

  Future<Map<String, dynamic>> login(String phone, String password) async {
    final result = await request('/auth/login', method: 'POST', body: {'phone': phone.trim(), 'password': password});
    if (result is! Map || (result['access_token'] ?? '').toString().isEmpty) {
      throw const SellerApiException('استجابة تسجيل الدخول غير صالحة.');
    }
    final token = result['access_token'].toString();
    await saveToken(token);
    return me(token);
  }

  Future<Map<String, dynamic>> me(String token) async {
    final result = await request('/auth/me', token: token);
    if (result is! Map) throw const SellerApiException('بيانات الحساب غير صحيحة.');
    return Map<String, dynamic>.from(result);
  }

  Future<Map<String, dynamic>?> myStore(String token) async {
    final result = await request('/vendors/mine', token: token);
    if (result == null) return null;
    if (result is! Map) throw const SellerApiException('بيانات المتجر غير صحيحة.');
    return Map<String, dynamic>.from(result);
  }

  Future<Map<String, dynamic>> applyStore(String token, String name, String phone, String description) async {
    final result = await request('/vendors/register', method: 'POST', token: token, body: {
      'store_name': name.trim(), 'phone': phone.trim(), 'description': description.trim(),
    });
    if (result is! Map) throw const SellerApiException('لم يستلم الخادم بيانات المتجر.');
    return Map<String, dynamic>.from(result);
  }

  Future<List<Map<String, dynamic>>> products(String token, String storeId) async =>
      _asList(await request('/products/vendor/${Uri.encodeComponent(storeId)}', token: token));

  Future<List<Map<String, dynamic>>> orders(String token, String storeId) async =>
      _asList(await request('/orders/vendor/${Uri.encodeComponent(storeId)}', token: token));

  Future<List<Map<String, dynamic>>> myTickets(String token) async =>
      _asList(await request('/support/mine', token: token));

  Future<void> createTicket(String token, String subject, String details) async {
    await request('/support/', method: 'POST', token: token, body: {
      'subject': subject.trim(),
      'details': details.trim(),
    });
  }

  Future<Map<String, dynamic>> salesSummary(String token, String storeId) async {
    final result = await request(
      '/orders/vendor/${Uri.encodeComponent(storeId)}/summary',
      token: token,
    );
    if (result is! Map) {
      throw const SellerApiException('استجابة تقرير المبيعات غير صحيحة.');
    }
    return Map<String, dynamic>.from(result);
  }

  Future<void> addProduct(String token, String name, String description, String image, String category) async {
    await request('/products/', method: 'POST', token: token, body: {
      'title': name.trim(), 'description': description.trim(), 'image_url': image.trim(),
      'category': category.trim().isEmpty ? 'عام' : category.trim(),
    });
  }

  Future<void> updateProduct(
    String token,
    String productId,
    String title,
    String description,
    String imageUrl,
    String category,
  ) async {
    await request('/products/${Uri.encodeComponent(productId)}', method: 'PUT',
      token: token, body: {
        'title': title.trim(),
        'description': description.trim(),
        'image_url': imageUrl.trim(),
        'category': category.trim().isEmpty ? 'عام' : category.trim(),
      });
  }

  Future<void> setAvailability(String token, String id, bool available) async {
    await request('/products/${Uri.encodeComponent(id)}/availability', method: 'PUT',
      token: token, body: {'is_available': available});
  }

  Future<void> setOrderStatus(String token, String id, String status) async {
    await request('/orders/${Uri.encodeComponent(id)}/status?status=${Uri.encodeQueryComponent(status)}',
      method: 'PUT', token: token);
  }

  Future<List<Map<String, dynamic>>> orderHistory(String token, String id) async =>
      _asList(await request('/orders/${Uri.encodeComponent(id)}/history', token: token));

  static List<Map<String, dynamic>> _asList(dynamic value) {
    if (value is! List) throw const SellerApiException('قائمة البيانات غير صالحة.');
    return value.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }

  void dispose() => _client.close();
}

class SellerApp extends StatefulWidget {
  const SellerApp({super.key});
  @override State<SellerApp> createState() => _SellerAppState();
}

class _SellerAppState extends State<SellerApp> {
  final _api = SellerApi();
  String? _token;
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _store;
  bool _loading = true;

  @override void initState() { super.initState(); _restore(); }
  @override void dispose() { _api.dispose(); super.dispose(); }

  Future<void> _restore() async {
    try {
      final token = await _api.loadToken();
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
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _login(String phone, String password) async {
    final user = await _api.login(phone, password);
    final token = await _api.loadToken();
    if (!mounted) return;
    if (token == null) throw const SellerApiException('تعذر حفظ جلسة الدخول.');
    setState(() { _token = token; _user = user; _store = null; });
    await _loadStore();
  }

  Future<void> _loadStore() async {
    final token = _token;
    if (token == null) return;
    final store = await _api.myStore(token);
    if (mounted) setState(() => _store = store);
  }

  Future<void> _logout() async {
    await _api.clearToken();
    if (mounted) setState(() { _token = null; _user = null; _store = null; });
  }

  @override
  Widget build(BuildContext context) {
    Widget page;
    if (_loading) {
      page = const Scaffold(body: Center(child: CircularProgressIndicator()));
    } else if (_token == null || _user == null) {
      page = LoginPage(onLogin: _login);
    } else if (_store == null || _store!['status'] == 'مرفوض') {
      page = ApplyStorePage(api: _api, token: _token!, user: _user!,
        existingStore: _store,
        onApplied: (value) => setState(() => _store = value), onLogout: _logout);
    } else if (_store!['status'] != 'مفعل') {
      page = StorePendingPage(store: _store!, onRefresh: _loadStore, onLogout: _logout);
    } else {
      page = SellerHomePage(api: _api, token: _token!, user: _user!, store: _store!, onLogout: _logout);
    }
    return MaterialApp(
      title: 'Alqlaisi Seller',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: _brand), useMaterial3: true),
      builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child ?? const SizedBox()),
      home: page,
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.onLogin});
  final Future<void> Function(String phone, String password) onLogin;
  @override State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;
  @override void dispose() { _phone.dispose(); _password.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      await widget.onLogin(_phone.text, _password.text);
    } catch (error) {
      if (mounted) setState(() => _error = error is SellerApiException ? error.message : 'تعذر تسجيل الدخول.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fields = <Widget>[
      const Icon(Icons.storefront, size: 56, color: _brand),
      const SizedBox(height: 12),
      Text('Alqlaisi', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 8),
      const Text('بوابة البائعين المعتمدين', textAlign: TextAlign.center),
      const SizedBox(height: 24),
      TextField(controller: _phone, keyboardType: TextInputType.phone,
        decoration: const InputDecoration(labelText: 'رقم الهاتف')),
      const SizedBox(height: 12),
      TextField(controller: _password, obscureText: true,
        decoration: const InputDecoration(labelText: 'كلمة المرور'), onSubmitted: (_) => _submit()),
      if (_error != null) Padding(padding: const EdgeInsets.only(top: 10),
        child: Text(_error!, style: const TextStyle(color: Colors.red))),
      const SizedBox(height: 16),
      FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? 'جارٍ التحقق...' : 'تسجيل الدخول')),
      const SizedBox(height: 10),
      const Text('يجب اعتماد المتجر من الإدارة قبل نشر المنتجات.', textAlign: TextAlign.center),
    ];
    return Scaffold(body: Center(
      child: SingleChildScrollView(padding: const EdgeInsets.all(24),
        child: SizedBox(width: 440, child: Card(child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: fields),
        ))),
      ),
    ));
  }
}

class ApplyStorePage extends StatefulWidget {
  const ApplyStorePage({super.key, required this.api, required this.token, required this.user,
    this.existingStore, required this.onApplied, required this.onLogout});
  final SellerApi api;
  final String token;
  final Map<String, dynamic> user;
  final Map<String, dynamic>? existingStore;
  final ValueChanged<Map<String, dynamic>> onApplied;
  final VoidCallback onLogout;
  @override State<ApplyStorePage> createState() => _ApplyStorePageState();
}

class _ApplyStorePageState extends State<ApplyStorePage> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _description = TextEditingController();
  bool _busy = false;
  String? _error;
  @override void initState() {
    super.initState();
    _name.text = (widget.existingStore?['store_name'] ?? widget.user['name'] ?? widget.user['full_name'] ?? '').toString();
    _phone.text = (widget.existingStore?['phone'] ?? widget.user['phone'] ?? '').toString();
    _description.text = (widget.existingStore?['description'] ?? '').toString();
  }
  @override void dispose() { _name.dispose(); _phone.dispose(); _description.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (_name.text.trim().length < 2 || _phone.text.trim().length < 7) {
      setState(() => _error = 'أدخل اسم المتجر ورقم هاتف صحيحين.');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      final store = await widget.api.applyStore(widget.token, _name.text, _phone.text, _description.text);
      widget.onApplied(store);
    } catch (error) {
      if (mounted) setState(() => _error = error is SellerApiException ? error.message : 'تعذر إرسال الطلب.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fields = <Widget>[
      const Icon(Icons.store_mall_directory_outlined, size: 48, color: _brand),
      Text('مرحباً ${widget.user['name'] ?? widget.user['full_name'] ?? ''}',
        style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      Text(widget.existingStore == null
        ? 'قدّم طلبك؛ ستتمكن من إدارة المنتجات بعد اعتماد المتجر.'
        : 'أعد تقديم طلب المتجر بعد معالجة ملاحظات المراجعة.'),
      const SizedBox(height: 18),
      TextField(controller: _name, decoration: const InputDecoration(labelText: 'اسم المتجر')),
      const SizedBox(height: 12),
      TextField(controller: _phone, keyboardType: TextInputType.phone,
        decoration: const InputDecoration(labelText: 'رقم التواصل')),
      const SizedBox(height: 12),
      TextField(controller: _description, maxLines: 3,
        decoration: const InputDecoration(labelText: 'وصف المتجر')),
      if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
      const SizedBox(height: 16),
      FilledButton(onPressed: _busy ? null : _submit,
        child: Text(_busy ? 'جارٍ الإرسال...' : widget.existingStore == null ? 'إرسال طلب اعتماد المتجر' : 'إعادة تقديم الطلب')),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('طلب فتح متجر'),
        actions: [TextButton(onPressed: widget.onLogout, child: const Text('خروج'))]),
      body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(20),
        child: SizedBox(width: 520, child: Card(child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: fields),
        ))),
      )),
    );
  }
}

class StorePendingPage extends StatelessWidget {
  const StorePendingPage({super.key, required this.store, required this.onRefresh, required this.onLogout});
  final Map<String, dynamic> store;
  final Future<void> Function() onRefresh;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final content = <Widget>[
      const Icon(Icons.hourglass_top_rounded, size: 60, color: Colors.orange),
      const SizedBox(height: 12),
      Text((store['store_name'] ?? 'متجرك').toString(), style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 10),
      Text('حالة الطلب: ${store['status'] ?? 'قيد المراجعة'}'),
      const SizedBox(height: 8),
      const Text('ستظهر إدارة المنتجات والطلبات بعد اعتماد المتجر.', textAlign: TextAlign.center),
      const SizedBox(height: 18),
      FilledButton.icon(onPressed: onRefresh, icon: const Icon(Icons.refresh), label: const Text('تحديث الحالة')),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('حالة طلب المتجر'),
        actions: [TextButton(onPressed: onLogout, child: const Text('خروج'))]),
      body: Center(child: Padding(padding: const EdgeInsets.all(24),
        child: SizedBox(width: 500, child: Card(child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: content),
        ))),
      )),
    );
  }
}

class SellerHomePage extends StatefulWidget {
  const SellerHomePage({super.key, required this.api, required this.token, required this.user,
    required this.store, required this.onLogout});
  final SellerApi api;
  final String token;
  final Map<String, dynamic> user;
  final Map<String, dynamic> store;
  final VoidCallback onLogout;
  @override State<SellerHomePage> createState() => _SellerHomePageState();
}

class _SellerHomePageState extends State<SellerHomePage> {
  int _tab = 0;
  bool _busy = false;
  String? _error;
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _orders = [];
  Map<String, dynamic>? _summary;

  @override void initState() { super.initState(); _refresh(); }

  Future<void> _refresh() async {
    setState(() => _busy = true);
    try {
      final storeId = widget.store['id'].toString();
      final products = await widget.api.products(widget.token, storeId);
      final orders = await widget.api.orders(widget.token, storeId);
      final summary = await widget.api.salesSummary(widget.token, storeId);
      if (mounted) {
        setState(() {
          _products = products;
          _orders = orders;
          _summary = summary;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error is SellerApiException ? error.message : 'تعذر تحميل البيانات.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String value) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> _createProduct() async {
    final key = GlobalKey<FormState>();
    final title = TextEditingController();
    final description = TextEditingController();
    final image = TextEditingController();
    final category = TextEditingController(text: 'قرطاسية');
    final accepted = await showDialog<bool>(context: context, builder: (dialogContext) {
      final fields = <Widget>[
        TextFormField(controller: title, decoration: const InputDecoration(labelText: 'اسم المنتج'),
          validator: (v) => v == null || v.trim().length < 2 ? 'أدخل اسم المنتج.' : null),
        const SizedBox(height: 10),
        TextFormField(controller: description, decoration: const InputDecoration(labelText: 'الوصف'), maxLines: 2),
        const SizedBox(height: 10),
        TextFormField(controller: category, decoration: const InputDecoration(labelText: 'التصنيف')),
        const SizedBox(height: 10),
        TextFormField(controller: image, decoration: const InputDecoration(labelText: 'رابط الصورة (اختياري)')),
        const SizedBox(height: 8),
        const Text('السعر النهائي تحدده الإدارة قبل النشر.', style: TextStyle(fontSize: 12)),
      ];
      return AlertDialog(
        title: const Text('إضافة منتج للمراجعة'),
        content: SizedBox(width: 420, child: Form(key: key,
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: fields)))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, key.currentState?.validate() == true),
            child: const Text('إرسال للمراجعة')),
        ],
      );
    });
    if (accepted == true) {
      try {
        await widget.api.addProduct(widget.token, title.text, description.text, image.text, category.text);
        _message('تم إرسال المنتج للمراجعة. ستحدد الإدارة سعر البيع.');
        await _refresh();
      } catch (error) {
        _message(error is SellerApiException ? error.message : 'تعذر إضافة المنتج.');
      }
    }
    title.dispose(); description.dispose(); image.dispose(); category.dispose();
  }

  Future<void> _editProduct(Map<String, dynamic> product) async {
    final key = GlobalKey<FormState>();
    final title = TextEditingController(text: (product['title'] ?? '').toString());
    final description = TextEditingController(text: (product['description'] ?? '').toString());
    final image = TextEditingController(text: (product['image_url'] ?? '').toString());
    final category = TextEditingController(text: (product['category'] ?? 'عام').toString());
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تعديل بيانات المنتج'),
        content: SizedBox(
          width: 440,
          child: Form(
            key: key,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'اسم المنتج'),
                  validator: (value) => value == null || value.trim().length < 2
                      ? 'أدخل اسم المنتج.'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: description,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'الوصف'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: category,
                  decoration: const InputDecoration(labelText: 'التصنيف'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: image,
                  decoration: const InputDecoration(labelText: 'رابط الصورة'),
                ),
                const SizedBox(height: 8),
                const Text(
                  'سيعود المنتج إلى المراجعة وسيتوقف عرضه حتى تعتمد الإدارة السعر والنشر مجدداً.',
                  style: TextStyle(fontSize: 12),
                ),
              ]),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, key.currentState?.validate() == true),
            child: const Text('حفظ وإرسال للمراجعة'),
          ),
        ],
      ),
    );
    if (accepted == true) {
      try {
        await widget.api.updateProduct(
          widget.token,
          product['id'].toString(),
          title.text,
          description.text,
          image.text,
          category.text,
        );
        _message('تم حفظ التعديلات وإرسال المنتج إلى مراجعة الإدارة.');
        await _refresh();
      } catch (error) {
        _message(error is SellerApiException ? error.message : 'تعذر تعديل المنتج.');
      }
    }
    title.dispose();
    description.dispose();
    image.dispose();
    category.dispose();
  }

  Future<void> _availability(Map<String, dynamic> product, bool value) async {
    try {
      await widget.api.setAvailability(widget.token, product['id'].toString(), value);
      _message('تم تحديث التوافر.');
      await _refresh();
    } catch (error) {
      _message(error is SellerApiException ? error.message : 'تعذر تحديث التوافر.');
    }
  }

  Future<void> _orderStatus(Map<String, dynamic> order, String value) async {
    try {
      await widget.api.setOrderStatus(widget.token, order['id'].toString(), value);
      _message('تم تحديث حالة الطلب.');
      await _refresh();
    } catch (error) {
      _message(error is SellerApiException ? error.message : 'تعذر تحديث حالة الطلب.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final storeName = (widget.store['store_name'] ?? 'Alqlaisi').toString();
    final pages = <Widget>[
      _overview(storeName),
      _productPage(),
      _orderPage(),
      _reportPage(),
      _settings(storeName),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(storeName),
        actions: [IconButton(tooltip: 'تحديث', onPressed: _refresh, icon: const Icon(Icons.refresh))]),
      body: Column(children: [
        if (_error != null) MaterialBanner(content: Text(_error!), actions: [
          TextButton(onPressed: _refresh, child: const Text('إعادة المحاولة')),
        ]),
        if (_busy) const LinearProgressIndicator(),
        Expanded(child: IndexedStack(index: _tab, children: pages)),
      ]),
      floatingActionButton: _tab == 1
          ? FloatingActionButton.extended(onPressed: _createProduct, icon: const Icon(Icons.add), label: const Text('إضافة منتج'))
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'المنتجات'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'الطلبات'),
          NavigationDestination(icon: Icon(Icons.analytics_outlined), selectedIcon: Icon(Icons.analytics), label: 'التقارير'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'الإعدادات'),
        ],
      ),
    );
  }

  Widget _overview(String storeName) {
    final pending = _products.where((p) => p['review_status'] == 'قيد المراجعة').length;
    final metrics = <Widget>[
      _MetricCard('المنتجات', _products.length.toString(), Icons.inventory_2),
      _MetricCard('قيد المراجعة', pending.toString(), Icons.pending_actions),
      _MetricCard('الطلبات', _orders.length.toString(), Icons.receipt_long),
      const _MetricCard('التوافر', 'يدوي', Icons.toggle_on),
    ];
    return RefreshIndicator(onRefresh: _refresh, child: ListView(padding: const EdgeInsets.all(16), children: [
      Text('مرحباً، ${widget.user['name'] ?? ''}', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 6),
      Text('متجر $storeName · معتمد', style: const TextStyle(color: Colors.green)),
      const SizedBox(height: 18),
      Wrap(spacing: 12, runSpacing: 12, children: metrics),
      const SizedBox(height: 18),
      const Card(child: ListTile(leading: Icon(Icons.info_outline), title: Text('سياسة التسعير'),
        subtitle: Text('ترسل المنتجات للإدارة للمراجعة؛ السعر النهائي يحدده مدير المنصة.'))),
      const Card(child: ListTile(leading: Icon(Icons.inventory_outlined), title: Text('التوافر اليدوي'),
        subtitle: Text('لا توجد كميات مخزون. حدد هل المنتج متاح أم غير متاح مؤقتاً.'))),
    ]));
  }

  Widget _productPage() {
    if (_products.isEmpty) return const Center(child: Text('لا توجد منتجات بعد. أضف منتجاً لإرساله للمراجعة.'));
    return RefreshIndicator(onRefresh: _refresh, child: ListView.builder(
      padding: const EdgeInsets.all(12), itemCount: _products.length,
      itemBuilder: (context, index) {
        final product = _products[index];
        final status = (product['review_status'] ?? 'قيد المراجعة').toString();
        final price = (product['price'] as num?)?.toString() ?? '0';
        final approved = status == 'منشور' && ((product['price'] as num?) ?? 0) > 0;
        final children = <Widget>[
          Row(
            children: [
              Expanded(
                child: Text(
                  (product['title'] ?? 'منتج').toString(),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'تعديل بيانات المنتج',
                onPressed: () => _editProduct(product),
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('السعر المعتمد: $price ريال'),
          Text('الحالة: $status'),
          Row(children: [
            const Expanded(child: Text('متاح للعملاء')),
            Switch(value: product['is_available'] == true && approved,
              onChanged: approved ? (value) => _availability(product, value) : null),
          ]),
          if (!approved) const Text('ينتظر اعتماد الإدارة وتحديد السعر.', style: TextStyle(color: Colors.orange)),
        ];
        return Card(child: Padding(padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children)));
      },
    ));
  }

  Widget _orderPage() {
    if (_orders.isEmpty) return const Center(child: Text('لا توجد طلبات جديدة لهذا المتجر.'));
    return RefreshIndicator(onRefresh: _refresh, child: ListView.builder(
      padding: const EdgeInsets.all(12), itemCount: _orders.length,
      itemBuilder: (context, index) {
        final order = _orders[index];
        final status = (order['status'] ?? 'بانتظار القبول').toString();
        final total = (order['total_price'] as num?)?.toString() ?? '0';
        final allowed = status == 'بانتظار القبول'
            ? ['قيد التجهيز', 'ملغي']
            : status == 'قيد التجهيز' ? ['جاهز للتوصيل', 'ملغي'] : <String>[];
        final children = <Widget>[
          Text('طلب ${order['id']}', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 5),
          Text('الإجمالي شامل التوصيل: $total ريال'),
          Text('طريقة الدفع: ${order['payment_method'] ?? 'الدفع عند الاستلام'}'),
          Text('العنوان: ${order['address'] ?? '—'}'),
          Text('الحالة: $status'),
          if (allowed.isNotEmpty) Wrap(spacing: 8,
            children: allowed.map((next) => OutlinedButton(
              onPressed: () => _orderStatus(order, next), child: Text(next))).toList()),
        ];
        return Card(child: Padding(padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children)));
      },
    ));
  }

  Widget _reportPage() {
    final summary = _summary;
    if (summary == null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('تعذر تحميل تقرير المبيعات من الخادم.'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة'),
          ),
        ]),
      );
    }

    final deliveredValue = summary['delivered_gross_value'];
    final commissionConfigured = summary['commission_configured'] == true;
    final currency = (summary['currency'] ?? 'YER').toString();
    String valueOf(String key) => (summary[key] ?? 0).toString();
    final statusCounts = summary['status_counts'];
    final statuses = statusCounts is Map
        ? Map<String, dynamic>.from(statusCounts)
        : <String, dynamic>{};

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('تقرير المتجر', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            'تقرير من الخادم للمتجر: ${summary['store_name'] ?? widget.store['store_name'] ?? ''}',
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MetricCard('كل الطلبات', valueOf('order_count'), Icons.receipt_long),
              _MetricCard('قيد المعالجة', valueOf('pending_count'), Icons.pending_actions),
              _MetricCard('تم التسليم', valueOf('delivered_count'), Icons.task_alt),
              _MetricCard('ملغاة', valueOf('cancelled_count'), Icons.cancel_outlined),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'إجمالي قيمة الطلبات المسلّمة',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${deliveredValue ?? 0} ريال',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: _brand,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'هذا إجمالي قيمة الطلبات التي وصلت إلى حالة "تم التسليم"، ويشمل رسوم التوصيل؛ '
                    'ليس صافي ربح البائع أو تسوية مالية.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('الطلبات حسب الحالة', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (statuses.isEmpty)
                    const Text('لا توجد بيانات حالة حالياً.')
                  else
                    ...statuses.entries.map((entry) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(entry.key),
                      trailing: Text(entry.value.toString()),
                    )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: Icon(
                commissionConfigured ? Icons.verified_outlined : Icons.info_outline,
                color: commissionConfigured ? Colors.green : Colors.orange,
              ),
              title: Text(commissionConfigured ? 'العمولة مهيأة' : 'العمولة غير محددة'),
              subtitle: Text(
                commissionConfigured
                    ? 'نسبة العمولة: ${summary['commission_percent'] ?? '—'}%'
                    : (summary['commission_note'] ??
                      'لم تحدد نسبة العمولة؛ لا يتم احتساب عمولة أو تسوية مالية.').toString(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'العملة المعلنة من الخادم: $currency · حدّث الصفحة لجلب أرقام أحدث.',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _settings(String storeName) => ListView(padding: const EdgeInsets.all(16), children: [
    Card(
      child: ListTile(
        leading: const Icon(Icons.support_agent, color: _brand),
        title: const Text('الدعم الفني للبائعين'),
        subtitle: const Text('إرسال استفسار ومتابعة ردود فريق المنصة'),
        trailing: const Icon(Icons.chevron_left),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SellerSupportPage(api: widget.api, token: widget.token),
          ),
        ),
      ),
    ),
    Card(child: ListTile(leading: const Icon(Icons.storefront), title: Text(storeName),
      subtitle: Text('معرّف المتجر: ${widget.store['id']}'))),
    Card(child: ListTile(leading: const Icon(Icons.person_outline),
      title: Text((widget.user['name'] ?? 'البائع').toString()),
      subtitle: Text((widget.user['phone'] ?? '').toString()))),
    const Card(child: ListTile(leading: Icon(Icons.local_shipping_outlined), title: Text('التوصيل'),
      subtitle: Text('تنسق المنصة التوصيل الداخلي وتحديث حالة الطلب.'))),
    const Card(child: ListTile(leading: Icon(Icons.payments_outlined), title: Text('المحاسبة'),
      subtitle: Text('الدفع عند الاستلام فقط في الإصدار الأول.'))),
    FilledButton.icon(onPressed: widget.onLogout, icon: const Icon(Icons.logout), label: const Text('تسجيل الخروج')),
  ]);
}

class SellerSupportPage extends StatefulWidget {
  const SellerSupportPage({
    super.key,
    required this.api,
    required this.token,
  });

  final SellerApi api;
  final String token;

  @override
  State<SellerSupportPage> createState() => _SellerSupportPageState();
}

class _SellerSupportPageState extends State<SellerSupportPage> {
  final _formKey = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _details = TextEditingController();
  List<Map<String, dynamic>> _tickets = [];
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _subject.dispose();
    _details.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tickets = await widget.api.myTickets(widget.token);
      if (mounted) setState(() => _tickets = tickets);
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is SellerApiException
            ? error.message
            : 'تعذر تحميل تذاكر الدعم.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.api.createTicket(
        widget.token,
        _subject.text,
        _details.text,
      );
      _subject.clear();
      _details.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إرسال تذكرة الدعم.')),
        );
      }
      await _load();
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is SellerApiException
            ? error.message
            : 'تعذر إرسال التذكرة.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الدعم الفني للبائعين'),
        actions: [
          IconButton(
            tooltip: 'تحديث التذاكر',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'تُحفظ التذكرة على حسابك الحالي، ولا يستطيع حساب آخر الاطلاع عليها.',
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _subject,
                      maxLength: 180,
                      decoration: const InputDecoration(labelText: 'عنوان المشكلة'),
                      validator: (value) => value == null || value.trim().length < 2
                          ? 'اكتب عنواناً واضحاً.'
                          : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _details,
                      maxLength: 5000,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: 'التفاصيل'),
                      validator: (value) => value == null || value.trim().length < 5
                          ? 'اكتب تفاصيل المشكلة.'
                          : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                    ],
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                      label: Text(_submitting ? 'جارٍ الإرسال...' : 'إرسال التذكرة'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('تذاكري السابقة', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (_loading && _tickets.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_tickets.isEmpty && _error == null)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text('لا توجد تذاكر سابقة.'),
              ),
            )
          else
            ..._tickets.map((ticket) => Card(
              child: ExpansionTile(
                leading: const Icon(Icons.support_agent, color: _brand),
                title: Text((ticket['subject'] ?? 'تذكرة دعم').toString()),
                subtitle: Text('الحالة: ${ticket['status'] ?? 'مفتوحة'}'),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text((ticket['details'] ?? '').toString()),
                  ),
                  const Divider(),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'رد المنصة: ${(ticket['response'] ?? '').toString().isEmpty
                          ? 'لم يتم الرد بعد'
                          : ticket['response']}',
                    ),
                  ),
                ],
              ),
            )),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(this.title, this.value, this.icon);
  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width > 700 ? 220.0 : (MediaQuery.sizeOf(context).width - 44) / 2;
    return SizedBox(width: width, child: Card(child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: _brand),
        const SizedBox(height: 10),
        Text(title),
        Text(value, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
      ]),
    )));
  }
}
