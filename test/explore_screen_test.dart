import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naija_go/screens/Main/explore_screen.dart';

void main() {
  testWidgets('shows the empty feed state when there are no videos', (tester) async {
    await tester.pumpWidget(MaterialApp(home: ExploreScreen(loadFeed: () async => [])));
    await tester.pumpAndSettle();
    expect(find.text('Discover NaijaGo'), findsOneWidget);
    expect(find.text('Create'), findsNothing);
  });

  testWidgets('shows the publisher action and video form only to publishers', (tester) async {
    await tester.pumpWidget(MaterialApp(home: ExploreScreen(
      canPublish: true,
      publisherLabel: 'Approved vendor',
      loadProducts: () async => [],
      loadFeed: () async => [],
    )));
    await tester.pumpAndSettle();
    expect(find.text('Create'), findsOneWidget);
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(find.text('Posting as Approved vendor'), findsOneWidget);
    expect(find.text('Publish video'), findsOneWidget);
  });
}
