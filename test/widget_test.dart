import 'package:aurum_app/core/constants/app_strings.dart';
import 'package:aurum_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:aurum_app/features/products/domain/models/product.dart';
import 'package:aurum_app/features/products/presentation/providers/product_provider.dart';
import 'package:aurum_app/features/store/presentation/pages/store_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('render basico', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Text('Aurum')),
      ),
    );

    expect(find.text('Aurum'), findsOneWidget);
  });

  testWidgets('store: abre y cierra filtros sin errores', (WidgetTester tester) async {
    final sample = Product(
      id: 'p1',
      name: 'Camisa test',
      price: 89,
      slug: 'camisa-test',
      images: const [],
      categoryId: 'c1',
      category: const {'name': 'Camisas'},
      sizes: const ['S', 'M'],
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) => null),
          productsProvider.overrideWith((ref) async => [sample]),
        ],
        child: const MaterialApp(home: StoreScreen()),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip(AppStrings.filtros));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.filtros), findsOneWidget);

    await tester.tap(find.text(AppStrings.limpiar));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.filtros), findsNothing);
  });
}
