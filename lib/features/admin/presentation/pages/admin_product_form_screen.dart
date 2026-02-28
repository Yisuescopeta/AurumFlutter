import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/admin_provider.dart';

class AdminProductFormScreen extends ConsumerStatefulWidget {
  const AdminProductFormScreen({super.key, this.productId});

  final String? productId;

  @override
  ConsumerState<AdminProductFormScreen> createState() => _AdminProductFormScreenState();
}

class _AdminProductFormScreenState extends ConsumerState<AdminProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _slug = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  final _salePrice = TextEditingController();
  final _sku = TextEditingController();
  final _material = TextEditingController();
  final _images = TextEditingController();

  bool _isOnSale = false;
  bool _isActive = true;
  String? _categoryId;
  bool _isSaving = false;
  List<Map<String, dynamic>> _variants = [
    {'size': 'M', 'stock': 0, 'sku_variant': ''},
  ];
  List<Map<String, dynamic>> _categories = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(adminRepositoryProvider);
    final list = await repo.getProducts();
    _categories = list.categories;

    if (widget.productId != null) {
      final product = await repo.getProductById(widget.productId!);
      _name.text = product['name']?.toString() ?? '';
      _slug.text = product['slug']?.toString() ?? '';
      _description.text = product['description']?.toString() ?? '';
      _sku.text = product['sku']?.toString() ?? '';
      _material.text = product['material']?.toString() ?? '';
      _price.text = (((product['price'] as num?)?.toInt() ?? 0) / 100).toStringAsFixed(2);
      _salePrice.text = (((product['sale_price'] as num?)?.toInt() ?? 0) / 100).toStringAsFixed(2);
      _isOnSale = product['is_on_sale'] == true;
      _isActive = product['is_active'] != false;
      _categoryId = product['category_id']?.toString();
      _images.text = ((product['images'] as List?) ?? const []).join(', ');
      _variants = (((product['product_variants'] as List?) ?? const [])).map((e) {
        final m = e as Map<String, dynamic>;
        return {
          'size': m['size']?.toString() ?? '',
          'stock': (m['stock'] as num?)?.toInt() ?? 0,
          'sku_variant': m['sku_variant']?.toString() ?? '',
        };
      }).toList();
      if (_variants.isEmpty) {
        _variants = [
          {'size': 'M', 'stock': 0, 'sku_variant': ''},
        ];
      }
    }

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _name.dispose();
    _slug.dispose();
    _description.dispose();
    _price.dispose();
    _salePrice.dispose();
    _sku.dispose();
    _material.dispose();
    _images.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.productId != null;
    return Scaffold(
      backgroundColor: AppTheme.lightGrey,
      appBar: AppBar(title: Text(isEdit ? 'Editar producto' : 'Nuevo producto')),
      body: _categories.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(labelText: 'Nombre'),
                      validator: (v) => (v == null || v.trim().length < 3) ? 'Minimo 3 caracteres' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _slug,
                      decoration: const InputDecoration(labelText: 'Slug'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _description,
                      decoration: const InputDecoration(labelText: 'Descripcion'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _price,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Precio (EUR)'),
                            validator: (v) {
                              final n = double.tryParse(v ?? '');
                              if (n == null || n <= 0) return 'Precio invalido';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _salePrice,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Precio oferta (EUR)'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _sku,
                            decoration: const InputDecoration(labelText: 'SKU'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _material,
                            decoration: const InputDecoration(labelText: 'Material'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _categoryId,
                      decoration: const InputDecoration(labelText: 'Categoria'),
                      items: _categories
                          .map(
                            (c) => DropdownMenuItem(
                              value: c['id'].toString(),
                              child: Text(c['name']?.toString() ?? '-'),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _categoryId = v),
                      validator: (v) => (v == null || v.isEmpty) ? 'Selecciona categoria' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _images,
                      decoration: const InputDecoration(
                        labelText: 'Imagenes (urls separadas por coma)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _isOnSale,
                      title: const Text('En oferta'),
                      onChanged: (v) => setState(() => _isOnSale = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _isActive,
                      title: const Text('Activo'),
                      onChanged: (v) => setState(() => _isActive = v),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Variantes de talla', style: Theme.of(context).textTheme.titleMedium),
                    ),
                    const SizedBox(height: 8),
                    ..._variants.asMap().entries.map((entry) {
                      final i = entry.key;
                      final v = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                initialValue: v['size']?.toString() ?? '',
                                decoration: const InputDecoration(labelText: 'Talla'),
                                onChanged: (val) => _variants[i]['size'] = val,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                initialValue: (v['stock'] as int).toString(),
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Stock'),
                                onChanged: (val) => _variants[i]['stock'] = int.tryParse(val) ?? 0,
                              ),
                            ),
                            IconButton(
                              onPressed: _variants.length == 1
                                  ? null
                                  : () => setState(() => _variants.removeAt(i)),
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                          ],
                        ),
                      );
                    }),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => setState(
                          () => _variants.add({'size': '', 'stock': 0, 'sku_variant': ''}),
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('Agregar talla'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _save,
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(isEdit ? 'Guardar cambios' : 'Crear producto'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final sale = double.tryParse(_salePrice.text.trim());
    final price = double.parse(_price.text.trim());
    if (_isOnSale && (sale == null || sale <= 0 || sale > price)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El precio oferta debe ser > 0 y <= precio base')),
      );
      return;
    }
    final duplicateSizes = <String>{};
    final seen = <String>{};
    for (final v in _variants) {
      final s = (v['size']?.toString().trim().toUpperCase() ?? '');
      if (s.isEmpty) continue;
      if (!seen.add(s)) duplicateSizes.add(s);
    }
    if (duplicateSizes.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tallas duplicadas: ${duplicateSizes.join(', ')}')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final payload = {
        'name': _name.text.trim(),
        'slug': _slug.text.trim(),
        'description': _description.text.trim().isEmpty ? null : _description.text.trim(),
        'price': (price * 100).round(),
        'sale_price': _isOnSale && sale != null ? (sale * 100).round() : null,
        'is_on_sale': _isOnSale,
        'sku': _sku.text.trim().isEmpty ? null : _sku.text.trim(),
        'material': _material.text.trim().isEmpty ? null : _material.text.trim(),
        'category_id': _categoryId,
        'images': _images.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        'is_active': _isActive,
      };
      final cleanedVariants = _variants
          .map(
            (v) => {
              'size': v['size']?.toString().trim().toUpperCase(),
              'stock': (v['stock'] as num?)?.toInt() ?? 0,
              'sku_variant': null,
            },
          )
          .where((v) => (v['size'] as String).isNotEmpty)
          .toList();

      await ref.read(adminRepositoryProvider).saveProduct(
            productId: widget.productId,
            productData: payload,
            variants: cleanedVariants,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.productId == null ? 'Producto creado' : 'Producto actualizado')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

