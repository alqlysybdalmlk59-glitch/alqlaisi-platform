import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_exception.dart';
import '../models/auth_user.dart';

class AuthService {
  AuthService(this._client);

  final ApiClient _client;

  Future<AuthSession> login({
    required String phone,
    required String password,
  }) async {
    final response = await _client.post(
      ApiEndpoints.login,
      body: {
        'phone': phone.trim(),
        'password': password,
      },
    );

    return _parseSession(response);
  }

  Future<AuthSession> register({
    required String fullName,
    required String phone,
    required String password,
    String? email,
  }) async {
    final response = await _client.post(
      ApiEndpoints.register,
      body: {
        'full_name': fullName.trim(),
        'phone': phone.trim(),
        'password': password,
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
      },
    );

    return _parseSession(response);
  }

  Future<AuthUser> getCurrentUser(String token) async {
    final response = await _client.get(
      ApiEndpoints.currentUser,
      token: token,
    );

    if (response is! Map) {
      throw const ApiException(
        message: 'بيانات المستخدم التي أعادها الخادم غير صحيحة.',
      );
    }

    final user = AuthUser.fromJson(
      Map<String, dynamic>.from(response),
    );

    if (user.id.isEmpty) {
      throw const ApiException(
        message: 'استجابة المستخدم لا تحتوي على معرّف.',
      );
    }

    return user;
  }

  Future<void> logout(String token) async {
    await _client.post(
      ApiEndpoints.logout,
      token: token,
    );
  }

  AuthSession _parseSession(dynamic response) {
    if (response is! Map) {
      throw const ApiException(
        message: 'استجابة المصادقة غير صحيحة.',
      );
    }

    final session = AuthSession.fromJson(
      Map<String, dynamic>.from(response),
    );

    if (session.accessToken.isEmpty) {
      throw const ApiException(
        message: 'لم يُرجع الخادم رمز الدخول.',
      );
    }

    if (session.user.id.isEmpty) {
      throw const ApiException(
        message: 'لم يُرجع الخادم بيانات المستخدم المطلوبة.',
      );
    }

    if (session.user.role != 'customer') {
      throw const ApiException(
        message: 'هذا التطبيق مخصص لحسابات العملاء.',
      );
    }

    return session;
  }
}
