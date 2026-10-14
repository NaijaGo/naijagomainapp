import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppleCustomerSession {
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('auth_provider');
  }

  static Future<void> save(
    Map<String, dynamic> result,
    String fingerprint, {
    Future<void> Function()? clearPassword,
    Future<void> Function(String)? linkPush,
  }) async {
    final token = result['token'], user = result['user'];
    if (token is! String ||
        token.isEmpty ||
        user is! Map ||
        (user['id'] ?? user['_id']) is! String ||
        !RegExp(
          r'^[a-f0-9]{24}$',
          caseSensitive: false,
        ).hasMatch((user['id'] ?? user['_id']) as String) ||
        result['loginProvider'] != 'apple') {
      throw const FormatException('Apple session was not confirmed');
    }
    final prefs = await SharedPreferences.getInstance();
    await (clearPassword?.call() ??
        const FlutterSecureStorage().delete(key: 'user_password'));
    await prefs.remove('user_password');
    await prefs.setString('device_fingerprint', fingerprint);
    await prefs.setString('user', jsonEncode(user));
    await prefs.setString('user_email', user['email']?.toString() ?? '');
    await prefs.setString('auth_provider', 'apple');
    // Save the authoritative session only; provider credentials are never cached.
    await prefs.setString('jwt_token', token);
    try {
      await (linkPush?.call((user['id'] ?? user['_id']) as String) ??
          OneSignal.login((user['id'] ?? user['_id']) as String));
      // No Apple email, name, purchases or advertising tags are sent to OneSignal.
    } catch (_) {
      /* Notification failure must not undo verified sign-in. */
    }
  }
}
