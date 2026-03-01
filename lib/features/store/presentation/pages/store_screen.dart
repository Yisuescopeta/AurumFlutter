import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../favorites/presentation/providers/favorites_provider.dart';
import '../../../products/domain/models/product.dart';
import '../../../products/presentation/providers/product_provider.dart';

enum _SortBy { newest, priceAsc, priceDesc }

class StoreScreen extends ConsumerStatefulWidget {
  const StoreScreen({super.key});

  @override
  ConsumerState<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends ConsumerState<StoreScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String? _selectedCategory;
  String? _selectedSize;
  RangeValues _priceRange = const RangeValues(0, 500);
  _SortBy _sortBy = _SortBy.newest;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5EF),
      appBar: AppBar(
        title: Text(
          AppStrings.tienda,
          style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: productsAsync.isLoading
                ? null
                : () => _showSortBottomSheet(context),
            icon: const Icon(Icons.swap_vert_rounded),
            tooltip: AppStrings.ordenar,
          ),
          IconButton(
            onPressed: productsAsync.isLoading ? null : _showFiltersBottomSheet,
            icon: const Icon(Icons.tune_rounded),
            tooltip: AppStrings.filtros,
          ),
        ],
      ),
      body: productsAsync.when(
        data: (products) {
          final activeProducts = products.where((p) => p.isActive).toList();
          final filtered = _applyFilters(activeProducts);

          return Column(
            children: [
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF101A30), Color(0xFF2B3958)],
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x26000000),
                      blurRadius: 24,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.gold,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.storefront_rounded,
                        color: AppTheme.navyBlue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'COLECCION BOUTIQUE',
                            style: GoogleFonts.inter(
                              color: Colors.white70,
                              fontSize: 11,
                              letterSpacing: 1.6,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${filtered.length} productos para descubrir',
                            style: GoogleFonts.playfairDisplay(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value.trim()),
                  decoration: InputDecoration(
                    hintText: AppStrings.buscarProducto,
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.close),
                          ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoPill(
                      icon: Icons.tune_rounded,
                      label: '${AppStrings.filtros}: ${_activeFiltersCount()}',
                    ),
                    _InfoPill(
                      icon: Icons.grid_view_rounded,
                      label: 'Resultados: ${filtered.length}',
                    ),
                    if (_selectedCategory != null &&
                        _selectedCategory!.isNotEmpty)
                      _InfoPill(
                        icon: Icons.sell_outlined,
                        label: _selectedCategory!,
                      ),
                  ],
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text(AppStrings.sinProductos))
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.60,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) =>
                            _StoreProductCard(product: filtered[index]),
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  int _activeFiltersCount() {
    var count = 0;
    if (_selectedCategory != null && _selectedCategory!.isNotEmpty) count++;
    if (_selectedSize != null && _selectedSize!.isNotEmpty) count++;
    if (_priceRange.start > 0 || _priceRange.end < 500) count++;
    return count;
  }

  List<Product> _applyFilters(List<Product> products) {
    Iterable<Product> result = products;

    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      result = result.where((p) {
        final name = p.name.toLowerCase();
        final categoryName =
            p.category?['name']?.toString().toLowerCase() ?? '';
        return name.contains(q) || categoryName.contains(q);
      });
    }

    if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
      result = result.where(
        (p) =>
            (p.category?['name']?.toString() ?? '').toLowerCase() ==
            _selectedCategory!.toLowerCase(),
      );
    }

    if (_selectedSize != null && _selectedSize!.isNotEmpty) {
      result = result.where((p) {
        final sizes = _extractSizes(p);
        return sizes.any(
          (size) => size.toLowerCase() == _selectedSize!.toLowerCase(),
        );
      });
    }

    result = result.where((p) {
      final price = p.currentPrice.toDouble();
      return price >= _priceRange.start && price <= _priceRange.end;
    });

    final sorted = result.toList();
    switch (_sortBy) {
      case _SortBy.newest:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case _SortBy.priceAsc:
        sorted.sort((a, b) => a.currentPrice.compareTo(b.currentPrice));
        break;
      case _SortBy.priceDesc:
        sorted.sort((a, b) => b.currentPrice.compareTo(a.currentPrice));
        break;
    }

    return sorted;
  }

  List<String> _extractSizes(Product p) {
    return p.availableSizes;
  }

  Future<void> _showSortBottomSheet(BuildContext context) async {
    final selected = await showModalBottomSheet<_SortBy>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text(AppStrings.recientes),
              trailing: _sortBy == _SortBy.newest
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.of(context).pop(_SortBy.newest),
            ),
            ListTile(
              title: const Text(AppStrings.precioAsc),
              trailing: _sortBy == _SortBy.priceAsc
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.of(context).pop(_SortBy.priceAsc),
            ),
            ListTile(
              title: const Text(AppStrings.precioDesc),
              trailing: _sortBy == _SortBy.priceDesc
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.of(context).pop(_SortBy.priceDesc),
            ),
          ],
        ),
      ),
    );

    if (selected != null) {
      setState(() => _sortBy = selected);
    }
  }

  Future<void> _showFiltersBottomSheet() async {
    final products = await ref.read(productsProvider.future);
    if (!mounted) return;

    final categories =
        products
            .map((p) => p.category?['name']?.toString().trim() ?? '')
            .where((v) => v.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final sizes = products.expand(_extractSizes).toSet().toList()..sort();

    String? tempCategory = _selectedCategory;
    String? tempSize = _selectedSize;
    RangeValues tempRange = _priceRange;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (modalContext) => StatefulBuilder(
        builder: (modalContext, setModalState) {
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.filtros,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppStrings.categoria,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: categories
                          .map(
                            (c) => ChoiceChip(
                              label: Text(c),
                              selected: tempCategory == c,
                              onSelected: (_) => setModalState(() {
                                tempCategory = tempCategory == c ? null : c;
                              }),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppStrings.talla,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: sizes
                          .map(
                            (s) => ChoiceChip(
                              label: Text(s),
                              selected: tempSize == s,
                              onSelected: (_) => setModalState(() {
                                tempSize = tempSize == s ? null : s;
                              }),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppStrings.precio,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                    RangeSlider(
                      values: tempRange,
                      min: 0,
                      max: 500,
                      divisions: 100,
                      labels: RangeLabels(
                        '${tempRange.start.toStringAsFixed(0)} EUR',
                        '${tempRange.end.toStringAsFixed(0)} EUR',
                      ),
                      onChanged: (value) =>
                          setModalState(() => tempRange = value),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _selectedCategory = null;
                                _selectedSize = null;
                                _priceRange = const RangeValues(0, 500);
                              });
                              Navigator.of(modalContext).pop();
                            },
                            child: const Text(AppStrings.limpiar),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _selectedCategory = tempCategory;
                                _selectedSize = tempSize;
                                _priceRange = tempRange;
                              });
                              Navigator.of(modalContext).pop();
                            },
                            child: const Text(AppStrings.aplicar),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StoreProductCard extends ConsumerWidget {
  const _StoreProductCard({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoriteIds =
        ref.watch(favoriteIdsProvider).valueOrNull ?? <String>{};
    final loadingIds = ref.watch(favoriteToggleLoadingProvider);
    final isFavorite = favoriteIds.contains(product.id);
    final isLoading = loadingIds.contains(product.id);

    return InkWell(
      onTap: () => context.push('/product-detail', extra: product),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEADFC5)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x17000000),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF2EEE4),
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (product.images.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: product.images.first,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (_, __, ___) => const Center(
                          child: Icon(
                            Icons.checkroom,
                            size: 46,
                            color: Colors.grey,
                          ),
                        ),
                      )
                    else
                      const Center(
                        child: Icon(
                          Icons.checkroom,
                          size: 46,
                          color: Colors.grey,
                        ),
                      ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: IconButton(
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(
                            minWidth: 30,
                            minHeight: 30,
                          ),
                          onPressed: isLoading
                              ? null
                              : () => _toggleFavorite(context, ref, product.id),
                          icon: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: isFavorite
                                ? const Color(0xFFB5483F)
                                : AppTheme.navyBlue,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                    if (product.isOnSale)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.navyBlue,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'SALE',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              product.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              (product.category?['name']?.toString() ?? '').toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 10,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF8A6C5A),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  Formatters.euro(product.currentPrice),
                  style: GoogleFonts.inter(
                    color: AppTheme.gold,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                if (product.isOnSale && product.salePrice != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    Formatters.euro(product.price),
                    style: GoogleFonts.inter(
                      color: Colors.grey,
                      decoration: TextDecoration.lineThrough,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleFavorite(
    BuildContext context,
    WidgetRef ref,
    String productId,
  ) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.iniciarSesionFavoritos)),
      );
      context.go('/login');
      return;
    }

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

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE3D5B8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.navyBlue),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.navyBlue,
            ),
          ),
        ],
      ),
    );
  }
}
