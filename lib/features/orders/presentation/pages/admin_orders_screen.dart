import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/design_system/widgets/aurum_card.dart';
import '../../../../core/design_system/widgets/aurum_empty_state.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../providers/orders_provider.dart';

class AdminOrdersScreen extends ConsumerWidget {
  const AdminOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(adminOrdersProvider);
    final status = ref.watch(adminStatusFilterProvider);

    return Scaffold(
      backgroundColor: AppTheme.lightGrey,
      appBar: AppBar(title: const Text(AppStrings.panelAdmin)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar por correo o id',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => ref.read(adminSearchQueryProvider.notifier).state = value,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButtonFormField<String>(
              initialValue: status,
              decoration: const InputDecoration(labelText: 'Estado'),
              items: orderStatuses
                  .map(
                    (s) => DropdownMenuItem(
                      value: s,
                      child: Text(s.isEmpty ? 'Todos' : Formatters.orderStatus(s)),
                    ),
                  )
                  .toList(),
              onChanged: (value) => ref.read(adminStatusFilterProvider.notifier).state = value ?? '',
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ordersAsync.when(
              data: (orders) {
                if (orders.isEmpty) {
                  return const AurumEmptyState(
                    icon: Icons.inventory_2_outlined,
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
                        title: Text('#${order.id.substring(0, 8)}'),
                        subtitle: Text(
                          '${order.customerEmail ?? 'Sin correo'} - ${Formatters.orderStatus(order.status)}',
                        ),
                        trailing: Text(
                          Formatters.euro(order.totalAmount / 100),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.gold,
                          ),
                        ),
                        onTap: () => context.push('/admin/order-detail', extra: order.id),
                      ),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemCount: orders.length,
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Error: $error')),
            ),
          ),
        ],
      ),
    );
  }
}
