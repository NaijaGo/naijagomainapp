import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:naija_go/services/planned_order_service.dart';

class _TestClient extends http.BaseClient {
  _TestClient(this.handler);
  final Future<http.Response> Function(http.Request request) handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await handler(request as http.Request);
    return http.StreamedResponse(
      Stream.value(utf8.encode(response.body)),
      response.statusCode,
      headers: response.headers,
      reasonPhrase: response.reasonPhrase,
      request: request,
    );
  }
}

void main() {
  const id = '000000000000000000000001';

  test('public config does not read or send authentication', () async {
    var tokenReads = 0;
    late http.Request captured;
    final service = PlannedOrderService(
      tokenReader: () async {
        tokenReads++;
        return 'private-token';
      },
      client: _TestClient((request) async {
        captured = request;
        return http.Response(jsonEncode({
          'groupOrderingEnabled': true,
          'recurringOrdersEnabled': true,
          'scheduledDeliveryEnabled': false,
          'automaticPaymentsEnabled': false,
        }), 200);
      }),
    );
    addTearDown(service.dispose);

    final config = await service.config();
    expect(config['groupOrderingEnabled'], isTrue);
    expect(config['recurringOrdersEnabled'], isTrue);
    expect(config['scheduledDeliveryEnabled'], isFalse);
    expect(config['automaticPaymentsEnabled'], isFalse);
    expect(tokenReads, 0);
    expect(captured.method, 'GET');
    expect(captured.url.path, '/api/planned-orders/config');
    expect(captured.headers.containsKey('Authorization'), isFalse);
  });

  test(
    'invite rotation sends only authenticated id and revision fields',
    () async {
      late http.Request captured;
      final service = PlannedOrderService(
        tokenReader: () async => 'customer-token',
        client: _TestClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'group': {'id': id},
              'inviteToken': 'private',
            }),
            200,
          );
        }),
      );
      addTearDown(service.dispose);

      final result = await service.rotateGroupInvite(id, revision: 7);
      expect(result['inviteToken'], 'private');
      expect(captured.method, 'POST');
      expect(captured.url.path, '/api/planned-orders/groups/$id/invite');
      expect(captured.headers['Authorization'], 'Bearer customer-token');
      expect(jsonDecode(captured.body), {'revision': 7});
    },
  );

  test(
    'pagination omits a null cursor and keeps its bounded page size',
    () async {
      late http.Request captured;
      final service = PlannedOrderService(
        tokenReader: () async => 'customer-token',
        client: _TestClient((request) async {
          captured = request;
        return http.Response(jsonEncode({'groups': <dynamic>[]}), 200);
        }),
      );
      addTearDown(service.dispose);

      await service.groups();
      expect(captured.url.queryParameters, {'limit': '20'});
    },
  );

  test(
    'authentication and server failures stay concise and redact bodies',
    () async {
      var calls = 0;
      final signedOut = PlannedOrderService(
        tokenReader: () async => null,
        client: _TestClient((_) async {
          calls++;
          return http.Response('{}', 200);
        }),
      );
      addTearDown(signedOut.dispose);
      await expectLater(
        signedOut.groups(),
        throwsA(
          isA<PlannedOrderException>().having(
            (error) => error.message,
            'message',
            'Please sign in to use planned orders.',
          ),
        ),
      );
      expect(calls, 0);

      final unavailable = PlannedOrderService(
        tokenReader: () async => 'customer-token',
        client: _TestClient(
          (_) async => http.Response(
            '{message:mongodb://private-user:private-password@example.invalid}',
            500,
          ),
        ),
      );
      addTearDown(unavailable.dispose);
      await expectLater(
        unavailable.groups(),
        throwsA(
          isA<PlannedOrderException>()
              .having(
                (error) => error.message,
                'message',
                contains('Check your connection'),
              )
              .having(
                (error) => error.message,
                'redacted',
                isNot(contains('private-password')),
              ),
        ),
      );
    },
  );

  test('HTML config 404 is reported as not deployed without parsing the body', () async {
    final service = PlannedOrderService(
      client: _TestClient((_) async => http.Response('<html>Not found</html>', 404)),
    );
    addTearDown(service.dispose);
    await expectLater(service.config(), throwsA(isA<PlannedOrderException>().having(
      (error) => error.code, 'code', 'PLANNED_ORDERS_NOT_DEPLOYED',
    )));
  });

  test('known disabled response is distinct from a generic server failure', () async {
    final service = PlannedOrderService(
      tokenReader: () async => 'customer-token',
      client: _TestClient((_) async => http.Response(jsonEncode({
        'code': 'PLANNED_ORDERS_DISABLED',
        'message': 'Normal checkout is available.',
      }), 503)),
    );
    addTearDown(service.dispose);
    await expectLater(service.groups(), throwsA(isA<PlannedOrderException>().having(
      (error) => error.message, 'message', 'Normal checkout is available.',
    )));
  });

  test('notification intents route group and recurring records safely', () {
    final group = PlannedOrderIntent.parse({
      'type': 'group_order_update',
      'plannedOrder': {'kind': 'group', 'id': id},
    });
    expect(group?.kind, 'group');
    expect(group?.id, id);

    final recurring = PlannedOrderIntent.parse({
      'type': 'recurring_order_update',
      'planId': id,
      'recordId': '000000000000000000000099',
    });
    expect(recurring?.kind, 'recurring');
    expect(recurring?.id, id);
    expect(
      PlannedOrderIntent.parse({
        'type': 'group_order_update',
        'recordId': 'not-an-object-id',
      }),
      isNull,
    );

    PlannedOrderIntent.clear();
    PlannedOrderIntent.receive({'relatedModel': 'GroupOrder', 'relatedId': id});
    expect(PlannedOrderIntent.take()?.id, id);
    expect(PlannedOrderIntent.take(), isNull);
  });
}
