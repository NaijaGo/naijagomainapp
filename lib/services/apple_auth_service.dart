import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AppleAuthUnavailable implements Exception {
  final String message;
  const AppleAuthUnavailable(this.message);
}

class AppleCredential {
  final String identityToken;
  final String? firstName, lastName;
  const AppleCredential(this.identityToken, {this.firstName, this.lastName});
}

class AppleAuthService {
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  static Future<AppleCredential?> authenticate(String nonce) async {
    if (!supported || !await SignInWithApple.isAvailable()) {
      throw const AppleAuthUnavailable(
        'Apple sign-in is available in the iPhone and iPad app.',
      );
    }
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );
      if (credential.identityToken?.isNotEmpty != true) {
        throw const AppleAuthUnavailable(
          'Apple did not return a valid identity. Please sign in again.',
        );
      }
      return AppleCredential(
        credential.identityToken!,
        firstName: credential.givenName,
        lastName: credential.familyName,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      throw const AppleAuthUnavailable(
        'Apple authorization could not be completed. Please try again.',
      );
    }
  }
}
