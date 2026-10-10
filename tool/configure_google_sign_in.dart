import 'dart:io';

/// Public OAuth IDs only. Keep Google client secrets off the app/device.
String? googleIosCallbackScheme(Map<String, String> environment) {
  final server = (environment['GOOGLE_SERVER_CLIENT_ID'] ?? '').trim();
  final ios = (environment['GOOGLE_IOS_CLIENT_ID'] ?? '').trim();
  if (server.isEmpty && ios.isEmpty) return null;
  final valid = RegExp(r'^[A-Za-z0-9-]+\.apps\.googleusercontent\.com$');
  if (!valid.hasMatch(server) || !valid.hasMatch(ios)) {
    throw const FormatException(
      'Both public Google server and iOS OAuth client IDs are required.',
    );
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
  } catch (_) {
    stderr.writeln(
      'Google configuration is invalid. Configure GOOGLE_SERVER_CLIENT_ID and GOOGLE_IOS_CLIENT_ID with public OAuth client IDs.',
    );
    exitCode = 1;
  }
}
