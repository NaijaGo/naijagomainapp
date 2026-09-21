import 'package:flutter/material.dart';
import '../models/order_payment_state.dart';

class OrderPaymentReviewNotice extends StatelessWidget {
  final OrderPaymentState payment;
  const OrderPaymentReviewNotice({super.key, required this.payment});

  @override
  Widget build(BuildContext context) {
    if (!payment.needsReview) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.errorContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          payment.message,
          style: TextStyle(color: colors.onErrorContainer, height: 1.4),
        ),
      ),
    );
  }
}
