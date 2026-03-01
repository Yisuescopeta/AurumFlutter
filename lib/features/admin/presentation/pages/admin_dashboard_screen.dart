import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/widgets/aurum_card.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../providers/admin_provider.dart';
import '../../../../core/design_system/widgets/aurum_loader.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({
    super.key,
    required this.onNewProduct,
    required this.onManageProducts,
    required this.onCreateCoupon,
    required this.onNewNotification,
    required this.onOpenOrders,
  });

  final VoidCallback onNewProduct;
  final VoidCallback onManageProducts;
  final VoidCallback onCreateCoupon;
  final VoidCallback onNewNotification;
  final VoidCallback onOpenOrders;

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  int _refreshTick = 0;

  int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  String _categoryName(dynamic categoriesField) {
    if (categoriesField is Map) {
      return categoriesField['name']?.toString() ?? '-';
    }
    if (categoriesField is List && categoriesField.isNotEmpty) {
      final first = categoriesField.first;
      if (first is Map) {
        return first['name']?.toString() ?? '-';
      }
    }
    return '-';
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(adminRepositoryProvider);
    return FutureBuilder(
      key: ValueKey(_refreshTick),
      future: repo.getDashboardStats(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AurumCenteredLoader();
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Center(
            child: Text('Error cargando dashboard: ${snapshot.error}'),
          );
        }
        final data = snapshot.data!;
        return RefreshIndicator(
          onRefresh: () async {
            setState(() => _refreshTick++);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Dashboard',
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _KpiCard(
                    title: 'Total productos',
                    value: '${data.totalProducts}',
                    icon: Icons.inventory_2_outlined,
                  ),
                  _KpiCard(
                    title: 'Valor inventario',
                    value: Formatters.euro(data.inventoryValueCents / 100),
                    icon: Icons.euro,
                  ),
                  _KpiCard(
                    title: 'Pedidos totales',
                    value: '${data.totalOrders}',
                    icon: Icons.shopping_bag_outlined,
                  ),
                  _KpiCard(
                    title: 'Stock bajo',
                    value: '${data.lowStockVariants}',
                    icon: Icons.warning_amber_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AurumCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Acciones rapidas',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: widget.onNewProduct,
                          icon: const Icon(Icons.add_box_outlined),
                          label: const Text('Nuevo producto'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: widget.onManageProducts,
                          icon: const Icon(Icons.storefront_outlined),
                          label: const Text('Gestionar productos'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: widget.onCreateCoupon,
                          icon: const Icon(Icons.local_offer_outlined),
                          label: const Text('Crear cupon'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: widget.onNewNotification,
                          icon: const Icon(Icons.notifications_active_outlined),
                          label: const Text('Nueva notificacion'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: widget.onOpenOrders,
                          icon: const Icon(Icons.receipt_long_outlined),
                          label: const Text('Pedidos'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AurumCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Productos recientes',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    ...(data.recentProducts.map((product) {
                      final name = product['name']?.toString() ?? 'Producto';
                      final category = _categoryName(product['categories']);
                      final price = _toInt(
                        product['is_on_sale'] == true
                            ? product['sale_price']
                            : product['price'],
                      );
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(name),
                        subtitle: Text(category),
                        trailing: Text(
                          Formatters.euro(price / 100),
                          style: const TextStyle(
                            color: AppTheme.gold,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      );
                    })),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width > 520
          ? (MediaQuery.of(context).size.width - 52) / 2
          : (MediaQuery.of(context).size.width - 42) / 2,
      child: AurumCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppTheme.navyBlue),
            const SizedBox(height: 8),
            Text(title, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
