import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naija_go/screens/Main/home_screen.dart';

void main() {
  test(
    'search sends one combined, encoded query and keeps server pagination',
    () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/products/search');
        expect(request.url.queryParameters, {
          'q': 'women clothes & bags',
          'format': 'discovery',
          'limit': '30',
          'ai': 'true',
          'page': '2',
          'sort': 'price_low',
          'category': 'Fashion',
          'minPrice': '10000.0',
          'maxPrice': '50000.0',
          'minRating': '4.0',
          'inStock': 'true',
          'productType': 'bag',
        });
        return http.Response(
          jsonEncode({
            'products': [],
            'total': 65,
            'page': 2,
            'hasMore': true,
            'externalAnswer': '',
            'externalSources': [],
            'collection': {
              'title': 'Women Fashion',
              'chips': [
                {'key': 'bag', 'label': 'Bags', 'count': 65},
              ],
            },
          }),
          200,
        );
      });
      addTearDown(client.close);
      final result = await ProductService(searchClient: client).searchProducts(
        'women clothes & bags',
        category: 'Fashion',
        minPrice: 10000,
        maxPrice: 50000,
        minRating: 4,
        inStock: true,
        sort: 'price_low',
        page: 2,
        productType: 'bag',
      );
      expect(result.total, 65);
      expect(result.page, 2);
      expect(result.hasMore, isTrue);
      expect(result.collection?['title'], 'Women Fashion');
    },
  );

  test('a backend failure is not interpreted as an empty catalog', () async {
    final client = MockClient((_) async => http.Response('unavailable', 503));
    addTearDown(client.close);
    try {
      await ProductService(searchClient: client).searchProducts('iPhone');
      fail('Expected server failure');
    } on CatalogSearchException catch (error) {
      expect(error.kind, CatalogSearchFailure.server);
      expect(error.userMessage, 'Search is temporarily unavailable. Please try again.');
    }
  });

  test('successful empty results remain an empty state, not an error', () async {
    final client = MockClient((_) async => http.Response(
          jsonEncode({'products': [], 'total': 0, 'page': 1, 'hasMore': false}),
          200,
        ));
    addTearDown(client.close);
    final result = await ProductService(searchClient: client).searchProducts('no such product');
    expect(result.products, isEmpty);
    expect(result.total, 0);
    expect(result.page, 1);
    expect(result.hasMore, isFalse);
  });

  test('grounded fallback remains separate and visibly labeled as external', () async {
    final client = MockClient((_) async => http.Response(
          jsonEncode({
            'products': [],
            'total': 0,
            'page': 1,
            'hasMore': false,
            'externalAnswer': 'Check these cited external sources.',
            'externalLabel': 'External information - not a NaijaGo listing.',
            'externalSources': [
              {'title': 'Example source', 'url': 'https://example.com/source'},
            ],
          }),
          200,
        ));
    addTearDown(client.close);
    final result = await ProductService(searchClient: client).searchProducts('plumber Gwarinpa');
    expect(result.products, isEmpty);
    expect(result.externalAnswer, 'Check these cited external sources.');
    expect(result.externalLabel, 'External information - not a NaijaGo listing.');
    expect(result.externalSources.single['url'], 'https://example.com/source');
  });

  test('network failure is distinguished from server failure', () async {
    final client = MockClient((_) async => throw http.ClientException('socket detail'));
    addTearDown(client.close);
    try {
      await ProductService(searchClient: client).searchProducts('rice');
      fail('Expected network failure');
    } on CatalogSearchException catch (error) {
      expect(error.kind, CatalogSearchFailure.network);
      expect(error.userMessage, isNot(contains('socket detail')));
    }
  });

  test('malformed backend input is handled as a safe validation message', () async {
    final client = MockClient((_) async => http.Response('{"message":"raw internal detail"}', 400));
    addTearDown(client.close);
    try {
      await ProductService(searchClient: client).searchProducts('(');
      fail('Expected invalid input');
    } on CatalogSearchException catch (error) {
      expect(error.kind, CatalogSearchFailure.invalidInput);
      expect(error.userMessage, isNot(contains('raw internal detail')));
    }
  });

  test(
    'smart matching can be disabled and interpreted results are identified',
    () async {
      final client = MockClient((request) async {
        expect(request.url.queryParameters['ai'], 'false');
        return http.Response(
          jsonEncode({'products': [], 'interpretation': 'gemini_intent'}),
          200,
        );
      });
      addTearDown(client.close);
      final result = await ProductService(
        searchClient: client,
      ).searchProducts('linen frock', allowSmartMatching: false);
      expect(result.interpretation, 'gemini_intent');
    },
  );
}
