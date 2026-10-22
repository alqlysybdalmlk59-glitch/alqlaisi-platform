import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import 'models/auth_user.dart';
import 'services/auth_service.dart';
import 'validators/auth_validators.dart';

const String _googleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.onAuthenticated,
    this.onRegister,
  });

  final ValueChanged<AuthSession> onAuthenticated;
  final VoidCallback? onRegister;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  late final ApiClient _client;
  late final AuthService _authService;

  bool _loading = false;
  bool _hidePassword = true;
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
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final session = await _authService.login(
        phone: _phoneController.text,
        password: _passwordController.text,
      );

      if (!mounted) return;

      widget.onAuthenticated(session);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'تعذر تسجيل الدخول.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loginWithGoogle() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_googleServerClientId.isEmpty) {
        throw const ApiException(message: 'تسجيل Google غير مهيأ في هذا البناء. أعد بناء التطبيق باستخدام GOOGLE_SERVER_CLIENT_ID الصحيح.');
      }
      final googleUser = await GoogleSignIn(serverClientId: _googleServerClientId).signIn();
      if (googleUser == null) {
        return; // The user cancelled the Google account picker.
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const ApiException(
          message: 'لم يصل رمز التحقق من Google. تحقق من إعداد OAuth.',
        );
      }

      final session = await _authService.signInWithGoogle(idToken: idToken);
      if (!mounted) return;
      widget.onAuthenticated(session);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'تعذر تسجيل الدخول بواسطة Google. تحقق من الإعدادات والاتصال.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل الدخول')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.storefront_rounded,
                    size: 68,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'مرحبًا بك في منصة القليسي',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'سجّل الدخول للمتابعة إلى حسابك.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    decoration: const InputDecoration(
                      labelText: 'رقم الهاتف',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    validator: AuthValidators.phone,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _hidePassword,
                    autofillHints: const [AutofillHints.password],
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
                    onFieldSubmitted: (_) => _login(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(color: AppTheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _loading ? null : _login,
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('تسجيل الدخول'),
                  ),
                  const SizedBox(height: 12),
                  if (_googleServerClientId.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: _loading ? null : _loginWithGoogle,
                      icon: const Icon(Icons.g_mobiledata, size: 30),
                      label: const Text('متابعة باستخدام Google'),
                    )
                  else
                    const Text(
                      'تسجيل Google يحتاج إعداد OAuth في نسخة التطبيق قبل إتاحته.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.muted),
                    ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _loading ? null : widget.onRegister,
                    child: const Text('ليس لديك حساب؟ أنشئ حسابًا'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
