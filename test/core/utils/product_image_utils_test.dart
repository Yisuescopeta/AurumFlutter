import 'package:flutter_test/flutter_test.dart';
import 'package:aurum_app/core/utils/product_image_utils.dart';

void main() {
  group('normalizeProductImages', () {
    test('returns empty list when input is not a list', () {
      final result = normalizeProductImages(
        {'images': []},
        toPublicUrl: (path) => 'https://cdn.example/$path',
      );

      expect(result, isEmpty);
    });

    test('keeps absolute urls and normalizes relative paths', () {
      final result = normalizeProductImages(
        [
          'https://example.com/a.jpg',
          '  /products/item.png ',
          'products/item-2.png',
          '   ',
        ],
        toPublicUrl: (path) => 'https://cdn.example/$path',
      );

      expect(
        result,
        equals([
          'https://example.com/a.jpg',
          'https://cdn.example/products/item.png',
          'https://cdn.example/products/item-2.png',
        ]),
      );
    });
  });
}
