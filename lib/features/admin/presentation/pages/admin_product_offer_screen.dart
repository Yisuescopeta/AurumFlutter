import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/widgets/aurum_app_bar_title.dart';
import '../../../../core/design_system/widgets/aurum_card.dart';
import '../../../../core/design_system/widgets/aurum_loader.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../providers/admin_provider.dart';

class AdminProductOfferScreen extends ConsumerStatefulWidget {
  const AdminProductOfferScreen({super.key, required this.productId});

  final String productId;

  @override
  ConsumerState<AdminProductOfferScreen> createState() =>
      _AdminProductOfferScreenState();
}

class _AdminProductOfferScreenState
    extends ConsumerState<AdminProductOfferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _salePriceController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _loadError;
  String _productName = '-';
  String _productSku = '-';
  int _basePriceCents = 0;
  bool _isOnSale = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _salePriceController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final repo = ref.read(adminRepositoryProvider);
      final product = await repo.getProductById(widget.productId);

      final salePriceCents = (product['sale_price'] as num?)?.toInt();
      setState(() {
        _productName = product['name']?.toString() ?? '-';
        _productSku = product['sku']?.toString() ?? '-';
        _basePriceCents = (product['price'] as num?)?.toInt() ?? 0;
        _isOnSale = product['is_on_sale'] == true;
        _salePriceController.text = salePriceCents == null
            ? ''
            : (salePriceCents / 100).toStringAsFixed(2);
      });
    } catch (e) {
      setState(() => _loadError = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int? _parseCents(String raw) {
    final normalized = raw.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    final value = double.tryParse(normalized);
    if (value == null) return null;
    return (value * 100).round();
  }

  String? _saleValidationMessage() {
    if (!_isOnSale) return null;
    final saleCents = _parseCents(_salePriceController.text);
    if (saleCents == null || saleCents <= 0 || saleCents > _basePriceCents) {
      return 'El precio oferta debe ser > 0 y <= precio base';
    }
    return null;
  }

  int? _discountPercent() {
    final saleCents = _parseCents(_salePriceController.text);
    if (!_isOnSale || saleCents == null || _basePriceCents <= 0) return null;
    if (saleCents >= _basePriceCents) return 0;
    final fraction = 1 - (saleCents / _basePriceCents);
    return (fraction * 100).round();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    final validationMessage = _saleValidationMessage();
    if (validationMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validationMessage)));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final repo = ref.read(adminRepositoryProvider);
      final saleCents = _parseCents(_salePriceController.text);
      await repo.updateProductCore(widget.productId, {
        'is_on_sale': _isOnSale,
        'sale_price': _isOnSale ? saleCents : null,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Oferta actualizada')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AurumAppBarTitle('Oferta')),
      backgroundColor: AppTheme.lightGrey,
      body: _isLoading
          ? const AurumCenteredLoader()
          : _loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'No se pudo cargar el producto: $_loadError',
                      textAlign: TextAlign.center,
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
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  AurumCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _productName,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'SKU: $_productSku',
                          style: const TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Precio base: ${Formatters.euro(_basePriceCents / 100)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.navyBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  AurumCard(
                    child: Column(
                      children: [
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: _isOnSale,
                          title: const Text('En oferta'),
                          subtitle: const Text('Activa o desactiva la oferta'),
                          onChanged: _isSaving
                              ? null
                              : (value) => setState(() => _isOnSale = value),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _salePriceController,
                          enabled: _isOnSale && !_isSaving,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Precio oferta (EUR)',
                            hintText: 'Ej: 39.99',
                          ),
                          validator: (_) => _saleValidationMessage(),
                        ),
                        if (_isOnSale) ...[
                          const SizedBox(height: 10),
                          Builder(
                            builder: (context) {
                              final discount = _discountPercent();
                              if (discount == null) {
                                return const SizedBox.shrink();
                              }
                              return Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.gold.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Descuento aplicado: $discount%',
                                  style: const TextStyle(
                                    color: AppTheme.navyBlue,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _save,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: AurumLoader(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        _isSaving ? 'Guardando...' : 'Guardar oferta',
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
