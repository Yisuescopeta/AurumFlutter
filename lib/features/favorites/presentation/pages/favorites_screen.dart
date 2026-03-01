import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../products/domain/models/product.dart';
import '../../presentation/providers/favorites_provider.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFFDF7E9),
        appBar: AppBar(title: const Text(AppStrings.favoritos)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFF4CF), Color(0xFFF3D27A)],
                ),
                border: Border.all(color: AppTheme.gold.withValues(alpha: 0.55), width: 1.2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x22B5483F),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.favorite_rounded, color: Color(0xFFB5483F), size: 64),
                  const SizedBox(height: 10),
                  Text(
                    AppStrings.favoritos,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.navyBlue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppStrings.iniciarSesionFavoritos,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF6B5440),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => context.go('/login'),
                      icon: const Icon(Icons.login_rounded),
                      label: const Text(AppStrings.iniciarSesion),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFB5483F),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final favoritesAsync = ref.watch(favoriteProductsProvider);
    final loadingIds = ref.watch(favoriteToggleLoadingProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFDF7E9),
      appBar: AppBar(title: const Text(AppStrings.favoritos)),
      body: favoritesAsync.when(
        data: (products) {
          if (products.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFFF4CF), Color(0xFFF3D27A)],
                    ),
                    border: Border.all(color: AppTheme.gold.withValues(alpha: 0.55), width: 1.2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22B5483F),
                        blurRadius: 20,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.favorite_outline, color: Color(0xFFB5483F), size: 64),
                      const SizedBox(height: 10),
                      Text(
                        AppStrings.favoritosVacio,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.navyBlue,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppStrings.favoritosVacioDesc,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF6B5440),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
            itemBuilder: (context, index) {
              final product = products[index];
              final isToggling = loadingIds.contains(product.id);
              return _FavoriteProductCard(
                product: product,
                isToggling: isToggling,
                onTap: () => context.push('/product-detail', extra: product),
                onRemove: () => _toggleFavorite(context, ref, product.id),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemCount: products.length,
          );
        },
        loading: () => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.favorite_rounded, color: Color(0xFFB5483F), size: 38),
              SizedBox(height: 10),
              CircularProgressIndicator(color: AppTheme.gold),
            ],
          ),
        ),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: $error'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.invalidate(favoriteProductsProvider),
                child: const Text(AppStrings.reintentar),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleFavorite(
    BuildContext context,
    WidgetRef ref,
    String productId,
  ) async {
    try {
      final result = await ref
          .read(favoriteToggleControllerProvider.notifier)
          .toggle(productId);

      if (!context.mounted || result == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result
                ? AppStrings.agregadoFavoritos
                : AppStrings.eliminadoFavoritos,
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar favoritos: $e')),
      );
    }
  }
}

class _FavoriteProductCard extends StatelessWidget {
  const _FavoriteProductCard({
    required this.product,
    required this.isToggling,
    required this.onTap,
    required this.onRemove,
  });

  final Product product;
  final bool isToggling;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF7DE), Color(0xFFF3D07A)],
          ),
          border: Border.all(color: AppTheme.gold.withValues(alpha: 0.75), width: 1.1),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1FB5483F),
              blurRadius: 18,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.gold.withValues(alpha: 0.7), width: 1.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: product.images.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: product.images.first,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const _FavoriteImagePlaceholder(),
                            errorWidget: (_, __, ___) => const _FavoriteImagePlaceholder(),
                          )
                        : const _FavoriteImagePlaceholder(),
                  ),
                ),
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: const Color(0xFFB5483F),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.favorite, color: Colors.white, size: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppTheme.navyBlue,
                    ),
                  ),
                  const SizedBox(height: 4),
                    Text(
                      (product.category?['name']?.toString() ?? '').toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFB5483F),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        Formatters.euro(product.currentPrice),
                        style: GoogleFonts.inter(
                          color: AppTheme.gold,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (product.isOnSale == true && product.salePrice != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          Formatters.euro(product.price),
                          style: GoogleFonts.inter(
                            color: const Color(0xFF8A6C5A),
                            fontSize: 12,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFECC0BC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: IconButton(
                tooltip: 'Quitar de favoritos',
                onPressed: isToggling ? null : onRemove,
                icon: isToggling
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_outline_rounded, color: Color(0xFFB5483F)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoriteImagePlaceholder extends StatelessWidget {
  const _FavoriteImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF3EEE4),
      alignment: Alignment.center,
      child: const Icon(Icons.checkroom, color: Color(0xFFB5483F), size: 28),
    );
  }
}
