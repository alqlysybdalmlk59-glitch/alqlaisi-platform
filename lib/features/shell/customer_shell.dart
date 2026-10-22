import 'package:flutter/material.dart';

import '../../core/cart/cart_scope.dart';
import '../../core/theme/app_theme.dart';
import '../cart/cart_page.dart';
import '../categories/category_page.dart';
import '../checkout/checkout_page.dart';
import '../home/home_page.dart';
import '../orders/orders_page.dart';

class CustomerShell extends StatefulWidget {
  const CustomerShell({super.key, required this.accessToken});

  final String accessToken;

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final cartService = CartScope.of(context);

    final pages = <Widget>[
      const HomePage(),
      const CategoryPage(),
      CartPage(
        cartService: cartService,
        onCheckout: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => CheckoutPage(
                cartService: cartService,
                token: widget.accessToken,
              ),
            ),
          );
        },
      ),
      const OrdersPage(),
      const _AccountPlaceholder(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        indicatorColor: AppTheme.primary.withValues(alpha: 0.12),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.category_outlined),
            selectedIcon: Icon(Icons.category),
            label: 'التصنيفات',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            selectedIcon: Icon(Icons.shopping_cart),
            label: 'السلة',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'طلباتي',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'حسابي',
          ),
        ],
      ),
    );
  }
}

class _AccountPlaceholder extends StatelessWidget {
  const _AccountPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('صفحة الحساب قيد التجهيز'),
      ),
    );
  }
}
