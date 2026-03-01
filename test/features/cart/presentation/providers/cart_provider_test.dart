import 'package:aurum_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CartController _load', () {
    test('cleans corrupted cart storage and keeps empty state', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'aurum_cart_v1': '{"not":"a-list"}',
      });

      final controller = CartController();
      await Future<void>.delayed(const Duration(milliseconds: 30));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('aurum_cart_v1'), isNull);
      expect(controller.state.items, isEmpty);

      controller.dispose();
    });

    test('loads persisted items when storage is valid', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'aurum_cart_v1':
            '[{"product_id":"p1","name":"Camisa","image":null,"size":"M","unit_price_cents":1000,"quantity":2}]',
      });

      final controller = CartController();
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(controller.state.items, hasLength(1));
      expect(controller.state.items.first.productId, 'p1');
      expect(controller.state.items.first.quantity, 2);

      controller.dispose();
    });
  });
}
