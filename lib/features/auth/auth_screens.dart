import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'auth_service.dart';

String authErrorText(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'هذا البريد مسجل مسبقًا.';
      case 'invalid-email':
        return 'صيغة البريد الإلكتروني غير صحيحة.';
      case 'weak-password':
        return 'كلمة المرور ضعيفة. استخدم 6 أحرف على الأقل.';
      case 'user-not-found':
      case 'invalid-credential':
      case 'wrong-password':
        return 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
      case 'too-many-requests':
        return 'محاولات كثيرة. انتظر قليلًا ثم حاول مجددًا.';
      case 'network-request-failed':
        return 'تعذر الاتصال بالإنترنت.';
      case 'google-sign-in-cancelled':
        return 'ألغيت عملية تسجيل الدخول بجوجل.';
      default:
        return error.message ??
            'تعذر إكمال العملية. تحقق من الإعدادات وحاول مجددًا.';
    }
  }
  return 'حدث خطأ غير متوقع. تحقق من الإنترنت والإعدادات ثم حاول مجددًا.';
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.storefront_rounded,
                        size: 64, color: Color(0xFF176B52)),
                    const SizedBox(height: 12),
                    Text('القليسي | Al Qulaisi',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 22),
                    Text(title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(subtitle,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 24),
                    child,
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) showMessage(context, authErrorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
        title: 'تسجيل الدخول',
        subtitle: 'سجّل الدخول لمتابعة التسوق وطلباتك',
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                    labelText: 'البريد الإلكتروني',
                    prefixIcon: Icon(Icons.email_outlined)),
                validator: (v) => v == null ||
                        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                            .hasMatch(v.trim())
                    ? 'أدخل بريدًا إلكترونيًا صحيحًا.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                obscureText: _hidePassword,
                decoration: InputDecoration(
                    labelText: 'كلمة المرور',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => _hidePassword = !_hidePassword),
                        icon: Icon(_hidePassword
                            ? Icons.visibility
                            : Icons.visibility_off))),
                validator: (v) =>
                    v == null || v.isEmpty ? 'أدخل كلمة المرور.' : null,
              ),
              Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                      onPressed: _busy
                          ? null
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const ForgotPasswordScreen())),
                      child: const Text('نسيت كلمة المرور؟'))),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () {
                        if (!_formKey.currentState!.validate()) return;
                        _run(() async {
                          await AuthService.instance.signIn(
                              email: _email.text, password: _password.text);
                        });
                      },
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('تسجيل الدخول'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.g_mobiledata, size: 30),
                label: const Text('متابعة باستخدام Google'),
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                          await AuthService.instance.signInWithGoogle();
                        }),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const RegisterScreen())),
                child: const Text('ليس لديك حساب؟ إنشاء حساب جديد'),
              ),
            ],
          ),
        ),
      );
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _accepted = false;
  bool _hide = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    if (!_accepted) {
      showMessage(context, 'يجب الموافقة على الشروط وسياسة الخصوصية للمتابعة.');
      return;
    }
    setState(() => _busy = true);
    try {
      await AuthService.instance.createAccount(
          name: _name.text, email: _email.text, password: _password.text);
      if (mounted) {
        showMessage(
            context, 'أُنشئ الحساب. افتح بريدك واضغط رابط التحقق قبل الدخول.');
      }
    } catch (e) {
      if (mounted) showMessage(context, authErrorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
        title: 'إنشاء حساب',
        subtitle: 'أنشئ حسابًا لتتمكن من التسوق ومتابعة طلباتك',
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                      labelText: 'الاسم الكامل',
                      prefixIcon: Icon(Icons.person_outline)),
                  validator: (v) => v == null || v.trim().length < 2
                      ? 'أدخل اسمك الكامل.'
                      : null),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                      labelText: 'البريد الإلكتروني',
                      prefixIcon: Icon(Icons.email_outlined)),
                  validator: (v) => v == null ||
                          !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                              .hasMatch(v.trim())
                      ? 'أدخل بريدًا صحيحًا.'
                      : null),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _password,
                  obscureText: _hide,
                  decoration: InputDecoration(
                      labelText: 'كلمة المرور (6 أحرف على الأقل)',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                          onPressed: () => setState(() => _hide = !_hide),
                          icon: Icon(_hide
                              ? Icons.visibility
                              : Icons.visibility_off))),
                  validator: (v) => v == null || v.length < 6
                      ? 'كلمة المرور يجب ألا تقل عن 6 أحرف.'
                      : null),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _confirm,
                  obscureText: true,
                  decoration: const InputDecoration(
                      labelText: 'تأكيد كلمة المرور',
                      prefixIcon: Icon(Icons.lock_reset)),
                  validator: (v) => v != _password.text
                      ? 'كلمتا المرور غير متطابقتين.'
                      : null),
              const SizedBox(height: 10),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _accepted,
                onChanged: (v) => setState(() => _accepted = v ?? false),
                title: const Text('أوافق على الشروط والأحكام وسياسة الخصوصية'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 8),
              FilledButton(
                  onPressed: _busy ? null : _register,
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('إنشاء الحساب وإرسال رابط التحقق')),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.g_mobiledata, size: 30),
                label: const Text('متابعة باستخدام Google'),
                onPressed: _busy
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        try {
                          await AuthService.instance.signInWithGoogle();
                        } catch (e) {
                          if (mounted) {
                            showMessage(this.context, authErrorText(e));
                          }
                        } finally {
                          if (mounted) setState(() => _busy = false);
                        }
                      },
              ),
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('لديك حساب؟ تسجيل الدخول')),
            ],
          ),
        ),
      );
}

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});
  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _busy = false;
  Future<void> _check() async {
    setState(() => _busy = true);
    try {
      await AuthService.instance.reloadCurrentUser();
      final user = FirebaseAuth.instance.currentUser;
      if (user?.emailVerified == true) {
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const _GateRefresh()),
              (_) => false);
        }
      } else if (mounted) {
        showMessage(
            context, 'لم يتم التحقق بعد. افتح رسالة البريد واضغط رابط التحقق.');
      }
    } catch (e) {
      if (mounted) showMessage(context, authErrorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
        title: 'تحقق من بريدك الإلكتروني',
        subtitle:
            'أرسلنا رابط تحقق إلى ${FirebaseAuth.instance.currentUser?.email ?? 'بريدك الإلكتروني'}. افتح الرسالة ثم ارجع واضغط تحقق.',
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          FilledButton(
              onPressed: _busy ? null : _check,
              child: _busy
                  ? const CircularProgressIndicator()
                  : const Text('تحققت من البريد')),
          const SizedBox(height: 8),
          OutlinedButton(
              onPressed: _busy
                  ? null
                  : () async {
                      try {
                        await AuthService.instance.resendVerification();
                        if (context.mounted) {
                          showMessage(context, 'أُعيد إرسال رابط التحقق.');
                        }
                      } catch (e) {
                        if (context.mounted) {
                          showMessage(context, authErrorText(e));
                        }
                      }
                    },
              child: const Text('إعادة إرسال رابط التحقق')),
          TextButton(
              onPressed: () async => AuthService.instance.signOut(),
              child: const Text('تسجيل الخروج')),
        ]),
      );
}

class _GateRefresh extends StatelessWidget {
  const _GateRefresh();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _busy = false;
  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
        title: 'استعادة كلمة المرور',
        subtitle: 'سنرسل رابطًا لإعادة تعيين كلمة المرور إلى بريدك المسجل',
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                  labelText: 'البريد الإلكتروني',
                  prefixIcon: Icon(Icons.email_outlined))),
          const SizedBox(height: 14),
          FilledButton(
              onPressed: _busy
                  ? null
                  : () async {
                      if (_email.text.trim().isEmpty) {
                        showMessage(context, 'أدخل البريد الإلكتروني.');
                        return;
                      }
                      setState(() => _busy = true);
                      try {
                        await AuthService.instance
                            .sendPasswordReset(_email.text);
                        if (context.mounted) {
                          showMessage(context,
                              'إذا كان البريد مسجلًا، فستصلك رسالة لإعادة تعيين كلمة المرور.');
                        }
                      } catch (e) {
                        if (context.mounted) {
                          showMessage(context, authErrorText(e));
                        }
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
              child: const Text('إرسال رابط الاستعادة')),
        ]),
      );
}
