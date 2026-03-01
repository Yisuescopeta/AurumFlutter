import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String _uniqueSizeToken = 'UNICA';

String normalizeVariantSize(String size) {
  return size.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');
}

bool isUniqueSize(String size) {
  final normalized = normalizeVariantSize(size);
  return normalized == _uniqueSizeToken ||
      normalized == 'ONE SIZE' ||
      normalized == 'ONESIZE' ||
      normalized == 'UNIQUE';
}

String buildVariantKey({required String productId, required String size}) {
  final normalizedProductId = productId.trim();
  final normalizedSize = normalizeVariantSize(size);
  return '$normalizedProductId-$normalizedSize';
}

class CartStockRepository {
  CartStockRepository(this._supabase);

  final SupabaseClient _supabase;

  Future<int> getStockForSize({
    required String productId,
    required String size,
  }) async {
    final normalizedProductId = productId.trim();
    final normalizedSize = normalizeVariantSize(size);
    if (normalizedProductId.isEmpty || normalizedSize.isEmpty) return 0;

    final rows = await _supabase
        .from('product_variants')
        .select('size,stock')
        .eq('product_id', normalizedProductId);

    for (final row in (rows as List)) {
      if (row is! Map) continue;
      final map = Map<String, dynamic>.from(row);
      final rowSize = map['size']?.toString() ?? '';
      if (normalizeVariantSize(rowSize) != normalizedSize) continue;
      return (map['stock'] as num?)?.toInt() ?? 0;
    }

    if (isUniqueSize(normalizedSize)) {
      return _getLegacyUniqueStock(normalizedProductId);
    }

    return 0;
  }

  Future<Map<String, int>> getStockForItems(
    List<(String productId, String size)> keys,
  ) async {
    if (keys.isEmpty) return const <String, int>{};

    final result = <String, int>{};
    final normalizedKeys = keys
        .map((key) => (key.$1.trim(), normalizeVariantSize(key.$2)))
        .where((key) => key.$1.isNotEmpty && key.$2.isNotEmpty)
        .toList();

    final productIds = normalizedKeys.map((key) => key.$1).toSet().toList();

    if (productIds.isNotEmpty) {
      final rows = await _supabase
          .from('product_variants')
          .select('product_id,size,stock')
          .inFilter('product_id', productIds);

      for (final row in (rows as List)) {
        if (row is! Map) continue;
        final map = Map<String, dynamic>.from(row);
        final productId = map['product_id']?.toString() ?? '';
        final size = normalizeVariantSize(map['size']?.toString() ?? '');
        if (productId.isEmpty || size.isEmpty) continue;
        result[buildVariantKey(productId: productId, size: size)] =
            (map['stock'] as num?)?.toInt() ?? 0;
      }
    }

    final needsLegacyUniqueFallback = normalizedKeys
        .where((key) => isUniqueSize(key.$2))
        .where(
          (key) => !result.containsKey(
            buildVariantKey(productId: key.$1, size: key.$2),
          ),
        )
        .map((key) => key.$1)
        .toSet()
        .toList();

    if (needsLegacyUniqueFallback.isNotEmpty) {
      final rows = await _supabase
          .from('products')
          .select('id,stock')
          .inFilter('id', needsLegacyUniqueFallback);

      for (final row in (rows as List)) {
        if (row is! Map) continue;
        final map = Map<String, dynamic>.from(row);
        final productId = map['id']?.toString() ?? '';
        if (productId.isEmpty) continue;
        final stock = (map['stock'] as num?)?.toInt() ?? 0;
        result[buildVariantKey(productId: productId, size: _uniqueSizeToken)] =
            stock < 0 ? 0 : stock;
      }
    }

    for (final key in normalizedKeys) {
      final mapKey = buildVariantKey(productId: key.$1, size: key.$2);
      result.putIfAbsent(mapKey, () => 0);
    }

    return result;
  }

  Future<int> _getLegacyUniqueStock(String productId) async {
    final data = await _supabase
        .from('products')
        .select('stock')
        .eq('id', productId)
        .maybeSingle();

    final stock = (data?['stock'] as num?)?.toInt() ?? 0;
    return stock < 0 ? 0 : stock;
  }
}

final cartStockRepositoryProvider = Provider<CartStockRepository>((ref) {
  return CartStockRepository(Supabase.instance.client);
});

final stockByVariantProvider =
    FutureProvider.family<int, ({String productId, String size})>((
      ref,
      params,
    ) async {
      final repository = ref.watch(cartStockRepositoryProvider);
      return repository.getStockForSize(
        productId: params.productId,
        size: params.size,
      );
    });
