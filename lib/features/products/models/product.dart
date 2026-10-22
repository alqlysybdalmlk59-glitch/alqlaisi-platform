class Product {
  const Product({
    required this.id,
    required this.name,
    this.description = '',
    required this.price,
    this.imageUrl,
    required this.storeId,
    this.storeName = '',
    this.isAvailable = true,
  });

  final String id;
  final String name;
  final String description;
  final int price;
  final String? imageUrl;
  final String storeId;
  final String storeName;
  final bool isAvailable;

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      price: (json['price'] as num?)?.toInt() ?? 0,
      imageUrl: json['image_url']?.toString(),
      storeId: (json['store_id'] ?? '').toString(),
      storeName: (json['store_name'] ?? '').toString(),
      isAvailable: json['is_available'] as bool? ?? true,
    );
  }
}
