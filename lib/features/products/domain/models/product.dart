class Product {
  final String id;
  final String name;
  final double price;
  final double? salePrice;
  final bool isOnSale;
  final String slug;
  final List<String> images;
  final String? description;
  final String categoryId;
  final Map<String, dynamic>? category;
  final dynamic sizes;

  Product({
    required this.id,
    required this.name,
    required this.price,
    this.salePrice,
    this.isOnSale = false,
    required this.slug,
    this.images = const [],
    this.description,
    required this.categoryId,
    this.category,
    this.sizes,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Unknown Product',
      price: ((json['price'] ?? 0) as num).toDouble() / 100,
      salePrice: json['sale_price'] != null
          ? (json['sale_price'] as num).toDouble() / 100
          : null,
      isOnSale: json['is_on_sale'] ?? false,
      slug: json['slug'] ?? '',
      images: json['images'] != null
          ? (json['images'] as List).map((e) => e.toString()).toList()
          : <String>[],
      description: json['description'],
      categoryId: json['category_id'] ?? '',
      category: json['categories'],
      sizes: json['sizes'],
    );
  }

  double get currentPrice => isOnSale && salePrice != null ? salePrice! : price;
}
