import 'package:go_router/go_router.dart';
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
        final orderId = state.extra as String;
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
        final productId = state.extra as String;
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
        final orderId = state.extra as String;
        return AdminOrderDetailScreen(orderId: orderId);
      },
    ),
    GoRoute(
      path: '/product-detail',
      builder: (context, state) {
        final product = state.extra as Product;
        return ProductDetailScreen(product: product);
      },
    ),
  ],
);
