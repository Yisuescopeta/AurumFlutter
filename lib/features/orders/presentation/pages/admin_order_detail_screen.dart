import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/design_system/widgets/aurum_app_bar_title.dart';
import '../../../../core/design_system/widgets/aurum_card.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../providers/orders_provider.dart';
import '../../../../core/design_system/widgets/aurum_loader.dart';

class AdminOrderDetailScreen extends ConsumerStatefulWidget {
  const AdminOrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<AdminOrderDetailScreen> createState() =>
      _AdminOrderDetailScreenState();
}

class _AdminOrderDetailScreenState
    extends ConsumerState<AdminOrderDetailScreen> {
  final _carrierController = TextEditingController();
  final _trackingController = TextEditingController();
  String _nextStatus = '';
  DateTime? _estimatedDelivery;

  @override
  void dispose() {
    _carrierController.dispose();
    _trackingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(orderDetailProvider(widget.orderId));

    return Scaffold(
      backgroundColor: AppTheme.lightGrey,
      appBar: AppBar(title: const AurumAppBarTitle('Gestionar pedido')),
      body: detailAsync.when(
        data: (detail) {
          final order = detail.order;
          _carrierController.text = _carrierController.text.isEmpty
              ? (order.carrier ?? '')
              : _carrierController.text;
          _trackingController.text = _trackingController.text.isEmpty
              ? (order.trackingNumber ?? '')
              : _trackingController.text;
          _nextStatus = _nextStatus.isEmpty ? order.status : _nextStatus;
          _estimatedDelivery ??= order.estimatedDelivery;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AurumCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pedido #${order.id.substring(0, 8)}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Estado actual: ${Formatters.orderStatus(order.status)}',
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _nextStatus,
                      decoration: const InputDecoration(
                        labelText: 'Nuevo estado',
                      ),
                      items: orderStatuses
                          .where((s) => s.isNotEmpty)
                          .map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Text(Formatters.orderStatus(s)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _nextStatus = value ?? order.status),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () => _updateStatus(order.status),
                      child: const Text('Actualizar estado'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AurumCard(
                child: Column(
                  children: [
                    TextField(
                      controller: _carrierController,
                      decoration: const InputDecoration(
                        labelText: AppStrings.transportista,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _trackingController,
                      decoration: const InputDecoration(
                        labelText: AppStrings.numeroSeguimiento,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(AppStrings.entregaEstimada),
                      subtitle: Text(Formatters.date(_estimatedDelivery)),
                      trailing: IconButton(
                        icon: const Icon(Icons.calendar_month),
                        onPressed: () async {
                          final now = DateTime.now();
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _estimatedDelivery ?? now,
                            firstDate: now.subtract(const Duration(days: 1)),
                            lastDate: now.add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setState(() => _estimatedDelivery = picked);
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _updateTracking,
                      child: const Text(AppStrings.guardarCambios),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const AurumCenteredLoader(),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Future<void> _updateStatus(String currentStatus) async {
    try {
      await ref
          .read(adminOrderControllerProvider.notifier)
          .updateStatus(
            orderId: widget.orderId,
            currentStatus: currentStatus,
            nextStatus: _nextStatus,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Estado actualizado')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar el estado: $e')),
      );
    }
  }

  Future<void> _updateTracking() async {
    try {
      await ref
          .read(adminOrderControllerProvider.notifier)
          .updateTracking(
            orderId: widget.orderId,
            carrier: _carrierController.text.trim(),
            trackingNumber: _trackingController.text.trim(),
            estimatedDelivery: _estimatedDelivery,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Datos de seguimiento actualizados')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar el seguimiento: $e')),
      );
    }
  }
}
