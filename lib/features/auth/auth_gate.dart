import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../shell/customer_shell.dart';
import 'login_page.dart';
import 'models/auth_user.dart';
import 'register_page.dart';
import 'services/auth_service.dart';
import 'services/auth_session_controller.dart';
import 'services/session_storage.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final ApiClient _apiClient;
  late final AuthService _authService;
  late final AuthSessionController _sessionController;

  bool _showRegister = false;
  bool _starting = true;

  @override
  void initState() {
    super.initState();

    _apiClient = ApiClient();
    _authService = AuthService(_apiClient);
    _sessionController = AuthSessionController(
      authService: _authService,
      storage: SessionStorage(),
    );

    _restoreSession();
  }

  Future<void> _restoreSession() async {
    try {
      await _sessionController.restoreSession();
    } catch (_) {
      // Ignore session restore error on start
    } finally {
      if (mounted) {
        setState(() => _starting = false);
      }
    }
  }

  Future<void> _onAuthenticated(AuthSession session) async {
    try {
      await _sessionController.acceptSession(session);

      if (!mounted) return;

      setState(() {
        _showRegister = false;
      });
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر حفظ جلسة الدخول على الجهاز.'),
        ),
      );
    }
  }



  Future<void> _logout() async {
    await _sessionController.logout();
    if (mounted) setState(() { _showRegister = false; });
  }

  @override
  void dispose() {
    _sessionController.dispose();
    _apiClient.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_starting) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: AppTheme.primary,
          ),
        ),
      );
    }

    if (_sessionController.isAuthenticated) {
      if (_sessionController.user?.role == 'customer') {
        return CustomerShell(accessToken: _sessionController.token ?? '', onLogout: _logout);
      }
      return _AccountRoleNotice(
        role: _sessionController.user?.role ?? 'unknown',
        onLogout: _logout,
      );
    }

    if (_showRegister) {
      return RegisterPage(
        onAuthenticated: _onAuthenticated,
        onLogin: () {
          setState(() => _showRegister = false);
        },
      );
    }

    return LoginPage(
      onAuthenticated: _onAuthenticated,
      onRegister: () {
        setState(() => _showRegister = true);
      },
    );
  }
}


class _AccountRoleNotice extends StatelessWidget {
  const _AccountRoleNotice({required this.role, required this.onLogout});
  final String role;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final isSeller = role == 'seller';
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(isSeller ? Icons.storefront : Icons.admin_panel_settings,
                    size: 64, color: AppTheme.primary),
                  const SizedBox(height: 16),
                  Text(isSeller ? 'تم ربط حسابك بمتجر بائع' : 'هذا الحساب ليس حساب عميل',
                    style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  Text(isSeller
                    ? 'استخدم تطبيق البائع لإدارة منتجات متجرك وطلباته. أعد فتح تطبيق البائع بعد اعتماد المتجر.'
                    : 'يرجى فتح الواجهة المخصصة لهذا الدور أو استخدام حساب عميل.',
                    textAlign: TextAlign.center),
                  const SizedBox(height: 18),
                  FilledButton(onPressed: onLogout, child: const Text('تسجيل الخروج')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
