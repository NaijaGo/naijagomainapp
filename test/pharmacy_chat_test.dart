import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:naija_go/services/pharmacy_chat_service.dart';
import 'package:naija_go/screens/Main/chat_screen.dart';
import 'package:naija_go/widgets/pharmacy_chat_widgets.dart';

const sid = '000000000000000000000001';
const pharmacist = '000000000000000000000002';
Map<String, dynamic> row(String id, String text, {String role = 'user'}) => {
  'id': id,
  'text': text,
  'senderType': role,
  'session': sid,
  'createdAt': '2026-10-10T10:00:00Z',
};
Map<String, dynamic> history({
  String role = 'user',
  bool closed = false,
  List<Map<String, dynamic>> messages = const [],
}) => {
  'session': {
    '_id': sid,
    'pharmacist': pharmacist,
    'status': closed ? 'closed' : 'assigned',
  },
  'actorRole': role,
  'pharmacistName': 'Local Pharmacy',
  'messages': messages,
};

class LocalSocket extends io.Socket {
  Map<String, dynamic> snapshot;
  int connections = 0;
  LocalSocket(this.snapshot)
    : super(
        io.io('https://example.invalid', <String, dynamic>{
          'autoConnect': false,
          'forceNew': true,
        }).io,
        '/',
        <String, dynamic>{'autoConnect': false},
      );
  @override
  io.Socket connect() {
    connected = true;
    connections++;
    onevent({
      'data': ['connect', null],
    });
    return this;
  }

  @override
  void emitWithAck(
    String event,
    dynamic data, {
    Function? ack,
    bool binary = false,
  }) {
    if (event == 'join_chat') ack?.call({'success': true, ...snapshot});
  }

  void receive(Map<String, dynamic> data) => onevent({
    'data': ['new_message', data],
  });
  @override
  io.Socket disconnect() {
    connected = false;
    return this;
  }

  @override
  void dispose() {
    connected = false;
    clearListeners();
  }
}

Future<void> chat(
  WidgetTester tester,
  Future<void> Function(LocalSocket?) action, {
  bool authenticated = true,
  bool vendor = false,
  bool closed = false,
  bool resume = false,
  bool live = true,
  double width = 390,
  double scale = 1,
  double keyboard = 0,
  Future<http.Response> Function(http.Request)? send,
  List<http.Request>? requests,
  List<Map<String, dynamic>> messages = const [],
}) async {
  final snapshot = history(
    role: vendor ? 'pharmacist' : 'user',
    closed: closed,
    messages: messages,
  );
  final socket = live ? LocalSocket(snapshot) : null;
  await http.runWithClient(
    () async {
      SharedPreferences.setMockInitialValues(
        authenticated ? {'jwt_token': 'local-chat-fixture'} : {},
      );
      tester.view.physicalSize = Size(width, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              viewInsets: EdgeInsets.only(bottom: keyboard),
            ),
            child: child!,
          ),
          home: RepaintBoundary(
            key: const ValueKey('chat-preview'),
            child: ChatScreen(
              sessionId: resume ? null : sid,
              isPharmacistView: vendor,
              socketFactory: (_, _) => socket,
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      try {
        await action(socket);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    },
    () => MockClient((request) async {
      requests?.add(request);
      if (request.url.path == '/api/chat/active') {
        return http.Response(jsonEncode({'session': snapshot['session']}), 200);
      }
      if (request.url.path.endsWith('/messages')) {
        return http.Response(jsonEncode(snapshot), 200);
      }
      if (request.url.path == '/api/chat/send') {
        if (send != null) return send(request);
        final body = jsonDecode(request.body);
        return http.Response(
          jsonEncode({
            'success': true,
            'message': row(
              body['clientMessageId'],
              body['message'],
              role: vendor ? 'pharmacist' : 'user',
            ),
          }),
          200,
        );
      }
      return http.Response('{}', 404);
    }),
  );
}

void main() {
  test('retry IDs are valid and unique', () {
    final ids = List.generate(100, (_) => newPharmacyMessageId());
    expect(ids.toSet().length, 100);
    for (final id in ids) {
      expect(RegExp(r'^[a-f0-9]{24}$').hasMatch(id), true);
    }
  });
  test('history and socket confirmation replace one pending row', () {
    final list = <Map<String, dynamic>>[
      {'id': 'a', 'from': 'user', 'text': 'hello', 'status': 'pending'},
    ];
    mergePharmacyMessage(list, pharmacyMessage(row('a', 'hello'))!);
    mergePharmacyMessage(list, pharmacyMessage(row('a', 'hello'))!);
    expect(list.length, 1);
    expect(list.single['status'], 'sent');
  });
  test('late failure cannot downgrade confirmed delivery', () {
    final list = <Map<String, dynamic>>[pharmacyMessage(row('a', 'hello'))!];
    mergePharmacyMessage(list, {'id': 'a', 'status': 'failed'});
    expect(list.single['status'], 'sent');
  });
  test('newer history is ordered by time', () {
    final list = <Map<String, dynamic>>[];
    mergePharmacyMessage(list, {
      ...pharmacyMessage(row('b', 'later'))!,
      'createdAt': '2026-10-10T12:00:00Z',
    });
    mergePharmacyMessage(list, pharmacyMessage(row('a', 'earlier'))!);
    expect(list.map((e) => e['id']), ['a', 'b']);
  });
  test('unknown AI and malformed messages are ignored', () {
    expect(pharmacyMessage({'senderType': 'ai'}), null);
    expect(pharmacyMessage(null), null);
    expect(
      pharmacyMessage({'id': 'a', 'senderType': 'foreign', 'text': 'x'}),
      null,
    );
  });
  for (final code in [401, 402, 403, 409, 500]) {
    test('HTTP $code is not treated as a sent message', () async {
      await http.runWithClient(() async {
        await expectLater(
          sendPharmacyMessage(
            apiUrl: 'https://example.invalid',
            token: 'fixture',
            sessionId: sid,
            text: 'hello',
            clientMessageId: 'a',
          ),
          throwsA(isA<PharmacyChatSendException>()),
        );
      }, () => MockClient((_) async => http.Response('{}', code)));
    });
  }
  test('a success response must confirm the same session', () async {
    await http.runWithClient(
      () async {
        await expectLater(
          sendPharmacyMessage(
            apiUrl: 'https://example.invalid',
            token: 'fixture',
            sessionId: sid,
            text: 'hello',
            clientMessageId: 'a',
          ),
          throwsA(isA<PharmacyChatSendException>()),
        );
      },
      () => MockClient(
        (_) async => http.Response(
          jsonEncode({
            'success': true,
            'message': {...row('a', 'hello'), 'session': 'foreign'},
          }),
          200,
        ),
      ),
    );
  });
  testWidgets(
    'provided customer session opens without starting or buying access',
    (tester) async {
      final requests = <http.Request>[];
      await chat(tester, (socket) async {
        expect(find.text('Local Pharmacy'), findsOneWidget);
        expect(find.text('Live chat connected'), findsOneWidget);
        expect(requests.where((r) => r.method != 'GET'), isEmpty);
      }, requests: requests);
    },
  );
  testWidgets(
    'customer reopens active consultation even without online pharmacists',
    (tester) async {
      final requests = <http.Request>[];
      await chat(
        tester,
        (_) async {
          expect(find.text('Local Pharmacy'), findsOneWidget);
          expect(requests.any((r) => r.url.path == '/api/chat/active'), true);
          expect(requests.any((r) => r.url.path == '/api/chat/start'), false);
        },
        resume: true,
        requests: requests,
      );
    },
  );
  testWidgets('socket echo and HTTP acknowledgement share a single bubble', (
    tester,
  ) async {
    await chat(
      tester,
      (socket) async {
        await tester.enterText(
          find.byKey(const ValueKey('chat-composer')),
          'A local question',
        );
        await tester.pump();
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('chat-send')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        final saved = tester
            .widget<PharmacyMessageBubble>(
              find.byType(PharmacyMessageBubble).first,
            )
            .message;
        socket!.receive(row(saved['id'].toString(), 'A local question'));
        socket.receive(row(saved['id'].toString(), 'A local question'));
        await tester.pump();
        expect(find.text('A local question'), findsOneWidget);
        expect(find.text('Sent'), findsOneWidget);
      },
      send: (request) async {
        final body = jsonDecode(request.body);
        final m = row(
          body['clientMessageId'],
          body['message'],
        ); // Confirm through history/HTTP; duplicate socket event is covered below.
        return http.Response(jsonEncode({'success': true, 'message': m}), 200);
      },
    );
  });
  testWidgets('failed send can retry with exactly the same ID', (tester) async {
    final ids = <String>[];
    await chat(
      tester,
      (_) async {
        await tester.enterText(
          find.byKey(const ValueKey('chat-composer')),
          'Retry question',
        );
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('chat-send')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('Not confirmed'), findsOneWidget);
        await tester.tap(find.text('Retry'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('Retry question'), findsOneWidget);
        expect(ids.length, 2);
        expect(ids[0], ids[1]);
        expect(find.text('Sent'), findsOneWidget);
      },
      send: (request) async {
        final b = jsonDecode(request.body);
        ids.add(b['clientMessageId']);
        return ids.length == 1
            ? http.Response('{}', 500)
            : http.Response(
                jsonEncode({
                  'success': true,
                  'message': row(b['clientMessageId'], b['message']),
                }),
                200,
              );
      },
    );
  });
  testWidgets('socket event from another consultation is ignored', (
    tester,
  ) async {
    await chat(tester, (socket) async {
      socket!.receive({...row('a', 'Wrong session'), 'session': 'foreign'});
      socket.receive(row('b', 'Their reply', role: 'pharmacist'));
      socket.receive(row('b', 'Their reply', role: 'pharmacist'));
      await tester.pump();
      expect(find.text('Wrong session'), findsNothing);
      expect(find.text('Their reply'), findsOneWidget);
    });
  });
  testWidgets('reconnection history preserves a pending message', (
    tester,
  ) async {
    final completed = Completer<http.Response>();
    await chat(
      tester,
      (socket) async {
        await tester.enterText(
          find.byKey(const ValueKey('chat-composer')),
          'Pending question',
        );
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('chat-send')));
        await tester.pump();
        socket!.onclose('local-test');
        socket.snapshot = {
          ...socket.snapshot,
          'messages': [row('reply', 'Recovered reply', role: 'pharmacist')],
        };
        socket.connect();
        await tester.pump();
        expect(find.text('Pending question'), findsOneWidget);
        expect(find.text('Recovered reply'), findsOneWidget);
        completed.complete(
          http.Response(
            jsonEncode({
              'success': true,
              'message': row('placeholder', 'Pending question'),
            }),
            200,
          ),
        );
        await tester.pump();
      },
      send: (r) {
        final b = jsonDecode(r.body); // Save only a local fixture ID.
        return completed.future.then((response) {
          final data = jsonDecode(response.body);
          data['message']['id'] = b['clientMessageId'];
          return http.Response(jsonEncode(data), 200);
        });
      },
    );
  });
  testWidgets('REST refresh retrieves missed messages without a socket', (
    tester,
  ) async {
    await chat(
      tester,
      (_) async {
        await tester.tap(find.byKey(const ValueKey('chat-refresh')));
        await tester.pump();
        expect(find.text('Offline history'), findsOneWidget);
        expect(find.byKey(const ValueKey('chat-composer')), findsOneWidget);
      },
      live: false,
      messages: [row('a', 'Offline history', role: 'pharmacist')],
    );
  });
  testWidgets('closed consultation disables the composer', (tester) async {
    await chat(tester, (_) async {
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('chat-composer')),
      );
      expect(field.enabled, false);
      expect(find.text('Consultation closed'), findsWidgets);
    }, closed: true);
  });
  testWidgets('pharmacist messages are on the sender side', (tester) async {
    await chat(
      tester,
      (_) async {
        final bubble = tester.widget<PharmacyMessageBubble>(
          find.byType(PharmacyMessageBubble).first,
        );
        expect(bubble.myRole, 'pharmacist');
        expect(find.text('You'), findsOneWidget);
      },
      vendor: true,
      messages: [row('a', 'Local guidance', role: 'pharmacist')],
    );
  });
  testWidgets('chat fits a small screen, larger text and the keyboard', (
    tester,
  ) async {
    await chat(
      tester,
      (_) async {
        expect(tester.takeException(), null);
        await tester.enterText(
          find.byKey(const ValueKey('chat-composer')),
          'A short question\nSecond line',
        );
        await tester.pump();
        expect(tester.takeException(), null);
      },
      width: 320,
      scale: 1.5,
      keyboard: 280,
    );
  });
  testWidgets('signed-out chat makes no authenticated requests', (
    tester,
  ) async {
    final requests = <http.Request>[];
    await chat(
      tester,
      (_) async {
        expect(requests, isEmpty);
        expect(
          find.text('Authentication failed. Please log in again.'),
          findsOneWidget,
        );
      },
      authenticated: false,
      requests: requests,
    );
  });
  for (final pharmacistView in [false, true]) {
    testWidgets(
      'renders actual chat for visual review: pharmacist=$pharmacistView',
      (tester) async {
        final fonts = Platform.environment['NAIJAGO_CHAT_FONT_DIR'];
        if (fonts != null) {
          await tester.runAsync(() async {
            final text = FontLoader('Roboto');
            for (final name in [
              'roboto-regular.ttf',
              'roboto-bold.ttf',
              'roboto-black.ttf',
            ]) {
              text.addFont(
                Future.value(
                  ByteData.sublistView(
                    await File('$fonts/$name').readAsBytes(),
                  ),
                ),
              );
            }
            await text.load();
            final icons = FontLoader('MaterialIcons');
            icons.addFont(
              Future.value(
                ByteData.sublistView(
                  await File('$fonts/materialicons-regular.otf').readAsBytes(),
                ),
              ),
            );
            await icons.load();
          });
        }
        await chat(
          tester,
          (_) async {
            expect(tester.takeException(), isNull);
            final directory = Platform.environment['NAIJAGO_CHAT_PREVIEW_DIR'];
            if (directory != null) {
              final boundary = tester.renderObject<RenderRepaintBoundary>(
                find.byKey(const ValueKey('chat-preview')),
              );
              await tester.runAsync(() async {
                final image = await boundary.toImage(pixelRatio: 2);
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                await Directory(directory).create(recursive: true);
                final label = pharmacistView ? 'pharmacist' : 'customer';
                await File(
                  '$directory/naijago-$label-chat-preview.png',
                ).writeAsBytes(bytes!.buffer.asUint8List());
                image.dispose();
              });
            }
          },
          vendor: pharmacistView,
          messages: [
            row(
              '000000000000000000000010',
              'Hello, can I speak with a pharmacist?',
            ),
            row(
              '000000000000000000000011',
              'Hello! How can I help you today?',
              role: 'pharmacist',
            ),
            row(
              '000000000000000000000012',
              'I would like to ask about a product before ordering.',
            ),
            row(
              '000000000000000000000013',
              'Of course. Please share the product name.',
              role: 'pharmacist',
            ),
          ],
        );
      },
    );
  }
}
