import 'package:intl/intl.dart';

class Formatters {
  static final NumberFormat _currency = NumberFormat.currency(
    locale: 'es_ES',
    symbol: '€',
    decimalDigits: 2,
  );

  static final DateFormat _date = DateFormat('dd/MM/yyyy', 'es_ES');

  static String euro(num value) => _currency.format(value);

  static String date(DateTime? value) {
    if (value == null) return '-';
    return _date.format(value.toLocal());
  }

  static String orderStatus(String status) {
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
        return 'Reembolsado';
      default:
        return status;
    }
  }
}
