import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../support/support_page.dart';

const String _googleServerClientId =
    String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.token,
    required this.onLogout,
  });

  final String token;
  final Future<void> Function() onLogout;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final ApiClient _api;
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _store;
  bool _loading = true;
  bool _applyingStore = false;
  bool _updatingProfile = false;
  bool _linkingGoogle = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _api = ApiClient();
    _load();
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rawUser = await _api.get('/auth/me', token: widget.token);
      if (rawUser is! Map) {
        throw const ApiException(message: 'استجابة بيانات الحساب غير صحيحة.');
      }
      final rawStore = await _api.get('/vendors/mine', token: widget.token);
      final store = rawStore is Map && (rawStore['id'] ?? '').toString().isNotEmpty
          ? Map<String, dynamic>.from(rawStore)
          : null;

      if (mounted) {
        setState(() {
          _user = Map<String, dynamic>.from(rawUser);
          _store = store;
          _error = null;
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر تحميل الملف الشخصي.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppTheme.error : null,
      ),
    );
  }

  Future<void> _editProfile() async {
    if (_user == null || _updatingProfile) return;

    final formKey = GlobalKey<FormState>();
    final name = TextEditingController(
      text: (_user?['full_name'] ?? _user?['name'] ?? '').toString(),
    );
    final phone = TextEditingController(text: (_user?['phone'] ?? '').toString());

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تعديل بيانات الحساب'),
        content: SizedBox(
          width: 420,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: name,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'الاسم الكامل'),
                  validator: (value) => value == null || value.trim().length < 2
                      ? 'أدخل الاسم الكامل.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'رقم الهاتف'),
                  validator: (value) {
                    final normalized = (value ?? '')
                        .trim()
                        .replaceAll(RegExp(r'[\\s()-]'), '');
                    return RegExp(r'^\\+?[0-9]{8,19}$').hasMatch(normalized)
                        ? null
                        : 'أدخل رقماً من 8 إلى 19 رقماً مع + اختياري.';
                  },
                ),
                const SizedBox(height: 8),
                const Text(
                  'البريد الإلكتروني لا يتغير من هذه الشاشة. ربط Google له مسار تحقق مستقل.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
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
                Navigator.pop(dialogContext, formKey.currentState?.validate() == true),
            child: const Text('حفظ التغييرات'),
          ),
        ],
      ),
    );

    if (save == true) {
      setState(() => _updatingProfile = true);
      try {
        final response = await _api.put(
          '/auth/me/profile',
          token: widget.token,
          body: {'full_name': name.text.trim(), 'phone': phone.text.trim()},
        );
        if (response is! Map) {
          throw const ApiException(message: 'استجابة تحديث الملف غير صحيحة.');
        }
        if (mounted) {
          setState(() => _user = Map<String, dynamic>.from(response));
          _showMessage('تم تحديث بيانات الحساب على الخادم.');
        }
      } on ApiException catch (error) {
        _showMessage(error.message, error: true);
      } catch (_) {
        _showMessage('تعذر حفظ البيانات؛ لم يتم تأكيد التغيير.', error: true);
      } finally {
        if (mounted) setState(() => _updatingProfile = false);
      }
    }

    name.dispose();
    phone.dispose();
  }

  Future<void> _linkGoogle() async {
    if (_linkingGoogle) return;
    if (_googleServerClientId.trim().isEmpty) {
      _showMessage(
        'إعداد GOOGLE_SERVER_CLIENT_ID غير موجود في نسخة التطبيق هذه.',
        error: true,
      );
      return;
    }

    setState(() => _linkingGoogle = true);
    try {
      final account =
          await GoogleSignIn(serverClientId: _googleServerClientId).signIn();
      if (account == null) return;

      final authentication = await account.authentication;
      final idToken = authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const ApiException(
          message: 'لم يصل رمز Google. تحقق من إعداد OAuth.',
        );
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
        _showMessage('تم التحقق من Google وربطه بهذا الحساب.');
      }
    } on ApiException catch (error) {
      _showMessage(error.message, error: true);
    } catch (_) {
      _showMessage(
        'تعذر ربط Google. لم يتم تعديل الحساب؛ تحقق من الإعدادات والاتصال.',
        error: true,
      );
    } finally {
      if (mounted) setState(() => _linkingGoogle = false);
    }
  }

  Future<void> _applyStore() async {
    if (_applyingStore) return;

    final formKey = GlobalKey<FormState>();
    final storeName = TextEditingController(
      text: (_store?['store_name'] ?? '').toString(),
    );
    final phone = TextEditingController(
      text: (_store?['phone'] ?? _user?['phone'] ?? '').toString(),
    );
    final description = TextEditingController(
      text: (_store?['description'] ?? '').toString(),
    );

    final submit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_store == null ? 'طلب فتح متجر' : 'إعادة تقديم طلب المتجر'),
        content: SizedBox(
          width: 440,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: storeName,
                    decoration: const InputDecoration(labelText: 'اسم المتجر'),
                    validator: (value) => value == null || value.trim().length < 2
                        ? 'أدخل اسم المتجر.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'رقم التواصل'),
                    validator: (value) => value == null || value.trim().length < 7
                        ? 'تحقق من رقم الهاتف.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: description,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'وصف المتجر'),
                  ),
                  if (_store?['admin_notes'] != null &&
                      _store!['admin_notes'].toString().trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'ملاحظات الإدارة: ${_store!['admin_notes']}',
                        style: const TextStyle(color: AppTheme.error),
                      ),
                    ),
                  ],
                ],
              ),
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
                Navigator.pop(dialogContext, formKey.currentState?.validate() == true),
            child: const Text('إرسال'),
          ),
        ],
      ),
    );

    if (submit == true) {
      setState(() => _applyingStore = true);
      try {
        final response = await _api.post(
          '/vendors/register',
          token: widget.token,
          body: {
            'store_name': storeName.text.trim(),
            'phone': phone.text.trim(),
            'description': description.text.trim(),
          },
        );
        if (response is! Map || (response['id'] ?? '').toString().isEmpty) {
          throw const ApiException(message: 'استجابة طلب المتجر غير صحيحة.');
        }
        if (mounted) {
          setState(() => _store = Map<String, dynamic>.from(response));
          _showMessage('تم إرسال طلب المتجر للمراجعة.');
        }
      } on ApiException catch (error) {
        _showMessage(error.message, error: true);
      } catch (_) {
        _showMessage('تعذر إرسال الطلب؛ تحقق من الاتصال وحاول مرة أخرى.', error: true);
      } finally {
        if (mounted) setState(() => _applyingStore = false);
      }
    }

    storeName.dispose();
    phone.dispose();
    description.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final store = _store;
    final googleLinked = user?['google_linked'] == true;
    final canApplyForStore = store == null || store['status'] == 'مرفوض';

    return Scaffold(
      appBar: AppBar(
        title: const Text('حسابي'),
        actions: [
          IconButton(
            tooltip: 'تحديث البيانات',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading && user == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: [
                      const CircleAvatar(
                        radius: 34,
                        child: Icon(Icons.person, size: 36),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        (user?['full_name'] ?? user?['name'] ?? 'المستخدم').toString(),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text((user?['phone'] ?? '').toString()),
                      Text((user?['email'] ?? 'لا يوجد بريد مسجل').toString()),
                      const SizedBox(height: 8),
                      Chip(label: Text('الدور: ${user?['role'] ?? 'customer'}')),
                    ],
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(_error!, style: const TextStyle(color: AppTheme.error)),
                  ),
                const SizedBox(height: 10),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.edit_outlined, color: AppTheme.primary),
                    title: const Text('تعديل بيانات الحساب'),
                    subtitle: const Text('تحديث الاسم ورقم الهاتف المحفوظين على الخادم'),
                    trailing: _updatingProfile
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_left),
                    onTap: _loading || _updatingProfile ? null : _editProfile,
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: Icon(
                      googleLinked ? Icons.verified_user : Icons.g_mobiledata,
                      color: googleLinked ? Colors.green : AppTheme.primary,
                      size: 30,
                    ),
                    title: Text(googleLinked ? 'حساب Google موثّق' : 'ربط حساب Google'),
                    subtitle: Text(
                      googleLinked
                          ? 'تم ربط هوية Google بهذا الحساب بعد التحقق من الخادم.'
                          : 'يتطلب تسجيل الدخول الحالي ثم التحقق من رمز Google على الخادم.',
                    ),
                    trailing: googleLinked
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : _linkingGoogle
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.chevron_left),
                    onTap: googleLinked || _linkingGoogle ? null : _linkGoogle,
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.support_agent),
                    title: const Text('الدعم الفني والشكاوى'),
                    subtitle: const Text('إرسال تذكرة ومتابعة الردود'),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => SupportPage(token: widget.token),
                      ),
                    ),
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.storefront),
                    title: const Text('حساب البائع والمتجر'),
                    subtitle: Text(
                      store == null
                          ? 'لم تقدم طلب متجر بعد.'
                          : '${store['store_name'] ?? ''} · ${store['status'] ?? 'قيد المراجعة'}',
                    ),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: canApplyForStore && !_applyingStore ? _applyStore : null,
                  ),
                ),
                if (canApplyForStore)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: FilledButton.icon(
                      onPressed: _applyingStore ? null : _applyStore,
                      icon: const Icon(Icons.add_business),
                      label: Text(
                        _applyingStore
                            ? 'جارٍ الإرسال...'
                            : store == null
                                ? 'طلب فتح متجر'
                                : 'إعادة تقديم طلب المتجر',
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: widget.onLogout,
                  icon: const Icon(Icons.logout),
                  label: const Text('تسجيل الخروج'),
                ),
              ],
            ),
    );
  }
}
