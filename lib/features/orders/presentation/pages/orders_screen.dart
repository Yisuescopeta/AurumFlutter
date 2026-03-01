import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/design_system/widgets/aurum_app_bar_title.dart';
import '../../../../core/design_system/widgets/aurum_card.dart';
import '../../../../core/design_system/widgets/aurum_empty_state.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../providers/orders_provider.dart';
import '../../../../core/design_system/widgets/aurum_loader.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(customerOrdersProvider);

    return Scaffold(
      backgroundColor: AppTheme.lightGrey,
      appBar: AppBar(title: const AurumAppBarTitle(AppStrings.misPedidos)),
      body: ordersAsync.when(
        data: (orders) {
          if (orders.isEmpty) {
            return const AurumEmptyState(
              icon: Icons.receipt_long_outlined,
              title: AppStrings.pedidos,
              description: AppStrings.pedidosVacio,
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final order = orders[index];
              return AurumCard(
                padding: const EdgeInsets.all(12),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '#${order.id.substring(0, 8)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${Formatters.orderStatus(order.status)} - ${Formatters.date(order.createdAt)}',
                  ),
                  trailing: Text(
                    Formatters.euro(order.totalAmount / 100),
                    style: const TextStyle(
                      color: AppTheme.gold,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () => context.push('/order-detail', extra: order.id),
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemCount: orders.length,
          );
        },
        loading: () => const AurumCenteredLoader(),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }
}
