import 'package:aurum_app/features/products/domain/models/product.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Product.availableSizes', () {
    test('prioritizes product_variants over legacy sizes', () {
      final product = Product.fromJson({
        'id': 'p1',
        'name': 'Producto',
        'price': 1000,
        'slug': 'producto',
        'category_id': 'c1',
        'created_at': DateTime(2026, 1, 1).toIso8601String(),
        'sizes': ['XS', 'S'],
        'product_variants': [
          {'size': 'M', 'stock': 2},
          {'size': 'L', 'stock': 0},
        ],
      });

      expect(product.availableSizes, ['M', 'L']);
    });

    test('falls back to legacy sizes list when no variants', () {
      final product = Product.fromJson({
        'id': 'p1',
        'name': 'Producto',
        'price': 1000,
        'slug': 'producto',
        'category_id': 'c1',
        'created_at': DateTime(2026, 1, 1).toIso8601String(),
        'sizes': ['S', 'M'],
      });

      expect(product.availableSizes, ['S', 'M']);
    });

    test('falls back to Unica when no variants and no legacy sizes', () {
      final product = Product.fromJson({
        'id': 'p1',
        'name': 'Producto',
        'price': 1000,
        'slug': 'producto',
        'category_id': 'c1',
        'created_at': DateTime(2026, 1, 1).toIso8601String(),
      });

      expect(product.availableSizes, ['Unica']);
    });
  });
}
