/// Presentation of server-verified order/payment responses. Gateway callbacks
/// must not be passed here as evidence that an order is paid.
class OrderPaymentState {
  final bool paid;
  final bool needsReview;

  const OrderPaymentState({required this.paid, required this.needsReview});

  /// Compare NGN totals in kobo before opening a gateway or debiting a wallet.
  /// A refreshed backend receipt is authoritative, but a changed amount still
  /// needs a new customer review instead of silently charging that amount.
  static bool matchesApprovedTotal(num approvedTotal, dynamic receiptTotal) {
    if (receiptTotal is! num ||
        !approvedTotal.isFinite ||
        !receiptTotal.isFinite ||
        approvedTotal < 0 ||
        receiptTotal < 0) {
      return false;
    }
    final approvedKobo = approvedTotal * 100;
    final receiptKobo = receiptTotal * 100;
    const maxSafeKobo = 9007199254740991;
    if (!approvedKobo.isFinite ||
        !receiptKobo.isFinite ||
        approvedKobo > maxSafeKobo ||
        receiptKobo > maxSafeKobo) {
      return false;
    }
    return approvedKobo.round() == receiptKobo.round();
  }

  factory OrderPaymentState.fromJson(Map<String, dynamic> data) {
    final payment = data['paymentResult'];
    final schedule = data['schedule'];
    final needsReview =
        data['code'] == 'PAYMENT_RECONCILIATION_PENDING' ||
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
