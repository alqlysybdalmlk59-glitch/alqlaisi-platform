import 'package:flutter/foundation.dart';

import '../models/auth_user.dart';
import 'auth_service.dart';
import 'session_storage.dart';

class AuthSessionController extends ChangeNotifier {
  AuthSessionController({
    required AuthService authService,
    required SessionStorage storage,
  })  : _authService = authService,
        _storage = storage;

  final AuthService _authService;
  final SessionStorage _storage;

  AuthUser? _user;
  String? _token;
  bool _loading = false;
  bool _initialized = false;

  AuthUser? get user => _user;
  String? get token => _token;
  bool get isLoading => _loading;
  bool get isInitialized => _initialized;
  bool get isAuthenticated => _token != null && _user != null;

  Future<void> restoreSession() async {
    _loading = true;
    notifyListeners();

    try {
      final savedToken = await _storage.readToken();

      if (savedToken != null && savedToken.isNotEmpty) {
        final user = await _authService.getCurrentUser(savedToken);

        _token = savedToken;
        _user = user;
      }
    } catch (_) {
      _token = null;
      _user = null;
      await _storage.clear();
    } finally {
      _loading = false;
      _initialized = true;
      notifyListeners();
    }
  }

  Future<void> acceptSession(AuthSession session) async {
    await _storage.saveToken(session.accessToken);

    _token = session.accessToken;
    _user = session.user;

    notifyListeners();
  }

  Future<void> logout() async {
    final currentToken = _token;

    _token = null;
    _user = null;

    await _storage.clear();
    notifyListeners();

    if (currentToken != null) {
      try {
        await _authService.logout(currentToken);
      } catch (_) {
        // انتهت الجلسة المحلية؛ قد يفشل طلب الخادم بسبب انقطاع الشبكة.
      }
    }
  }
}
