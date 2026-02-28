import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/design_system/app_motion.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/design_system/app_adaptive.dart';
import '../../../../core/design_system/app_tokens.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../cart/presentation/pages/cart_screen.dart';
import '../../../products/presentation/pages/home_screen.dart';
import '../../../store/presentation/pages/store_screen.dart';
import '../../../auth/presentation/pages/profile_screen.dart';
import '../../../favorites/presentation/pages/favorites_screen.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const StoreScreen(),
    const CartScreen(),
    const FavoritesScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final reduceMotion = AppAdaptive.reduceMotion(context);
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: AnimatedContainer(
          duration: reduceMotion ? const Duration(milliseconds: 120) : AppMotion.short,
          curve: AppMotion.emphasized,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.97),
            borderRadius: BorderRadius.circular(AppTokens.radiusXl),
            border: Border.all(color: AppTokens.slate100),
            boxShadow: const [
              BoxShadow(
                color: Color(0x19000000),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTokens.radiusXl),
            child: NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: (index) {
                setState(() => _currentIndex = index);
              },
              backgroundColor: Colors.transparent,
              elevation: 0,
              indicatorColor: AppTheme.gold.withOpacity(0.12),
              height: 70,
              destinations: const [
                NavigationDestination(
                  icon: Icon(LucideIcons.home),
                  selectedIcon: Icon(LucideIcons.home, color: AppTheme.gold),
                  label: AppStrings.inicio,
                ),
                NavigationDestination(
                  icon: Icon(LucideIcons.search),
                  selectedIcon: Icon(LucideIcons.search, color: AppTheme.gold),
                  label: AppStrings.tienda,
                ),
                NavigationDestination(
                  icon: Icon(LucideIcons.shoppingBag),
                  selectedIcon: Icon(LucideIcons.shoppingBag, color: AppTheme.gold),
                  label: AppStrings.carrito,
                ),
                NavigationDestination(
                  icon: Icon(LucideIcons.heart),
                  selectedIcon: Icon(LucideIcons.heart, color: AppTheme.gold),
                  label: AppStrings.favoritos,
                ),
                NavigationDestination(
                  icon: Icon(LucideIcons.user),
                  selectedIcon: Icon(LucideIcons.user, color: AppTheme.gold),
                  label: AppStrings.perfil,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
