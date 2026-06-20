// lib/services/payment_service.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutterwave_standard/flutterwave.dart';
import 'package:uuid/uuid.dart';

class PaymentService {
  static const String _publicKeyFromBuild = String.fromEnvironment(
    'FLUTTERWAVE_PUBLIC_KEY',
  );
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
      return _publicKeyFromBuild.trim();
    }

    final envValue = _readEnv('FLUTTERWAVE_PUBLIC_KEY')?.trim();
    return envValue == null || envValue.isEmpty ? null : envValue;
  }

  bool get isTestMode {
    final rawValue = _testModeFromBuild.trim().isNotEmpty
        ? _testModeFromBuild
        : _readEnv('FLUTTERWAVE_TEST_MODE') ?? 'true';
    return rawValue.toLowerCase() == 'true';
  }

  String get redirectUrl {
    if (_redirectUrlFromBuild.trim().isNotEmpty) {
      return _redirectUrlFromBuild.trim();
    }

    final envValue = _readEnv('FLUTTERWAVE_REDIRECT_URL')?.trim();
    return envValue == null || envValue.isEmpty
        ? 'https://naijago.com/payment-redirect'
        : envValue;
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
    if (configuredPublicKey == null || configuredPublicKey.isEmpty) {
      debugPrint(
        'Missing FLUTTERWAVE_PUBLIC_KEY. Set it in .env for local runs or pass it with --dart-define in CI.',
      );
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Payment is not configured. Please contact support.'),
        ),
      );
      return null;
    }

    final txRef = 'FLW_${const Uuid().v4()}';
    final flutterwave = Flutterwave(
      publicKey: configuredPublicKey,
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
