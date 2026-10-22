class Product {
  const Product({
    required this.id,
    required this.name,
    this.description = '',
    required this.price,
    this.imageUrl,
    required this.storeId,
    this.storeName = '',
    this.isAvailable = false,
    this.category = 'عام',
  });

  final String id;
  final String name;
  final String description;
  final int price;
  final String? imageUrl;
  final String storeId;
  final String storeName;
  final bool isAvailable;
  final String category;

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: (json['id'] ?? '').toString(),
    name: (json['title'] ?? json['name'] ?? '').toString(),
    description: (json['description'] ?? '').toString(),
    price: (json['price'] as num?)?.round() ?? 0,
    imageUrl: (json['image_url']?.toString().trim().isNotEmpty ?? false) ? json['image_url'].toString() : null,
    storeId: (json['vendor_id'] ?? json['store_id'] ?? '').toString(),
    storeName: (json['vendor_name'] ?? json['store_name'] ?? '').toString(),
    isAvailable: json['is_available'] as bool? ?? false,
    category: (json['category'] ?? 'عام').toString(),
  );
}
