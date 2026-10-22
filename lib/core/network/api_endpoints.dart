import 'package:flutter/foundation.dart';

class ApiEndpoints {
  ApiEndpoints._();

  static const String _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_configuredBaseUrl.trim().isNotEmpty) {
      return _configuredBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    }
    if (kIsWeb) return 'http://localhost:8000/api';
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Android emulator host loopback; production builds should pass API_BASE_URL.
      return 'http://10.0.2.2:8000/api';
    }
    return 'http://localhost:8000/api';
  }

  static const String checkout = '/checkout';
  static const String orderDetails = '/orders';
  static const String customerAddresses = '/customer/addresses';

  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String googleLogin = '/auth/google';
  static const String logout = '/auth/logout';
  static const String currentUser = '/auth/me';
  static const String forgotPassword = '/auth/forgot-password';
}
