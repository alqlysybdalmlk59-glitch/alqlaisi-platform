import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import 'models/auth_user.dart';
import 'services/auth_service.dart';
import 'validators/auth_validators.dart';

const String _googleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

class RegisterPage extends StatefulWidget {
  const RegisterPage({
    super.key,
    required this.onAuthenticated,
    this.onLogin,
  });

  final ValueChanged<AuthSession> onAuthenticated;
  final VoidCallback? onLogin;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  late final ApiClient _client;
  late final AuthService _authService;

  bool _loading = false;
  bool _hidePassword = true;
  bool _hideConfirm = true;
  bool _acceptedTerms = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _client = ApiClient();
    _authService = AuthService(_client);
  }

  @override
  void dispose() {
    _client.close();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    if (!_acceptedTerms) {
      setState(() => _error = 'يجب الموافقة على الشروط قبل إنشاء الحساب.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final session = await _authService.register(
        fullName: _nameController.text,
        phone: _phoneController.text,
        password: _passwordController.text,
        email: _emailController.text,
      );

      if (!mounted) return;
      widget.onAuthenticated(session);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'تعذر إنشاء الحساب. حاول مرة أخرى.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _registerWithGoogle() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (!ApiEndpoints.googleServerClientIdConfigured) {
        throw const ApiException(
          message: 'تسجيل Google غير مهيأ. استخدم معرّف Web OAuth الحقيقي من Google Cloud في GOOGLE_SERVER_CLIENT_ID.',
        );
      }

      final googleUser = await GoogleSignIn(
        serverClientId: _googleServerClientId,
      ).signIn();
      if (googleUser == null) return;

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const ApiException(
          message: 'لم يصل رمز التحقق من Google. تحقق من إعداد OAuth.',
        );
      }

      // The backend verifies Google's ID token and returns the existing
      // platform account for the same Google subject, or creates it once.
      final session = await _authService.signInWithGoogle(idToken: idToken);
      if (!mounted) return;
      widget.onAuthenticated(session);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'تعذر إنشاء الحساب بواسطة Google. تحقق من الإعدادات والاتصال.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إنشاء حساب جديد')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(22),
            children: [
              const Icon(
                Icons.person_add_alt_1_rounded,
                size: 62,
                color: AppTheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                'انضم إلى منصة القليسي',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'أدخل بياناتك لإنشاء حساب عميل.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'الاسم الكامل',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: AuthValidators.fullName,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'رقم الهاتف',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: AuthValidators.phone,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'البريد الإلكتروني (اختياري)',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: AuthValidators.email,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _passwordController,
                obscureText: _hidePassword,
                decoration: InputDecoration(
                  labelText: 'كلمة المرور',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    onPressed: () => setState(
                      () => _hidePassword = !_hidePassword,
                    ),
                    icon: Icon(
                      _hidePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: AuthValidators.password,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _confirmController,
                obscureText: _hideConfirm,
                decoration: InputDecoration(
                  labelText: 'تأكيد كلمة المرور',
                  prefixIcon: const Icon(Icons.lock_reset_outlined),
                  suffixIcon: IconButton(
                    onPressed: () => setState(
                      () => _hideConfirm = !_hideConfirm,
                    ),
                    icon: Icon(
                      _hideConfirm
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: (value) => AuthValidators.confirmPassword(
                  value,
                  _passwordController.text,
                ),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _acceptedTerms,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: _loading
                    ? null
                    : (value) {
                        setState(() {
                          _acceptedTerms = value ?? false;
                          _error = null;
                        });
                      },
                title: const Text(
                  'أوافق على شروط الاستخدام وسياسة الخصوصية.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(color: AppTheme.error),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loading ? null : _register,
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('إنشاء الحساب'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _loading ? null : _registerWithGoogle,
                icon: const Icon(Icons.g_mobiledata, size: 30),
                label: const Text('المتابعة باستخدام Google'),
              ),
              TextButton(
                onPressed: _loading ? null : widget.onLogin,
                child: const Text('لديك حساب بالفعل؟ تسجيل الدخول'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
