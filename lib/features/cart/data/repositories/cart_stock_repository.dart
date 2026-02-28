import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CartStockRepository {
  CartStockRepository(this._supabase);

  final SupabaseClient _supabase;

  Future<int> getStockForSize({
    required String productId,
    required String size,
  }) async {
    final data = await _supabase
        .from('product_variants')
        .select('stock')
        .eq('product_id', productId)
        .eq('size', size)
        .maybeSingle();

    return (data?['stock'] as num?)?.toInt() ?? 0;
  }

  Future<Map<String, int>> getStockForItems(
    List<(String productId, String size)> keys,
  ) async {
    final result = <String, int>{};

    for (final key in keys) {
      final stock = await getStockForSize(productId: key.$1, size: key.$2);
      result['${key.$1}-${key.$2}'] = stock;
    }

    return result;
  }
}

final cartStockRepositoryProvider = Provider<CartStockRepository>((ref) {
  return CartStockRepository(Supabase.instance.client);
});

final stockByVariantProvider =
    FutureProvider.family<int, ({String productId, String size})>(
  (ref, params) async {
    final repository = ref.watch(cartStockRepositoryProvider);
    return repository.getStockForSize(
      productId: params.productId,
      size: params.size,
    );
  },
);
