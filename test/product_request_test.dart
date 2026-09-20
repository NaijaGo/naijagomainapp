import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naija_go/services/product_request_service.dart';
import 'package:naija_go/screens/Main/product_requests_screen.dart';

const requestId = 'aaaaaaaaaaaaaaaaaaaaaaaa';
Map<String, dynamic> draft({String previewState = 'not_requested'}) => {
  'id': requestId,
  'query': 'purple canvas backpack',
  'notes': '',
  'state': 'draft',
  'revision': 0,
  'history': [],
  'preview': {
    'state': previewState,
    'canGenerate': true,
    'generation': 0,
    'purchasable': false,
  },
};
void main() {
  test(
    'request service authenticates and preserves encoded retry identity and search criteria',
    () async {
      final service = ProductRequestService(
        tokenReader: () async => 'test-token',
        client: MockClient((request) async {
          expect(request.url.path, '/api/product-requests/');
          expect(request.headers['Authorization'], 'Bearer test-token');
          final body = jsonDecode(request.body) as Map;
          expect(body['clientRequestId'], 'same-retry-id');
          expect(body['criteria']['maxPrice'], '20000');
          return http.Response(jsonEncode(draft()), 201);
        }),
      );
      addTearDown(service.dispose);
      expect(
        (await service.request(
          '',
          method: 'POST',
          body: {
            'query': 'bag & purse',
            'clientRequestId': 'same-retry-id',
            'criteria': {'maxPrice': '20000'},
          },
        ))['id'],
        requestId,
      );
    },
  );
  test('signed-out customers never send a private request', () async {
    final service = ProductRequestService(
      tokenReader: () async => null,
      client: MockClient((_) async {
        fail('No unauthenticated request.');
      }),
    );
    addTearDown(service.dispose);
    await expectLater(
      service.request(''),
      throwsA(isA<ProductRequestException>()),
    );
  });
  test(
    'raw backend errors and invalid JSON become a short connection message',
    () async {
      for (final body in [
        'not-json',
        jsonEncode({'message': 'private-provider-secret'}),
      ]) {
        final service = ProductRequestService(
          tokenReader: () async => 'test',
          client: MockClient((_) async => http.Response(body, 503)),
        );
        addTearDown(service.dispose);
        await expectLater(
          service.request(''),
          throwsA(
            predicate(
              (error) =>
                  error is ProductRequestException &&
                  !error.message.contains('private-provider-secret'),
            ),
          ),
        );
      }
    },
  );
  test(
    'only valid request notification identities are accepted and pending intents are consumed once',
    () {
      ProductRequestIntent.clear();
      expect(
        ProductRequestIntent.parse({
          'type': 'product_request',
          'requestId': requestId,
        }),
        requestId,
      );
      expect(
        ProductRequestIntent.parse({
          'relatedModel': 'ProductRequest',
          'relatedId': requestId,
        }),
        requestId,
      );
      expect(
        ProductRequestIntent.parse({
          'type': 'product_request',
          'requestId': 'https://example.invalid',
        }),
        isNull,
      );
      expect(
        ProductRequestIntent.parse({'type': 'order', 'requestId': requestId}),
        isNull,
      );
      ProductRequestIntent.receive({
        'type': 'product_request',
        'requestId': requestId,
      });
      expect(ProductRequestIntent.take(), requestId);
      expect(ProductRequestIntent.take(), isNull);
    },
  );
  testWidgets(
    'concept screen clearly labels non-inventory and requires consent before generation',
    (tester) async {
      tester.view.physicalSize = const Size(1100, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final calls = <http.Request>[];
      final service = ProductRequestService(
        tokenReader: () async => 'test',
        client: MockClient((request) async {
          calls.add(request);
          return http.Response(jsonEncode(draft()), 200);
        }),
      );
      addTearDown(service.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: ProductRequestScreen(requestId: requestId, service: service),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'AI-generated concept - not an actual product. Not for sale.',
        ),
        findsOneWidget,
      );
      expect(find.text('Add to cart'), findsNothing);
      expect(find.text('Request This Product'), findsOneWidget);
      final button = find.ancestor(
        of: find.text('Generate AI concept'),
        matching: find.byWidgetPredicate((widget) => widget is OutlinedButton),
      );
      expect(button, findsOneWidget);
      expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      expect(tester.widget<OutlinedButton>(button).onPressed, isNotNull);
      expect(calls.length, 1); // Loading alone never generates an image.
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(calls.length, 2);
      expect(calls.last.url.path, '/api/product-requests/$requestId/preview');
      expect(jsonDecode(calls.last.body)['aiConsent'], isTrue);
    },
  );
  testWidgets(
    'creating a private draft does not automatically submit or generate an image',
    (tester) async {
      final calls = <http.Request>[];
      final service = ProductRequestService(
        tokenReader: () async => 'test',
        client: MockClient((request) async {
          calls.add(request);
          return http.Response(jsonEncode(draft()), 201);
        }),
      );
      addTearDown(service.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: ProductRequestScreen(
            query: 'purple canvas backpack',
            service: service,
          ),
        ),
      );
      await tester.tap(find.text('Continue to request'));
      await tester.pumpAndSettle();
      expect(calls.length, 1);
      expect(calls.single.method, 'POST');
      expect(calls.single.url.path, '/api/product-requests/');
      expect(find.text('Private draft'), findsOneWidget);
    },
  );
}
