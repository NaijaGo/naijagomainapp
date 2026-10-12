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
import 'package:naija_go/theme/app_theme.dart';
import 'helpers/location_tiles.dart';
import 'helpers/premium_preview.dart';

void main() {
  for (final scale in [1.0, 1.3]) {
    testWidgets(
      'checkout keeps server quote and actions at phone width, text scale $scale',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'jwt_token': 'local-test-token',
        });
        tester.view.physicalSize = Size(scale == 1 ? 390 : 320, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final requests = <String>[];
        final client = MockClient((request) async {
          requests.add(request.url.path);
          if (request.url.path == '/api/auth/me') {
            return http.Response(
              jsonEncode({
                'userWalletBalance': 3000,
                'deliveryAddresses': [
                  {
                    '_id': 'fixture-address',
                    'name': 'Local customer',
                    'phoneNumber': '08000000000',
                    'addressLine': '12 Test Road, Wuse',
                    'street': '12 Test Road',
                    'area': 'Wuse',
                    'city': 'Abuja',
                    'state': 'FCT',
                    'zipCode': '900001',
                    'country': 'Nigeria',
                    'latitude': 9.08,
                    'longitude': 7.46,
                    'isDefault': true,
                  },
                ],
              }),
              200,
            );
          }
          if (request.url.path == '/api/orders/summary') {
            return http.Response(
              jsonEncode({
                'totalSubtotal': 200,
                'totalShippingPrice': 875,
                'totalPrice': 1075,
                'shipmentSummaries': [],
                'deliveryFeePolicy': {
                  'pricingMode': 'road_km',
                  'route': {'distanceKm': 5},
                  'consolidatedFee': {'baseFee': 300, 'distanceFee': 575},
                },
              }),
              200,
            );
          }
          throw StateError(
            'Unexpected request in isolated layout test: ${request.url.path}',
          );
        });
        addTearDown(client.close);
        final cart = CartProvider()
          ..addProduct(
            Product(
              id: 'fixture-product',
              name: 'Rice',
              description: 'Local layout fixture',
              price: 200,
              category: 'Groceries',
              stockQuantity: 5,
              vendorId: '',
            ),
          );
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: cart,
            child: MaterialApp(
              theme: await previewTheme(tester, AppTheme.lightTheme),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: RepaintBoundary(
                key: const ValueKey('checkout-preview'),
                child: CheckoutScreen(
                  onOrderSuccess: () {},
                  httpClient: client,
                  locationTileProvider: LocationTestTiles(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(requests, ['/api/auth/me', '/api/orders/summary']);
        expect(find.text('Checkout'), findsOneWidget);
        expect(find.text('Place Order'), findsOneWidget);
        expect(find.textContaining('1,075.00'), findsWidgets);
        expect(tester.takeException(), isNull);
        await savePremiumPreview(
          tester,
          const ValueKey('checkout-preview'),
          'checkout-$scale',
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }
}
