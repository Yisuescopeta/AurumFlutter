import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../products/presentation/pages/home_screen.dart';
import '../../../auth/presentation/pages/profile_screen.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const Center(child: Text('Catalog')), // Placeholder
    const Center(child: Text('Cart')), // Placeholder
    const Center(child: Text('Favorites')), // Placeholder
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Colors.grey.withOpacity(0.1), width: 1),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() => _currentIndex = index);
          },
          backgroundColor: Colors.white,
          elevation: 0,
          indicatorColor: AppTheme.gold.withOpacity(0.1),
          destinations: const [
            NavigationDestination(
              icon: Icon(LucideIcons.home),
              selectedIcon: Icon(LucideIcons.home, color: AppTheme.gold),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(LucideIcons.search),
              selectedIcon: Icon(LucideIcons.search, color: AppTheme.gold),
              label: 'Shop',
            ),
            NavigationDestination(
              icon: Icon(LucideIcons.shoppingBag),
              selectedIcon: Icon(LucideIcons.shoppingBag, color: AppTheme.gold),
              label: 'Cart',
            ),
            NavigationDestination(
              icon: Icon(LucideIcons.heart),
              selectedIcon: Icon(LucideIcons.heart, color: AppTheme.gold),
              label: 'Favorites',
            ),
            NavigationDestination(
              icon: Icon(LucideIcons.user),
              selectedIcon: Icon(LucideIcons.user, color: AppTheme.gold),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
