import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/repositories/product_repository.dart';
import '../../domain/models/product.dart';

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository(Supabase.instance.client);
});

final newArrivalsProvider = FutureProvider<List<Product>>((ref) async {
  final repository = ref.watch(productRepositoryProvider);
  return repository.getNewArrivals();
});

final productsProvider = FutureProvider<List<Product>>((ref) async {
  final repository = ref.watch(productRepositoryProvider);
  return repository.getProducts();
});

final flashOffersProvider = FutureProvider<List<Product>>((ref) async {
  final repository = ref.watch(productRepositoryProvider);
  return repository.getFlashOffers();
});

class RelatedProductsRequest {
  const RelatedProductsRequest({
    required this.productId,
    required this.categoryId,
  });

  final String productId;
  final String categoryId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RelatedProductsRequest &&
          runtimeType == other.runtimeType &&
          productId == other.productId &&
          categoryId == other.categoryId;

  @override
  int get hashCode => Object.hash(productId, categoryId);
}

final relatedProductsProvider =
    FutureProvider.family<List<Product>, RelatedProductsRequest>((ref, request) async {
  final repository = ref.watch(productRepositoryProvider);
  return repository.getRelatedProducts(
    productId: request.productId,
    categoryId: request.categoryId,
  );
});
