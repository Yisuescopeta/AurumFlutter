import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../products/domain/models/product.dart';
import '../../data/repositories/favorites_repository.dart';

final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  return FavoritesRepository(Supabase.instance.client);
});

final favoriteIdsProvider = FutureProvider<Set<String>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return <String>{};
  return ref.watch(favoritesRepositoryProvider).getFavoriteProductIds(user.id);
});

final favoriteProductsProvider = FutureProvider<List<Product>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return <Product>[];
  return ref.watch(favoritesRepositoryProvider).getFavoriteProducts(user.id);
});

final favoriteToggleLoadingProvider = StateProvider<Set<String>>((ref) {
  return <String>{};
});

class FavoriteToggleController extends StateNotifier<AsyncValue<void>> {
  FavoriteToggleController(this.ref) : super(const AsyncData(null));

  final Ref ref;

  Future<bool?> toggle(String productId) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return null;

    final loadingSet = {...ref.read(favoriteToggleLoadingProvider)};
    if (loadingSet.contains(productId)) return null;

    loadingSet.add(productId);
    ref.read(favoriteToggleLoadingProvider.notifier).state = loadingSet;

    state = const AsyncLoading();

    try {
      final isFavorite = await ref
          .read(favoritesRepositoryProvider)
          .toggleFavorite(user.id, productId);
      ref.invalidate(favoriteIdsProvider);
      ref.invalidate(favoriteProductsProvider);
      state = const AsyncData(null);
      return isFavorite;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    } finally {
      final updated = {...ref.read(favoriteToggleLoadingProvider)};
      updated.remove(productId);
      ref.read(favoriteToggleLoadingProvider.notifier).state = updated;
    }
  }
}

final favoriteToggleControllerProvider =
    StateNotifierProvider<FavoriteToggleController, AsyncValue<void>>((ref) {
      return FavoriteToggleController(ref);
    });
