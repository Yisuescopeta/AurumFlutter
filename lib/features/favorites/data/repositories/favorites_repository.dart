import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../products/domain/models/product.dart';

class FavoritesRepository {
  final SupabaseClient _supabase;

  FavoritesRepository(this._supabase);

  List<String> _normalizeImages(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .map((value) {
          if (value.startsWith('http://') || value.startsWith('https://')) {
            return value;
          }
          final normalized = value.startsWith('/') ? value.substring(1) : value;
          return _supabase.storage.from('product-images').getPublicUrl(normalized);
        })
        .toList();
  }

  Map<String, dynamic> _normalizeProductJson(Map<String, dynamic> input) {
    final map = Map<String, dynamic>.from(input);
    map['images'] = _normalizeImages(map['images']);
    return map;
  }

  Future<Set<String>> getFavoriteProductIds(String userId) async {
    final response = await _supabase
        .from('favorites')
        .select('product_id')
        .eq('user_id', userId);

    return (response as List)
        .map((e) => e['product_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  Future<List<Product>> getFavoriteProducts(String userId) async {
    final response = await _supabase
        .from('favorites')
        .select('id, product_id, products(*, categories(name, slug))')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    final products = <Product>[];
    final orphanProductIds = <String>[];

    for (final row in (response as List)) {
      final productData = row['products'];
      if (productData is Map<String, dynamic>) {
        products.add(Product.fromJson(_normalizeProductJson(productData)));
      } else {
        final orphanId = row['product_id']?.toString();
        if (orphanId != null && orphanId.isNotEmpty) {
          orphanProductIds.add(orphanId);
        }
      }
    }

    if (orphanProductIds.isNotEmpty) {
      await _supabase
          .from('favorites')
          .delete()
          .eq('user_id', userId)
          .inFilter('product_id', orphanProductIds);
    }

    return products;
  }

  Future<bool> isFavorite(String userId, String productId) async {
    final response = await _supabase
        .from('favorites')
        .select('id')
        .eq('user_id', userId)
        .eq('product_id', productId)
        .maybeSingle();

    return response != null;
  }

  Future<void> addFavorite(String userId, String productId) async {
    final existing = await _supabase
        .from('favorites')
        .select('id')
        .eq('user_id', userId)
        .eq('product_id', productId)
        .maybeSingle();

    if (existing != null) return;

    await _supabase.from('favorites').insert({
      'user_id': userId,
      'product_id': productId,
    });
  }

  Future<void> removeFavorite(String userId, String productId) async {
    await _supabase
        .from('favorites')
        .delete()
        .eq('user_id', userId)
        .eq('product_id', productId);
  }

  Future<bool> toggleFavorite(String userId, String productId) async {
    final exists = await isFavorite(userId, productId);
    if (exists) {
      await removeFavorite(userId, productId);
      return false;
    }

    await addFavorite(userId, productId);
    return true;
  }
}
