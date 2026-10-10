import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../tool/configure_google_sign_in.dart';

void main() {
  test('every CI workflow supplies the matching public Google clients', () {
    final yaml = File(
      'codemagic.yaml',
    ).readAsStringSync().replaceAll('\r\n', '\n');
    final environments = RegExp(
      r'^    environment:',
      multiLine: true,
    ).allMatches(yaml).length;
    expect(environments, 1);
    for (final entry in {
      'GOOGLE_SERVER_CLIENT_ID':
          '878060644963-ujmbu0ka7g3rh07muknotij2lbsaq4oh.apps.googleusercontent.com',
      'GOOGLE_IOS_CLIENT_ID':
          '878060644963-fidv0hop5uu6ekj6ee0tts9885jluoc8.apps.googleusercontent.com',
    }.entries) {
      final definition = RegExp(
        '^        ${entry.key}: "${RegExp.escape(entry.value)}"\u0024',
        multiLine: true,
      );
      expect(definition.allMatches(yaml).length, environments);
    }
  });
  test('supplied public iOS client produces its callback scheme', () {
    expect(
      googleIosCallbackScheme({
        'GOOGLE_SERVER_CLIENT_ID':
            '878060644963-ujmbu0ka7g3rh07muknotij2lbsaq4oh.apps.googleusercontent.com',
        'GOOGLE_IOS_CLIENT_ID':
            '878060644963-fidv0hop5uu6ekj6ee0tts9885jluoc8.apps.googleusercontent.com',
      }),
      'com.googleusercontent.apps.878060644963-fidv0hop5uu6ekj6ee0tts9885jluoc8',
    );
  });
  test('native iOS callback is wired into both build configurations', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains(r'$(GOOGLE_REVERSED_CLIENT_ID)'));
    for (final name in ['Debug', 'Release']) {
      final config = File('ios/Flutter/$name.xcconfig').readAsStringSync();
      expect(config, contains('GoogleSignIn.xcconfig'));
    }
    expect(File('tool/configure_google_sign_in.dart').existsSync(), isTrue);
  });
  test('checked-in iOS callback has valid URL scheme syntax', () {
    final config = File('ios/Flutter/GoogleSignIn.xcconfig').readAsStringSync();
    final scheme = config.split('GOOGLE_REVERSED_CLIENT_ID = ').last.trim();
    expect(RegExp(r'^[A-Za-z][A-Za-z0-9+.-]*$').hasMatch(scheme), isTrue);
  });
  test('generated iOS configuration contains real line breaks', () {
    expect(
      googleIosConfigContent('com.googleusercontent.apps.example'),
      '// Generated from public OAuth client IDs.\nGOOGLE_REVERSED_CLIENT_ID = com.googleusercontent.apps.example\n',
    );
  });
  test('unconfigured Google does not enable iOS sign-in', () {
    expect(googleIosCallbackScheme({}), isNull);
  });
  test('partial and malformed OAuth configuration fail closed', () {
    expect(
      () => googleIosCallbackScheme({
        'GOOGLE_SERVER_CLIENT_ID': 'server.apps.googleusercontent.com',
      }),
      throwsFormatException,
    );
    expect(
      () => googleIosCallbackScheme({
        'GOOGLE_SERVER_CLIENT_ID': 'server.apps.googleusercontent.com',
        'GOOGLE_IOS_CLIENT_ID': 'invalid',
      }),
      throwsFormatException,
    );
  });
  test('iOS callback derives only from the matching iOS client ID', () {
    expect(
      googleIosCallbackScheme({
        'GOOGLE_SERVER_CLIENT_ID': 'server.apps.googleusercontent.com',
        'GOOGLE_IOS_CLIENT_ID': '123456-example.apps.googleusercontent.com',
      }),
      'com.googleusercontent.apps.123456-example',
    );
  });
  for (final field in ['GOOGLE_SERVER_CLIENT_ID', 'GOOGLE_IOS_CLIENT_ID']) {
    test('missing OAuth field identifies the variable: $field', () {
      final environment = {
        'GOOGLE_SERVER_CLIENT_ID': 'server.apps.googleusercontent.com',
        'GOOGLE_IOS_CLIENT_ID': '123456-ios.apps.googleusercontent.com',
      }..remove(field);
      expect(
        () => googleIosCallbackScheme(environment),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('$field is missing'),
          ),
        ),
      );
    });
    test(
      'invalid OAuth field is identified without logging its value: $field',
      () {
        const malformed = 'do-not-log-this-value';
        final environment = {
          'GOOGLE_SERVER_CLIENT_ID': 'server.apps.googleusercontent.com',
          'GOOGLE_IOS_CLIENT_ID': '123456-ios.apps.googleusercontent.com',
          field: malformed,
        };
        expect(
          () => googleIosCallbackScheme(environment),
          throwsA(
            isA<FormatException>()
                .having(
                  (e) => e.message,
                  'message',
                  contains('$field is invalid'),
                )
                .having(
                  (e) => e.message,
                  'message',
                  isNot(contains(malformed)),
                ),
          ),
        );
      },
    );
  }
  test('surrounding whitespace is accepted while quoted IDs stay invalid', () {
    expect(
      googleIosCallbackScheme({
        'GOOGLE_SERVER_CLIENT_ID': ' server.apps.googleusercontent.com ',
        'GOOGLE_IOS_CLIENT_ID': ' 123456-ios.apps.googleusercontent.com ',
      }),
      'com.googleusercontent.apps.123456-ios',
    );
    expect(
      () => googleIosCallbackScheme({
        'GOOGLE_SERVER_CLIENT_ID': 'server.apps.googleusercontent.com',
        'GOOGLE_IOS_CLIENT_ID': '"123456-ios.apps.googleusercontent.com"',
      }),
      throwsFormatException,
    );
  });
}
