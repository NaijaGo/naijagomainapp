import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naija_go/screens/Main/home_screen.dart';

void main() {
  test('search sends one combined, encoded query and keeps server pagination', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/products/search');
      expect(request.url.queryParameters, {
        'q': 'women clothes & bags', 'format': 'discovery', 'limit': '30',
        'page': '2', 'sort': 'price_low', 'category': 'Fashion',
        'minPrice': '10000.0', 'maxPrice': '50000.0', 'minRating': '4.0',
        'inStock': 'true', 'productType': 'bag',
      });
      return http.Response(jsonEncode({
        'products': [], 'total': 65, 'page': 2, 'hasMore': true,
        'collection': {'title': 'Women Fashion', 'chips': [{'key': 'bag', 'label': 'Bags', 'count': 65}]},
      }), 200);
    });
    addTearDown(client.close);
    final result = await ProductService(searchClient: client).searchProducts(
      'women clothes & bags', category: 'Fashion', minPrice: 10000,
      maxPrice: 50000, minRating: 4, inStock: true, sort: 'price_low',
      page: 2, productType: 'bag',
    );
    expect(result.total, 65);
    expect(result.page, 2);
    expect(result.hasMore, isTrue);
    expect(result.collection?['title'], 'Women Fashion');
  });

  test('a backend failure is not interpreted as an empty catalog', () async {
    final client = MockClient((_) async => http.Response('unavailable', 503));
    addTearDown(client.close);
    await expectLater(ProductService(searchClient: client).searchProducts('iPhone'), throwsException);
  });
}
