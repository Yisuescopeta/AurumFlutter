import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/widgets/aurum_card.dart';
import '../providers/admin_provider.dart';

class AdminEmailsScreen extends ConsumerStatefulWidget {
  const AdminEmailsScreen({super.key});

  @override
  ConsumerState<AdminEmailsScreen> createState() => _AdminEmailsScreenState();
}

class _AdminEmailsScreenState extends ConsumerState<AdminEmailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _subject = TextEditingController();
  final _message = TextEditingController();
  final _couponCode = TextEditingController();
  final _couponValue = TextEditingController();
  bool _sending = false;
  bool _includeCoupon = false;
  String _couponMode = 'generic';
  String _couponType = 'percent';
  DateTime? _couponExpiration;

  @override
  void dispose() {
    _title.dispose();
    _subject.dispose();
    _message.dispose();
    _couponCode.dispose();
    _couponValue.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Correos', style: Theme.of(context).textTheme.displayMedium),
        const SizedBox(height: 12),
        AurumCard(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'Titulo de cabecera'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _subject,
                  decoration: const InputDecoration(labelText: 'Asunto'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _message,
                  decoration: const InputDecoration(labelText: 'Mensaje'),
                  maxLines: 8,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: _includeCoupon,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Incluir cupon'),
                  onChanged: (v) => setState(() => _includeCoupon = v),
                ),
                if (_includeCoupon) ...[
                  DropdownButtonFormField<String>(
                    initialValue: _couponMode,
                    decoration: const InputDecoration(labelText: 'Modo cupon'),
                    items: const [
                      DropdownMenuItem(value: 'generic', child: Text('Generico')),
                      DropdownMenuItem(value: 'unique', child: Text('Unico por usuario')),
                    ],
                    onChanged: (v) => setState(() => _couponMode = v ?? 'generic'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _couponType,
                    decoration: const InputDecoration(labelText: 'Tipo descuento'),
                    items: const [
                      DropdownMenuItem(value: 'percent', child: Text('Porcentaje')),
                      DropdownMenuItem(value: 'fixed', child: Text('Fijo (EUR)')),
                    ],
                    onChanged: (v) => setState(() => _couponType = v ?? 'percent'),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _couponValue,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Valor descuento'),
                    validator: (v) {
                      if (!_includeCoupon) return null;
                      final n = num.tryParse(v ?? '');
                      if (n == null || n <= 0) return 'Valor invalido';
                      if (_couponType == 'percent' && n > 100) return 'Maximo 100';
                      return null;
                    },
                  ),
                  if (_couponMode == 'generic') ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _couponCode,
                      decoration: const InputDecoration(labelText: 'Codigo cupon (opcional)'),
                    ),
                  ],
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Expiracion'),
                    subtitle: Text(_couponExpiration == null
                        ? 'Sin expiracion'
                        : '${_couponExpiration!.day}/${_couponExpiration!.month}/${_couponExpiration!.year}'),
                    trailing: TextButton(
                      onPressed: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _couponExpiration ?? now,
                          firstDate: now.subtract(const Duration(days: 1)),
                          lastDate: now.add(const Duration(days: 3650)),
                        );
                        if (picked != null) {
                          setState(() => _couponExpiration = picked);
                        }
                      },
                      child: const Text('Elegir'),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _sending ? null : _sendCampaign,
                    icon: _sending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_outlined),
                    label: Text(_sending ? 'Enviando...' : 'Enviar campana'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _sendCampaign() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);
    try {
      final payload = {
        'title': _title.text.trim(),
        'subject': _subject.text.trim(),
        'message': _message.text.trim(),
        'include_coupon': _includeCoupon,
        'coupon_mode': _couponMode,
        'coupon_type': _couponType,
        'coupon_value': _includeCoupon ? num.parse(_couponValue.text.trim()) : null,
        'coupon_code': _couponMode == 'generic' ? _couponCode.text.trim().toUpperCase() : null,
        'coupon_expiration': _couponExpiration?.toIso8601String(),
      };

      final result = await ref.read(adminRepositoryProvider).sendBroadcastCampaign(payload);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'campana enviada. ${result['sent'] ?? 0}/${result['total_recipients'] ?? 0} correos enviados.',
          ),
        ),
      );
      _formKey.currentState?.reset();
      _title.clear();
      _subject.clear();
      _message.clear();
      _couponCode.clear();
      _couponValue.clear();
      setState(() {
        _includeCoupon = false;
        _couponMode = 'generic';
        _couponType = 'percent';
        _couponExpiration = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error enviando campana: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}

