import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naija_go/models/order_payment_state.dart';
import 'package:naija_go/widgets/order_payment_review_notice.dart';

void main() {
  test(
    'payment cannot exceed or silently change the total the customer reviewed',
    () {
      expect(OrderPaymentState.matchesApprovedTotal(2500, 2500.0), isTrue);
      expect(
        OrderPaymentState.matchesApprovedTotal(10.10, 10.10000000001),
        isTrue,
      );
      expect(OrderPaymentState.matchesApprovedTotal(2500, 2501), isFalse);
      expect(OrderPaymentState.matchesApprovedTotal(2500, 2499), isFalse);
      for (final value in [
        null,
        '2500',
        -1,
        double.nan,
        double.infinity,
        1e100,
      ]) {
        expect(OrderPaymentState.matchesApprovedTotal(2500, value), isFalse);
      }
      expect(OrderPaymentState.matchesApprovedTotal(double.nan, 2500), isFalse);
    },
  );
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
    'delayed reconciliation blocks repeat checkout without claiming a paid receipt',
    () {
      final state = OrderPaymentState.fromJson({
        'code': 'PAYMENT_RECONCILIATION_PENDING',
      });
      expect(state.paid, isFalse);
      expect(state.needsReview, isTrue);
      expect(state.stopsNewPayment, isTrue);
      expect(state.message, contains('do not pay again'));
      expect(state.message, isNot(contains('Payment received')));
      expect(
        OrderPaymentState.fromJson({'code': 'SERVER_ERROR'}).stopsNewPayment,
        isFalse,
      );
      expect(
        OrderPaymentState.fromJson({
          'code': 'PAYMENT_QUOTE_CHANGED',
        }).stopsNewPayment,
        isFalse,
      );
    },
  );
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
