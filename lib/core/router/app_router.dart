import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/presentation/pages/login_screen.dart';
import '../../features/auth/presentation/pages/onboarding_screen.dart';
import '../../features/auth/presentation/pages/splash_screen.dart';
import '../../features/shared/presentation/pages/main_screen.dart';
import '../../features/products/presentation/pages/product_detail_screen.dart';
import '../../features/products/domain/models/product.dart';
import '../../features/favorites/presentation/pages/favorites_screen.dart';
import '../../features/notifications/presentation/pages/notifications_screen.dart';
import '../../features/orders/presentation/pages/orders_screen.dart';
import '../../features/orders/presentation/pages/order_detail_screen.dart';
import '../../features/orders/presentation/pages/admin_orders_screen.dart';
import '../../features/orders/presentation/pages/admin_order_detail_screen.dart';
import '../../features/admin/presentation/pages/admin_shell_screen.dart';
import '../../features/admin/presentation/pages/admin_product_form_screen.dart';
import '../../features/admin/presentation/pages/admin_categories_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  redirect: (context, state) async {
    final path = state.uri.path;
    if (!path.startsWith('/admin')) return null;

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return '/login';

    try {
      final profile = await supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();
      final role = profile?['role']?.toString();
      if (role != 'admin') return '/home';
    } catch (_) {
      return '/home';
    }

    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/home', builder: (context, state) => const MainScreen()),
    GoRoute(
      path: '/favorites',
      builder: (context, state) => const FavoritesScreen(),
    ),
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const NotificationsScreen(),
    ),
    GoRoute(
      path: '/orders',
      builder: (context, state) => const OrdersScreen(),
    ),
    GoRoute(
      path: '/order-detail',
      builder: (context, state) {
        final orderId = _readExtraString(state);
        if (orderId == null) {
          return const _RouteErrorScreen(
            message: 'No se pudo abrir el detalle del pedido.',
          );
        }
        return OrderDetailScreen(orderId: orderId);
      },
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminShellScreen(),
    ),
    GoRoute(
      path: '/admin/products/new',
      builder: (context, state) => const AdminProductFormScreen(),
    ),
    GoRoute(
      path: '/admin/products/edit',
      builder: (context, state) {
        final productId = _readExtraString(state);
        if (productId == null) {
          return const _RouteErrorScreen(
            message: 'No se pudo abrir la edicion del producto.',
          );
        }
        return AdminProductFormScreen(productId: productId);
      },
    ),
    GoRoute(
      path: '/admin/categories',
      builder: (context, state) => const AdminCategoriesScreen(),
    ),
    GoRoute(
      path: '/admin/orders',
      builder: (context, state) => const AdminOrdersScreen(),
    ),
    GoRoute(
      path: '/admin/order-detail',
      builder: (context, state) {
        final orderId = _readExtraString(state);
        if (orderId == null) {
          return const _RouteErrorScreen(
            message: 'No se pudo abrir el detalle del pedido.',
          );
        }
        return AdminOrderDetailScreen(orderId: orderId);
      },
    ),
    GoRoute(
      path: '/product-detail',
      builder: (context, state) {
        final product = _readExtraProduct(state);
        if (product == null) {
          return const _RouteErrorScreen(
            message: 'No se pudo abrir el detalle del producto.',
          );
        }
        return ProductDetailScreen(product: product);
      },
    ),
  ],
);

String? _readExtraString(GoRouterState state) {
  final extra = state.extra;
  if (extra is String && extra.trim().isNotEmpty) {
    return extra;
  }
  return null;
}

Product? _readExtraProduct(GoRouterState state) {
  final extra = state.extra;
  if (extra is Product) return extra;
  return null;
}

class _RouteErrorScreen extends StatelessWidget {
  const _RouteErrorScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ruta invalida')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
