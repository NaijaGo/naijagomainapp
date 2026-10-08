import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naija_go/widgets/order_tracking_widget.dart';

void main() {
  Future<void> showOrder(
    WidgetTester tester,
    Map<String, dynamic> order,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: OrderTrackingWidget(order: order)),
        ),
      ),
    );
  }

  testWidgets(
    'unpaid processing shipment does not show completed payment or preparation',
    (tester) async {
      await showOrder(tester, {
        'isPaid': false,
        'mainOrderStatus': 'pending_payment',
        'shipmentStatus': 'processing',
      });
      expect(find.text('Payment pending'), findsOneWidget);
      expect(
        find.text('Preparation starts after payment confirmation.'),
        findsOneWidget,
      );
      expect(
        find.text('The vendor is preparing your items for dispatch.'),
        findsNothing,
      );
      expect(find.byIcon(Icons.check), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unpaid shipment cannot advance payment through a later shipment status',
    (tester) async {
      await showOrder(tester, {
        'isPaid': false,
        'mainOrderStatus': 'pending_payment',
        'shipmentStatus': 'out_for_delivery',
      });
      expect(find.text('Payment pending'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'backend-confirmed paid processing order retains its existing progress',
    (tester) async {
      await showOrder(tester, {
        'isPaid': true,
        'mainOrderStatus': 'processing',
        'shipmentStatus': 'processing',
      });
      expect(find.text('Payment confirmed'), findsOneWidget);
      expect(
        find.text('The vendor is preparing your items for dispatch.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.check), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );
}
