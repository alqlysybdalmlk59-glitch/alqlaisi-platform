import '../../products/models/product.dart';

class CartItem {
  CartItem({
    required this.product,
    this.quantity = 1,
  }) : assert(quantity > 0);

  final Product product;
  int quantity;

  String get storeId => product.storeId;

  int get lineTotal => product.price * quantity;

  bool get isAvailable => product.isAvailable;

  void increase() {
    quantity++;
  }

  void decrease() {
    if (quantity > 1) {
      quantity--;
    }
  }
}
