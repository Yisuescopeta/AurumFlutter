import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrderConfirmationDeferredException implements Exception {
  OrderConfirmationDeferredException([this.details]);

  final String? details;

  @override
  String toString() {
    final info = details?.trim();
    if (info == null || info.isEmpty) {
      return 'OrderConfirmationDeferredException';
    }
    return 'OrderConfirmationDeferredException: $info';
  }
}

class CheckoutShippingData {
  CheckoutShippingData({
    required this.fullName,
    required this.phone,
    required this.address,
    required this.city,
    required this.postalCode,
    required this.email,
    required this.saveInfo,
  });

  final String fullName;
  final String phone;
  final String address;
  final String city;
  final String postalCode;
  final String email;
  final bool saveInfo;

  Map<String, dynamic> toJson() {
    return {
      'full_name': fullName,
      'phone': phone,
      'address': address,
      'city': city,
      'postal_code': postalCode,
    };
  }
}

class CheckoutLineItem {
  CheckoutLineItem({
    required this.productId,
    required this.name,
    required this.priceInCents,
    required this.quantity,
    required this.size,
  });

  final String productId;
  final String name;
  final int priceInCents;
  final int quantity;
  final String size;
}

class CheckoutResult {
  CheckoutResult({
    required this.paymentIntentId,
    required this.amount,
    required this.currency,
  });

  final String paymentIntentId;
  final int amount;
  final String currency;
}

class CheckoutService {
  CheckoutService._();
  static final CheckoutService instance = CheckoutService._();

  final SupabaseClient _supabase = Supabase.instance.client;

  Future<CheckoutResult> startCheckout({
    required CheckoutLineItem item,
    required CheckoutShippingData shipping,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Debes iniciar sesion para comprar');
    }

    if (shipping.saveInfo) {
      await _supabase.from('profiles').update({
        'full_name': shipping.fullName,
        'phone': shipping.phone,
        'address': shipping.address,
        'city': shipping.city,
        'postal_code': shipping.postalCode,
      }).eq('id', user.id);
    }

    return _startPaymentSheet(
      body: {
        'product_id': item.productId,
        'size': item.size,
        'quantity': item.quantity,
        'shipping': shipping.toJson(),
      },
      shipping: shipping,
      fallbackAmount: item.priceInCents,
    );
  }

  Future<CheckoutResult> startCartCheckout({
    required List<CheckoutLineItem> items,
    required CheckoutShippingData shipping,
    String? couponCode,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Debes iniciar sesion para comprar');
    }

    if (items.isEmpty) {
      throw Exception('El carrito esta vacio');
    }

    if (shipping.saveInfo) {
      await _supabase.from('profiles').update({
        'full_name': shipping.fullName,
        'phone': shipping.phone,
        'address': shipping.address,
        'city': shipping.city,
        'postal_code': shipping.postalCode,
      }).eq('id', user.id);
    }

    final fallbackAmount = items.fold<int>(0, (sum, item) => sum + (item.priceInCents * item.quantity));
    return _startPaymentSheet(
      body: {
        'items': items
            .map(
              (item) => {
                'product_id': item.productId,
                'name': item.name,
                'size': item.size,
                'quantity': item.quantity,
                'price': item.priceInCents,
              },
            )
            .toList(),
        'coupon_code': couponCode,
        'shipping': shipping.toJson(),
      },
      shipping: shipping,
      fallbackAmount: fallbackAmount,
    );
  }

  Future<CheckoutResult> _startPaymentSheet({
    required Map<String, dynamic> body,
    required CheckoutShippingData shipping,
    required int fallbackAmount,
  }) async {
    final response = await _supabase.functions.invoke('create-payment-intent', body: body);
    final data = response.data;
    if (data is! Map) {
      throw Exception('Respuesta invalida al crear el pago');
    }

    final map = Map<String, dynamic>.from(data);
    final clientSecret = map['payment_intent_client_secret']?.toString() ?? '';
    final paymentIntentId = map['payment_intent_id']?.toString() ?? '';
    final amount = (map['amount'] as num?)?.toInt() ?? fallbackAmount;
    final currency = map['currency']?.toString() ?? 'eur';
    if (clientSecret.isEmpty || paymentIntentId.isEmpty) {
      throw Exception(map['error']?.toString() ?? 'No se pudo iniciar el pago');
    }

    try {
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Aurum Fashion',
          style: ThemeMode.system,
          billingDetails: BillingDetails(
            email: shipping.email,
            name: shipping.fullName,
            phone: shipping.phone,
            address: Address(
              line1: shipping.address,
              line2: '',
              city: shipping.city,
              state: '',
              postalCode: shipping.postalCode,
              country: 'ES',
            ),
          ),
        ),
      );

      await Stripe.instance.presentPaymentSheet();
      return CheckoutResult(paymentIntentId: paymentIntentId, amount: amount, currency: currency);
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        throw Exception('Pago cancelado');
      }
      throw Exception(e.error.localizedMessage ?? 'Error de pago');
    }
  }

  Future<void> confirmOrderAfterPayment(String paymentIntentId) async {
    const retryDelays = <Duration>[
      Duration.zero,
      Duration(milliseconds: 700),
      Duration(milliseconds: 1500),
    ];

    Object? lastError;

    for (final delay in retryDelays) {
      if (delay > Duration.zero) {
        await Future.delayed(delay);
      }

      try {
        final response = await _supabase.functions.invoke(
          'confirm-payment-intent',
          body: {'payment_intent_id': paymentIntentId},
        );

        final data = response.data;
        if (data is! Map) {
          lastError = Exception('Respuesta invalida en confirm-payment-intent');
          continue;
        }

        final map = Map<String, dynamic>.from(data);
        final ok = map['ok'] == true;
        final created = map['order_created'] == true;
        if (ok && created) return;

        final reason = map['error']?.toString().trim();
        lastError = Exception(
          reason == null || reason.isEmpty
              ? 'confirm-payment-intent no confirmo el pedido'
              : reason,
        );
      } on FunctionException catch (e) {
        if (e.status == 401 || e.status == 404 || e.status == 409 || e.status >= 500) {
          lastError = e;
          continue;
        }
        rethrow;
      } catch (e) {
        lastError = e;
      }
    }

    throw OrderConfirmationDeferredException(lastError?.toString());
  }

  Future<bool> waitForOrderPersistence(
    String paymentIntentId, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    if (paymentIntentId.trim().isEmpty) return false;

    final startedAt = DateTime.now();
    const pollDelays = <Duration>[
      Duration.zero,
      Duration(milliseconds: 700),
      Duration(milliseconds: 1300),
      Duration(milliseconds: 2200),
      Duration(milliseconds: 3200),
      Duration(milliseconds: 4600),
    ];

    for (final delay in pollDelays) {
      if (delay > Duration.zero) {
        await Future.delayed(delay);
      }

      final elapsed = DateTime.now().difference(startedAt);
      if (elapsed > timeout) break;

      try {
        final rows = await _supabase
            .from('orders')
            .select('id')
            .eq('payment_intent_id', paymentIntentId)
            .limit(1);
        if (rows.isNotEmpty) {
          return true;
        }
      } catch (_) {
        // Ignore transient read failures during background sync.
      }
    }

    return false;
  }
}
