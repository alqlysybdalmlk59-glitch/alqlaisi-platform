import 'package:flutter/foundation.dart';

class ApiEndpoints {
  ApiEndpoints._();

  static const String _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const String _blockedBaseUrl = 'https://api-not-configured.invalid/api';
  static const String _googleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

  static bool get googleServerClientIdConfigured {
    final value = _googleServerClientId.trim();
    final pieces = value.split('-');
    return pieces.length >= 2 &&
        RegExp(r'^[0-9]+$').hasMatch(pieces.first) &&
        value.endsWith('.apps.googleusercontent.com') &&
        !value.contains('YOUR_');
  }

  static String? get configurationError {
    if (!kReleaseMode) return null;
    final configured = _configuredBaseUrl.trim();
    if (configured.isEmpty) {
      return 'نسخة الإنتاج غير مهيأة: يجب بناء التطبيق باستخدام API_BASE_URL يبدأ بـ https://.';
    }
    final uri = Uri.tryParse(configured);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      return 'عنوان API غير آمن. يجب استخدام HTTPS وعنوان خادم موثوق.';
    }
    if (!googleServerClientIdConfigured) {
      return 'نسخة الإنتاج غير مهيأة: يجب تحديد معرّف Google Web OAuth حقيقي بصيغة GOOGLE_SERVER_CLIENT_ID.';
    }
    return null;
  }

  static String get baseUrl {
    final configured = _configuredBaseUrl.trim();
    if (configured.isNotEmpty) {
      final uri = Uri.tryParse(configured);
      if (kReleaseMode && (uri == null || uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty)) {
        return _blockedBaseUrl;
      }
      return configured.replaceAll(RegExp(r'/+$'), '');
    }
    if (kReleaseMode) return _blockedBaseUrl;
    if (kIsWeb) return 'http://localhost:8000/api';
    if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:8000/api';
    return 'http://localhost:8000/api';
  }

  static const String checkout = '/checkout';
  static const String orderDetails = '/orders';
  static const String customerAddresses = '/customer/addresses';
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String googleLogin = '/auth/google';
  static const String googleLink = '/auth/google/link';
  static const String logout = '/auth/logout';
  static const String currentUser = '/auth/me';
  static const String forgotPassword = '/auth/forgot-password';
}
