// lib/services/payment_service.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutterwave_standard/flutterwave.dart';
import 'package:uuid/uuid.dart';

class PaymentService {
  static const String _publicKeyFromBuild = String.fromEnvironment(
    'FLUTTERWAVE_PUBLIC_KEY',
  );
  // Flutterwave public keys are client-side identifiers. Keep secret keys on
  // the backend only.
  static const String _publicKeyFallback =
      'FLWPUBK-772dd96b7e735ec7acf62240aaaf1989-X';
  static const String _testModeFromBuild = String.fromEnvironment(
    'FLUTTERWAVE_TEST_MODE',
  );
  static const String _redirectUrlFromBuild = String.fromEnvironment(
    'FLUTTERWAVE_REDIRECT_URL',
  );

  String? _readEnv(String key) {
    try {
      return dotenv.env[key];
    } catch (_) {
      return null;
    }
  }

  String? get publicKey {
    if (_publicKeyFromBuild.trim().isNotEmpty) {
      return _normalizeEnvValue(_publicKeyFromBuild);
    }

    final envValue = _readEnv('FLUTTERWAVE_PUBLIC_KEY')?.trim();
    if (envValue != null && envValue.isNotEmpty) {
      return _normalizeEnvValue(envValue);
    }

    return _publicKeyFallback;
  }

  bool get isTestMode {
    final rawValue = _normalizeEnvValue(
      _testModeFromBuild.trim().isNotEmpty
          ? _testModeFromBuild
          : _readEnv('FLUTTERWAVE_TEST_MODE') ?? 'false',
    );
    return rawValue.toLowerCase() == 'true';
  }

  String get redirectUrl {
    if (_redirectUrlFromBuild.trim().isNotEmpty) {
      return _normalizeEnvValue(_redirectUrlFromBuild);
    }

    final envValue = _normalizeEnvValue(_readEnv('FLUTTERWAVE_REDIRECT_URL'));
    return envValue.isEmpty ? 'https://naijago.com/payment-redirect' : envValue;
  }

  String _normalizeEnvValue(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.length >= 2 &&
        ((trimmed.startsWith('"') && trimmed.endsWith('"')) ||
            (trimmed.startsWith("'") && trimmed.endsWith("'")))) {
      return trimmed.substring(1, trimmed.length - 1).trim();
    }
    return trimmed;
  }

  String? _publicKeyConfigError(String? key) {
    final normalized = _normalizeEnvValue(key);
    if (normalized.isEmpty) {
      return 'Missing FLUTTERWAVE_PUBLIC_KEY.';
    }

    if (normalized.contains(' ') ||
        normalized.contains('\n') ||
        normalized.contains('\r')) {
      return 'FLUTTERWAVE_PUBLIC_KEY contains whitespace.';
    }

    if (normalized.startsWith('FLWSECK') ||
        normalized.startsWith('FLWSECK_TEST')) {
      return 'FLUTTERWAVE_PUBLIC_KEY is set to a secret key. Use the public key from Flutterwave instead.';
    }

    final isTestKey = normalized.startsWith('FLWPUBK_TEST-');
    final isLiveKey =
        normalized.startsWith('FLWPUBK-') &&
        !normalized.startsWith('FLWPUBK_TEST-');
    if (!isTestKey && !isLiveKey) {
      return 'FLUTTERWAVE_PUBLIC_KEY has an invalid format. Expected FLWPUBK_TEST-... for test mode or FLWPUBK-... for live mode.';
    }

    if (isTestMode && !isTestKey) {
      return 'FLUTTERWAVE_TEST_MODE is true, but FLUTTERWAVE_PUBLIC_KEY is not a test public key.';
    }

    if (!isTestMode && !isLiveKey) {
      return 'FLUTTERWAVE_TEST_MODE is false, but FLUTTERWAVE_PUBLIC_KEY is not a live public key.';
    }

    return null;
  }

  Future<ChargeResponse?> startFlutterwavePayment({
    required BuildContext context,
    required double amount,
    required String email,
    required String name,
    required String phoneNumber,
    String? userId,
    String title = 'NaijaGo Payment',
  }) async {
    final configuredPublicKey = publicKey;
    final configError = _publicKeyConfigError(configuredPublicKey);
    if (configError != null) {
      debugPrint('$configError Set it with --dart-define in CI/local builds.');
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Payment is not configured. Please contact support.'),
        ),
      );
      return null;
    }

    final flutterwavePublicKey = configuredPublicKey!;
    final txRef = 'FLW_${const Uuid().v4()}';
    final flutterwave = Flutterwave(
      publicKey: flutterwavePublicKey,
      currency: 'NGN',
      redirectUrl: redirectUrl,
      txRef: txRef,
      amount: amount.toStringAsFixed(2),
      customer: Customer(email: email, name: name, phoneNumber: phoneNumber),
      paymentOptions: 'card, ussd, banktransfer',
      customization: Customization(title: title),
      isTestMode: isTestMode,
      meta: userId != null ? {'userId': userId} : null,
    );

    try {
      debugPrint(
        'Initiating Flutterwave payment | Amount: NGN $amount | Email: $email | Ref: $txRef | UserID: ${userId ?? 'not_set'}',
      );

      final response = await flutterwave.charge(context);

      debugPrint(
        'Flutterwave payment status: ${response.status} | Ref: ${response.txRef}',
      );
      return response;
    } catch (error, stackTrace) {
      debugPrint('Flutterwave payment error: $error');
      debugPrint(stackTrace.toString());
      return null;
    }
  }
}
