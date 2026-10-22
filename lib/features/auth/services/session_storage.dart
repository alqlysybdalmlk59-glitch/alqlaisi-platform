import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionStorage {
  SessionStorage({
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const String _tokenKey = 'alqlaisi_access_token';

  Future<void> saveToken(String token) async {
    if (token.trim().isEmpty) {
      throw ArgumentError.value(token, 'token', 'لا يمكن حفظ رمز فارغ.');
    }

    await _storage.write(
      key: _tokenKey,
      value: token,
    );
  }

  Future<String?> readToken() {
    return _storage.read(key: _tokenKey);
  }

  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
  }
}
