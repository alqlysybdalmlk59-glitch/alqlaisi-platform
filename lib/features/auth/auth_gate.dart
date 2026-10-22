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
      return const CustomerShell();
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
