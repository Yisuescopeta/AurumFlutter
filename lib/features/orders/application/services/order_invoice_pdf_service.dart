import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../domain/models/order.dart';

class OrderInvoicePdfService {
  const OrderInvoicePdfService._();

  static Future<void> openOrderInvoicePreview({
    required OrderDetail detail,
  }) async {
    final order = detail.order;
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => _buildOrderInvoice(detail),
      ),
    );

    await _layoutPdf(
      bytes: await doc.save(),
      fileName: 'factura-pedido-${_shortOrderId(order.id)}.pdf',
    );
  }

  static Future<void> openRefundInvoicePreview({
    required OrderDetail detail,
  }) async {
    final order = detail.order;
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => _buildRefundInvoice(detail),
      ),
    );

    await _layoutPdf(
      bytes: await doc.save(),
      fileName: 'factura-devolucion-${_shortOrderId(order.id)}.pdf',
    );
  }

  static Future<void> _layoutPdf({
    required Uint8List bytes,
    required String fileName,
  }) {
    return Printing.layoutPdf(
      name: fileName,
      onLayout: (format) async => bytes,
    );
  }

  static List<pw.Widget> _buildOrderInvoice(OrderDetail detail) {
    final order = detail.order;
    final subtotal = detail.items.fold<int>(
      0,
      (sum, item) => sum + (item.priceAtPurchase * item.quantity),
    );

    return [
      _header(
        title: 'Factura',
        orderId: order.id,
        date: order.createdAt,
      ),
      pw.SizedBox(height: 12),
      _customerSection(order),
      pw.SizedBox(height: 16),
      _itemsTable(detail),
      pw.SizedBox(height: 12),
      _totals(
        subtotal: subtotal,
        shipping: order.shippingCost,
        total: order.totalAmount,
      ),
      pw.SizedBox(height: 18),
      pw.Text(
        'Estado del pedido: ${_statusLabel(order.status)}',
        style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
      ),
    ];
  }

  static List<pw.Widget> _buildRefundInvoice(OrderDetail detail) {
    final order = detail.order;
    final refundedAmount = (order.totalAmount - order.shippingCost).clamp(0, order.totalAmount);
    final refundDate = order.refundedAt ?? DateTime.now();

    return [
      _header(
        title: 'Factura de devolucion',
        orderId: order.id,
        date: refundDate,
      ),
      pw.SizedBox(height: 12),
      _customerSection(order),
      pw.SizedBox(height: 16),
      _itemsTable(detail),
      pw.SizedBox(height: 12),
      _refundSummary(
        refundedAmount: refundedAmount,
        shipping: order.shippingCost,
        refundStatus: order.refundStatus,
      ),
      pw.SizedBox(height: 18),
      pw.Text(
        'Nota: los gastos de envio no son reembolsables.',
        style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
      ),
    ];
  }

  static pw.Widget _header({
    required String title,
    required String orderId,
    required DateTime? date,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Aurum Fashion',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey900,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(title, style: pw.TextStyle(fontSize: 13)),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              '#${_shortOrderId(orderId)}',
              style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
            ),
            pw.Text(
              _formatDate(date),
              style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _customerSection(OrderModel order) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Datos del cliente y envio',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text('Email: ${order.customerEmail ?? '-'}', style: const pw.TextStyle(fontSize: 10)),
          pw.Text('Telefono: ${order.shippingPhone ?? '-'}', style: const pw.TextStyle(fontSize: 10)),
          pw.Text(
            'Direccion: ${order.shippingAddress}, ${order.shippingPostalCode} ${order.shippingCity}',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
  }

  static pw.Widget _itemsTable(OrderDetail detail) {
    final rows = detail.items
        .map(
          (item) => [
            item.productName,
            item.size ?? '-',
            '${item.quantity}',
            _money(item.priceAtPurchase),
            _money(item.priceAtPurchase * item.quantity),
          ],
        )
        .toList();

    return pw.TableHelper.fromTextArray(
      headers: const ['Producto', 'Talla', 'Cant.', 'Precio', 'Total'],
      data: rows,
      cellStyle: const pw.TextStyle(fontSize: 9),
      headerStyle: pw.TextStyle(
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.blueGrey900,
      ),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      cellAlignment: pw.Alignment.centerLeft,
      columnWidths: {
        0: const pw.FlexColumnWidth(4),
        1: const pw.FlexColumnWidth(1.2),
        2: const pw.FlexColumnWidth(1),
        3: const pw.FlexColumnWidth(1.5),
        4: const pw.FlexColumnWidth(1.5),
      },
    );
  }

  static pw.Widget _totals({
    required int subtotal,
    required int shipping,
    required int total,
  }) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _line('Subtotal', _money(subtotal)),
          _line('Envio', _money(shipping)),
          _line('Total', _money(total), bold: true),
        ],
      ),
    );
  }

  static pw.Widget _refundSummary({
    required int refundedAmount,
    required int shipping,
    required String? refundStatus,
  }) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _line('Importe devuelto', _money(refundedAmount), bold: true),
          _line('Envio no reembolsado', _money(shipping)),
          _line('Estado devolucion', _statusLabel(refundStatus ?? 'refunded')),
        ],
      ),
    );
  }

  static pw.Widget _line(String label, String value, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.SizedBox(
            width: 140,
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime? value) {
    if (value == null) return '-';
    return DateFormat('dd/MM/yyyy', 'es_ES').format(value.toLocal());
  }

  static String _money(int cents) {
    final amount = cents / 100;
    return NumberFormat.currency(
      locale: 'es_ES',
      symbol: 'EUR ',
      decimalDigits: 2,
    ).format(amount);
  }

  static String _shortOrderId(String id) {
    if (id.length <= 8) return id.toUpperCase();
    return id.substring(0, 8).toUpperCase();
  }

  static String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Pendiente';
      case 'paid':
        return 'Pagado';
      case 'confirmed':
        return 'Confirmado';
      case 'processing':
        return 'En preparacion';
      case 'shipped':
        return 'Enviado';
      case 'delivered':
        return 'Entregado';
      case 'cancelled':
        return 'Cancelado';
      case 'refunded':
        return 'Devuelto';
      case 'completed':
        return 'Completado';
      case 'failed':
        return 'Fallido';
      default:
        return status;
    }
  }
}
