/// Presentation of server-verified order/payment responses. Gateway callbacks
/// must not be passed here as evidence that an order is paid.
class OrderPaymentState {
  final bool paid;
  final bool needsReview;

  const OrderPaymentState({required this.paid, required this.needsReview});

  factory OrderPaymentState.fromJson(Map<String, dynamic> data) {
    final payment = data['paymentResult'];
    final schedule = data['schedule'];
    final needsReview =
        data['mainOrderStatus'] == 'payment_review' ||
        data['status'] == 'payment_review' ||
        (payment is Map && payment['fulfillmentStatus'] == 'needs_attention') ||
        (schedule is Map && schedule['state'] == 'needs_attention');
    return OrderPaymentState(
      paid:
          data['isPaid'] == true ||
          data['status'] == 'verified' ||
          data['status'] == 'payment_review',
      needsReview: needsReview,
    );
  }

  bool get stopsNewPayment => paid || needsReview;

  String get message {
    if (needsReview) {
      return paid
          ? 'Payment received. Your order needs support review before preparation. Please do not pay again. Check My Orders or contact support with your order number.'
          : 'Your payment is being reviewed. Please do not pay again. Check My Orders or contact support with your order number.';
    }
    return paid
        ? 'Payment confirmed. Track your order in My Orders.'
        : 'Payment confirmation is pending. Please do not pay again. Check My Orders for updates.';
  }
}
