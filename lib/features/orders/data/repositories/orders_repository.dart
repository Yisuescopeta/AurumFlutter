import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/order.dart';

class OrdersRepository {
  OrdersRepository(this._supabase);

  final SupabaseClient _supabase;

  Future<List<OrderModel>> getUserOrders(String userId) async {
    final response = await _supabase
        .from('orders')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((e) => OrderModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<OrderModel>> getAdminOrders({String? status}) async {
    var query = _supabase.from('orders').select();

    if (status != null && status.isNotEmpty) {
      query = query.eq('status', status);
    }

    final response = await query.order('created_at', ascending: false);

    return (response as List)
        .map((e) => OrderModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<OrderDetail> getOrderDetail(String orderId) async {
    final orderResponse = await _supabase
        .from('orders')
        .select()
        .eq('id', orderId)
        .single();

    final itemsResponse = await _supabase
        .from('order_items')
        .select()
        .eq('order_id', orderId);

    final historyResponse = await _supabase
        .from('order_status_history')
        .select()
        .eq('order_id', orderId)
        .order('created_at', ascending: false);

    return OrderDetail(
      order: OrderModel.fromJson(orderResponse),
      items: (itemsResponse as List)
          .map((e) => OrderItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      history: (historyResponse as List)
          .map((e) =>
              OrderStatusHistoryModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<void> updateOrderStatus({
    required String orderId,
    required String status,
    String? notes,
    required String actorUserId,
  }) async {
    await _supabase.from('orders').update({'status': status}).eq('id', orderId);

    await _supabase.from('order_status_history').insert({
      'order_id': orderId,
      'status': status,
      'notes': notes,
      'created_by': actorUserId,
    });
  }

  Future<void> updateOrderTracking({
    required String orderId,
    String? carrier,
    String? trackingNumber,
    DateTime? estimatedDelivery,
  }) async {
    await _supabase.from('orders').update({
      'carrier': carrier,
      'tracking_number': trackingNumber,
      'estimated_delivery': estimatedDelivery?.toIso8601String(),
    }).eq('id', orderId);
  }
}
