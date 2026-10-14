import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:naija_go/auth/screens/apple_login_screen.dart';
import 'package:naija_go/auth/screens/login_screen.dart';
import 'package:naija_go/auth/screens/registration_screen.dart';
import 'package:naija_go/services/apple_auth_service.dart';
import 'package:naija_go/services/apple_customer_session.dart';

final nonce = 'a' * 64, challenge = 'b' * 64;
const session = {
  'token': 'fixture-session',
  'loginProvider': 'apple',
  'user': {
    'id': 'aaaaaaaaaaaaaaaaaaaaaaaa',
    'email': 'fixture@privaterelay.appleid.com',
  },
};
http.Response reply(int status, Map<String, dynamic> body) =>
    http.Response(jsonEncode(body), status);
Future<void> open(
  WidgetTester tester,
  Future<http.Response> Function(Map<String, dynamic>) request, {
  Future<AppleCredential?> Function(String)? authenticate,
  Future<http.Response> Function(Map<String, dynamic>)? challengeRequest,
  ValueChanged<Map<String, dynamic>?>? result,
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
                      builder: (_) => AppleLoginScreen(
                        deviceFingerprint: 'fixture-device',
                        request: request,
                        challengeRequest:
                            challengeRequest ??
                            (_) async => reply(200, {
                              'success': true,
                              'nonce': nonce,
                              'challengeId': challenge,
                            }),
                        authenticate:
                            authenticate ??
                            (n) async {
                              expect(n, nonce);
                              return const AppleCredential('fixture-identity');
                            },
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
  await tester.scrollUntilVisible(
    find.text(label),
    160,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => debugDefaultTargetPlatformOverride = null);
  testWidgets(
    'Apple session returns to existing flow after server verification only',
    (tester) async {
      Map<String, dynamic>? returned;
      await open(tester, (body) async {
        expect(body['idToken'], 'fixture-identity');
        expect(body['challengeId'], challenge);
        expect(body['app'], 'customer');
        expect(body['deviceFingerprint'], 'fixture-device');
        expect(body.containsKey('email'), false);
        expect(body.containsKey('phoneNumber'), false);
        return reply(200, session);
      }, result: (v) => returned = v);
      expect(returned?['token'], 'fixture-session');
      expect(find.text('Login fixture'), findsOneWidget);
    },
  );
  testWidgets('cancellation sends no Apple authentication POST', (
    tester,
  ) async {
    var posts = 0;
    await open(tester, (_) async {
      posts++;
      return reply(200, session);
    }, authenticate: (_) async => null);
    expect(posts, 0);
    expect(find.text('Login fixture'), findsOneWidget);
  });
  testWidgets(
    'signup preserves private relay email, asks terms, never requires phone or missing name',
    (tester) async {
      final bodies = <Map<String, dynamic>>[];
      await open(tester, (body) async {
        bodies.add(body);
        return bodies.length == 1
            ? reply(202, {
                'code': 'APPLE_PROFILE_REQUIRED',
                'profile': {'email': 'fixture@privaterelay.appleid.com'},
              })
            : reply(200, session);
      });
      expect(find.text('fixture@privaterelay.appleid.com'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
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
      final p = bodies.last['profile'] as Map;
      expect(p['acceptedTerms'], true);
      expect(p['firstName'], '');
      expect(p['lastName'], '');
      expect(p.containsKey('phoneNumber'), false);
    },
  );
  testWidgets(
    'existing account linking requires its password and does not invent identities',
    (tester) async {
      final bodies = <Map<String, dynamic>>[];
      await open(tester, (body) async {
        bodies.add(body);
        return bodies.length == 1
            ? reply(409, {'code': 'APPLE_LINK_REQUIRED'})
            : reply(200, session);
      });
      await tap(tester, 'Link and continue');
      expect(bodies.length, 1);
      await tester.enterText(find.byType(TextField), 'existing-password');
      await tap(tester, 'Link and continue');
      expect(bodies.last['linkPassword'], 'existing-password');
      expect(bodies.length, 2);
    },
  );
  testWidgets(
    'expired token triggers fresh challenge and authorization on explicit retry',
    (tester) async {
      var challenges = 0, authorizations = 0, posts = 0;
      await open(
        tester,
        (_) async {
          posts++;
          return posts == 1
              ? reply(401, {
                  'code': 'APPLE_TOKEN_INVALID',
                  'message': 'Please authorize again.',
                })
              : reply(200, session);
        },
        challengeRequest: (_) async {
          challenges++;
          return reply(200, {
            'success': true,
            'nonce': nonce,
            'challengeId': challenge,
          });
        },
        authenticate: (_) async {
          authorizations++;
          return const AppleCredential('fixture-identity');
        },
      );
      await tap(tester, 'Try again');
      expect(challenges, 2);
      expect(authorizations, 2);
      expect(posts, 2);
    },
  );
  testWidgets('network timeout never records success or blindly retries', (
    tester,
  ) async {
    var posts = 0;
    Map<String, dynamic>? returned;
    await open(tester, (_) async {
      posts++;
      throw TimeoutException('fixture');
    }, result: (v) => returned = v);
    expect(posts, 1);
    expect(returned, null);
    expect(find.textContaining('Unable to confirm sign-in'), findsOneWidget);
  });
  testWidgets('malformed success and challenge fail closed', (tester) async {
    await open(tester, (_) async => reply(200, {'token': 'fake', 'user': {}}));
    expect(find.textContaining('Unable to confirm sign-in'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    var auth = 0, posts = 0;
    await open(
      tester,
      (_) async {
        posts++;
        return reply(200, session);
      },
      challengeRequest: (_) async =>
          reply(200, {'success': true, 'nonce': 'bad'}),
      authenticate: (_) async {
        auth++;
        return null;
      },
    );
    expect(auth, 0);
    expect(posts, 0);
  });
  test(
    'Apple session storage/logout use existing session keys and no provider tokens or password',
    () async {
      SharedPreferences.setMockInitialValues({
        'user_password': 'old',
        'jwt_token': 'old-session',
      });
      var cleared = 0;
      String? pushId;
      await AppleCustomerSession.save(
        session,
        'fixture-device',
        clearPassword: () async {
          cleared++;
        },
        linkPush: (id) async => pushId = id,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('jwt_token'), 'fixture-session');
      expect(prefs.getString('auth_provider'), 'apple');
      expect(prefs.getString('user_password'), null);
      expect(prefs.getString('user_email'), 'fixture@privaterelay.appleid.com');
      expect(cleared, 1);
      expect(pushId, 'aaaaaaaaaaaaaaaaaaaaaaaa');
      expect(
        prefs.getKeys().any(
          (k) => k.contains('identity') || k.contains('nonce'),
        ),
        false,
      );
      await AppleCustomerSession.clear();
      expect(prefs.getString('jwt_token'), null);
      expect(prefs.getString('auth_provider'), null);
    },
  );
  test('unconfirmed Apple session cannot overwrite current session', () async {
    SharedPreferences.setMockInitialValues({'jwt_token': 'old'});
    await expectLater(
      AppleCustomerSession.save({'token': 'unverified'}, 'fixture'),
      throwsFormatException,
    );
    expect(
      (await SharedPreferences.getInstance()).getString('jwt_token'),
      'old',
    );
  });
  for (final width in [390.0, 820.0]) {
    testWidgets(
      'Apple login and registration buttons are visible on iOS at $width',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        tester.view.physicalSize = Size(width, 1180);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(home: LoginScreen(onLoginSuccess: () {})),
        );
        await tester.pumpAndSettle();
        expect(find.byType(SignInWithAppleButton), findsOneWidget);
        expect(find.text('Continue with Google'), findsOneWidget);
        await tester.pumpWidget(const MaterialApp(home: RegistrationScreen()));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byType(SignInWithAppleButton),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.byType(SignInWithAppleButton), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        debugDefaultTargetPlatformOverride = null;
      },
    );
  }
  test(
    'iOS capability is wired in every existing Xcode configuration and CI SDK supports the package',
    () {
      final entitlement = File(
        'ios/Runner/Runner.entitlements',
      ).readAsStringSync();
      expect(entitlement, contains('com.apple.developer.applesignin'));
      expect(entitlement, contains('<string>Default</string>'));
      final project = File(
        'ios/Runner.xcodeproj/project.pbxproj',
      ).readAsStringSync();
      expect(
        RegExp(
          r'CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements',
        ).allMatches(project).length,
        3,
      );
      expect(
        File('codemagic.yaml').readAsStringSync(),
        contains('flutter: 3.47.6'),
      );
      final main = File('lib/main.dart').readAsStringSync();
      expect(main, contains('await AppleCustomerSession.clear()'));
      expect(main, contains("prefs.getString('auth_provider') == 'apple'"));
    },
  );
}
