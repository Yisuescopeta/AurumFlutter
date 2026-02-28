import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/product.dart';

class ProductRepository {
  final SupabaseClient _supabase;

  ProductRepository(this._supabase);

  List<Product> _toProducts(dynamic response) {
    if (response is! List) return const [];
    return response
        .whereType<Map>()
        .map((e) => Product.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<Product>> getProducts() async {
    final response = await _supabase
        .from('products')
        .select('*, categories(name, slug)')
        .eq('is_active', true)
        .order('created_at', ascending: false);

    return _toProducts(response);
  }

  Future<List<Product>> getNewArrivals({int limit = 10}) async {
    final response = await _supabase
        .from('products')
        .select('*, categories(name, slug)')
        .eq('is_active', true)
        .order('created_at', ascending: false)
        .limit(limit);

    return _toProducts(response);
  }

  Future<List<Product>> getFlashOffers({int limit = 8}) async {
    final response = await _supabase
        .from('products')
        .select('*, categories(name, slug)')
        .eq('is_active', true)
        .eq('is_on_sale', true)
        .eq('is_featured', true)
        .order('updated_at', ascending: false)
        .order('created_at', ascending: false)
        .limit(limit);

    return _toProducts(response);
  }

  Future<List<Product>> getRelatedProducts({
    required String productId,
    required String categoryId,
    int limit = 8,
  }) async {
    List<Product> related = const [];

    if (categoryId.trim().isNotEmpty) {
      final sameCategory = await _supabase
          .from('products')
          .select('*, categories(name, slug)')
          .eq('is_active', true)
          .eq('category_id', categoryId)
          .neq('id', productId)
          .order('created_at', ascending: false)
          .limit(limit);
      related = _toProducts(sameCategory);
    }

    if (related.length >= limit) {
      return related.take(limit).toList();
    }

    final fallback = await _supabase
        .from('products')
        .select('*, categories(name, slug)')
        .eq('is_active', true)
        .neq('id', productId)
        .order('created_at', ascending: false)
        .limit(limit * 2);

    final fallbackProducts = _toProducts(fallback);
    final merged = <Product>[
      ...related,
      ...fallbackProducts.where(
        (p) => related.every((r) => r.id != p.id),
      ),
    ];

    return merged.take(limit).toList();
  }
}
