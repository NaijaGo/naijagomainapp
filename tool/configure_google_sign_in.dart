import 'dart:io';

/// Public OAuth IDs only. Keep Google client secrets off the app/device.
String? googleIosCallbackScheme(Map<String, String> environment) {
  final server = (environment['GOOGLE_SERVER_CLIENT_ID'] ?? '').trim();
  final ios = (environment['GOOGLE_IOS_CLIENT_ID'] ?? '').trim();
  if (server.isEmpty && ios.isEmpty) return null;
  final valid = RegExp(r'^[A-Za-z0-9-]+\.apps\.googleusercontent\.com$');
  for (final entry in {
    'GOOGLE_SERVER_CLIENT_ID': server,
    'GOOGLE_IOS_CLIENT_ID': ios,
  }.entries) {
    if (entry.value.isEmpty) {
      throw FormatException(
        '${entry.key} is missing. Add its public OAuth client ID to the environment variables of this Codemagic workflow.',
      );
    }
    if (!valid.hasMatch(entry.value)) {
      throw FormatException(
        '${entry.key} is invalid. Paste only the client ID ending in .apps.googleusercontent.com, without quotes, a variable name, JSON or a client secret.',
      );
    }
  }
  return 'com.googleusercontent.apps.${ios.split('.').first}';
}

String googleIosConfigContent(String scheme) =>
    '// Generated from public OAuth client IDs.\nGOOGLE_REVERSED_CLIENT_ID = $scheme\n';

void main() {
  try {
    final scheme = googleIosCallbackScheme(Platform.environment);
    if (scheme == null) {
      stdout.writeln(
        'Google sign-in is disabled: public OAuth IDs have not been configured.',
      );
      return;
    }
    final config = File('ios/Flutter/GoogleSignIn.xcconfig');
    if (!config.existsSync()) {
      throw const FileSystemException('Run from the Flutter repository root.');
    }
    config.writeAsStringSync(googleIosConfigContent(scheme));
    stdout.writeln('Google iOS callback configuration prepared.');
  } on FormatException catch (error) {
    stderr.writeln('Google configuration is invalid: ${error.message}');
    exitCode = 1;
  } on FileSystemException {
    stderr.writeln(
      'Cannot prepare the Google iOS callback file. Run the Pre-build script from the Flutter project root and check that ios/Flutter/GoogleSignIn.xcconfig exists and is writable.',
    );
    exitCode = 1;
  } catch (_) {
    stderr.writeln('Google iOS configuration could not be prepared.');
    exitCode = 1;
  }
}
