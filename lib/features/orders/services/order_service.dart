import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_exception.dart';
import '../../cart/services/cart_service.dart';
import '../models/order_result.dart';

class OrderService {
  OrderService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<OrderResult>> checkout({
    required CartService cart,
    required String token,
    required String recipientName,
    required String phone,
    required String address,
    String? notes,
  }) async {
    if (cart.isEmpty) {
      throw const ApiException(message: 'السلة فارغة.');
    }

    if (cart.hasUnavailableItems) {
      throw const ApiException(
        message: 'توجد منتجات غير متوفرة في السلة.',
      );
    }

    final body = <String, dynamic>{
      'recipient_name': recipientName.trim(),
      'phone': phone.trim(),
      'delivery_address': address.trim(),
      'notes': notes?.trim() ?? '',
      'payment_method': 'cash_on_delivery',
      'items': cart.items.map((item) {
        return {
          'product_id': item.product.id,
          'quantity': item.quantity,
        };
      }).toList(),
    };

    final response = await _apiClient.post(
      ApiEndpoints.checkout,
      body: body,
      token: token,
    );

    final dynamic rawOrders;

    if (response is Map && response['orders'] is List) {
      rawOrders = response['orders'];
    } else if (response is List) {
      rawOrders = response;
    } else if (response is Map && response['data'] is List) {
      rawOrders = response['data'];
    } else if (response is Map &&
        (response['id'] != null || response['order_id'] != null)) {
      rawOrders = [response];
    } else {
      throw const ApiException(
        message: 'استجابة إنشاء الطلب غير صحيحة.',
      );
    }

    final results = <OrderResult>[];

    for (final item in rawOrders as List) {
      if (item is Map<String, dynamic>) {
        final order = OrderResult.fromJson(item);

        if (order.id.isEmpty) {
          throw const ApiException(
            message: 'الخادم أعاد طلبًا دون معرّف.',
          );
        }

        results.add(order);
      } else if (item is Map) {
        final order = OrderResult.fromJson(
          Map<String, dynamic>.from(item),
        );

        if (order.id.isEmpty) {
          throw const ApiException(
            message: 'الخادم أعاد طلبًا دون معرّف.',
          );
        }

        results.add(order);
      }
    }

    if (results.isEmpty) {
      throw const ApiException(
        message: 'لم تؤكد الخادم إنشاء أي طلب.',
      );
    }

    return results;
  }
}
