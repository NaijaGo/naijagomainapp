import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:naija_go/auth/screens/google_login_screen.dart';
import 'package:naija_go/services/google_auth_service.dart';

http.Response reply(int status, Map<String, dynamic> data) =>
    http.Response(jsonEncode(data), status);
const profile = {
  'code': 'GOOGLE_PROFILE_REQUIRED',
  'profile': {
    'firstName': 'Local',
    'lastName': 'Fixture',
    'email': 'localfixture@gmail.com',
  },
};
const session = {
  'token': 'local-session',
  'user': {'id': 'local-user', 'email': 'localfixture@gmail.com'},
};

Future<void> open(
  WidgetTester tester,
  Future<http.Response> Function(Map<String, dynamic>) request, {
  Future<String?> Function()? authenticate,
  void Function(Map<String, dynamic>?)? result,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              final value = await Navigator.of(context)
                  .push<Map<String, dynamic>>(
                    MaterialPageRoute(
                      builder: (_) => GoogleLoginScreen(
                        app: 'customer',
                        deviceFingerprint: 'local-device',
                        oneSignalPlayerId: 'local-push',
                        authenticate:
                            authenticate ?? () async => 'local-google-token',
                        request: request,
                      ),
                    ),
                  );
              result?.call(value);
            },
            child: const Text('Login fixture'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Login fixture'));
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Google session is returned to existing login flow', (
    tester,
  ) async {
    Map<String, dynamic>? returned;
    await open(tester, (body) async {
      expect(body['idToken'], 'local-google-token');
      expect(body['deviceFingerprint'], 'local-device');
      expect(body.containsKey('email'), false);
      expect(body.containsKey('isVendor'), false);
      return reply(200, session);
    }, result: (value) => returned = value);
    expect(returned?['token'], 'local-session');
    expect(find.text('Login fixture'), findsOneWidget);
  });
  testWidgets(
    'signup collects phone and explicit terms without inventing email',
    (tester) async {
      final bodies = <Map<String, dynamic>>[];
      await open(tester, (body) async {
        bodies.add(body);
        return reply(
          bodies.length == 1 ? 202 : 200,
          bodies.length == 1 ? profile : session,
        );
      });
      expect(find.text('localfixture@gmail.com'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).at(2), '08012345678');
      await tap(tester, 'Create account');
      expect(bodies.length, 1);
      expect(
        find.text('Please accept the terms to create your account.'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tap(tester, 'Create account');
      expect(bodies.length, 2);
      final values = bodies.last['profile'] as Map;
      expect(values['phoneNumber'], '08012345678');
      expect(values['acceptedTerms'], true);
      expect(values.containsKey('email'), false);
    },
  );
  testWidgets('invalid phone does not submit signup', (tester) async {
    var calls = 0;
    await open(tester, (_) async {
      calls++;
      return reply(202, profile);
    });
    await tester.enterText(find.byType(TextFormField).at(2), 'invalid');
    await tap(tester, 'Create account');
    expect(calls, 1);
    expect(find.text('Enter a valid Nigerian phone number'), findsOneWidget);
  });
  testWidgets('existing account requires explicit password linking', (
    tester,
  ) async {
    final bodies = <Map<String, dynamic>>[];
    await open(tester, (body) async {
      bodies.add(body);
      return reply(
        bodies.length == 1 ? 409 : 200,
        bodies.length == 1 ? {'code': 'GOOGLE_LINK_REQUIRED'} : session,
      );
    });
    await tester.enterText(find.byType(TextFormField), 'existing-password');
    await tap(tester, 'Link and continue');
    expect(bodies.last['linkPassword'], 'existing-password');
    expect(bodies.last.containsKey('profile'), false);
  });
  testWidgets('device verification response remains retryable', (tester) async {
    var calls = 0;
    await open(tester, (_) async {
      calls++;
      return reply(
        calls == 1 ? 403 : 200,
        calls == 1
            ? {
                'code': 'DEVICE_VERIFICATION_REQUIRED',
                'message': 'Verify this device by email.',
              }
            : session,
      );
    });
    expect(find.text('Verify this device by email.'), findsOneWidget);
    await tap(tester, 'Try again');
    expect(calls, 2);
  });
  testWidgets('malformed success never establishes a session', (tester) async {
    await open(
      tester,
      (_) async => reply(200, {
        'user': {'id': 'local-user'},
      }),
    );
    expect(
      find.text(
        'Unable to connect right now. Please try again or use email and password.',
      ),
      findsOneWidget,
    );
  });
  testWidgets('cancellation returns to login without sending a request', (
    tester,
  ) async {
    var calls = 0;
    await open(tester, (_) async {
      calls++;
      return reply(200, session);
    }, authenticate: () async => null);
    expect(calls, 0);
    expect(find.text('Login fixture'), findsOneWidget);
  });
  testWidgets('missing configuration gives email password fallback', (
    tester,
  ) async {
    await open(
      tester,
      (_) async => reply(200, session),
      authenticate: GoogleAuthService.idToken,
    );
    expect(
      find.text(
        'Google sign-in is not available yet. Please use email and password.',
      ),
      findsOneWidget,
    );
    await tap(tester, 'Back to login');
    expect(find.text('Login fixture'), findsOneWidget);
  });
  testWidgets('pending request disables duplicate submission', (tester) async {
    final completion = Completer<http.Response>();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: GoogleLoginScreen(
          app: 'customer',
          deviceFingerprint: 'local-device',
          authenticate: () async => 'local-token',
          request: (_) {
            calls++;
            return completion.future;
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(calls, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    completion.complete(reply(503, {'message': 'Try later.'}));
    await tester.pumpAndSettle();
    expect(calls, 1);
  });
  testWidgets('late response does not update disposed screen', (tester) async {
    final completion = Completer<http.Response>();
    await tester.pumpWidget(
      MaterialApp(
        home: GoogleLoginScreen(
          app: 'customer',
          deviceFingerprint: 'local-device',
          authenticate: () async => 'local-token',
          request: (_) => completion.future,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: Text('Different screen')));
    completion.complete(reply(503, {'message': 'Try later.'}));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
