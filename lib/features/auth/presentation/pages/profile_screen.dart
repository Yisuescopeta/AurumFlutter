import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/design_system/widgets/aurum_card.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: AppTheme.lightGrey,
      appBar: AppBar(title: const Text(AppStrings.perfil)),
      body: profileAsync.when(
        data: (profile) {
          final isAdmin = profile?.role == 'admin';
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                AurumCard(
                  child: Column(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: AppTheme.navyBlue,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.gold, width: 3),
                        ),
                        child: Center(
                          child: Text(
                            profile?.fullName?.substring(0, 1).toUpperCase() ??
                                user?.email?.substring(0, 1).toUpperCase() ??
                                'U',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.gold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        profile?.fullName ?? 'Usuario',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(user?.email ?? ''),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.gold.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isAdmin ? AppStrings.administrador : AppStrings.cliente,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.gold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                AurumCard(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      _buildMenuItem(
                        icon: LucideIcons.shoppingBag,
                        title: AppStrings.misPedidos,
                        onTap: () => context.push('/orders'),
                      ),
                      const Divider(height: 1),
                      _buildMenuItem(
                        icon: LucideIcons.heart,
                        title: AppStrings.favoritos,
                        onTap: () => context.push('/favorites'),
                      ),
                      const Divider(height: 1),
                      _buildMenuItem(
                        icon: LucideIcons.mapPin,
                        title: AppStrings.direccionEnvio,
                        subtitle: profile?.address ?? 'No configurada',
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
                if (isAdmin) ...[
                  const SizedBox(height: 12),
                  AurumCard(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: _buildMenuItem(
                      icon: LucideIcons.layoutDashboard,
                      title: AppStrings.panelAdmin,
                      onTap: () => context.push('/admin'),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                AurumCard(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: _buildMenuItem(
                    icon: LucideIcons.logOut,
                    title: AppStrings.cerrarSesion,
                    titleColor: Colors.red,
                    iconColor: Colors.red,
                    onTap: () => _logout(context, ref),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error al cargar el perfil: $error')),
      ),
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          AppStrings.cerrarSesion,
          style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold),
        ),
        content: const Text(AppStrings.confirmarCerrarSesion),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(AppStrings.cancelar),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(AppStrings.cerrarSesion),
          ),
        ],
      ),
    );

    if (shouldLogout == true && context.mounted) {
      await ref.read(authControllerProvider.notifier).signOut();
      if (context.mounted) context.go('/login');
    }
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? titleColor,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? AppTheme.navyBlue),
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          color: titleColor ?? AppTheme.navyBlue,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
            )
          : null,
      trailing: Icon(LucideIcons.chevronRight, color: Colors.grey[400], size: 20),
      onTap: onTap,
    );
  }
}
