import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/design_system/widgets/aurum_card.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../providers/admin_provider.dart';
import '../../data/repositories/admin_repository.dart';

class AdminProductsScreen extends ConsumerStatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  ConsumerState<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends ConsumerState<AdminProductsScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String _stock = 'all';
  String _status = 'all';
  String? _categoryId;

  int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  List<Map<String, dynamic>> _asMapList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  List<String> _asStringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
  }

  String? _primaryImage(dynamic raw) {
    final images = _asStringList(raw);
    return images.isEmpty ? null : images.first;
  }
  String? _resolveImageUrl(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final raw = value.trim();
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    final normalized = raw.startsWith('/') ? raw.substring(1) : raw;
    return Supabase.instance.client.storage
        .from('product-images')
        .getPublicUrl(normalized);
  }

  String _categoryName(dynamic categoriesField) {
    if (categoriesField is Map) {
      return categoriesField['name']?.toString() ?? 'Sin categoria';
    }
    if (categoriesField is List && categoriesField.isNotEmpty) {
      final first = categoriesField.first;
      if (first is Map) {
        return first['name']?.toString() ?? 'Sin categoria';
      }
    }
    return 'Sin categoria';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(adminRepositoryProvider);
    return FutureBuilder<ProductListResult>(
      future: repo.getProducts(
        query: _query,
        categoryId: _categoryId,
        stockFilter: _stock,
        statusFilter: _status,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Error cargando productos: ${snapshot.error}'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          );
        }

        final result = snapshot.data!;
        final categoryIds = result.categories
            .map((c) => c['id']?.toString())
            .whereType<String>()
            .toSet();
        final selectedCategory =
            (_categoryId != null && categoryIds.contains(_categoryId))
                ? _categoryId
                : '';
        return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Productos',
                      style: Theme.of(context).textTheme.displayMedium,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await context.push('/admin/categories');
                      if (mounted) setState(() {});
                    },
                    icon: const Icon(Icons.category_outlined),
                    label: const Text('Categorias'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await context.push('/admin/products/new');
                      if (mounted) setState(() {});
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Nuevo'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AurumCard(
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Buscar por nombre, slug o SKU',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) => setState(() => _query = value.trim()),
                    ),
                    const SizedBox(height: 8),
                    Column(
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: selectedCategory,
                          decoration: const InputDecoration(labelText: 'Categoria'),
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem(value: '', child: Text('Todas')),
                            ...result.categories.map(
                              (c) => DropdownMenuItem(
                                value: c['id'].toString(),
                                child: Text(c['name']?.toString() ?? '-'),
                              ),
                            ),
                          ],
                          onChanged: (v) => setState(() => _categoryId = (v == null || v.isEmpty) ? null : v),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _stock,
                                decoration: const InputDecoration(labelText: 'Stock'),
                                isExpanded: true,
                                items: const [
                                  DropdownMenuItem(value: 'all', child: Text('Todo')),
                                  DropdownMenuItem(value: 'low', child: Text('Bajo')),
                                  DropdownMenuItem(value: 'out', child: Text('Sin stock')),
                                ],
                                onChanged: (v) => setState(() => _stock = v ?? 'all'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _status,
                                decoration: const InputDecoration(labelText: 'Estado'),
                                isExpanded: true,
                                items: const [
                                  DropdownMenuItem(value: 'all', child: Text('Todos')),
                                  DropdownMenuItem(value: 'active', child: Text('Activos')),
                                  DropdownMenuItem(value: 'inactive', child: Text('Inactivos')),
                                ],
                                onChanged: (v) => setState(() => _status = v ?? 'all'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (result.products.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: Text('No hay productos para estos filtros')),
                ),
              ...result.products.map((p) {
                final variants = _asMapList(p['product_variants']);
                final totalStock = variants.fold<int>(
                  0,
                  (sum, v) => sum + _toInt(v['stock']),
                );
                final displayPrice =
                    _toInt(p['is_on_sale'] == true ? p['sale_price'] : p['price']);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AurumCard(
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: _ProductThumb(imageUrl: _resolveImageUrl(_primaryImage(p['images']))),
                          title: Text(p['name']?.toString() ?? '-'),
                          subtitle: Text(
                            [
                              'Categoria: ${_categoryName(p['categories'])}',
                              'Stock: $totalStock',
                              'Slug: ${p['slug'] ?? '-'}',
                              'SKU: ${p['sku'] ?? '-'}',
                              'Estado: ${p['is_active'] == true ? 'Activo' : 'Inactivo'}',
                            ].join('\n'),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                Formatters.euro(displayPrice / 100),
                                style: const TextStyle(
                                  color: AppTheme.gold,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (p['is_on_sale'] == true &&
                                  _toInt(p['price']) != displayPrice)
                                Text(
                                  Formatters.euro(_toInt(p['price']) / 100),
                                  style: const TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                    color: Colors.black54,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: () => _showProductDetail(p, totalStock),
                              icon: const Icon(Icons.visibility_outlined),
                              label: const Text('Ver'),
                            ),
                            TextButton.icon(
                              onPressed: () async {
                                await context.push('/admin/products/edit', extra: p['id'].toString());
                                if (mounted) setState(() {});
                              },
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Editar'),
                            ),
                            TextButton.icon(
                              onPressed: () => _deleteProduct(p['id'].toString(), p['name']?.toString() ?? 'Producto'),
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              label: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
      },
    );
  }

  void _showProductDetail(Map<String, dynamic> product, int totalStock) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final variants = _asMapList(product['product_variants']);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProductThumb(imageUrl: _resolveImageUrl(_primaryImage(product['images']))),
                const SizedBox(height: 10),
                Text(
                  product['name']?.toString() ?? '-',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text('Slug: ${product['slug'] ?? '-'}'),
                Text('SKU: ${product['sku'] ?? '-'}'),
                Text('Activo: ${product['is_active'] == true ? 'Si' : 'No'}'),
                Text('Stock total: $totalStock'),
                const SizedBox(height: 8),
                Text('Variantes:', style: Theme.of(context).textTheme.titleMedium),
                ...variants.map((v) {
                  return Text(' -  ${v['size']}: ${v['stock']} uds');
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteProduct(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text(
          'Se eliminara "$name" de forma permanente solo si no tiene pedidos asociados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    try {
      await ref.read(adminRepositoryProvider).deleteProductIfNoOrders(id);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Producto eliminado')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo eliminar: $e')),
      );
    }
  }
}

class _ProductThumb extends StatelessWidget {
  const _ProductThumb({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 56,
        height: 56,
        child: imageUrl == null
            ? Container(
                color: Colors.black12,
                child: const Icon(Icons.image_not_supported_outlined),
              )
            : Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.black12,
                  child: const Icon(Icons.broken_image_outlined),
                ),
              ),
      ),
    );
  }
}

