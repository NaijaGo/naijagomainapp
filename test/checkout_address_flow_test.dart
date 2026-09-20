import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:naija_go/models/product.dart';
import 'package:naija_go/providers/cart_provider.dart';
import 'package:naija_go/screens/Main/checkout_screen.dart';
import 'package:naija_go/services/address_autocomplete_service.dart';

class _Suggestions extends AddressAutocompleteService {
  _Suggestions({this.postalCode = '900001'});
  final String postalCode;

  @override
  List<AddressSuggestion> cachedSuggestions(String query) => const [];

  @override
  Future<List<AddressSuggestion>> search(
    String query, {
    double? latitude,
    double? longitude,
  }) async => [
    AddressSuggestion(
      id: 'wuse',
      label: '12 Test Road, Wuse, Abuja',
      address: '12 Test Road',
      city: 'Abuja',
      state: 'FCT',
      postalCode: postalCode,
      country: 'Nigeria',
      latitude: 9.08,
      longitude: 7.46,
    ),
  ];
}

http.Response _quote() => http.Response(
  jsonEncode({
    'totalSubtotal': 1000,
    'totalShippingPrice': 1000,
    'totalPrice': 2000,
    'shipmentSummaries': [],
  }),
  200,
);

Future<void> _showCheckout(
  WidgetTester tester,
  http.Client client, {
  AddressAutocompleteService? suggestions,
}) async {
  SharedPreferences.setMockInitialValues({'jwt_token': 'local-test-token'});
  await tester.binding.setSurfaceSize(const Size(1200, 3000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  addTearDown(client.close);
  final cart = CartProvider();
  cart.addProduct(
    Product(
      id: 'test-product',
      name: 'Rice',
      description: 'Local test fixture',
      price: 1000,
      category: 'Groceries',
      stockQuantity: 5,
      vendorId: '',
    ),
  );
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: cart,
      child: MaterialApp(
        home: CheckoutScreen(
          onOrderSuccess: () {},
          httpClient: client,
          autocompleteService: suggestions ?? _Suggestions(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

Future<void> _selectManual(WidgetTester tester) async {
  await tester.tap(find.text('Enter address manually'));
  await tester.pumpAndSettle();
  await tester.enterText(_field('Street address'), 'Wuse');
  await tester.pumpAndSettle();
  await tester.tap(find.text('12 Test Road, Wuse, Abuja'));
}

void main() {
  testWidgets(
    'suggestion automatically quotes its coordinates and stays manual',
    (tester) async {
      final quotes = <Map<String, dynamic>>[];
      final client = MockClient((request) async {
        if (request.url.path == '/api/auth/me') {
          return http.Response(jsonEncode({'deliveryAddresses': []}), 200);
        }
        expect(request.url.path, '/api/orders/summary');
        quotes.add(jsonDecode(request.body) as Map<String, dynamic>);
        return _quote();
      });
      await _showCheckout(tester, client);
      await _selectManual(tester);
      await tester.pumpAndSettle();
      expect(quotes, hasLength(1));
      expect(quotes.single['shippingAddress']['address'], '12 Test Road');
      expect(quotes.single['userLocation'], {
        'latitude': 9.08,
        'longitude': 7.46,
      });
      expect(find.text('Manual address'), findsOneWidget);
      expect(find.text('Current location'), findsNothing);
      expect(find.text('Ready'), findsOneWidget);
      await tester.tap(find.text('Use this address'));
      await tester.pumpAndSettle();
      expect(quotes, hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'missing postal code waits for completion then calculates total',
    (tester) async {
      final quotes = <Map<String, dynamic>>[];
      final client = MockClient((request) async {
        if (request.url.path == '/api/auth/me') {
          return http.Response(jsonEncode({'deliveryAddresses': []}), 200);
        }
        quotes.add(jsonDecode(request.body) as Map<String, dynamic>);
        return _quote();
      });
      await _showCheckout(
        tester,
        client,
        suggestions: _Suggestions(postalCode: ''),
      );
      await _selectManual(tester);
      await tester.pumpAndSettle();
      expect(quotes, isEmpty);
      expect(find.textContaining('Add postal code below'), findsOneWidget);
      await tester.enterText(_field('Postal code'), '900001');
      await tester.tap(find.text('Use this address'));
      await tester.pumpAndSettle();
      expect(quotes, hasLength(1));
      expect(quotes.single['userLocation']['latitude'], 9.08);
      expect(find.text('Ready'), findsOneWidget);
    },
  );

  testWidgets(
    'late quote cannot restore checkout after the address is edited',
    (tester) async {
      final reply = Completer<http.Response>();
      final client = MockClient((request) async {
        if (request.url.path == '/api/auth/me') {
          return http.Response(jsonEncode({'deliveryAddresses': []}), 200);
        }
        return reply.future;
      });
      await _showCheckout(tester, client);
      await _selectManual(tester);
      await tester.pump();
      await tester.enterText(_field('City'), 'Lagos');
      reply.complete(_quote());
      await tester.pumpAndSettle();
      expect(find.text('Ready'), findsNothing);
      expect(find.text('Required'), findsOneWidget);
      expect(
        find.text('Choose a delivery address to continue.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'switching saved addresses quotes the newly selected coordinates',
    (tester) async {
      final quotes = <Map<String, dynamic>>[];
      final client = MockClient((request) async {
        if (request.url.path == '/api/auth/me') {
          return http.Response(
            jsonEncode({
              'deliveryAddresses': [
                {
                  '_id': 'home',
                  'name': 'Home',
                  'address': '1 Home Road',
                  'city': 'Abuja',
                  'postalCode': '900001',
                  'country': 'Nigeria',
                  'latitude': 9.1,
                  'longitude': 7.1,
                  'isDefault': true,
                },
                {
                  '_id': 'office',
                  'name': 'Office',
                  'address': '2 Office Road',
                  'city': 'Abuja',
                  'postalCode': '900002',
                  'country': 'Nigeria',
                  'latitude': 9.2,
                  'longitude': 7.2,
                },
              ],
            }),
            200,
          );
        }
        quotes.add(jsonDecode(request.body) as Map<String, dynamic>);
        return _quote();
      });
      await _showCheckout(tester, client);
      await tester.tap(find.text('Choose saved address'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Office'));
      await tester.pumpAndSettle();
      expect(quotes, hasLength(2));
      expect(quotes.last['userLocation'], {'latitude': 9.2, 'longitude': 7.2});
      expect(quotes.last['shippingAddress']['address'], '2 Office Road');
    },
  );
}
