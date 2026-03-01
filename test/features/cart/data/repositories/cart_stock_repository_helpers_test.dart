import 'package:aurum_app/features/cart/data/repositories/cart_stock_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('variant helpers', () {
    test('normalizes size and key consistently', () {
      expect(normalizeVariantSize(' m '), 'M');
      expect(buildVariantKey(productId: ' p1 ', size: ' m '), 'p1-M');
    });

    test('recognizes unique-size aliases', () {
      expect(isUniqueSize('Unica'), isTrue);
      expect(isUniqueSize(' one size '), isTrue);
      expect(isUniqueSize('M'), isFalse);
    });
  });
}
