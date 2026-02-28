import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/widgets/aurum_card.dart';
import '../../../../core/utils/formatters.dart';
import '../providers/admin_provider.dart';

class AdminCouponsScreen extends ConsumerStatefulWidget {
  const AdminCouponsScreen({super.key});

  @override
  ConsumerState<AdminCouponsScreen> createState() => _AdminCouponsScreenState();
}

class _AdminCouponsScreenState extends ConsumerState<AdminCouponsScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(adminRepositoryProvider);
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: repo.getCoupons(query: _query),
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
                  Text('Error cargando cupones: ${snapshot.error}'),
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
        final coupons = snapshot.data ?? const <Map<String, dynamic>>[];
        final itemCount = coupons.isEmpty ? 3 : coupons.length + 3;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: itemCount,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Row(
                children: [
                  Expanded(
                    child: Text(
                      'Cupones',
                      style: Theme.of(context).textTheme.displayMedium,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _openCouponForm(),
                    icon: const Icon(Icons.add),
                    label: const Text('Nuevo'),
                  ),
                ],
              );
            }

            if (index == 1) {
              return const SizedBox(height: 12);
            }

            if (index == 2) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AurumCard(
                  child: TextField(
                    controller: _search,
                    decoration: const InputDecoration(
                      hintText: 'Buscar por codigo',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) => setState(() => _query = v.trim()),
                  ),
                ),
              );
            }

            if (coupons.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: Text('No hay cupones creados')),
              );
            }

            final c = coupons[index - 3];
            final expRaw = c['expiration_date']?.toString();
            final exp = expRaw == null ? null : DateTime.tryParse(expRaw);
            final isPercent = c['discount_type'] == 'percent';
            final value = c['discount_value']?.toString() ?? '0';
            final label = isPercent ? '-$value%' : '-EUR$value';

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AurumCard(
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(c['code']?.toString() ?? '-'),
                      subtitle: Text(
                        '$label  -  ${c['is_single_use'] == true ? 'Unico' : 'Multiuso'}  -  '
                        'limite: ${c['usage_limit'] ?? '-'}  -  min: ${c['min_purchase_amount'] ?? 0}',
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(c['is_active'] == true ? 'Activo' : 'Inactivo'),
                          Text(
                            exp == null ? 'Sin expiracion' : Formatters.date(exp),
                            style: const TextStyle(fontSize: 12),
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
                          onPressed: () => _openCouponForm(coupon: c),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Editar'),
                        ),
                        TextButton.icon(
                          onPressed: () => _toggleActive(c),
                          icon: Icon(c['is_active'] == true ? Icons.toggle_on : Icons.toggle_off),
                          label: Text(c['is_active'] == true ? 'Desactivar' : 'Activar'),
                        ),
                        TextButton.icon(
                          onPressed: () => _deleteCoupon(c['id']?.toString() ?? ''),
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          label: const Text('Borrar', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _toggleActive(Map<String, dynamic> coupon) async {
    final id = coupon['id']?.toString() ?? '';
    if (id.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cupon invalido: falta id')),
      );
      return;
    }

    try {
      await ref.read(adminRepositoryProvider).updateCoupon(
            id,
            {'is_active': coupon['is_active'] != true},
          );
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _deleteCoupon(String id) async {
    if (id.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cupon invalido: falta id')),
      );
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Borrar cupon'),
        content: const Text('Esta accion no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Borrar')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref.read(adminRepositoryProvider).deleteCoupon(id);
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _openCouponForm({Map<String, dynamic>? coupon}) async {
    final formKey = GlobalKey<FormState>();
    final code = TextEditingController(text: coupon?['code']?.toString() ?? '');
    final value = TextEditingController(text: coupon?['discount_value']?.toString() ?? '');
    final minPurchase = TextEditingController(text: coupon?['min_purchase_amount']?.toString() ?? '0');
    final usageLimit = TextEditingController(text: coupon?['usage_limit']?.toString() ?? '');
    String type = coupon?['discount_type']?.toString() ?? 'percent';
    bool singleUse = coupon?['is_single_use'] == true;
    bool active = coupon?['is_active'] != false;
    DateTime? expiration = coupon?['expiration_date'] != null
        ? DateTime.tryParse(coupon!['expiration_date'].toString())
        : null;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModal) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(coupon == null ? 'Nuevo cupon' : 'Editar cupon', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: code,
                      decoration: const InputDecoration(labelText: 'Codigo'),
                      enabled: coupon == null,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: type,
                      decoration: const InputDecoration(labelText: 'Tipo descuento'),
                      items: const [
                        DropdownMenuItem(value: 'percent', child: Text('Porcentaje')),
                        DropdownMenuItem(value: 'fixed', child: Text('Fijo (EUR)')),
                      ],
                      onChanged: (v) => setModal(() => type = v ?? 'percent'),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: value,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Valor'),
                      validator: (v) {
                        final n = num.tryParse(v ?? '');
                        if (n == null || n <= 0) return 'Valor invalido';
                        if (type == 'percent' && n > 100) return 'Maximo 100%';
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: minPurchase,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Compra minima (EUR)'),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: usageLimit,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Limite de uso (opcional)'),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: singleUse,
                      title: const Text('Uso unico por usuario'),
                      onChanged: (v) => setModal(() => singleUse = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: active,
                      title: const Text('Activo'),
                      onChanged: (v) => setModal(() => active = v),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Expiracion'),
                      subtitle: Text(expiration == null ? 'Sin expiracion' : Formatters.date(expiration)),
                      trailing: TextButton(
                        onPressed: () async {
                          final now = DateTime.now();
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: expiration ?? now,
                            firstDate: now.subtract(const Duration(days: 1)),
                            lastDate: now.add(const Duration(days: 3650)),
                          );
                          if (picked != null) setModal(() => expiration = picked);
                        },
                        child: const Text('Elegir'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          final payload = {
                            'code': code.text.trim().toUpperCase(),
                            'discount_type': type,
                            'discount_value': num.parse(value.text.trim()),
                            'expiration_date': expiration?.toIso8601String(),
                            'usage_limit': usageLimit.text.trim().isEmpty ? null : int.parse(usageLimit.text.trim()),
                            'is_single_use': singleUse,
                            'min_purchase_amount': num.tryParse(minPurchase.text.trim()) ?? 0,
                            'is_active': active,
                          };
                          try {
                            if (coupon == null) {
                              await ref.read(adminRepositoryProvider).createCoupon(payload);
                            } else {
                              final id = coupon['id']?.toString() ?? '';
                              if (id.isEmpty) {
                                throw Exception('Cupon invalido: falta id');
                              }
                              await ref.read(adminRepositoryProvider).updateCoupon(id, payload);
                            }
                            if (!context.mounted) return;
                            Navigator.of(context).pop(true);
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error guardando cupon: $e')),
                            );
                          }
                        },
                        child: const Text('Guardar'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (saved == true && mounted) setState(() {});
  }
}
