import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/widgets/aurum_app_bar_title.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'admin_coupons_screen.dart';
import 'admin_customers_screen.dart';
import 'admin_dashboard_screen.dart';
import 'admin_notifications_screen.dart';
import 'admin_products_screen.dart';
import '../../../../core/design_system/widgets/aurum_loader.dart';

class AdminShellScreen extends ConsumerStatefulWidget {
  const AdminShellScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  ConsumerState<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends ConsumerState<AdminShellScreen> {
  late int _tab;
  static const List<String> _adminNavLabels = <String>[
    'Dashboard',
    'Productos',
    'Clientes',
    'Cupones',
    'Notificaciones',
  ];

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
      return const Scaffold(body: AurumCenteredLoader());
    }

    return profileAsync.when(
      data: (profile) {
        if (profile == null) {
          return Scaffold(
            appBar: AppBar(
              title: const AurumAppBarTitle('Panel de administracion'),
            ),
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
            appBar: AppBar(
              title: const AurumAppBarTitle('Panel de administracion'),
            ),
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
            onNewNotification: () => setState(() => _tab = 4),
            onOpenOrders: () => context.push('/admin/orders'),
          ),
          const AdminProductsScreen(),
          const AdminCustomersScreen(),
          const AdminCouponsScreen(),
          const AdminNotificationsScreen(),
        ];

        return Scaffold(
          appBar: AppBar(
            title: const AurumAppBarTitle('Panel de administracion'),
            actions: [
              IconButton(
                onPressed: () => context.push('/admin/orders'),
                icon: const Icon(Icons.receipt_long_outlined),
                tooltip: 'Pedidos',
              ),
            ],
          ),
          body: tabs[_tab],
          bottomNavigationBar: LayoutBuilder(
            builder: (context, constraints) {
              final adaptiveFontSize = _computeAdaptiveNavFontSize(
                context: context,
                maxWidth: constraints.maxWidth,
                labels: _adminNavLabels,
                minFontSize: 10,
              );
              final navTheme = Theme.of(context).navigationBarTheme;
              final defaultLabelStyle =
                  navTheme.labelTextStyle?.resolve(const <WidgetState>{}) ??
                  Theme.of(context).textTheme.labelSmall ??
                  const TextStyle(fontSize: 12);
              final selectedLabelStyle =
                  navTheme.labelTextStyle?.resolve(const <WidgetState>{
                    WidgetState.selected,
                  }) ??
                  defaultLabelStyle.copyWith(fontWeight: FontWeight.w700);
              final labelTextStyle = WidgetStateProperty.resolveWith<TextStyle>(
                (states) {
                  final isSelected = states.contains(WidgetState.selected);
                  final base = isSelected
                      ? selectedLabelStyle
                      : defaultLabelStyle;
                  return base.copyWith(fontSize: adaptiveFontSize);
                },
              );

              return NavigationBarTheme(
                data: navTheme.copyWith(labelTextStyle: labelTextStyle),
                child: NavigationBar(
                  selectedIndex: _tab,
                  onDestinationSelected: (index) =>
                      setState(() => _tab = index),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      label: 'Dashboard',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.inventory_2_outlined),
                      label: 'Productos',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.people_outline),
                      label: 'Clientes',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.local_offer_outlined),
                      label: 'Cupones',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.notifications_outlined),
                      label: 'Notificaciones',
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
      loading: () => const Scaffold(body: AurumCenteredLoader()),
      error: (error, _) => Scaffold(body: Center(child: Text('Error: $error'))),
    );
  }

  double _computeAdaptiveNavFontSize({
    required BuildContext context,
    required double maxWidth,
    required List<String> labels,
    required double minFontSize,
  }) {
    if (maxWidth <= 0 || labels.isEmpty) return minFontSize;

    final navTheme = Theme.of(context).navigationBarTheme;
    final defaultLabelStyle =
        navTheme.labelTextStyle?.resolve(const <WidgetState>{}) ??
        Theme.of(context).textTheme.labelSmall ??
        const TextStyle(fontSize: 12);
    final selectedLabelStyle =
        navTheme.labelTextStyle?.resolve(const <WidgetState>{
          WidgetState.selected,
        }) ??
        defaultLabelStyle.copyWith(fontWeight: FontWeight.w700);
    final baseFontSize = defaultLabelStyle.fontSize ?? 12;
    final textDirection = Directionality.of(context);
    final itemWidth = maxWidth / labels.length;
    const horizontalPadding = 28.0;
    final availableLabelWidth = (itemWidth - horizontalPadding).clamp(
      1.0,
      double.infinity,
    );

    var maxLabelWidth = 0.0;
    for (final label in labels) {
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: selectedLabelStyle.copyWith(fontSize: baseFontSize),
        ),
        maxLines: 1,
        textDirection: textDirection,
      )..layout();
      if (painter.width > maxLabelWidth) {
        maxLabelWidth = painter.width;
      }
    }

    if (maxLabelWidth <= availableLabelWidth) {
      return baseFontSize;
    }

    final scaled = baseFontSize * (availableLabelWidth / maxLabelWidth);
    return scaled.clamp(minFontSize, baseFontSize).toDouble();
  }
}
