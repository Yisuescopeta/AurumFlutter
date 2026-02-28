import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import 'admin_coupons_screen.dart';
import 'admin_customers_screen.dart';
import 'admin_dashboard_screen.dart';
import 'admin_emails_screen.dart';
import 'admin_products_screen.dart';

class AdminShellScreen extends ConsumerStatefulWidget {
  const AdminShellScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  ConsumerState<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends ConsumerState<AdminShellScreen> {
  late int _tab;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab.clamp(0, 4);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final profileAsync = ref.watch(profileProvider);

    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/login');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return profileAsync.when(
      data: (profile) {
        if (profile == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Panel de administracion')),
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'No existe perfil para este usuario en la base de datos actual.',
                  ),
                  const SizedBox(height: 8),
                  SelectableText('user_id: ${user.id}'),
                  const SizedBox(height: 12),
                  const Text(
                    'Crea una fila en la tabla profiles con este id y role = admin.',
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.go('/home'),
                    child: const Text('Volver a inicio'),
                  ),
                ],
              ),
            ),
          );
        }

        if (profile.role != 'admin') {
          return Scaffold(
            appBar: AppBar(title: const Text('Panel de administracion')),
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('No tienes acceso a administracion en esta base.'),
                  const SizedBox(height: 8),
                  Text('Rol actual: ${profile.role}'),
                  const SizedBox(height: 12),
                  SelectableText('user_id: ${user.id}'),
                  const SizedBox(height: 12),
                  const Text(
                    'Actualiza tu fila en profiles y pon role = admin.',
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.go('/home'),
                    child: const Text('Volver a inicio'),
                  ),
                ],
              ),
            ),
          );
        }

        final tabs = [
          AdminDashboardScreen(
            onNewProduct: () => context.push('/admin/products/new'),
            onManageProducts: () => setState(() => _tab = 1),
            onCreateCoupon: () => setState(() => _tab = 3),
            onNewCampaign: () => setState(() => _tab = 4),
            onOpenOrders: () => context.push('/admin/orders'),
          ),
          const AdminProductsScreen(),
          const AdminCustomersScreen(),
          const AdminCouponsScreen(),
          const AdminEmailsScreen(),
        ];

        return Scaffold(
          appBar: AppBar(
            title: const Text('Panel de administracion'),
            actions: [
              IconButton(
                onPressed: () => context.push('/admin/orders'),
                icon: const Icon(Icons.receipt_long_outlined),
                tooltip: 'Pedidos',
              ),
            ],
          ),
          body: tabs[_tab],
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (index) => setState(() => _tab = index),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
              NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: 'Productos'),
              NavigationDestination(icon: Icon(Icons.people_outline), label: 'Clientes'),
              NavigationDestination(icon: Icon(Icons.local_offer_outlined), label: 'Cupones'),
              NavigationDestination(icon: Icon(Icons.mail_outline), label: 'Correos'),
            ],
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(body: Center(child: Text('Error: $error'))),
    );
  }
}
