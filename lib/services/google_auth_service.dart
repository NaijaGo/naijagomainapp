import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthUnavailable implements Exception {
  final String message;
  const GoogleAuthUnavailable(this.message);
}

/// OAuth client IDs are public build configuration, never client secrets.
class GoogleAuthService {
  static const serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );
  static const iosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');
  static Future<void>? _initialization;
  static bool _busy = false;

  static Future<GoogleSignInAccount?> authenticate() async {
    if (_busy) return null;
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      throw const GoogleAuthUnavailable(
        'Google sign-in is available in the Android and iPhone apps.',
      );
    }
    if (serverClientId.isEmpty ||
        (defaultTargetPlatform == TargetPlatform.iOS && iosClientId.isEmpty)) {
      throw const GoogleAuthUnavailable(
        'Google sign-in is not available yet. Please use email and password.',
      );
    }
    _busy = true;
    try {
      _initialization ??= GoogleSignIn.instance
          .initialize(
            serverClientId: serverClientId,
            clientId: defaultTargetPlatform == TargetPlatform.iOS
                ? iosClientId
                : null,
          )
          .catchError((Object error) {
            _initialization = null;
            throw error;
          });
      await _initialization;
      return await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      throw const GoogleAuthUnavailable(
        'Unable to sign in with Google. Please try again or use email and password.',
      );
    } finally {
      _busy = false;
    }
  }

  static Future<void> signOut() async {
    if (_initialization == null) return;
    try {
      await _initialization;
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // The NaijaGo session must still be cleared if the Google SDK is unavailable.
    }
  }

  static Future<String?> idToken() async {
    final account = await authenticate();
    if (account == null) return null;
    final token = account.authentication.idToken;
    if (token == null || token.isEmpty) {
      throw const GoogleAuthUnavailable(
        'Google sign-in could not be verified. Please try again.',
      );
    }
    return token;
  }
}
