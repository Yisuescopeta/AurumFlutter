import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class StripeService {
  StripeService._();
  static final StripeService instance = StripeService._();

  Future<void> makePayment({
    required int amount, // in cents
    required String currency,
    required String productName,
  }) async {
    try {
      debugPrint('--- STRIPE: Starting Payment for $productName ---');
      debugPrint('Amount: $amount $currency');

      // 1. Create Payment Intent
      debugPrint('--- STRIPE: Creating Payment Intent ---');
      Map<String, dynamic>? paymentIntent = await _createPaymentIntent(
        amount.toString(),
        currency,
      );

      if (paymentIntent == null) {
        debugPrint('--- STRIPE: Payment Intent is null ---');
        return;
      }
      debugPrint(
        '--- STRIPE: Client Secret: ${paymentIntent['client_secret']} ---',
      );

      // 2. Initialize Payment Sheet
      debugPrint('--- STRIPE: Initializing Payment Sheet ---');
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: paymentIntent['client_secret'],
          merchantDisplayName: 'Aurum',
          style: ThemeMode.system,
          billingDetailsCollectionConfiguration:
              const BillingDetailsCollectionConfiguration(
                email: CollectionMode.always,
                phone: CollectionMode.never,
                address: AddressCollectionMode.never,
              ),
        ),
      );
      debugPrint('--- STRIPE: Payment Sheet Initialized ---');

      // 3. Display Payment Sheet
      debugPrint('--- STRIPE: Presenting Payment Sheet ---');
      await _displayPaymentSheet();
      debugPrint('--- STRIPE: Payment Sheet Displayed/Completed ---');
    } catch (e, stack) {
      debugPrint('--- STRIPE ERROR: $e ---');
      debugPrint('--- STRIPE STACKTRACE: $stack ---');
      rethrow;
    }
  }

  Future<void> _displayPaymentSheet() async {
    try {
      await Stripe.instance.presentPaymentSheet();
    } catch (e) {
      if (e is StripeException) {
        debugPrint('Stripe Error: ${e.error.localizedMessage}');
        rethrow;
      } else {
        debugPrint('Error displaying payment sheet: $e');
        rethrow;
      }
    }
  }

  Future<Map<String, dynamic>?> _createPaymentIntent(
    String amount,
    String currency,
  ) async {
    try {
      final String? secretKey = dotenv.env['STRIPE_SECRET_KEY'];
      if (secretKey == null || secretKey.isEmpty) {
        throw Exception('Stripe Secret Key is missing in .env');
      }

      Map<String, dynamic> body = {
        'amount': amount,
        'currency': currency,
        'payment_method_types[]': 'card',
      };

      var response = await http.post(
        Uri.parse('https://api.stripe.com/v1/payment_intents'),
        headers: {
          'Authorization': 'Bearer $secretKey',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: body,
      );

      final Map<String, dynamic> data = jsonDecode(response.body);

      if (response.statusCode != 200) {
        final error = data['error']?['message'] ?? 'Unknown Stripe error';
        throw Exception(error);
      }

      if (data['client_secret'] == null) {
        throw Exception('Failed to get client_secret from Stripe');
      }

      return data;
    } catch (e) {
      debugPrint('Error creating payment intent: $e');
      rethrow;
    }
  }
}
