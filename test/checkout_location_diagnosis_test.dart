import 'helpers/location_tiles.dart';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naija_go/models/product.dart';
import 'package:naija_go/providers/cart_provider.dart';
import 'package:naija_go/screens/Main/checkout_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Synthetic GPS/provider boundaries only; these are not customer coordinates.
class _Gps extends GeolocatorPlatform {
  @override
  Future<bool> isLocationServiceEnabled() async => true;
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;
  @override
  Future<LocationAccuracyStatus> getLocationAccuracy() async =>
      LocationAccuracyStatus.precise;
  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async => Position(
    latitude: 9.08,
    longitude: 7.46,
    timestamp: DateTime.now(),
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

void main() {
  for (final status in [200, 422]) {
    testWidgets(
      'current GPS preserves coordinates through summary HTTP $status without postal code',
      (tester) async {
        final oldGps = GeolocatorPlatform.instance;
        GeolocatorPlatform.instance = _Gps();
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        addTearDown(() {
          GeolocatorPlatform.instance = oldGps;
          debugDefaultTargetPlatformOverride = null;
        });
        SharedPreferences.setMockInitialValues({
          'jwt_token': 'local-test-token',
        });
        await tester.binding.setSurfaceSize(const Size(1200, 3000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final quotes = <Map<String, dynamic>>[];
        final client = MockClient((request) async {
          if (request.url.path == '/api/auth/me') {
            return http.Response(jsonEncode({'deliveryAddresses': []}), 200);
          }
          if (request.url.path == '/api/locations/reverse') {
            expect(request.url.queryParameters['lat'], '9.08');
            expect(request.url.queryParameters['lng'], '7.46');
            return http.Response(
              jsonEncode({
                'address': {
                  'addressLine': '3rd Avenue',
                  'city': 'Abuja',
                  'country': 'Nigeria',
                  'postalCode': '',
                  'latitude': 9.08,
                  'longitude': 7.46,
                },
              }),
              200,
            );
          }
          expect(request.url.path, '/api/orders/summary');
          expect(request.method, 'POST');
          quotes.add(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response(
            jsonEncode(
              status == 200
                  ? {
                      'totalSubtotal': 1000,
                      'totalShippingPrice': 1250,
                      'totalPrice': 2250,
                      'shipmentSummaries': [],
                    }
                  : {
                      'message':
                          'This location is outside the current delivery area.',
                    },
            ),
            status,
          );
        });
        addTearDown(client.close);
        final cart = CartProvider()
          ..addProduct(
            Product(
              id: 'test-product',
              name: 'Rice',
              description: 'Local fixture',
              price: 1000,
              category: 'Groceries',
              stockQuantity: 5,
              vendorId: '',
            ),
          );
        try {
          await http.runWithClient(() async {
            await tester.pumpWidget(
              ChangeNotifierProvider.value(
                value: cart,
                child: MaterialApp(
                  home: CheckoutScreen(
                    locationTileProvider: LocationTestTiles(),
                    onOrderSuccess: () {},
                    httpClient: client,
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            await tester.tap(find.text('Use current location'));
            await tester.pumpAndSettle();
            expect(quotes, hasLength(1));
            expect(quotes.single['userLocation'], {
              'latitude': 9.08,
              'longitude': 7.46,
            });
            expect(quotes.single['shippingAddress']['address'], '3rd Avenue');
            expect(quotes.single['shippingAddress']['postalCode'], '');
            if (status == 422) {
              expect(
                find.text(
                  'This location is outside the current delivery area.',
                ),
                findsOneWidget,
              );
            }
            expect(tester.takeException(), isNull);
          }, () => client);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  }
}
