import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:naija_go/providers/cart_provider.dart';
import 'package:naija_go/screens/Main/home_screen.dart';
import 'package:naija_go/screens/Main/product_detail_screen.dart';
import 'package:naija_go/screens/Main/shopping_assistant_screen.dart';
import 'package:naija_go/services/shopping_assistant_service.dart';

const pid = '507f1f77bcf86cd799439011';
const oid = '507f1f77bcf86cd799439012';
const vid = '507f1f77bcf86cd799439013';
Map<String, dynamic> product() => {
  '_id': pid,
  'name': 'Phone charger fixture',
  'description': 'USB phone charger',
  'price': 20000,
  'effectivePrice': 15000,
  'category': 'Electronics',
  'stockQuantity': 5,
  'isActive': true,
  'imageUrls': [],
  'sellerType': 'vendor',
  'sellerId': vid,
  'sellerName': 'Lucas World',
  'vendor': {'_id': vid, 'businessName': 'Lucas World'},
  'selectedOffer': {'_id': oid},
};
Map<String, dynamic> result({
  List<Map<String, dynamic>>? products,
  String? question,
  String message = 'Here are matching NaijaGo listings.',
}) => {
  'products': products ?? [product()],
  'maxPrice': 15000,
  'question': question,
  'message': message,
  'notice':
      'Individual suggestions, not a combined basket quote. Delivery excluded.',
  'budgetScope': 'per_listing',
  'deliveryIncluded': false,
  'source': 'naijago_catalog',
  'limitedResults': false,
};
http.Response response(Map<String, dynamic> data, {int status = 200}) =>
    http.Response(
      jsonEncode(data),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
ShoppingAssistantService api(
  Future<http.Response> Function(String, Map) post,
) => ShoppingAssistantService(post: post);

Future<void> show(
  WidgetTester tester,
  Widget screen, {
  CartProvider? cart,
}) async {
  SharedPreferences.setMockInitialValues({});
  await tester.binding.setSurfaceSize(const Size(1200, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));
  final provider = cart ?? CartProvider();
  if (cart == null) addTearDown(provider.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: screen,
      ),
    ),
  );
}

Future<void> submit(WidgetTester tester) async {
  await tester.enterText(
    find.byType(TextField).first,
    'Find me a phone charger under ₦15k.',
  );
  await tester.tap(find.text('Find options'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

// Existing screens use real http.get; isolate the network boundary only.
Future<void> localReads(Future<void> Function() action) async {
  final client = MockClient((request) async {
    expect(
      request.method,
      'GET',
      reason: 'Navigation must not place an order or mutate production.',
    );
    final path = request.url.path;
    if (path == '/api/products/search') {
      return response({
        'products': [],
        'total': 0,
        'page': 1,
        'hasMore': false,
      });
    }
    if (path == '/api/deals') {
      return response({
        'deals': [],
        'total': 0,
        'page': 1,
        'limit': 6,
        'hasMore': false,
        'serverTime': DateTime.now().toUtc().toIso8601String(),
      });
    }
    if (path == '/api/carousels/home') return response({});
    if (path.contains('food-readiness')) return response({'campaign': null});
    return http.Response(
      '[]',
      200,
      headers: {'content-type': 'application/json'},
    );
  });
  try {
    await http.runWithClient(action, () => client);
  } finally {
    client.close();
  }
}

void main() {
  test(
    'parses server price, exact offer/vendor and individual-budget contract',
    () {
      final parsed = ShoppingSuggestions.fromJson(result());
      expect(parsed.products.single.id, pid);
      expect(parsed.products.single.offerId, oid);
      expect(parsed.products.single.sellerId, vid);
      expect(parsed.products.single.price, 15000);
      expect(parsed.maxPrice, 15000);
      expect(parsed.notice, contains('not a combined basket'));
    },
  );
  test('successful empty result and clarification are preserved', () {
    final parsed = ShoppingSuggestions.fromJson(
      result(products: [], question: 'What category?', message: ''),
    );
    expect(parsed.products, isEmpty);
    expect(parsed.question, 'What category?');
    expect(parsed.message, isEmpty);
  });
  test('duplicates do not create repeated recommendation cards', () {
    expect(
      ShoppingSuggestions.fromJson(
        result(products: [product(), product()]),
      ).products.length,
      1,
    );
  });
  test('unsafe response source, budget scope and price/stock are rejected', () {
    for (final change in [
      {'source': 'external'},
      {'budgetScope': 'basket'},
      {'deliveryIncluded': true},
      {'maxPrice': -1},
      {
        'products': [
          {...product(), 'effectivePrice': 15001},
        ],
      },
      {
        'products': [
          {...product(), 'effectivePrice': -1},
        ],
      },
      {
        'products': [
          {...product(), 'stockQuantity': 0},
        ],
      },
    ]) {
      expect(
        () => ShoppingSuggestions.fromJson({...result(), ...change}),
        throwsA(anything),
      );
    }
  });
  test(
    'service sends only message to the existing authenticated API wrapper',
    () async {
      final service = api((path, body) async {
        expect(path, '/api/products/shopping-assistant');
        expect(body, {'message': 'phone under ₦15k'});
        return response(result());
      });
      expect(
        (await service.suggest(' phone under ₦15k ')).products.single.price,
        15000,
      );
    },
  );
  test('empty and excessive request input sends no network request', () async {
    var calls = 0;
    final service = api((_, _) async {
      calls++;
      return response(result());
    });
    for (final input in ['', ' ', 'x' * 501]) {
      await expectLater(
        service.suggest(input),
        throwsA(isA<ShoppingAssistantException>()),
      );
    }
    expect(calls, 0);
  });
  for (final status in [404, 429, 500, 503]) {
    test(
      'HTTP $status produces safe fallback/error rather than fake listings',
      () async {
        final service = api(
          (_, _) async =>
              http.Response('raw server secret/stack detail', status),
        );
        try {
          await service.suggest('charger');
          fail('Expected error');
        } on ShoppingAssistantException catch (error) {
          expect(error.message, isNot(contains('secret')));
          expect(
            error.message,
            status == 429
                ? contains('Wait a minute')
                : contains(status == 404 ? 'Normal search' : 'normal search'),
          );
        }
      },
    );
  }
  test('network and timeout errors are sanitized', () async {
    for (final error in [
      http.ClientException('private socket info'),
      TimeoutException('internal details'),
    ]) {
      final service = api((_, _) async => throw error);
      await expectLater(
        service.suggest('phone'),
        throwsA(
          isA<ShoppingAssistantException>().having(
            (e) => e.message,
            'message',
            isNot(contains('private')),
          ),
        ),
      );
    }
  });
  test(
    'malformed assistant JSON is an error rather than a successful empty result',
    () async {
      await expectLater(
        api((_, _) async => http.Response('not json', 200)).suggest('phone'),
        throwsA(isA<ShoppingAssistantException>()),
      );
    },
  );
  testWidgets(
    'request submission shows loading and prevents duplicate requests',
    (tester) async {
      final pending = Completer<http.Response>();
      var calls = 0;
      await show(
        tester,
        ShoppingAssistantScreen(
          service: api((_, _) {
            calls++;
            return pending.future;
          }),
        ),
      );
      await tester.enterText(find.byType(TextField), 'phone');
      await tester.tap(find.text('Find options'));
      await tester.pump();
      expect(find.text('Finding listings…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.text('Finding listings…'));
      expect(calls, 1);
      pending.complete(response(result(products: [])));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );
  testWidgets(
    'recommendations reuse ProductCard and display exact backend prices',
    (tester) async {
      await show(
        tester,
        ShoppingAssistantScreen(
          service: api((_, _) async => response(result())),
        ),
      );
      await submit(tester);
      expect(find.byType(ProductCard), findsOneWidget);
      expect(find.text('Phone charger fixture'), findsOneWidget);
      expect(find.text('₦15,000.00'), findsWidgets);
      expect(
        tester.widget<ProductCard>(find.byType(ProductCard)).product.offerId,
        oid,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'valid no-result state renders without an error or fake product',
    (tester) async {
      await show(
        tester,
        ShoppingAssistantScreen(
          service: api(
            (_, _) async => response(
              result(
                products: [],
                message: 'No suitable NaijaGo listings were found.',
              ),
            ),
          ),
        ),
      );
      await submit(tester);
      expect(
        find.text('No suitable NaijaGo listings were found.'),
        findsOneWidget,
      );
      expect(find.byType(ProductCard), findsNothing);
      expect(find.text('Retry'), findsNothing);
    },
  );
  testWidgets('clarification asks user to refine the original request', (
    tester,
  ) async {
    await show(
      tester,
      ShoppingAssistantScreen(
        service: api(
          (_, _) async => response(
            result(
              products: [],
              question: 'What type of product?',
              message: '',
            ),
          ),
        ),
      ),
    );
    await submit(tester);
    expect(find.text('What type of product?'), findsOneWidget);
    expect(
      find.text('Edit your request above and tap Find options again.'),
      findsOneWidget,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      contains('phone charger'),
    );
  });
  testWidgets(
    'server failure renders safely and retry obtains authoritative results',
    (tester) async {
      var calls = 0;
      await show(
        tester,
        ShoppingAssistantScreen(
          service: api(
            (_, _) async => ++calls == 1
                ? http.Response('private error', 503)
                : response(result()),
          ),
        ),
      );
      await submit(tester);
      expect(find.textContaining('temporarily unavailable'), findsOneWidget);
      expect(find.byType(ProductCard), findsNothing);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(calls, 2);
      expect(find.byType(ProductCard), findsOneWidget);
    },
  );
  testWidgets(
    'normal-search fallback opens the existing SearchScreen with the request',
    (tester) async {
      await localReads(() async {
        await show(
          tester,
          ShoppingAssistantScreen(
            service: api((_, _) async => http.Response('unavailable', 503)),
          ),
        );
        await submit(tester);
        await tester.tap(find.text('Use normal search'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        final search = tester.widget<SearchScreen>(find.byType(SearchScreen));
        expect(search.initialQuery, 'Find me a phone charger under ₦15k.');
      });
    },
  );
  testWidgets(
    'recommended product opens existing product detail with exact offer and price',
    (tester) async {
      await localReads(() async {
        await show(
          tester,
          ShoppingAssistantScreen(
            service: api((_, _) async => response(result())),
          ),
        );
        await submit(tester);
        await tester.tap(find.text('Phone charger fixture'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        final detail = tester.widget<ProductDetailScreen>(
          find.byType(ProductDetailScreen),
        );
        expect(detail.product.id, pid);
        expect(detail.product.offerId, oid);
        expect(detail.product.price, 15000);
        expect(tester.takeException(), isNull);
      });
    },
  );
  testWidgets(
    'existing product card adds the selected offer through the normal cart flow',
    (tester) async {
      final cart = CartProvider();
      addTearDown(cart.dispose);
      await show(
        tester,
        ShoppingAssistantScreen(
          service: api((_, _) async => response(result())),
        ),
        cart: cart,
      );
      await submit(tester);
      await tester.tap(find.text('Add to Cart'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(cart.itemCount, 1);
      final payload = cart.items.values.single.toJson();
      expect(payload['product'], pid);
      expect(payload['offer'], oid);
      expect(payload['price'], 15000);
    },
  );
  testWidgets('recommendations render without overflow on a phone viewport', (
    tester,
  ) async {
    await show(
      tester,
      ShoppingAssistantScreen(service: api((_, _) async => response(result()))),
    );
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await submit(tester);
    await tester.scrollUntilVisible(
      find.byType(ProductCard),
      250,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pump();
    expect(find.byType(ProductCard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('actual Home entry opens ShoppingAssistantScreen', (
    tester,
  ) async {
    await localReads(() async {
      await show(tester, const HomeScreen());
      await tester.pump(const Duration(seconds: 1));
      await tester.ensureVisible(
        find.byKey(const ValueKey('open-shopping-assistant')),
      );
      await tester.pump();
      expect(find.text('Shopping Assistant'), findsOneWidget);
      expect(find.text('Open assistant'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('open-shopping-assistant')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(ShoppingAssistantScreen), findsOneWidget);
      // Dispose Home's existing periodic motion/ticker tasks inside the isolated zone.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });
}
