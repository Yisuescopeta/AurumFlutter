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
    if (keys.isEmpty) return const <String, int>{};

    final result = <String, int>{};
    final productIds = keys
        .map((key) => key.$1.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (productIds.isNotEmpty) {
      final rows = await _supabase
          .from('product_variants')
          .select('product_id,size,stock')
          .inFilter('product_id', productIds);

      for (final row in (rows as List)) {
        if (row is! Map) continue;
        final map = Map<String, dynamic>.from(row);
        final productId = map['product_id']?.toString() ?? '';
        final size = map['size']?.toString() ?? '';
        if (productId.isEmpty || size.isEmpty) continue;
        result['$productId-$size'] = (map['stock'] as num?)?.toInt() ?? 0;
      }
    }

    for (final key in keys) {
      final mapKey = '${key.$1}-${key.$2}';
      result.putIfAbsent(mapKey, () => 0);
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
