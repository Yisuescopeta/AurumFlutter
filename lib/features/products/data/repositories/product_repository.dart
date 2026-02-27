import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/product.dart';

class ProductRepository {
  final SupabaseClient _supabase;

  ProductRepository(this._supabase);

  Future<List<Product>> getProducts() async {
    final response = await _supabase
        .from('products')
        .select('*, categories(name, slug)')
        .eq('is_active', true)
        .order('created_at', ascending: false);

    return (response as List).map((e) => Product.fromJson(e)).toList();
  }

  Future<List<Product>> getNewArrivals() async {
    final response = await _supabase
        .from('products')
        .select('*, categories(name, slug)')
        .eq('is_active', true)
        .order('created_at', ascending: false)
        .limit(10);

    return (response as List).map((e) => Product.fromJson(e)).toList();
  }
}
