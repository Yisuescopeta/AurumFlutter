import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/design_system/widgets/aurum_card.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../cart/data/repositories/cart_stock_repository.dart';
import '../../../cart/domain/models/cart_item.dart';
import '../../../cart/presentation/providers/cart_provider.dart';
import '../../../favorites/presentation/providers/favorites_provider.dart';
import '../../domain/models/product.dart';
import '../providers/product_provider.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({super.key, required this.product});

  final Product product;

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  String? _selectedSize;
  int _selectedQuantity = 1;
  int _currentImageIndex = 0;
  bool _isAdding = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final availableSizes = p.availableSizes;
    final favoriteIds =
        ref.watch(favoriteIdsProvider).valueOrNull ?? <String>{};
    final isFavorite = favoriteIds.contains(p.id);
    final loadingIds = ref.watch(favoriteToggleLoadingProvider);
    final isLoadingFavorite = loadingIds.contains(p.id);
    final selectedSize = _selectedSize;
    final quantityInCart = selectedSize == null
        ? 0
        : _currentQuantityInCart(productId: p.id, size: selectedSize);
    final stockAsync = selectedSize == null
        ? const AsyncValue<int>.data(0)
        : ref.watch(
            stockByVariantProvider((productId: p.id, size: selectedSize)),
          );
    final remainingAsync = stockAsync.whenData((stock) {
      final remaining = stock - quantityInCart;
      return remaining < 0 ? 0 : remaining;
    });
    final canAddToCart =
        selectedSize != null &&
        !_isAdding &&
        remainingAsync.maybeWhen(
          data: (remaining) => remaining > 0,
          orElse: () => false,
        );
    final canIncreaseQty = remainingAsync.maybeWhen(
      data: (remaining) => _selectedQuantity < remaining,
      orElse: () => false,
    );

    final relatedRequest = RelatedProductsRequest(
      productId: p.id,
      categoryId: p.categoryId,
    );
    final relatedAsync = ref.watch(relatedProductsProvider(relatedRequest));

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 450,
            pinned: true,
            backgroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                children: [
                  PageView.builder(
                    itemCount: p.images.length,
                    onPageChanged: (index) =>
                        setState(() => _currentImageIndex = index),
                    itemBuilder: (context, index) {
                      return CachedNetworkImage(
                        imageUrl: p.images[index],
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const Center(
                          child: Icon(
                            Icons.checkroom,
                            size: 48,
                            color: Colors.grey,
                          ),
                        ),
                      );
                    },
                  ),
                  if (p.images.length > 1)
                    Positioned(
                      bottom: 20,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: p.images.asMap().entries.map((entry) {
                          return Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _currentImageIndex == entry.key
                                  ? AppTheme.gold
                                  : Colors.white.withValues(alpha: 0.5),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.name,
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.navyBlue,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (p.category != null)
                            Text(
                              p.category?['name']?.toString().toUpperCase() ??
                                  '',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                letterSpacing: 2,
                                color: AppTheme.gold,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite ? Colors.red : AppTheme.navyBlue,
                      ),
                      onPressed: isLoadingFavorite
                          ? null
                          : () => _toggleFavorite(p.id),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      Formatters.euro(p.currentPrice),
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.navyBlue,
                      ),
                    ),
                    if (p.isOnSale && p.salePrice != null) ...[
                      const SizedBox(width: 12),
                      Text(
                        Formatters.euro(p.price),
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          color: Colors.grey,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  p.description ?? AppStrings.sinDescripcion,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Text(
                      AppStrings.seleccionarTalla,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        letterSpacing: 3,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.navyBlue,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _showSizeGuide,
                      icon: const Icon(Icons.straighten),
                      label: const Text(AppStrings.verGuiaTallas),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: availableSizes.map((size) {
                    final isSelected = _selectedSize == size;
                    return GestureDetector(
                      onTap: () => setState(() {
                        _selectedSize = size;
                        _selectedQuantity = 1;
                      }),
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.navyBlue
                                : Colors.grey[300]!,
                            width: 2,
                          ),
                          color: isSelected ? AppTheme.navyBlue : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            size,
                            style: GoogleFonts.inter(
                              color: isSelected
                                  ? Colors.white
                                  : AppTheme.navyBlue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBF8F2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE9DDC2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.stockTitulo,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          letterSpacing: 2.4,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.navyBlue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _StockMessage(
                        selectedSize: selectedSize,
                        quantityInCart: quantityInCart,
                        remainingAsync: remainingAsync,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Text(
                            AppStrings.cantidad,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.navyBlue,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: _selectedQuantity > 1
                                ? () => setState(() => _selectedQuantity--)
                                : null,
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Container(
                            width: 48,
                            alignment: Alignment.center,
                            child: Text(
                              '$_selectedQuantity',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: canIncreaseQty
                                ? () => setState(() => _selectedQuantity++)
                                : null,
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  AppStrings.masInformacionProducto,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                AurumCard(
                  child: Column(
                    children: [
                      _InfoRow(
                        title: AppStrings.materialTitulo,
                        value:
                            (p.material == null || p.material!.trim().isEmpty)
                            ? AppStrings.materialNoEspecificado
                            : p.material!,
                      ),
                      const Divider(height: 20),
                      const _InfoRow(
                        title: AppStrings.cuidadosTitulo,
                        value: AppStrings.cuidadosTexto,
                      ),
                      const Divider(height: 20),
                      const _InfoRow(
                        title: AppStrings.envioDevolucionesTitulo,
                        value: AppStrings.envioDevolucionesTexto,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  AppStrings.tePodriaInteresar,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                relatedAsync.when(
                  data: (products) {
                    if (products.isEmpty) {
                      return const Text(AppStrings.noRelacionados);
                    }
                    return SizedBox(
                      height: 265,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: products.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) => SizedBox(
                          width: 180,
                          child: _RelatedProductCard(product: products[index]),
                        ),
                      ),
                    );
                  },
                  loading: () => const SizedBox(
                    height: 120,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (_, __) => SizedBox(
                    height: 120,
                    child: Center(
                      child: TextButton(
                        onPressed: () => ref.invalidate(
                          relatedProductsProvider(relatedRequest),
                        ),
                        child: const Text(AppStrings.reintentarCarga),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 120),
              ]),
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 22,
              offset: Offset(0, -8),
            ),
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: canAddToCart ? _addToCart : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.navyBlue,
              foregroundColor: Colors.white,
            ),
            child: _isAdding
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(
                    selectedSize == null
                        ? AppStrings.seleccionarTalla
                        : remainingAsync.isLoading
                        ? AppStrings.comprobandoStock
                        : remainingAsync.hasError
                        ? AppStrings.stockNoDisponible
                        : canAddToCart
                        ? '${AppStrings.anadirCarrito} (${_selectedQuantity}x)'
                        : AppStrings.sinStock,
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ),
    );
  }

  int _currentQuantityInCart({
    required String productId,
    required String size,
  }) {
    final normalized = normalizeVariantSize(size);
    final cart = ref.read(cartControllerProvider);
    return cart.items
        .where((item) => item.productId == productId)
        .where((item) => normalizeVariantSize(item.size) == normalized)
        .fold<int>(0, (sum, item) => sum + item.quantity);
  }

  Future<void> _toggleFavorite(String productId) async {
    try {
      final result = await ref
          .read(favoriteToggleControllerProvider.notifier)
          .toggle(productId);
      if (!mounted || result == null) return;
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar favoritos: $e')),
      );
    }
  }

  Future<void> _addToCart() async {
    final product = widget.product;
    final size = normalizeVariantSize(_selectedSize ?? 'Unica');
    final stockRepository = ref.read(cartStockRepositoryProvider);
    final quantityInCart = _currentQuantityInCart(
      productId: product.id,
      size: size,
    );

    setState(() => _isAdding = true);
    try {
      final stock = await stockRepository.getStockForSize(
        productId: product.id,
        size: size,
      );
      final remaining = stock - quantityInCart;
      if (remaining <= 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text(AppStrings.sinStock)));
        return;
      }

      final quantityToAdd = _selectedQuantity > remaining
          ? remaining
          : _selectedQuantity;
      final cartItem = CartItem(
        productId: product.id,
        name: product.name,
        image: product.images.isEmpty ? null : product.images.first,
        size: size,
        unitPriceCents: (product.currentPrice * 100).round(),
        quantity: quantityToAdd,
        categoryName: product.category?['name']?.toString(),
        isOnSale: product.isOnSale,
      );

      final added = await ref
          .read(cartControllerProvider.notifier)
          .addItem(cartItem, maxStock: stock);

      if (!mounted) return;
      if (!added) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.stockInsuficiente)),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppStrings.productoAnadidoCarrito}: $quantityToAdd'),
          action: SnackBarAction(
            label: AppStrings.carrito,
            onPressed: () => context.go('/home'),
          ),
        ),
      );
      setState(() => _selectedQuantity = 1);
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  Future<void> _showSizeGuide() async {
    const rows = <({String size, String pecho, String cintura, String cadera})>[
      (size: 'XS', pecho: '80-84 cm', cintura: '60-64 cm', cadera: '86-90 cm'),
      (size: 'S', pecho: '84-88 cm', cintura: '64-68 cm', cadera: '90-94 cm'),
      (size: 'M', pecho: '88-94 cm', cintura: '68-74 cm', cadera: '94-100 cm'),
      (
        size: 'L',
        pecho: '94-100 cm',
        cintura: '74-80 cm',
        cadera: '100-106 cm',
      ),
      (
        size: 'XL',
        pecho: '100-106 cm',
        cintura: '80-86 cm',
        cadera: '106-112 cm',
      ),
    ];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.guiaTallas,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Talla')),
                    DataColumn(label: Text('Pecho')),
                    DataColumn(label: Text('Cintura')),
                    DataColumn(label: Text('Cadera')),
                  ],
                  rows: rows
                      .map(
                        (r) => DataRow(
                          cells: [
                            DataCell(Text(r.size)),
                            DataCell(Text(r.pecho)),
                            DataCell(Text(r.cintura)),
                            DataCell(Text(r.cadera)),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StockMessage extends StatelessWidget {
  const _StockMessage({
    required this.selectedSize,
    required this.quantityInCart,
    required this.remainingAsync,
  });

  final String? selectedSize;
  final int quantityInCart;
  final AsyncValue<int> remainingAsync;

  @override
  Widget build(BuildContext context) {
    if (selectedSize == null) {
      return const Text(
        AppStrings.seleccionaTallaVerStock,
        style: TextStyle(color: Colors.black54, fontSize: 13),
      );
    }

    return remainingAsync.when(
      loading: () => const Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Text(
            AppStrings.comprobandoStock,
            style: TextStyle(color: Colors.black54, fontSize: 13),
          ),
        ],
      ),
      error: (_, __) => const Text(
        AppStrings.stockNoDisponible,
        style: TextStyle(color: Colors.redAccent, fontSize: 13),
      ),
      data: (remaining) {
        if (remaining <= 0) {
          return Text(
            '${AppStrings.sinStock} (${selectedSize!})',
            style: const TextStyle(
              color: Color(0xFFB54435),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          );
        }
        final selectedText =
            '${AppStrings.stockDisponible}: $remaining ${AppStrings.unidades}';
        if (quantityInCart <= 0) {
          return Text(
            selectedText,
            style: const TextStyle(
              color: Color(0xFF1E6A41),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          );
        }
        return Text(
          '$selectedText - ${AppStrings.enCarrito}: $quantityInCart',
          style: const TextStyle(
            color: Color(0xFF1E6A41),
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppTheme.navyBlue,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(value)),
      ],
    );
  }
}

class _RelatedProductCard extends StatelessWidget {
  const _RelatedProductCard({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/product-detail', extra: product),
      child: AurumCard(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: product.images.isEmpty
                    ? const Center(
                        child: Icon(
                          Icons.checkroom,
                          size: 46,
                          color: Colors.grey,
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: product.images.first,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const Center(
                          child: Icon(
                            Icons.checkroom,
                            size: 46,
                            color: Colors.grey,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              product.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              Formatters.euro(product.currentPrice),
              style: GoogleFonts.inter(
                color: AppTheme.gold,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
