import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:naija_go/screens/Main/categories_screen.dart';
import 'package:naija_go/screens/Main/category_products_screen.dart';

class _Routes extends NavigatorObserver {
  int pushes = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes++;
    super.didPush(route, previousRoute);
  }
}

Future<void> _mount(WidgetTester tester, _Routes routes) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(navigatorObservers: [routes], home: const CategoriesScreen()),
  );
  await tester.pump();
}

Future<void> _select(WidgetTester tester, String category) async {
  final finder = find.byKey(ValueKey('main-category-$category'));
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      250,
      scrollable: find
          .descendant(
            of: find.byType(ListView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _localRequests(Future<void> Function(List<Uri>) action) async {
  final requests = <Uri>[];
  await http.runWithClient(
    () => action(requests),
    () => MockClient((request) async {
      requests.add(request.url);
      // No live backend or image provider is called by these navigation tests.
      if (request.url.path.startsWith('/api/products')) {
        return http.Response(
          '[]',
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('', 404);
    }),
  );
}

void main() {
  testWidgets(
    'main category shows only its subcategories without opening products',
    (tester) async {
      await _localRequests((requests) async {
        final routes = _Routes();
        await _mount(tester, routes);
        await _select(tester, 'Fashion');
        expect(routes.pushes, 1);
        expect(find.byType(CategoryProductsScreen), findsNothing);
        expect(
          find.byKey(const ValueKey("subcategory-Fashion-Men's Fashion")),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('subcategory-Home & Office-Appliances')),
          findsNothing,
        );
        expect(
          find.text('Choose a subcategory to see products.'),
          findsOneWidget,
        );
        expect(find.text('See all'), findsNothing);
        expect(
          requests.where((uri) => uri.path.startsWith('/api/products')),
          isEmpty,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      });
    },
  );

  testWidgets('main category heading also stays on subcategory selection', (
    tester,
  ) async {
    await _localRequests((requests) async {
      final routes = _Routes();
      await _mount(tester, routes);
      await _select(tester, 'Phones & Tablets');
      await tester.tap(find.text('Phones & Tablets').last);
      await tester.pump(const Duration(milliseconds: 500));
      expect(routes.pushes, 1);
      expect(find.byType(CategoryProductsScreen), findsNothing);
      expect(
        find.byKey(
          const ValueKey('subcategory-Phones & Tablets-Mobile Phones'),
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  testWidgets(
    'subcategory opens only its product category and back keeps selection',
    (tester) async {
      await _localRequests((requests) async {
        final routes = _Routes();
        await _mount(tester, routes);
        await _select(tester, 'Phones & Tablets');
        await tester.tap(
          find.byKey(
            const ValueKey('subcategory-Phones & Tablets-Mobile Phones'),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump();
        expect(routes.pushes, 2);
        final screen = tester.widget<CategoryProductsScreen>(
          find.byType(CategoryProductsScreen),
        );
        expect(screen.category, 'Phones & Tablets > Mobile Phones');
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await tester.pump();
        final products = requests.where(
          (uri) => uri.path.startsWith('/api/products'),
        );
        expect(products, isNotEmpty);
        expect(
          products.every(
            (uri) =>
                uri.queryParameters['category'] ==
                'Phones & Tablets > Mobile Phones',
          ),
          isTrue,
        );
        Navigator.of(tester.element(find.byType(CategoryProductsScreen))).pop();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byType(CategoryProductsScreen), findsNothing);
        expect(
          find.byKey(
            const ValueKey('subcategory-Phones & Tablets-Mobile Phones'),
          ),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      });
    },
  );

  testWidgets(
    'selecting main category from search restores its subcategory panel',
    (tester) async {
      await _localRequests((requests) async {
        final routes = _Routes();
        await _mount(tester, routes);
        await tester.enterText(find.byType(TextField), 'phone');
        await tester.pump();
        await _select(tester, 'Phones & Tablets');
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          isEmpty,
        );
        expect(
          find.byKey(
            const ValueKey('subcategory-Phones & Tablets-Mobile Phones'),
          ),
          findsOneWidget,
        );
        expect(routes.pushes, 1);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    },
  );

  testWidgets('medicine keeps pharmacy options after subcategory selection', (
    tester,
  ) async {
    await _localRequests((requests) async {
      final routes = _Routes();
      await _mount(tester, routes);
      await _select(tester, 'Cosmetics & Beauty');
      final medicine = find.byKey(
        const ValueKey('subcategory-Cosmetics & Beauty-Medicine'),
      );
      await tester.ensureVisible(medicine);
      await tester.pump();
      await tester.tap(medicine);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Pharmacy Store'), findsOneWidget);
      expect(find.byType(CategoryProductsScreen), findsNothing);
      expect(
        requests.where((uri) => uri.path.startsWith('/api/products')),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
  testWidgets('creator equipment opens its exact product category', (
    tester,
  ) async {
    await _localRequests((requests) async {
      final routes = _Routes();
      await _mount(tester, routes);
      await _select(tester, 'Photography');
      expect(routes.pushes, 1);
      expect(find.byType(CategoryProductsScreen), findsNothing);
      expect(
        requests.where((uri) => uri.path.startsWith('/api/products')),
        isEmpty,
      );
      final equipment = find.byKey(
        const ValueKey('subcategory-Photography-Content Creator Equipment'),
      );
      await tester.ensureVisible(equipment);
      await tester.pump();
      await tester.tap(equipment);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(routes.pushes, 2);
      final screen = tester.widget<CategoryProductsScreen>(
        find.byType(CategoryProductsScreen),
      );
      expect(screen.category, 'Photography > Content Creator Equipment');
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
      final productRequests = requests.where(
        (uri) => uri.path.startsWith('/api/products'),
      );
      expect(productRequests, isNotEmpty);
      expect(
        productRequests.every(
          (uri) =>
              uri.queryParameters['category'] ==
              'Photography > Content Creator Equipment',
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  testWidgets('category search finds content creator equipment', (
    tester,
  ) async {
    await _localRequests((requests) async {
      final routes = _Routes();
      await _mount(tester, routes);
      await tester.enterText(find.byType(TextField), 'creator');
      await tester.pump();
      await tester.tap(find.byType(ExpansionTile));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Content Creator Equipment'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey('subcategory-Photography-Content Creator Equipment'),
        ),
        findsOneWidget,
      );
      expect(find.byType(CategoryProductsScreen), findsNothing);
      expect(
        requests.where((uri) => uri.path.startsWith('/api/products')),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
