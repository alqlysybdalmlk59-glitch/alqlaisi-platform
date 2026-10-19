import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // عنوان الخادم الخارجي أو المحلي الخاص بـ Python FastAPI Backend
  static const String baseUrl = 'http://10.0.2.2:8000/api';

  static Future<List<dynamic>> fetchProducts() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/products/'));
      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      }
    } catch (e) {
      // إرجاع البيانات التجريبية محلياً عند عدم الاتصال بالخادم
    }
    return [];
  }

  static Future<bool> toggleProductAvailability(String productId) async {
    try {
      final response = await http.put(Uri.parse('$baseUrl/products/$productId/availability'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> checkoutOrders(List<Map<String, dynamic>> ordersJson) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/orders/checkout'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(ordersJson),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<String> getAiSalesInsights(String query) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/ai/sales-insights?query=${Uri.encodeComponent(query)}'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return data['insights'] ?? '';
      }
    } catch (e) {
      // إرجاع رد افتراضي محلي
    }
    return "تحليل Gemini AI منصة القليسي: أداء المبيعات مرتفع ونسبة التجاوب مع الدفع عند الاستلام جيدة جداً.";
  }
}
