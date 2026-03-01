import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/utils/product_image_utils.dart';
import '../../domain/models/product.dart';

class ProductRepository {
  final SupabaseClient _supabase;
  static const _productSelect =
      '*, categories(name, slug), product_variants(size, stock)';

  ProductRepository(this._supabase);

  Map<String, dynamic> _normalizeProductJson(Map<String, dynamic> input) {
    final map = Map<String, dynamic>.from(input);
    map['images'] = normalizeProductImages(
      map['images'],
      toPublicUrl: (path) =>
          _supabase.storage.from('product-images').getPublicUrl(path),
    );
    return map;
  }

  List<Product> _toProducts(dynamic response) {
    if (response is! List) return const [];
    return response
        .whereType<Map>()
        .map((e) => _normalizeProductJson(Map<String, dynamic>.from(e)))
        .map(Product.fromJson)
        .toList();
  }

  Future<List<Product>> getProducts() async {
    final response = await _supabase
        .from('products')
        .select(_productSelect)
        .eq('is_active', true)
        .order('created_at', ascending: false);

    return _toProducts(response);
  }

  Future<List<Product>> getNewArrivals({int limit = 10}) async {
    final response = await _supabase
        .from('products')
        .select(_productSelect)
        .eq('is_active', true)
        .order('created_at', ascending: false)
        .limit(limit);

    return _toProducts(response);
  }

  Future<List<Product>> getFlashOffers({int limit = 8}) async {
    final response = await _supabase
        .from('products')
        .select(_productSelect)
        .eq('is_active', true)
        .eq('is_on_sale', true)
        .not('sale_price', 'is', null)
        .gt('sale_price', 0)
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
          .select(_productSelect)
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
        .select(_productSelect)
        .eq('is_active', true)
        .neq('id', productId)
        .order('created_at', ascending: false)
        .limit(limit * 2);

    final fallbackProducts = _toProducts(fallback);
    final merged = <Product>[
      ...related,
      ...fallbackProducts.where((p) => related.every((r) => r.id != p.id)),
    ];

    return merged.take(limit).toList();
  }

  Future<Product?> getProductById(String productId) async {
    final response = await _supabase
        .from('products')
        .select(_productSelect)
        .eq('id', productId)
        .eq('is_active', true)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return Product.fromJson(_normalizeProductJson(response));
  }
}
