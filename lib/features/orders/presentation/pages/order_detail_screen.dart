import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../application/services/order_invoice_pdf_service.dart';
import '../../domain/models/order.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/design_system/widgets/aurum_card.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../providers/orders_provider.dart';

class OrderDetailScreen extends ConsumerStatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  bool _creatingOrderInvoice = false;
  bool _creatingRefundInvoice = false;

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(orderDetailProvider(widget.orderId));

    return Scaffold(
      backgroundColor: AppTheme.lightGrey,
      appBar: AppBar(title: const Text('Detalle de pedido')),
      body: detailAsync.when(
        data: (detail) {
          final order = detail.order;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionCard(
                title: 'Resumen',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${AppStrings.estado}: ${Formatters.orderStatus(order.status)}'),
                    Text('Subtotal: ${Formatters.euro((order.totalAmount - order.shippingCost) / 100)}'),
                    Text('Gastos de envio: ${Formatters.euro(order.shippingCost / 100)}'),
                    Text(
                      '${AppStrings.total}: ${Formatters.euro(order.totalAmount / 100)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('Fecha: ${Formatters.date(order.createdAt)}'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Envio',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.shippingAddress),
                    Text('${order.shippingCity} ${order.shippingPostalCode}'),
                    if ((order.carrier ?? '').isNotEmpty)
                      Text('${AppStrings.transportista}: ${order.carrier}'),
                    if ((order.trackingNumber ?? '').isNotEmpty)
                      Text('${AppStrings.numeroSeguimiento}: ${order.trackingNumber}'),
                    Text(
                      '${AppStrings.entregaEstimada}: ${Formatters.date(order.estimatedDelivery)}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Productos',
                child: Column(
                  children: detail.items
                      .map(
                        (item) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(item.productName),
                          subtitle: Text('Cantidad: ${item.quantity} | Talla: ${item.size ?? '-'}'),
                          trailing: Text(
                            Formatters.euro(item.priceAtPurchase / 100),
                            style: const TextStyle(color: AppTheme.gold),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Historial',
                child: Column(
                  children: detail.history
                      .map(
                        (h) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(Formatters.orderStatus(h.status)),
                          subtitle: Text(Formatters.date(h.createdAt)),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Documentos',
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _creatingOrderInvoice
                            ? null
                            : () => _downloadInvoice(detail),
                        icon: _creatingOrderInvoice
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.download_outlined),
                        label: Text(
                          _creatingOrderInvoice
                              ? 'Generando factura...'
                              : 'Descargar factura',
                        ),
                      ),
                    ),
                    if (_canDownloadRefundInvoice(order)) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _creatingRefundInvoice
                              ? null
                              : () => _downloadRefundInvoice(detail),
                          icon: _creatingRefundInvoice
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.assignment_return_outlined),
                          label: Text(
                            _creatingRefundInvoice
                                ? 'Generando factura de devolucion...'
                                : 'Descargar factura de devolucion',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (order.status == 'paid' || order.status == 'delivered') ...[
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => _refundOrder(context, order.id),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade100,
                    foregroundColor: Colors.red.shade900,
                  ),
                  child: const Text('Devolver Pedido'),
                ),
                const SizedBox(height: 24),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }

  bool _canDownloadRefundInvoice(OrderModel order) {
    return order.status == 'refunded' ||
        order.refundStatus == 'completed' ||
        order.refundedAt != null;
  }

  Future<void> _downloadInvoice(OrderDetail detail) async {
    if (_creatingOrderInvoice) return;
    setState(() => _creatingOrderInvoice = true);
    try {
      await OrderInvoicePdfService.openOrderInvoicePreview(detail: detail);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo generar la factura: $e')),
      );
    } finally {
      if (mounted) setState(() => _creatingOrderInvoice = false);
    }
  }

  Future<void> _downloadRefundInvoice(OrderDetail detail) async {
    if (_creatingRefundInvoice) return;
    setState(() => _creatingRefundInvoice = true);
    try {
      await OrderInvoicePdfService.openRefundInvoicePreview(detail: detail);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo generar la factura de devolucion: $e')),
      );
    } finally {
      if (mounted) setState(() => _creatingRefundInvoice = false);
    }
  }

  Future<void> _refundOrder(BuildContext context, String orderId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Devolucion'),
        content: const Text(
          'Seguro que deseas devolver este pedido? Se devolvera el importe de los productos, pero los gastos de envio no son reembolsables.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Devolver', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!context.mounted) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final response = await Supabase.instance.client.functions.invoke(
        'refund-order',
        body: {'order_id': orderId},
      );

      if (context.mounted) Navigator.pop(context);

      if (response.status != 200) {
        throw Exception('Error al devolver el pedido. ${response.data}');
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pedido devuelto correctamente')),
        );
      }

      ref.invalidate(orderDetailProvider(orderId));
      ref.invalidate(customerOrdersProvider);
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo procesar la devolucion: $e')),
        );
      }
    }
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AurumCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppTheme.navyBlue,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
