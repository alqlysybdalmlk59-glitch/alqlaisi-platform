import 'package:flutter/material.dart';

import 'app.dart';
import 'core/cart/cart_scope.dart';
import 'features/cart/services/cart_service.dart';

final CartService appCartService = CartService();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    CartScope(
      cartService: appCartService,
      child: const AlQulaisiApp(),
    ),
  );
}
