import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naija_go/services/explore_service.dart';
import 'package:naija_go/screens/Main/explore_screen.dart';

void main() {
  testWidgets('feed shows real product identity and excludes expired campaign cards', (tester) async {
    final service = ExploreService(client: MockClient((_) async => http.Response(jsonEncode({
      'serverTime': DateTime.now().toUtc().toIso8601String(),
      'items': [{'id': 'product1', 'type': 'product', 'title': 'Real cotton shirt', 'sellerName': 'Verified shop', 'price': 20000,
        'media': {'kind': 'image'}, 'reactions': {}, 'comments': 0}],
      'campaigns': [{'id': 'ad1', 'title': 'Expired promotion', 'expiresAt': '2020-01-01T00:00:00Z', 'media': {'kind': 'image'}}],
    }), 200)), tokenReader: () async => 'test');
    addTearDown(service.dispose);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ExploreScreen(service: service))));
    await tester.pumpAndSettle();
    expect(find.text('Real cotton shirt'), findsOneWidget);
    expect(find.text('Verified shop'), findsOneWidget);
    expect(find.text('Expired promotion'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('feed network failure exposes a retry action instead of a false empty success', (tester) async {
    var calls = 0;
    final service = ExploreService(client: MockClient((_) async {
      calls++;
      return calls == 1 ? http.Response('{}', 503) : http.Response(jsonEncode({'items': [], 'campaigns': []}), 200);
    }), tokenReader: () async => 'test');
    addTearDown(service.dispose);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ExploreScreen(service: service))));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry')); await tester.pumpAndSettle();
    expect(calls, 2); expect(find.text('Retry'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
