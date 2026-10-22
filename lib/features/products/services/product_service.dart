import '../../../core/network/api_client.dart';
import '../models/product.dart';

class ProductService {
  ProductService(this._api);
  final ApiClient _api;

  Future<List<Product>> getPublishedProducts() async {
    final result = await _api.get('/products/');
    if (result is! List) {
      throw const FormatException('صيغة قائمة المنتجات القادمة من الخادم غير صحيحة.');
    }
    return result.whereType<Map>().map((json) =>
      Product.fromJson(Map<String, dynamic>.from(json))).toList();
  }

  Future<List<Map<String, dynamic>>> getPublicStores() async {
    final result = await _api.get('/vendors/public');
    if (result is! List) {
      throw const FormatException('صيغة قائمة المتاجر القادمة من الخادم غير صحيحة.');
    }
    return result.whereType<Map>().map((json) => Map<String, dynamic>.from(json)).toList();
  }
}
