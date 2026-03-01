import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/orders_repository.dart';
import '../../domain/models/order.dart';

const orderStatuses = <String>[
  '',
  'pending',
  'paid',
  'confirmed',
  'processing',
  'shipped',
  'delivered',
  'cancelled',
  'refunded',
  'returned',
];

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  return OrdersRepository(Supabase.instance.client);
});

final customerOrdersProvider = FutureProvider<List<OrderModel>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  return ref.watch(ordersRepositoryProvider).getUserOrders(user.id);
});

final orderDetailProvider = FutureProvider.family<OrderDetail, String>((
  ref,
  orderId,
) async {
  return ref.watch(ordersRepositoryProvider).getOrderDetail(orderId);
});

final adminStatusFilterProvider = StateProvider<String>((ref) => '');
final adminSearchQueryProvider = StateProvider<String>((ref) => '');

final adminOrdersProvider = FutureProvider<List<OrderModel>>((ref) async {
  final status = ref.watch(adminStatusFilterProvider);
  final query = ref.watch(adminSearchQueryProvider).toLowerCase().trim();

  final orders = await ref
      .watch(ordersRepositoryProvider)
      .getAdminOrders(status: status.isEmpty ? null : status);

  if (query.isEmpty) return orders;

  return orders.where((order) {
    final email = order.customerEmail?.toLowerCase() ?? '';
    final id = order.id.toLowerCase();
    return email.contains(query) || id.contains(query);
  }).toList();
});

class AdminOrderController extends StateNotifier<AsyncValue<void>> {
  AdminOrderController(this.ref) : super(const AsyncData(null));

  final Ref ref;

  static const Map<String, Set<String>> _transitions = {
    'pending': {'paid', 'confirmed', 'cancelled'},
    'paid': {'confirmed', 'cancelled', 'refunded'},
    'confirmed': {'processing', 'cancelled'},
    'processing': {'shipped', 'cancelled'},
    'shipped': {'delivered', 'cancelled'},
    'delivered': {},
    'cancelled': {},
    'refunded': {},
    'returned': {},
  };

  bool canTransition(String current, String next) {
    if (current == next) return true;
    return _transitions[current]?.contains(next) ?? false;
  }

  Future<void> updateStatus({
    required String orderId,
    required String currentStatus,
    required String nextStatus,
    String? notes,
  }) async {
    final user = ref.read(currentUserProvider);
    if (user == null) throw Exception('Sesion expirada');

    if (!canTransition(currentStatus, nextStatus)) {
      throw Exception('Transicion de estado no permitida');
    }

    state = const AsyncLoading();
    try {
      await ref
          .read(ordersRepositoryProvider)
          .updateOrderStatus(
            orderId: orderId,
            status: nextStatus,
            notes: notes,
            actorUserId: user.id,
          );
      ref.invalidate(adminOrdersProvider);
      ref.invalidate(orderDetailProvider(orderId));
      ref.invalidate(customerOrdersProvider);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> updateTracking({
    required String orderId,
    String? carrier,
    String? trackingNumber,
    DateTime? estimatedDelivery,
  }) async {
    state = const AsyncLoading();
    try {
      await ref
          .read(ordersRepositoryProvider)
          .updateOrderTracking(
            orderId: orderId,
            carrier: carrier,
            trackingNumber: trackingNumber,
            estimatedDelivery: estimatedDelivery,
          );
      ref.invalidate(adminOrdersProvider);
      ref.invalidate(orderDetailProvider(orderId));
      ref.invalidate(customerOrdersProvider);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

final adminOrderControllerProvider =
    StateNotifierProvider<AdminOrderController, AsyncValue<void>>((ref) {
      return AdminOrderController(ref);
    });
