import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/widgets/aurum_card.dart';
import '../providers/admin_provider.dart';
import '../../../../core/design_system/widgets/aurum_loader.dart';

class AdminNotificationsScreen extends ConsumerStatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  ConsumerState<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState
    extends ConsumerState<AdminNotificationsScreen> {
  final _broadcastFormKey = GlobalKey<FormState>();
  final _templateFormKey = GlobalKey<FormState>();
  final _broadcastTitle = TextEditingController();
  final _broadcastBody = TextEditingController();
  final _templateTitle = TextEditingController();
  final _templateBody = TextEditingController();

  bool _sendingBroadcast = false;
  bool _savingTemplate = false;
  bool _templateLoaded = false;
  bool _broadcastOptionsLoaded = false;
  bool _includeAdmins = true;
  String _selectedCouponId = '';
  String _selectedProductId = '';
  List<Map<String, dynamic>> _availableCoupons = const [];
  List<Map<String, dynamic>> _availableProducts = const [];

  String _friendlyError(Object error) {
    final raw = error.toString().trim();
    if (raw.startsWith('Exception:')) {
      return raw.substring('Exception:'.length).trim();
    }
    return raw;
  }

  @override
  void initState() {
    super.initState();
    _loadTemplate();
    _loadBroadcastOptions();
  }

  @override
  void dispose() {
    _broadcastTitle.dispose();
    _broadcastBody.dispose();
    _templateTitle.dispose();
    _templateBody.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedCoupon = _findById(_availableCoupons, _selectedCouponId);
    final selectedProduct = _findById(_availableProducts, _selectedProductId);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Notificaciones',
          style: Theme.of(context).textTheme.displayMedium,
        ),
        const SizedBox(height: 12),
        AurumCard(
          child: Form(
            key: _broadcastFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Envio masivo personalizado',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _broadcastTitle,
                  decoration: const InputDecoration(labelText: 'Titulo'),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Requerido'
                      : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _broadcastBody,
                  decoration: const InputDecoration(labelText: 'Mensaje'),
                  maxLines: 6,
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Requerido'
                      : null,
                ),
                const SizedBox(height: 8),
                if (!_broadcastOptionsLoaded)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(),
                  ),
                DropdownButtonFormField<String>(
                  key: ValueKey(
                    'coupon-$_selectedCouponId-${_availableCoupons.length}',
                  ),
                  initialValue:
                      _availableCoupons.any(
                        (c) => c['id']?.toString() == _selectedCouponId,
                      )
                      ? _selectedCouponId
                      : '',
                  decoration: const InputDecoration(
                    labelText: 'Cupon (opcional)',
                  ),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem(value: '', child: Text('Sin cupon')),
                    ..._availableCoupons.map(
                      (c) => DropdownMenuItem(
                        value: c['id']?.toString() ?? '',
                        child: Text(_couponLabel(c)),
                      ),
                    ),
                  ],
                  onChanged: (_sendingBroadcast || !_broadcastOptionsLoaded)
                      ? null
                      : (value) => setState(
                          () => _selectedCouponId = (value ?? '').trim(),
                        ),
                ),
                if (selectedCoupon != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Cupon seleccionado: ${selectedCoupon['code'] ?? ''}',
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ),
                      TextButton(
                        onPressed: _sendingBroadcast
                            ? null
                            : () => _insertCouponIntoMessage(selectedCoupon),
                        child: const Text('Insertar en mensaje'),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  key: ValueKey(
                    'product-$_selectedProductId-${_availableProducts.length}',
                  ),
                  initialValue:
                      _availableProducts.any(
                        (p) => p['id']?.toString() == _selectedProductId,
                      )
                      ? _selectedProductId
                      : '',
                  decoration: const InputDecoration(
                    labelText: 'Producto (opcional)',
                  ),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('Sin producto'),
                    ),
                    ..._availableProducts.map(
                      (p) => DropdownMenuItem(
                        value: p['id']?.toString() ?? '',
                        child: Text(_productLabel(p)),
                      ),
                    ),
                  ],
                  onChanged: (_sendingBroadcast || !_broadcastOptionsLoaded)
                      ? null
                      : (value) => setState(
                          () => _selectedProductId = (value ?? '').trim(),
                        ),
                ),
                if (selectedProduct != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Producto seleccionado: ${selectedProduct['name'] ?? ''}',
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ),
                      TextButton(
                        onPressed: _sendingBroadcast
                            ? null
                            : () => _insertProductIntoMessage(selectedProduct),
                        child: const Text('Insertar en mensaje'),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _includeAdmins,
                  onChanged: _sendingBroadcast
                      ? null
                      : (value) => setState(() => _includeAdmins = value),
                  title: const Text('Incluir admins'),
                  subtitle: const Text(
                    'Permite validar notificaciones sin cambiar de cuenta',
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _sendingBroadcast ? null : _sendBroadcast,
                    icon: _sendingBroadcast
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: AurumLoader(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_outlined),
                    label: Text(
                      _sendingBroadcast ? 'Enviando...' : 'Enviar notificacion',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        AurumCard(
          child: Form(
            key: _templateFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Plantilla favoritos en descuento',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Variables disponibles: {{product_name}}, {{sale_price}}, {{old_price}}',
                ),
                const SizedBox(height: 10),
                if (!_templateLoaded)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(),
                  ),
                TextFormField(
                  controller: _templateTitle,
                  decoration: const InputDecoration(
                    labelText: 'Titulo plantilla',
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Requerido'
                      : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _templateBody,
                  decoration: const InputDecoration(
                    labelText: 'Mensaje plantilla',
                  ),
                  maxLines: 5,
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Requerido'
                      : null,
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (_savingTemplate || !_templateLoaded)
                        ? null
                        : _saveTemplate,
                    icon: _savingTemplate
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: AurumLoader(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      _savingTemplate ? 'Guardando...' : 'Guardar plantilla',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Map<String, dynamic>? _findById(List<Map<String, dynamic>> rows, String? id) {
    final value = (id ?? '').trim();
    if (value.isEmpty) return null;
    for (final row in rows) {
      if (row['id']?.toString() == value) return row;
    }
    return null;
  }

  String _couponLabel(Map<String, dynamic> coupon) {
    final code = coupon['code']?.toString() ?? '-';
    final type = coupon['discount_type']?.toString() ?? '';
    final value = coupon['discount_value'];
    final numericValue = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '');
    if (numericValue == null) return code;
    if (type == 'fixed') {
      return '$code (${numericValue.toStringAsFixed(2)} EUR)';
    }
    final display = numericValue % 1 == 0
        ? numericValue.toStringAsFixed(0)
        : numericValue.toStringAsFixed(2);
    return '$code ($display%)';
  }

  String _productLabel(Map<String, dynamic> product) {
    final name = product['name']?.toString() ?? 'Producto';
    final sku = product['sku']?.toString().trim() ?? '';
    if (sku.isEmpty) return name;
    return '$name ($sku)';
  }

  void _insertCouponIntoMessage(Map<String, dynamic> coupon) {
    final code = coupon['code']?.toString().trim() ?? '';
    if (code.isEmpty) return;
    final current = _broadcastBody.text.trim();
    final line = 'Cupon: $code';
    if (current.contains(line)) return;
    _broadcastBody.text = current.isEmpty ? line : '$current\n$line';
    _broadcastBody.selection = TextSelection.fromPosition(
      TextPosition(offset: _broadcastBody.text.length),
    );
  }

  void _insertProductIntoMessage(Map<String, dynamic> product) {
    final name = product['name']?.toString().trim() ?? '';
    if (name.isEmpty) return;
    final current = _broadcastBody.text.trim();
    final line = 'Producto: $name';
    if (current.contains(line)) return;
    _broadcastBody.text = current.isEmpty ? line : '$current\n$line';
    _broadcastBody.selection = TextSelection.fromPosition(
      TextPosition(offset: _broadcastBody.text.length),
    );
  }

  Future<void> _loadBroadcastOptions() async {
    try {
      final repo = ref.read(adminRepositoryProvider);
      final coupons = await repo.getCoupons();
      final productResult = await repo.getProducts(statusFilter: 'active');
      final products = [...productResult.products]
        ..sort(
          (a, b) => (a['name']?.toString() ?? '').toLowerCase().compareTo(
            (b['name']?.toString() ?? '').toLowerCase(),
          ),
        );

      if (!mounted) return;
      setState(() {
        _availableCoupons = coupons;
        _availableProducts = products;
        _broadcastOptionsLoaded = true;
        if (!_availableCoupons.any(
          (c) => c['id']?.toString() == _selectedCouponId,
        )) {
          _selectedCouponId = '';
        }
        if (!_availableProducts.any(
          (p) => p['id']?.toString() == _selectedProductId,
        )) {
          _selectedProductId = '';
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _broadcastOptionsLoaded = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudieron cargar cupones/productos: ${_friendlyError(error)}',
          ),
        ),
      );
    }
  }

  Future<void> _loadTemplate() async {
    try {
      final data = await ref
          .read(adminRepositoryProvider)
          .getFavoriteDiscountTemplate();
      if (!mounted) return;
      _templateTitle.text = data['title'] ?? '';
      _templateBody.text = data['body'] ?? '';
      setState(() => _templateLoaded = true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _templateLoaded = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo cargar la plantilla: ${_friendlyError(error)}',
          ),
        ),
      );
    }
  }

  Future<void> _sendBroadcast() async {
    if (!_broadcastFormKey.currentState!.validate()) return;

    final selectedCoupon = _findById(_availableCoupons, _selectedCouponId);
    final selectedProduct = _findById(_availableProducts, _selectedProductId);
    var body = _broadcastBody.text.trim();
    if (selectedCoupon != null) {
      final code = selectedCoupon['code']?.toString().trim() ?? '';
      final line = 'Cupon: $code';
      if (code.isNotEmpty && !body.contains(line)) {
        body = body.isEmpty ? line : '$body\n$line';
      }
    }
    if (selectedProduct != null) {
      final name = selectedProduct['name']?.toString().trim() ?? '';
      final line = 'Producto: $name';
      if (name.isNotEmpty && !body.contains(line)) {
        body = body.isEmpty ? line : '$body\n$line';
      }
    }

    setState(() => _sendingBroadcast = true);
    try {
      final result = await ref
          .read(adminRepositoryProvider)
          .sendBroadcastNotification({
            'title': _broadcastTitle.text.trim(),
            'body': body,
            'route': selectedProduct != null
                ? '/product-detail'
                : '/notifications',
            'product_id': selectedProduct?['id']?.toString(),
            'coupon_id': selectedCoupon?['id']?.toString(),
            'coupon_code': selectedCoupon?['code']?.toString(),
            'include_admins': _includeAdmins,
          });
      if (!mounted) return;
      final sent = (result['sent'] as num?)?.toInt() ?? 0;
      final total = (result['total_recipients'] as num?)?.toInt() ?? 0;
      final skipped = (result['skipped'] as num?)?.toInt() ?? 0;
      final duplicates = (result['duplicates'] as num?)?.toInt() ?? 0;
      final failed = (result['failed'] as num?)?.toInt() ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            total == 0
                ? 'No hay destinatarios para esta campana (0 usuarios).'
                : 'Notificacion enviada. $sent/$total entregadas. Omitidas: $skipped, duplicadas: $duplicates, fallidas: $failed.',
          ),
        ),
      );
      _broadcastTitle.clear();
      _broadcastBody.clear();
      setState(() {
        _selectedCouponId = '';
        _selectedProductId = '';
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error enviando notificacion: ${_friendlyError(error)}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _sendingBroadcast = false);
    }
  }

  Future<void> _saveTemplate() async {
    if (!_templateFormKey.currentState!.validate()) return;
    setState(() => _savingTemplate = true);
    try {
      await ref
          .read(adminRepositoryProvider)
          .saveFavoriteDiscountTemplate(
            titleTemplate: _templateTitle.text,
            bodyTemplate: _templateBody.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Plantilla guardada')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error guardando plantilla: ${_friendlyError(error)}'),
        ),
      );
    } finally {
      if (mounted) setState(() => _savingTemplate = false);
    }
  }
}
