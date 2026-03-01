class OrderModel {
  final String id;
  final String? userId;
  final String? customerEmail;
  final int totalAmount;
  final int shippingCost;
  final String status;
  final DateTime? createdAt;
  final String shippingAddress;
  final String shippingCity;
  final String shippingPostalCode;
  final String? shippingPhone;
  final String? notes;
  final String? trackingNumber;
  final String? carrier;
  final DateTime? estimatedDelivery;

  OrderModel({
    required this.id,
    required this.userId,
    required this.customerEmail,
    required this.totalAmount,
    required this.shippingCost,
    required this.status,
    required this.createdAt,
    required this.shippingAddress,
    required this.shippingCity,
    required this.shippingPostalCode,
    required this.shippingPhone,
    required this.notes,
    required this.trackingNumber,
    required this.carrier,
    required this.estimatedDelivery,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString(),
      customerEmail: json['customer_email']?.toString(),
      totalAmount: (json['total_amount'] as num?)?.toInt() ?? 0,
      shippingCost: (json['shipping_cost'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? 'pending',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      shippingAddress: json['shipping_address']?.toString() ?? '',
      shippingCity: json['shipping_city']?.toString() ?? '',
      shippingPostalCode: json['shipping_postal_code']?.toString() ?? '',
      shippingPhone: json['shipping_phone']?.toString(),
      notes: json['notes']?.toString(),
      trackingNumber: json['tracking_number']?.toString(),
      carrier: json['carrier']?.toString(),
      estimatedDelivery: json['estimated_delivery'] != null
          ? DateTime.tryParse(json['estimated_delivery'].toString())
          : null,
    );
  }
}

class OrderItemModel {
  final String id;
  final String? orderId;
  final String? productId;
  final String productName;
  final int quantity;
  final int priceAtPurchase;
  final String? size;

  OrderItemModel({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.priceAtPurchase,
    required this.size,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      id: json['id']?.toString() ?? '',
      orderId: json['order_id']?.toString(),
      productId: json['product_id']?.toString(),
      productName: json['product_name']?.toString() ?? 'Producto',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      priceAtPurchase: (json['price_at_purchase'] as num?)?.toInt() ?? 0,
      size: json['size']?.toString(),
    );
  }
}

class OrderStatusHistoryModel {
  final String id;
  final String orderId;
  final String status;
  final String? notes;
  final String? createdBy;
  final DateTime? createdAt;

  OrderStatusHistoryModel({
    required this.id,
    required this.orderId,
    required this.status,
    required this.notes,
    required this.createdBy,
    required this.createdAt,
  });

  factory OrderStatusHistoryModel.fromJson(Map<String, dynamic> json) {
    return OrderStatusHistoryModel(
      id: json['id']?.toString() ?? '',
      orderId: json['order_id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      notes: json['notes']?.toString(),
      createdBy: json['created_by']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }
}

class OrderDetail {
  final OrderModel order;
  final List<OrderItemModel> items;
  final List<OrderStatusHistoryModel> history;

  OrderDetail({
    required this.order,
    required this.items,
    required this.history,
  });
}
