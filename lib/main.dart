import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  runApp(const AlqulaisiPlatformApp());
}

class AlqulaisiPlatformApp extends StatelessWidget {
  const AlqulaisiPlatformApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'منصة القليسي',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar', 'YE'),
      supportedLocales: const [Locale('ar', 'YE')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B5E20),
          primary: const Color(0xFF1B5E20),
          secondary: const Color(0xFF4CAF50),
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const MainRootScreen(),
    );
  }
}

// ----------------------------------------------------
// Enums and Data Models
// ----------------------------------------------------

enum UserRole { client, vendor, admin }

class User {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String phone;
  final String address;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone = '0770000000',
    this.address = 'صنعاء - اليمن',
  });
}

class Product {
  final String id;
  final String title;
  final String description;
  final double price;
  final String imageUrl;
  final String vendorId;
  final String vendorName;
  final String category;
  bool isAvailable; // متاح / غير متاح مؤقتاً (بدون كميات مخزون)
  String reviewStatus; // "منشور", "قيد المراجعة", "مرفوض"

  Product({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.vendorId,
    required this.vendorName,
    required this.category,
    this.isAvailable = true,
    this.reviewStatus = "منشور",
  });
}

class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, required this.quantity});
}

class Order {
  final String id;
  final String clientId;
  final String clientName;
  final String vendorId;
  final String vendorName;
  final List<CartItem> items;
  final double itemsPrice;
  final double deliveryFee;
  final double totalPrice;
  final String paymentMethod;
  final String address;
  String status; // "بانتظار القبول", "مقبولة وقيد التجهيز", "للتوصيل", "تم الاستلام", "ملغي"
  final String date;

  Order({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.vendorId,
    required this.vendorName,
    required this.items,
    required this.itemsPrice,
    this.deliveryFee = 15.0,
    required this.totalPrice,
    this.paymentMethod = "الدفع عند الاستلام",
    required this.address,
    required this.status,
    required this.date,
  });
}

class VendorStore {
  final String id;
  final String storeName;
  final String ownerName;
  final String phone;
  final String description;
  String status; // "مفعل", "قيد المراجعة", "مرفوض"

  VendorStore({
    required this.id,
    required this.storeName,
    required this.ownerName,
    required this.phone,
    required this.description,
    required this.status,
  });
}

class SupportTicket {
  final String id;
  final String userName;
  final String subject;
  final String details;
  String status;
  String response;

  SupportTicket({
    required this.id,
    required this.userName,
    required this.subject,
    required this.details,
    this.status = "مفتوحة",
    this.response = "",
  });
}

// ----------------------------------------------------
// Mock Central Repository State
// ----------------------------------------------------

class PlatformRepository {
  static User? currentUser = User(
    id: "u1",
    name: "أحمد العميل",
    email: "client@alqulaisi.com",
    role: UserRole.client,
  );

  static List<Product> products = [
    Product(
      id: "p1",
      title: "هاتف ذكي برو ماكس",
      description: "شاشة أوليد 6.7 إنش، ذاكرة 256 جيجابايت",
      price: 850.0,
      imageUrl: "https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=500",
      vendorId: "v1",
      vendorName: "متجر التقنية الحديثة",
      category: "إلكترونيات",
      isAvailable: true,
      reviewStatus: "منشور",
    ),
    Product(
      id: "p2",
      title: "ساعة ذكية رياضية",
      description: "مقاومة للماء، قياس نبضات القلب ونسبة الأكسجين",
      price: 120.0,
      imageUrl: "https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=500",
      vendorId: "v1",
      vendorName: "متجر التقنية الحديثة",
      category: "إلكترونيات",
      isAvailable: true,
      reviewStatus: "منشور",
    ),
    Product(
      id: "p3",
      title: "حذاء رياضي أنيق",
      description: "مريح جداً للجري والمشي اليومي",
      price: 45.0,
      imageUrl: "https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=500",
      vendorId: "v2",
      vendorName: "متجر الأزياء العصرية",
      category: "أزياء",
      isAvailable: true,
      reviewStatus: "منشور",
    ),
  ];

  static List<CartItem> cart = [];

  static List<Order> orders = [
    Order(
      id: "ord-101",
      clientId: "u1",
      clientName: "أحمد العميل",
      vendorId: "v1",
      vendorName: "متجر التقنية الحديثة",
      items: [CartItem(product: products[0], quantity: 1)],
      itemsPrice: 850.0,
      deliveryFee: 15.0,
      totalPrice: 865.0,
      address: "صنعاء - شارع الخمسين",
      status: "بانتظار القبول",
      date: "2025-05-10",
    ),
  ];

  static List<VendorStore> vendors = [
    VendorStore(
      id: "v1",
      storeName: "متجر التقنية الحديثة",
      ownerName: "محمد التاجر",
      phone: "0771111111",
      description: "متجر متخصص بالأجهزة الإلكترونية",
      status: "مفعل",
    ),
    VendorStore(
      id: "v2",
      storeName: "متجر الأزياء العصرية",
      ownerName: "سارة الأنيقة",
      phone: "0772222222",
      description: "أحدث صيحات الموضة والأزياء",
      status: "مفعل",
    ),
  ];

  static List<SupportTicket> tickets = [
    SupportTicket(
      id: "t1",
      userName: "أحمد العميل",
      subject: "استفسار عن موعد التوصيل",
      details: "متى سيتم توصيل الطلب ord-101؟",
    )
  ];
}

// ----------------------------------------------------
// Root Screen with Role Navigation
// ----------------------------------------------------

class MainRootScreen extends StatefulWidget {
  const MainRootScreen({super.key});

  @override
  State<MainRootScreen> createState() => _MainRootScreenState();
}

class _MainRootScreenState extends State<MainRootScreen> {
  void _login(UserRole role) {
    setState(() {
      if (role == UserRole.client) {
        PlatformRepository.currentUser = User(
          id: "u1",
          name: "أحمد العميل",
          email: "client@alqulaisi.com",
          role: UserRole.client,
        );
      } else if (role == UserRole.vendor) {
        PlatformRepository.currentUser = User(
          id: "v1",
          name: "محمد التاجر",
          email: "vendor@alqulaisi.com",
          role: UserRole.vendor,
        );
      } else {
        PlatformRepository.currentUser = User(
          id: "admin1",
          name: "مدير النظام العام",
          email: "admin@alqulaisi.com",
          role: UserRole.admin,
        );
      }
    });
  }

  void _logout() {
    setState(() {
      PlatformRepository.currentUser = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = PlatformRepository.currentUser;

    if (user == null) {
      return LoginScreen(onLogin: _login);
    }

    switch (user.role) {
      case UserRole.client:
        return ClientPortalScreen(onLogout: _logout);
      case UserRole.vendor:
        return VendorPortalScreen(onLogout: _logout);
      case UserRole.admin:
        return AdminPortalScreen(onLogout: _logout);
    }
  }
}

// ----------------------------------------------------
// Login Screen
// ----------------------------------------------------

class LoginScreen extends StatelessWidget {
  final Function(UserRole) onLogin;

  const LoginScreen({super.key, required this.onLogin});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'منصة القليسي',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              const Text('منصة التجارة الإلكترونية متعددة البائعين'),
              const SizedBox(height: 48),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: () => onLogin(UserRole.client),
                icon: const Icon(Icons.person),
                label: const Text('الدخول كعميل (Client Portal)'),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: () => onLogin(UserRole.vendor),
                icon: const Icon(Icons.store),
                label: const Text('الدخول كبائع (Vendor Portal)'),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Colors.amber.shade800,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => onLogin(UserRole.admin),
                icon: const Icon(Icons.admin_panel_settings),
                label: const Text('الدخول للوحة الإدارة (Admin Portal)'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------
// Client Portal (Flutter / Dart)
// ----------------------------------------------------

class ClientPortalScreen extends StatefulWidget {
  final VoidCallback onLogout;

  const ClientPortalScreen({super.key, required this.onLogout});

  @override
  State<ClientPortalScreen> createState() => _ClientPortalScreenState();
}

class _ClientPortalScreenState extends State<ClientPortalScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('منصة القليسي - متجر العميل'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: widget.onLogout,
          )
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildStoreCatalog(),
          _buildCartView(),
          _buildOrdersView(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.store), label: 'المتجر'),
          NavigationDestination(icon: Icon(Icons.shopping_cart), label: 'السلة'),
          NavigationDestination(icon: Icon(Icons.list_alt), label: 'طلباتي'),
        ],
      ),
    );
  }

  Widget _buildStoreCatalog() {
    final publishedProducts = PlatformRepository.products
        .where((p) => p.reviewStatus == "منشور")
        .toList();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: publishedProducts.length,
      itemBuilder: (context, index) {
        final product = publishedProducts[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(product.imageUrl, width: 60, height: 60, fit: BoxFit.cover),
            ),
            title: Text(product.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('المتجر: ${product.vendorName}\n${product.price} ر.ي'),
            trailing: ElevatedButton(
              onPressed: product.isAvailable
                  ? () {
                      setState(() {
                        PlatformRepository.cart.add(CartItem(product: product, quantity: 1));
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('تمت إضافة ${product.title} للسلة')),
                      );
                    }
                  : null,
              child: Text(product.isAvailable ? 'إضافة' : 'غير متاح'),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCartView() {
    final cart = PlatformRepository.cart;
    if (cart.isEmpty) {
      return const Center(child: Text('سلة التسوق فارغة'));
    }

    final total = cart.fold<double>(0, (sum, item) => sum + (item.product.price * item.quantity));

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: cart.length,
              itemBuilder: (context, index) {
                final item = cart[index];
                return Card(
                  child: ListTile(
                    title: Text(item.product.title),
                    subtitle: Text('${item.product.price} ر.ي × ${item.quantity}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => setState(() => cart.removeAt(index)),
                    ),
                  ),
                );
              },
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('الإجمالي (الدفع عند الاستلام):', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('$total ر.ي', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
            onPressed: () {
              setState(() {
                // إنشاء طلب وتقسيمه حسب البائع
                final newOrder = Order(
                  id: "ord-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}",
                  clientId: "u1",
                  clientName: "أحمد العميل",
                  vendorId: cart.first.product.vendorId,
                  vendorName: cart.first.product.vendorName,
                  items: List.from(cart),
                  itemsPrice: total,
                  totalPrice: total + 15.0,
                  address: "صنعاء - اليمن",
                  status: "بانتظار القبول",
                  date: "اليوم",
                );
                PlatformRepository.orders.insert(0, newOrder);
                PlatformRepository.cart.clear();
                _selectedIndex = 2;
              });
            },
            child: const Text('تأكيد الطلب والدفع عند الاستلام'),
          )
        ],
      ),
    );
  }

  Widget _buildOrdersView() {
    final orders = PlatformRepository.orders;
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return Card(
          child: ListTile(
            title: Text('طلب #: ${order.id} (${order.vendorName})'),
            subtitle: Text('الإجمالي: ${order.totalPrice} ر.ي\nالحالة: ${order.status}'),
            trailing: Text(order.date, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
        );
      },
    );
  }
}

// ----------------------------------------------------
// Vendor Portal (Flutter / Dart)
// ----------------------------------------------------

class VendorPortalScreen extends StatefulWidget {
  final VoidCallback onLogout;

  const VendorPortalScreen({super.key, required this.onLogout});

  @override
  State<VendorPortalScreen> createState() => _VendorPortalScreenState();
}

class _VendorPortalScreenState extends State<VendorPortalScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final myProducts = PlatformRepository.products.where((p) => p.vendorId == "v1").toList();
    final myOrders = PlatformRepository.orders.where((o) => o.vendorId == "v1").toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('تطبيق البائع - متجر التقنية'),
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: widget.onLogout)],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          // إدارة المنتجات والتوافر اليدوي
          ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: myProducts.length,
            itemBuilder: (context, index) {
              final product = myProducts[index];
              return Card(
                child: SwitchListTile(
                  title: Text(product.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('السعر: ${product.price} ر.ي | الحالة: ${product.reviewStatus}'),
                  value: product.isAvailable,
                  onChanged: (val) => setState(() => product.isAvailable = val),
                ),
              );
            },
          ),
          // طلبات البائع
          ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: myOrders.length,
            itemBuilder: (context, index) {
              final order = myOrders[index];
              return Card(
                child: ListTile(
                  title: Text('طلب #: ${order.id}'),
                  subtitle: Text('العميل: ${order.clientName}\nالحالة: ${order.status}'),
                  trailing: order.status == "بانتظار القبول"
                      ? ElevatedButton(
                          onPressed: () => setState(() => order.status = "مقبولة وقيد التجهيز"),
                          child: const Text('قبول'),
                        )
                      : Text(order.status, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                ),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.inventory), label: 'المنتجات'),
          NavigationDestination(icon: Icon(Icons.assignment), label: 'الطلبات'),
        ],
      ),
    );
  }
}

// ----------------------------------------------------
// Admin Portal (Flutter / Dart)
// ----------------------------------------------------

class AdminPortalScreen extends StatefulWidget {
  final VoidCallback onLogout;

  const AdminPortalScreen({super.key, required this.onLogout});

  @override
  State<AdminPortalScreen> createState() => _AdminPortalScreenState();
}

class _AdminPortalScreenState extends State<AdminPortalScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة الإدارة المركزية (Admin Portal)'),
        backgroundColor: Colors.amber.shade800,
        foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: widget.onLogout)],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          // المتاجر
          ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: PlatformRepository.vendors.length,
            itemBuilder: (context, index) {
              final vendor = PlatformRepository.vendors[index];
              return Card(
                child: ListTile(
                  title: Text(vendor.storeName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('المالك: ${vendor.ownerName} | الحالة: ${vendor.status}'),
                  trailing: vendor.status != "مفعل"
                      ? ElevatedButton(
                          onPressed: () => setState(() => vendor.status = "مفعل"),
                          child: const Text('تفعيل'),
                        )
                      : const Icon(Icons.check_circle, color: Colors.green),
                ),
              );
            },
          ),
          // Gemini AI Sales Assistant
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.smart_toy, color: Colors.purple),
                            SizedBox(width: 8),
                            Text('تحليلات الذكاء الاصطناعي (Gemini AI)', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        SizedBox(height: 12),
                        Text('أداء المبيعات في نمو مستمر بنسبة 22% هذا الشهر. الأكثر طلباً: الهواتف والأزياء العصرية.'),
                      ],
                    ),
                  ),
                )
              ],
            ),
          )
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.storefront), label: 'المتاجر'),
          NavigationDestination(icon: Icon(Icons.smart_toy), label: 'الذكاء الاصطناعي'),
        ],
      ),
    );
  }
}
