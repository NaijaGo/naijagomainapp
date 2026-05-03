// lib/services/payment_service.dart
import 'package:flutter/material.dart';
import 'package:flutterwave_standard/flutterwave.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PaymentService {
  String? _readEnv(String key) {
    try {
      return dotenv.env[key];
    } catch (_) {
      return null;
    }
  }

  /// Starts a Flutterwave payment flow
  /// Returns [ChargeResponse] if successful, null otherwise
  Future<ChargeResponse?> startFlutterwavePayment({
    required BuildContext context,
    required double amount,
    required String email,
    required String name,
    required String phoneNumber,
    String? userId, // NEW: Add optional userId parameter for webhooks
  }) async {
    // --- Load keys from .env ---
    final publicKey = _readEnv('FLUTTERWAVE_PUBLIC_KEY');
    if (publicKey == null || publicKey.trim().isEmpty) {
      debugPrint("❌ [PaymentService] Missing FLUTTERWAVE_PUBLIC_KEY in .env");
      return null;
    }

    // Test mode flag (true/false in .env)
    final bool isTestMode =
        (_readEnv('FLUTTERWAVE_TEST_MODE') ?? 'true').toLowerCase() == 'true';

    // --- Generate a unique transaction reference ---
    final String txRef = 'FLW_${const Uuid().v4()}';

    // --- Initialize payment ---
    final flutterwave = Flutterwave(
      publicKey: publicKey,
      currency: 'NGN',
      redirectUrl:
          _readEnv('FLUTTERWAVE_REDIRECT_URL') ??
          'https://www.google.com', // Fallback redirect URL
      txRef: txRef,
      amount: amount.toStringAsFixed(2),
      customer: Customer(email: email, name: name, phoneNumber: phoneNumber),
      paymentOptions: "card, ussd, banktransfer",
      customization: Customization(title: 'E-commerce Payment'),
      isTestMode: isTestMode,
      // CRITICAL FIX: Add meta field with userId for webhook linking
      meta: userId != null ? {'userId': userId} : null,
    );

    try {
      debugPrint(
        "💳 [PaymentService] Initiating payment | Amount: ₦$amount | Email: $email | Ref: $txRef | UserID: ${userId ?? 'not_set'}",
      );

      final response = await flutterwave.charge(context);

      debugPrint(
        "✅ [PaymentService] Payment status: ${response.status} | Ref: ${response.txRef}",
      );
      return response;
    } catch (e, stackTrace) {
      debugPrint("❌ [PaymentService] Error: $e");
      debugPrint(stackTrace.toString());
      return null;
    }
  }
}
