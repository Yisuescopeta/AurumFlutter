class CartItem {
  CartItem({
    required this.productId,
    required this.name,
    required this.image,
    required this.size,
    required this.unitPriceCents,
    required this.quantity,
    this.categoryName,
    this.isOnSale = false,
  });

  final String productId;
  final String name;
  final String? image;
  final String size;
  final int unitPriceCents;
  final int quantity;
  final String? categoryName;
  final bool isOnSale;

  String get id => '$productId-$size';

  CartItem copyWith({
    String? productId,
    String? name,
    String? image,
    String? size,
    int? unitPriceCents,
    int? quantity,
    String? categoryName,
    bool? isOnSale,
  }) {
    return CartItem(
      productId: productId ?? this.productId,
      name: name ?? this.name,
      image: image ?? this.image,
      size: size ?? this.size,
      unitPriceCents: unitPriceCents ?? this.unitPriceCents,
      quantity: quantity ?? this.quantity,
      categoryName: categoryName ?? this.categoryName,
      isOnSale: isOnSale ?? this.isOnSale,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'name': name,
      'image': image,
      'size': size,
      'unit_price_cents': unitPriceCents,
      'quantity': quantity,
      'category_name': categoryName,
      'is_on_sale': isOnSale,
    };
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      productId: json['product_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      image: json['image']?.toString(),
      size: json['size']?.toString() ?? 'Unica',
      unitPriceCents: (json['unit_price_cents'] as num?)?.toInt() ?? 0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      categoryName: json['category_name']?.toString(),
      isOnSale: json['is_on_sale'] == true,
    );
  }
}
