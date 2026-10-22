import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_endpoints.dart';
import 'api_exception.dart';

class ApiClient {
  ApiClient({String? baseUrl, http.Client? client})
      : baseUrl = baseUrl ?? ApiEndpoints.baseUrl,
        _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Map<String, String> _headers(String? token) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<dynamic> get(String endpoint, {String? token}) async {
    try {
      final url = Uri.parse('$baseUrl$endpoint');
      final response = await _client.get(url, headers: _headers(token));
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'فشل الاتصال بالخادم: $e');
    }
  }

  Future<dynamic> post(
    String endpoint, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    try {
      final url = Uri.parse('$baseUrl$endpoint');
      final response = await _client.post(
        url,
        headers: _headers(token),
        body: body != null ? jsonEncode(body) : null,
      );
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'فشل الاتصال بالخادم: $e');
    }
  }

  Future<dynamic> put(
    String endpoint, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    try {
      final url = Uri.parse('$baseUrl$endpoint');
      final response = await _client.put(
        url,
        headers: _headers(token),
        body: body != null ? jsonEncode(body) : null,
      );
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'فشل الاتصال بالخادم: $e');
    }
  }

  dynamic _processResponse(http.Response response) {
    dynamic decoded;
    try {
      if (response.body.isNotEmpty) {
        decoded = jsonDecode(response.body);
      }
    } catch (_) {}

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded ?? {};
    }

    String message = 'حدث خطأ غير متوقع (${response.statusCode})';
    if (decoded is Map && decoded['detail'] != null) {
      message = decoded['detail'].toString();
    } else if (decoded is Map && decoded['message'] != null) {
      message = decoded['message'].toString();
    }

    throw ApiException(
      message: message,
      statusCode: response.statusCode,
    );
  }

  void close() {
    _client.close();
  }
}
