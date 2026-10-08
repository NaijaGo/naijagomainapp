import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:naija_go/widgets/checkout_location_map.dart';
import 'helpers/location_tiles.dart';
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
          locationTileProvider: LocationTestTiles(),
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
  await tester.enterText(_field('Search delivery address'), 'Wuse');
  await tester.pumpAndSettle();
  await tester.tap(find.text('12 Test Road, Wuse, Abuja'));
}

class _PendingGps extends GeolocatorPlatform {
  final reply = Completer<Position>();
  @override
  Future<bool> isLocationServiceEnabled() async => true;
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;
  @override
  Future<LocationAccuracyStatus> getLocationAccuracy() async =>
      LocationAccuracyStatus.precise;
  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) =>
      reply.future;
}

class _ReverseReplies extends _Suggestions {
  final replies = <String, Completer<AddressSuggestion?>>{};
  @override
  Future<AddressSuggestion?> reverseGeocode(double lat, double lon) =>
      (replies['$lat,$lon'] ??= Completer<AddressSuggestion?>()).future;
}

AddressSuggestion _address(double lat, double lon, String street) =>
    AddressSuggestion(
      id: street,
      label: street,
      address: street,
      street: street,
      area: 'Gwarinpa',
      city: 'Abuja',
      state: 'FCT',
      country: 'Nigeria',
      postalCode: '',
      latitude: lat,
      longitude: lon,
    );
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
      await tester.tap(find.text('Confirm location'));
      await tester.pumpAndSettle();
      expect(quotes, hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'missing postal code is accepted; adding it preserves coordinates and requotes',
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
      expect(quotes, hasLength(1));
      expect(quotes.single['shippingAddress']['postalCode'], '');
      await tester.enterText(_field('Postal code (optional)'), '900001');
      await tester.tap(find.text('Confirm location'));
      await tester.pumpAndSettle();
      expect(quotes, hasLength(2));
      expect(quotes.last['userLocation']['latitude'], 9.08);
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

  testWidgets('GPS arriving after manual search cannot overwrite destination', (
    tester,
  ) async {
    final old = GeolocatorPlatform.instance;
    final gps = _PendingGps();
    GeolocatorPlatform.instance = gps;
    addTearDown(() => GeolocatorPlatform.instance = old);
    final quotes = <Map<String, dynamic>>[];
    final client = MockClient((request) async {
      if (request.url.path == '/api/auth/me')
        return http.Response(jsonEncode({'deliveryAddresses': []}), 200);
      quotes.add(jsonDecode(request.body));
      return _quote();
    });
    await _showCheckout(tester, client);
    await tester.tap(find.text('Use current location'));
    await tester.pump();
    await _selectManual(tester);
    await tester.pumpAndSettle();
    gps.reply.complete(
      Position(
        latitude: 8,
        longitude: 6,
        timestamp: DateTime.now(),
        accuracy: 5,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      ),
    );
    await tester.pumpAndSettle();
    expect(quotes, hasLength(1));
    expect(quotes.single['userLocation'], {
      'latitude': 9.08,
      'longitude': 7.46,
    });
    expect(find.text('Ready'), findsOneWidget);
  });
  testWidgets(
    'reverse A after pin B cannot overwrite B; summary and final payload agree',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final service = _ReverseReplies();
      final quotes = <Map<String, dynamic>>[];
      final orders = <Map<String, dynamic>>[];
      final client = MockClient((request) async {
        if (request.url.path == '/api/auth/me')
          return http.Response(jsonEncode({'deliveryAddresses': []}), 200);
        if (request.url.path == '/api/orders') {
          orders.add(jsonDecode(request.body));
          return http.Response(
            jsonEncode({'message': 'Isolated test stops before payment'}),
            400,
          );
        }
        expect(request.url.path, '/api/orders/summary');
        quotes.add(jsonDecode(request.body));
        return _quote();
      });
      await http.runWithClient(() async {
        await _showCheckout(tester, client, suggestions: service);
        tester
            .widget<CheckoutLocationMap>(find.byType(CheckoutLocationMap))
            .onSelected(const LatLng(9.1, 7.1));
        await tester.pump(const Duration(milliseconds: 601));
        tester
            .widget<CheckoutLocationMap>(find.byType(CheckoutLocationMap))
            .onSelected(const LatLng(9.2, 7.2));
        await tester.pump(const Duration(milliseconds: 601));
        service.replies['9.2,7.2']!.complete(_address(9.2, 7.2, 'B Road'));
        await tester.pumpAndSettle();
        service.replies['9.1,7.1']!.complete(_address(9.1, 7.1, 'A Road'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(_field('Street address')).controller!.text,
          'B Road',
        );
        await tester.enterText(_field('Street address'), 'B Road, gate 2');
        await tester.tap(find.text('Confirm location'));
        await tester.pumpAndSettle();
        expect(quotes.single['userLocation'], {
          'latitude': 9.2,
          'longitude': 7.2,
        });
        expect(quotes.single['shippingAddress']['address'], 'B Road, gate 2');
        await tester.ensureVisible(find.text('Place Order'));
        await tester.tap(find.text('Place Order'));
        await tester.pumpAndSettle();
        expect(orders, hasLength(1));
        expect(orders.single['userLocation'], quotes.single['userLocation']);
        expect(
          orders.single['shippingAddress'],
          quotes.single['shippingAddress'],
        );
        expect(tester.takeException(), isNull);
      }, () => client);
      debugDefaultTargetPlatformOverride = null;
    },
  );
  testWidgets('older autocomplete reply cannot replace newer results', (
    tester,
  ) async {
    final old = Completer<List<AddressSuggestion>>();
    final latest = Completer<List<AddressSuggestion>>();
    final service = _SearchReplies(old, latest);
    final client = MockClient(
      (request) async =>
          http.Response(jsonEncode({'deliveryAddresses': []}), 200),
    );
    await _showCheckout(tester, client, suggestions: service);
    await tester.tap(find.text('Enter address manually'));
    await tester.pumpAndSettle();
    await tester.enterText(_field('Search delivery address'), 'Old');
    await tester.pump();
    await tester.enterText(_field('Search delivery address'), 'Latest');
    await tester.pump(const Duration(milliseconds: 121));
    latest.complete([_address(9.2, 7.2, 'Latest Road')]);
    await tester.pumpAndSettle();
    old.complete([_address(9.1, 7.1, 'Old Road')]);
    await tester.pumpAndSettle();
    expect(find.text('Latest Road'), findsOneWidget);
    expect(find.text('Old Road'), findsNothing);
  });
}

class _SearchReplies extends _Suggestions {
  final Completer<List<AddressSuggestion>> old, latest;
  _SearchReplies(this.old, this.latest);
  @override
  Future<List<AddressSuggestion>> search(
    String query, {
    double? latitude,
    double? longitude,
  }) => query == 'Old' ? old.future : latest.future;
}
