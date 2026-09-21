import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naija_go/models/order_payment_state.dart';
import 'package:naija_go/widgets/order_payment_review_notice.dart';

void main() {
  test('all backend review markers stop another payment', () {
    for (final data in <Map<String, dynamic>>[
      {'status': 'payment_review'},
      {'isPaid': true, 'mainOrderStatus': 'payment_review'},
      {
        'isPaid': true,
        'paymentResult': {'fulfillmentStatus': 'needs_attention'},
      },
      {
        'schedule': {'state': 'needs_attention'},
      },
    ]) {
      final state = OrderPaymentState.fromJson(data);
      expect(state.needsReview, isTrue);
      expect(state.stopsNewPayment, isTrue);
      expect(state.message, contains('do not pay again'));
    }
  });
  test('unverified review does not falsely claim payment was received', () {
    final state = OrderPaymentState.fromJson({
      'mainOrderStatus': 'payment_review',
    });
    expect(state.paid, isFalse);
    expect(state.message, contains('being reviewed'));
  });
  test(
    'server-verified success is distinct from pending and gateway callbacks',
    () {
      expect(OrderPaymentState.fromJson({'status': 'verified'}).paid, isTrue);
      expect(
        OrderPaymentState.fromJson({'isPaid': true}).stopsNewPayment,
        isTrue,
      );
      expect(
        OrderPaymentState.fromJson({'status': 'successful'}).paid,
        isFalse,
      );
      expect(OrderPaymentState.fromJson({}).stopsNewPayment, isFalse);
    },
  );
  test('malformed optional fields do not crash payment presentation', () {
    final state = OrderPaymentState.fromJson({
      'isPaid': 'true',
      'paymentResult': 'bad',
      'schedule': [],
    });
    expect(state.paid, isFalse);
    expect(state.needsReview, isFalse);
  });
  testWidgets(
    'review notice wraps on a narrow screen without a payment button',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 240,
                child: OrderPaymentReviewNotice(
                  payment: OrderPaymentState.fromJson({
                    'isPaid': true,
                    'mainOrderStatus': 'payment_review',
                  }),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.textContaining('Payment received.'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('normal orders have no review notice', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OrderPaymentReviewNotice(
          payment: OrderPaymentState.fromJson({'isPaid': true}),
        ),
      ),
    );
    expect(find.byType(Text), findsNothing);
  });
}
