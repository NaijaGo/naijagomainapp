import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naija_go/services/explore_service.dart';

void main() {
  test('configuration does not send a customer token', () async {
    final service = ExploreService(client: MockClient((request) async {
      expect(request.url.path, '/api/explore/config');
      expect(request.headers.containsKey('authorization'), isFalse);
      return http.Response(jsonEncode({'enabled': true}), 200);
    }), tokenReader: () async => 'private-token');
    addTearDown(service.dispose);
    expect((await service.config())['enabled'], isTrue);
  });
  test('feed requests attach authentication and encode cursors', () async {
    final service = ExploreService(client: MockClient((request) async {
      expect(request.headers['authorization'], 'Bearer test-token');
      expect(request.url.queryParameters['before'], 'abc123');
      return http.Response(jsonEncode({'items': [], 'campaigns': []}), 200);
    }), tokenReader: () async => 'test-token');
    addTearDown(service.dispose);
    expect((await service.request('feed', query: {'before': 'abc123'}))['items'], isEmpty);
  });
  test('reaction clearing sends null rather than inventing a reaction', () async {
    final service = ExploreService(client: MockClient((request) async {
      expect(request.method, 'PUT');
      expect(jsonDecode(request.body), {'reaction': null});
      return http.Response(jsonEncode({'myReaction': null}), 200);
    }), tokenReader: () async => 'test-token');
    addTearDown(service.dispose);
    await service.request('items/product/id/reaction', method: 'PUT', body: {'reaction': null});
  });
  test('server stack traces are not displayed to the shopper', () async {
    final service = ExploreService(client: MockClient((_) async => http.Response(jsonEncode({'message': 'Database password secret'}), 503)), tokenReader: () async => 'test-token');
    addTearDown(service.dispose);
    await expectLater(service.request('feed'), throwsA(isA<ExploreException>().having((error) => error.message, 'safe message', isNot(contains('secret')))));
  });
  test('missing authentication fails before sending a request', () async {
    final service = ExploreService(client: MockClient((_) async => throw StateError('Must not send')), tokenReader: () async => null);
    addTearDown(service.dispose);
    await expectLater(service.request('feed'), throwsA(isA<ExploreException>()));
  });
}
