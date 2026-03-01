import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/design_system/widgets/aurum_app_bar_title.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/admin_provider.dart';
import '../../../../core/design_system/widgets/aurum_loader.dart';

class AdminProductFormScreen extends ConsumerStatefulWidget {
  const AdminProductFormScreen({super.key, this.productId});

  final String? productId;

  @override
  ConsumerState<AdminProductFormScreen> createState() =>
      _AdminProductFormScreenState();
}

class _ProductImageItem {
  _ProductImageItem.remote(this.url) : localFile = null, bytes = null;

  _ProductImageItem.local(this.localFile, this.bytes) : url = null;

  final String? url;
  final XFile? localFile;
  final Uint8List? bytes;

  bool get isLocal => localFile != null;
}

class _AdminProductFormScreenState
    extends ConsumerState<AdminProductFormScreen> {
  static const _maxImages = 6;

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  final _salePrice = TextEditingController();
  final _material = TextEditingController();
  final _picker = ImagePicker();

  bool _isOnSale = false;
  bool _isActive = true;
  String? _categoryId;
  bool _isSaving = false;
  bool _isLoading = true;
  String? _loadError;
  String? _currentSlug;
  String? _currentSku;

  List<Map<String, dynamic>> _variants = [
    {'size': 'M', 'stock': 0, 'sku_variant': ''},
  ];
  List<Map<String, dynamic>> _categories = const [];
  List<_ProductImageItem> _imageItems = <_ProductImageItem>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final repo = ref.read(adminRepositoryProvider);
      _categories = await repo.getCategories();

      if (widget.productId != null) {
        final product = await repo.getProductById(widget.productId!);
        _name.text = product['name']?.toString() ?? '';
        _description.text = product['description']?.toString() ?? '';
        _material.text = product['material']?.toString() ?? '';
        _price.text = (((product['price'] as num?)?.toInt() ?? 0) / 100)
            .toStringAsFixed(2);
        _salePrice.text =
            (((product['sale_price'] as num?)?.toInt() ?? 0) / 100)
                .toStringAsFixed(2);
        _isOnSale = product['is_on_sale'] == true;
        _isActive = product['is_active'] != false;
        _categoryId = product['category_id']?.toString();
        _currentSlug = product['slug']?.toString();
        _currentSku = product['sku']?.toString();

        final rawImages = (product['images'] as List?) ?? const [];
        _imageItems = rawImages
            .map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .map((url) => _ProductImageItem.remote(url))
            .toList();

        _variants = (((product['product_variants'] as List?) ?? const [])).map((
          e,
        ) {
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
    } catch (e) {
      _loadError = e.toString();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    _salePrice.dispose();
    _material.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.productId != null;
    return Scaffold(
      backgroundColor: AppTheme.lightGrey,
      appBar: AppBar(
        title: AurumAppBarTitle(isEdit ? 'Editar producto' : 'Nuevo producto'),
      ),
      body: _isLoading
          ? const AurumCenteredLoader()
          : _loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('No se pudo cargar el formulario'),
                    const SizedBox(height: 8),
                    Text(
                      _loadError!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _load,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            )
          : _categories.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'No hay categorias disponibles. Crea una categoria primero.',
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () async {
                        await context.push('/admin/categories');
                        if (!mounted) return;
                        await _load();
                      },
                      icon: const Icon(Icons.category_outlined),
                      label: const Text('Ir a categorias'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _load,
                      child: const Text('Actualizar'),
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(labelText: 'Nombre'),
                      validator: (v) => (v == null || v.trim().length < 3)
                          ? 'Minimo 3 caracteres'
                          : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _description,
                      decoration: const InputDecoration(
                        labelText: 'Descripcion',
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _price,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Precio (EUR)',
                            ),
                            validator: (v) {
                              final n = double.tryParse(v ?? '');
                              if (n == null || n <= 0) {
                                return 'Precio invalido';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _salePrice,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Precio oferta (EUR)',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _material,
                      decoration: const InputDecoration(labelText: 'Material'),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _categoryId,
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
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Selecciona categoria'
                          : null,
                    ),
                    const SizedBox(height: 8),
                    _buildImageSection(context),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: const Text(
                        'Slug y SKU se generan automaticamente al guardar.',
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
                      child: Text(
                        'Variantes de talla',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
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
                                decoration: const InputDecoration(
                                  labelText: 'Talla',
                                ),
                                onChanged: (val) => _variants[i]['size'] = val,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                initialValue: (v['stock'] as int).toString(),
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Stock',
                                ),
                                onChanged: (val) => _variants[i]['stock'] =
                                    int.tryParse(val) ?? 0,
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
                          () => _variants.add({
                            'size': '',
                            'stock': 0,
                            'sku_variant': '',
                          }),
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
                                child: AurumLoader(strokeWidth: 2),
                              )
                            : Text(
                                isEdit ? 'Guardar cambios' : 'Crear producto',
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildImageSection(BuildContext context) {
    final remaining = _maxImages - _imageItems.length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Imagenes del producto (${_imageItems.length}/$_maxImages)',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: (_isSaving || remaining <= 0)
                    ? null
                    : _pickFromGallery,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Galeria'),
              ),
              OutlinedButton.icon(
                onPressed: (_isSaving || remaining <= 0)
                    ? null
                    : _pickFromCamera,
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Camara'),
              ),
            ],
          ),
          if (_imageItems.isNotEmpty) ...[
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth < 360 ? 2 : 3;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _imageItems.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 0.72,
                  ),
                  itemBuilder: (context, index) {
                    final item = _imageItems[index];
                    return Column(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: item.isLocal
                                ? Image.memory(
                                    item.bytes!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                  )
                                : Image.network(
                                    item.url!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                  ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _ThumbActionButton(
                              icon: Icons.chevron_left,
                              onPressed: index == 0
                                  ? null
                                  : () => setState(() {
                                      final cur = _imageItems.removeAt(index);
                                      _imageItems.insert(index - 1, cur);
                                    }),
                            ),
                            _ThumbActionButton(
                              icon: Icons.delete_outline,
                              onPressed: () =>
                                  setState(() => _imageItems.removeAt(index)),
                            ),
                            _ThumbActionButton(
                              icon: Icons.chevron_right,
                              onPressed: index == _imageItems.length - 1
                                  ? null
                                  : () => setState(() {
                                      final cur = _imageItems.removeAt(index);
                                      _imageItems.insert(index + 1, cur);
                                    }),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 6),
            const Text('La primera imagen sera la portada del producto.'),
          ],
        ],
      ),
    );
  }

  Future<void> _pickFromGallery() async {
    final remaining = _maxImages - _imageItems.length;
    if (remaining <= 0) return;
    try {
      final picked = await _picker.pickMultiImage(imageQuality: 85);
      if (picked.isEmpty) return;
      final selected = picked.take(remaining).toList();
      final toAdd = <_ProductImageItem>[];
      for (final file in selected) {
        final bytes = await file.readAsBytes();
        toAdd.add(_ProductImageItem.local(file, bytes));
      }
      setState(() => _imageItems.addAll(toAdd));
      if (picked.length > remaining && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Solo puedes subir hasta $_maxImages imagenes'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir la galeria: $e')),
      );
    }
  }

  Future<void> _pickFromCamera() async {
    final remaining = _maxImages - _imageItems.length;
    if (remaining <= 0) return;
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      setState(() => _imageItems.add(_ProductImageItem.local(picked, bytes)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo abrir la camara: $e')));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final sale = double.tryParse(_salePrice.text.trim());
    final price = double.parse(_price.text.trim());

    if (_isOnSale && (sale == null || sale <= 0 || sale > price)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El precio oferta debe ser > 0 y <= precio base'),
        ),
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
        SnackBar(
          content: Text('Tallas duplicadas: ${duplicateSizes.join(', ')}'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final repo = ref.read(adminRepositoryProvider);
      final productId = widget.productId;

      final slugToSave =
          (_currentSlug != null && _currentSlug!.trim().isNotEmpty)
          ? _currentSlug!.trim()
          : await repo.generateUniqueSlug(
              _name.text.trim(),
              currentProductId: productId,
            );

      final skuToSave = (_currentSku != null && _currentSku!.trim().isNotEmpty)
          ? _currentSku!.trim()
          : await repo.generateUniqueSku();

      final corePayload = {
        'name': _name.text.trim(),
        'slug': slugToSave,
        'description': _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
        'price': (price * 100).round(),
        'sale_price': _isOnSale && sale != null ? (sale * 100).round() : null,
        'is_on_sale': _isOnSale,
        'sku': skuToSave,
        'material': _material.text.trim().isEmpty
            ? null
            : _material.text.trim(),
        'category_id': _categoryId,
        'is_active': _isActive,
      };

      late final String id;
      if (productId == null) {
        id = await repo.createProductBase({
          ...corePayload,
          'images': <String>[],
        });
      } else {
        await repo.updateProductCore(productId, corePayload);
        id = productId;
      }

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

      await repo.upsertProductVariantsAndStock(
        productId: id,
        variants: cleanedVariants,
      );

      final localFiles = _imageItems
          .where((e) => e.isLocal)
          .map((e) => e.localFile!)
          .toList();

      final uploadedUrls = await repo.uploadProductImages(
        productId: id,
        files: localFiles,
      );

      var localIdx = 0;
      final finalImageUrls = <String>[];
      for (final item in _imageItems) {
        if (item.url != null && item.url!.trim().isNotEmpty) {
          finalImageUrls.add(item.url!.trim());
          continue;
        }
        if (item.localFile != null && localIdx < uploadedUrls.length) {
          finalImageUrls.add(uploadedUrls[localIdx]);
          localIdx += 1;
        }
      }

      await repo.saveProductImages(productId: id, imageUrls: finalImageUrls);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.productId == null
                ? 'Producto creado'
                : 'Producto actualizado',
          ),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class _ThumbActionButton extends StatelessWidget {
  const _ThumbActionButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 28, height: 28),
      padding: EdgeInsets.zero,
      iconSize: 18,
      onPressed: onPressed,
      icon: Icon(icon),
    );
  }
}
