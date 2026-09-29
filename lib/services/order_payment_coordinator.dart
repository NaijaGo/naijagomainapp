import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants.dart';
import '../models/hosted_checkout.dart';
import '../models/order_payment_state.dart';
import 'payment_service.dart';

class OrderPaymentResult {
  const OrderPaymentResult({required this.completed, required this.message});
  final bool completed;
  final String message;
}

class OrderPaymentCoordinator {
  OrderPaymentCoordinator({http.Client? client})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;
  final http.Client _client;
  final bool _ownsClient;

  Map<String, dynamic> _json(String body) {
    try {
      final value = jsonDecode(body);
      return value is Map
          ? Map<String, dynamic>.from(value)
          : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<OrderPaymentResult> pay(
    BuildContext context, {
    required String orderId,
    required double approvedTotal,
    required String paymentMethod,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null || token.isEmpty) {
      return const OrderPaymentResult(
        completed: false,
        message: 'Please sign in again before paying.',
      );
    }
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token',
    };
    if (paymentMethod == 'Wallet') {
      final response = await _client
          .put(
            Uri.parse('$baseUrl/api/orders/$orderId/pay/wallet'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 35));
      final data = _json(response.body);
      return OrderPaymentResult(
        completed: response.statusCode == 200,
        message:
            data['message']?.toString() ??
            (response.statusCode == 200
                ? 'Order paid successfully.'
                : 'Wallet payment could not be completed.'),
      );
    }

    final intentResponse = await _client
        .post(
          Uri.parse('$baseUrl/api/orders/$orderId/payment-intent'),
          headers: headers,
          body: jsonEncode({
            'supported_payment_providers': ['korapay', 'squad', 'flutterwave'],
          }),
        )
        .timeout(const Duration(seconds: 35));
    final intent = _json(intentResponse.body);
    if (intentResponse.statusCode != 200 && intentResponse.statusCode != 201) {
      return OrderPaymentResult(
        completed: false,
        message: intent['message']?.toString() ?? 'Unable to prepare payment.',
      );
    }
    final intentState = OrderPaymentState.fromJson(intent);
    if (intentState.stopsNewPayment) {
      return OrderPaymentResult(completed: true, message: intentState.message);
    }
    final reference = intent['tx_ref']?.toString();
    final amount = (intent['amount'] as num?)?.toDouble();
    if (reference == null ||
        reference.isEmpty ||
        amount == null ||
        !OrderPaymentState.matchesApprovedTotal(approvedTotal, amount)) {
      return const OrderPaymentResult(
        completed: false,
        message: 'The payment total changed. Refresh and review it again.',
      );
    }
    final provider = intent['provider']?.toString().trim().toLowerCase() ?? '';
    String clientStatus;
    if (HostedCheckout.supports(provider)) {
      final checkout = HostedCheckout.validatedUrl(
        provider,
        intent['checkout_url'],
      );
      if (checkout == null ||
          !await launchUrl(checkout, mode: LaunchMode.externalApplication)) {
        return const OrderPaymentResult(
          completed: false,
          message: 'Unable to open the secure payment page.',
        );
      }
      if (!context.mounted) {
        return const OrderPaymentResult(
          completed: false,
          message: 'Payment was not verified.',
        );
      }
      final verify = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Complete your payment'),
          content: Text(
            'Finish payment on the secure ${HostedCheckout.label(provider)} page, return to NaijaGo, then tap Verify payment. Do not pay twice.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('I did not pay'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Verify payment'),
            ),
          ],
        ),
      );
      clientStatus = verify == true
          ? 'customer_requested_verification'
          : 'customer_did_not_complete';
    } else if (provider == 'flutterwave') {
      if (!context.mounted) {
        return const OrderPaymentResult(
          completed: false,
          message: 'Payment was not started.',
        );
      }
      final response = await PaymentService().startFlutterwavePayment(
        context: context,
        amount: amount,
        email: prefs.getString('email') ?? 'customer@example.com',
        name: prefs.getString('fullName') ?? 'NaijaGo customer',
        phoneNumber: prefs.getString('phoneNumber') ?? '',
        transactionReference: reference,
      );
      clientStatus = response?.status ?? 'unknown_from_client';
    } else {
      return const OrderPaymentResult(
        completed: false,
        message: 'This payment option is unavailable. Please contact support.',
      );
    }

    final confirm = await _client
        .put(
          Uri.parse('$baseUrl/api/orders/$orderId/pay'),
          headers: headers,
          body: jsonEncode({
            'transaction_id': reference,
            'status': clientStatus,
            'update_time': DateTime.now().toIso8601String(),
            'email_address': prefs.getString('email') ?? '',
          }),
        )
        .timeout(const Duration(seconds: 45));
    final data = _json(confirm.body);
    final state = OrderPaymentState.fromJson(data);
    final accepted =
        confirm.statusCode == 200 ||
        confirm.statusCode == 202 ||
        state.needsReview;
    return OrderPaymentResult(
      completed: accepted,
      message:
          data['message']?.toString() ??
          (accepted
              ? 'Payment is being confirmed. Do not pay twice.'
              : 'Payment could not be confirmed.'),
    );
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }
}
