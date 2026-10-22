import 'package:flutter/widgets.dart';

import '../../features/cart/services/cart_service.dart';

class CartScope extends InheritedNotifier<CartService> {
  const CartScope({
    super.key,
    required CartService cartService,
    required super.child,
  }) : super(notifier: cartService);

  static CartService of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<CartScope>();

    assert(scope != null, 'CartScope غير موجود أعلى شجرة التطبيق.');

    return scope!.notifier!;
  }
}
