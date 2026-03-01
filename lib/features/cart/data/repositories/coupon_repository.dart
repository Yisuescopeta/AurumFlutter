import 'package:supabase_flutter/supabase_flutter.dart';

class CouponValidationResult {
  CouponValidationResult({
    required this.valid,
    required this.code,
    required this.discountAmount,
    required this.finalTotal,
    required this.error,
  });

  final bool valid;
  final String? code;
  final int discountAmount;
  final int finalTotal;
  final String? error;

  factory CouponValidationResult.fromJson(Map<String, dynamic> json) {
    final coupon = json['coupon'];
    return CouponValidationResult(
      valid: json['valid'] == true,
      code: coupon is Map ? coupon['code']?.toString() : null,
      discountAmount: (json['discount_amount'] as num?)?.toInt() ?? 0,
      finalTotal: (json['final_total'] as num?)?.toInt() ?? 0,
      error: json['error']?.toString(),
    );
  }
}

class CouponRepository {
  CouponRepository(this._supabase);

  final SupabaseClient _supabase;

  Future<CouponValidationResult> validateCoupon({
    required String code,
    required int cartTotal,
  }) async {
    final response = await _supabase.functions.invoke(
      'validate-coupon',
      body: {
        'code': code,
        'cart_total': cartTotal,
      },
    );

    final data = response.data;
    if (data is! Map) {
      throw Exception('Respuesta invalida al validar cupon');
    }

    return CouponValidationResult.fromJson(Map<String, dynamic>.from(data));
  }
}
