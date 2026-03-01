class Product {
  final String id;
  final String name;
  final double price;
  final double? salePrice;
  final bool isOnSale;
  final String slug;
  final List<String> images;
  final String? description;
  final String? material;
  final String categoryId;
  final Map<String, dynamic>? category;
  final dynamic sizes;
  final bool isActive;
  final DateTime createdAt;

  Product({
    required this.id,
    required this.name,
    required this.price,
    this.salePrice,
    this.isOnSale = false,
    required this.slug,
    this.images = const [],
    this.description,
    this.material,
    required this.categoryId,
    this.category,
    this.sizes,
    this.isActive = true,
    required this.createdAt,
  });

  static double _centsToPrice(dynamic raw) {
    if (raw == null) return 0;
    if (raw is num) return raw.toDouble() / 100;
    final parsed = double.tryParse(raw.toString());
    return parsed == null ? 0 : parsed / 100;
  }

  static Map<String, dynamic>? _parseCategory(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is List && raw.isNotEmpty && raw.first is Map) {
      return Map<String, dynamic>.from(raw.first as Map);
    }
    return null;
  }

  static List<String> _parseImages(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    return <String>[];
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Unknown Product',
      price: _centsToPrice(json['price']),
      salePrice: json['sale_price'] != null
          ? _centsToPrice(json['sale_price'])
          : null,
      isOnSale: json['is_on_sale'] ?? false,
      slug: json['slug'] ?? '',
      images: _parseImages(json['images']),
      description: json['description'],
      material: json['material']?.toString(),
      categoryId: json['category_id'] ?? '',
      category: _parseCategory(json['categories']),
      sizes: json['sizes'],
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  double get currentPrice => isOnSale && salePrice != null ? salePrice! : price;
}
