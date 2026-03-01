import 'package:flutter/foundation.dart';

@Deprecated(
  'No usar en cliente. Usa CheckoutService con la Edge Function create-payment-intent.',
)
class StripeService {
  StripeService._();
  static final StripeService instance = StripeService._();

  @Deprecated(
    'Flujo legacy deshabilitado por seguridad. Usa CheckoutService.startCheckout/startCartCheckout.',
  )
  Future<void> makePayment({
    required int amount, // in cents
    required String currency,
    required String productName,
  }) async {
    debugPrint(
      'StripeService.makePayment deshabilitado por seguridad. '
      'Usa CheckoutService con Edge Function.',
    );
    throw UnsupportedError(
      'Flujo Stripe legacy deshabilitado. Usa CheckoutService.',
    );
  }
}
