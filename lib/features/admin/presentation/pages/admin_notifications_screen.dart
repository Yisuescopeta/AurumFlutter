import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/widgets/aurum_card.dart';
import '../providers/admin_provider.dart';

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

  @override
  void initState() {
    super.initState();
    _loadTemplate();
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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Notificaciones', style: Theme.of(context).textTheme.displayMedium),
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
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? 'Requerido' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _broadcastBody,
                  decoration: const InputDecoration(labelText: 'Mensaje'),
                  maxLines: 6,
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? 'Requerido' : null,
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
                            child: CircularProgressIndicator(strokeWidth: 2),
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
                  decoration: const InputDecoration(labelText: 'Titulo plantilla'),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? 'Requerido' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _templateBody,
                  decoration: const InputDecoration(labelText: 'Mensaje plantilla'),
                  maxLines: 5,
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? 'Requerido' : null,
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed:
                        (_savingTemplate || !_templateLoaded) ? null : _saveTemplate,
                    icon: _savingTemplate
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
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

  Future<void> _loadTemplate() async {
    try {
      final data =
          await ref.read(adminRepositoryProvider).getFavoriteDiscountTemplate();
      if (!mounted) return;
      _templateTitle.text = data['title'] ?? '';
      _templateBody.text = data['body'] ?? '';
      setState(() => _templateLoaded = true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _templateLoaded = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cargar la plantilla: $error')),
      );
    }
  }

  Future<void> _sendBroadcast() async {
    if (!_broadcastFormKey.currentState!.validate()) return;
    setState(() => _sendingBroadcast = true);
    try {
      final result = await ref.read(adminRepositoryProvider).sendBroadcastNotification(
        {
          'title': _broadcastTitle.text.trim(),
          'body': _broadcastBody.text.trim(),
          'route': '/notifications',
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Notificacion enviada. ${result['sent'] ?? 0}/${result['total_recipients'] ?? 0} entregadas.',
          ),
        ),
      );
      _broadcastTitle.clear();
      _broadcastBody.clear();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error enviando notificacion: $error')),
      );
    } finally {
      if (mounted) setState(() => _sendingBroadcast = false);
    }
  }

  Future<void> _saveTemplate() async {
    if (!_templateFormKey.currentState!.validate()) return;
    setState(() => _savingTemplate = true);
    try {
      await ref.read(adminRepositoryProvider).saveFavoriteDiscountTemplate(
            titleTemplate: _templateTitle.text,
            bodyTemplate: _templateBody.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plantilla guardada')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error guardando plantilla: $error')),
      );
    } finally {
      if (mounted) setState(() => _savingTemplate = false);
    }
  }
}
