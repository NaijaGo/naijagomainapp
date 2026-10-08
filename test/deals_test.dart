import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naija_go/models/deal.dart';
import 'package:naija_go/providers/deals_provider.dart';
import 'package:naija_go/services/deals_service.dart';
import 'package:naija_go/screens/Main/deals_screen.dart';
import 'package:naija_go/widgets/deal_card.dart';
import 'package:naija_go/widgets/deals_home_section.dart';

const id = 'aaaaaaaaaaaaaaaaaaaaaaaa';
const productId = 'bbbbbbbbbbbbbbbbbbbbbbbb';
const offerId = 'cccccccccccccccccccccccc';
const vendorId = 'dddddddddddddddddddddddd';
const secondId = 'eeeeeeeeeeeeeeeeeeeeeeee';
final now = DateTime.utc(2030, 1, 1, 12);
Map<String, dynamic> row({String dealId = id, DateTime? end}) => {
  '_id': dealId,
  'productId': productId,
  'productOfferId': offerId,
  'vendorId': vendorId,
  'product': {'_id': productId, 'name': 'NaijaGo Blender', 'imageUrls': []},
  'vendor': {'_id': vendorId, 'businessName': 'Lucas World'},
  'originalPrice': 10000,
  'finalPrice': 7000,
  'discountType': 'percentage',
  'discountValue': 30,
  'savingsAmount': 3000,
  'savingsPercentage': 30,
  'startAt': now.subtract(const Duration(hours: 1)).toIso8601String(),
  'endAt': (end ?? now.add(const Duration(hours: 4, minutes: 32)))
      .toIso8601String(),
  'featured': false,
};
Map<String, dynamic> page(
  List<Map<String, dynamic>> rows, {
  int number = 1,
  bool more = false,
  int? total,
  int limit = 20,
}) => {
  'deals': rows,
  'total': total ?? rows.length,
  'page': number,
  'limit': limit,
  'hasMore': more,
  'serverTime': now.toIso8601String(),
};
DealsService service(Future<http.Response> Function(http.Request) respond) {
  final client = MockClient(respond);
  addTearDown(client.close);
  return DealsService(
    get: (path) => client.get(Uri.parse('https://local.test$path')),
  );
}

http.Response response(Map<String, dynamic> data) => http.Response(
  jsonEncode(data),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  test('pagination failure preserves rows and retries the same page', () async {
    var fail = true;
    final requests = <int>[];
    final api = service((request) async {
      final number = int.parse(request.url.queryParameters['page']!);
      requests.add(number);
      if (number == 2 && fail) return http.Response('Unavailable', 503);
      return response(
        page(
          [row(dealId: number == 1 ? id : secondId)],
          number: number,
          more: number == 1,
        ),
      );
    });
    final provider = DealsProvider(service: api, clock: () => now);
    addTearDown(provider.dispose);
    await provider.refresh();
    await provider.loadMore();
    expect(provider.deals.single.id, id);
    expect(provider.error, isNotNull);
    expect(provider.hasMore, true);
    fail = false;
    await provider.retry();
    expect(requests, [1, 2, 2]);
    expect(provider.deals.map((deal) => deal.id), [id, secondId]);
    expect(provider.error, isNull);
    expect(provider.hasMore, false);
  });
  test('disposed provider ignores a pending response', () async {
    final pending = Completer<http.Response>();
    final provider = DealsProvider(service: service((_) => pending.future));
    final request = provider.refresh();
    provider.dispose();
    pending.complete(response(page([row()])));
    await request;
  });
  testWidgets('Home See All opens the paginated Deals screen', (tester) async {
    final limits = <int>[];
    final api = service((request) async {
      final limit = int.parse(request.url.queryParameters['limit']!);
      limits.add(limit);
      return response(page([], limit: limit));
    });
    addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DealsHomeSection(service: api)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('See All'));
    await tester.pumpAndSettle();
    expect(find.byType(DealsScreen), findsOneWidget);
    expect(limits, [6, 20]);
  });
  testWidgets('Deal card fits narrow layout with enlarged text', (
    tester,
  ) async {
    final api = service((_) async => response(page([])));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Builder(
              builder: (context) => SizedBox(
                width: 160,
                height: DealCard.height(context),
                child: DealCard(
                  deal: Deal.fromJson(row()),
                  now: now,
                  service: api,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
  test(
    'parses actual backend Deal prices, references and pagination without recomputing',
    () {
      final result = DealPage.fromJson(page([row()], more: true, total: 65));
      expect(result.total, 65);
      expect(result.hasMore, true);
      expect(result.page, 1);
      final deal = result.deals.single;
      expect(deal.id, id);
      expect(deal.offerId, offerId);
      expect(deal.vendorName, 'Lucas World');
      expect(deal.originalPrice, 10000);
      expect(deal.finalPrice, 7000);
      expect(deal.savingsAmount, 3000);
      expect(deal.countdownAt(now), 'Ends in 4h 32m');
    },
  );
  test(
    'missing/invalid/reversed dates are not active and do not crash countdown',
    () {
      for (final dates in [
        {'startAt': null},
        {'endAt': 'not-a-date'},
        {'startAt': now.add(const Duration(days: 2)).toIso8601String()},
      ]) {
        final deal = Deal.fromJson({...row(), ...dates});
        expect(deal.isActiveAt(now), false);
        expect(deal.remainingAt(now), Duration.zero);
        expect(deal.countdownAt(now), 'Offer ended');
      }
    },
  );
  test(
    'expired, future, paused and rejected Deals are hidden; exact expiry boundary excluded',
    () {
      for (final changes in [
        {'endAt': now.toIso8601String()},
        {'startAt': now.add(const Duration(seconds: 1)).toIso8601String()},
        {'status': 'paused'},
        {'status': 'rejected'},
      ]) {
        expect(Deal.fromJson({...row(), ...changes}).isActiveAt(now), false);
      }
      expect(
        Deal.fromJson({
          ...row(),
          'startAt': now.toIso8601String(),
        }).isActiveAt(now),
        true,
      );
    },
  );
  test(
    'readable day/minute countdown and currency preserve server decimals',
    () {
      expect(
        Deal.fromJson(
          row(end: now.add(const Duration(days: 2, hours: 3))),
        ).countdownAt(now),
        'Ends in 2d 3h',
      );
      expect(
        Deal.fromJson(
          row(end: now.add(const Duration(seconds: 90))),
        ).countdownAt(now),
        'Ends in 1m 30s',
      );
      expect(formatDealPrice(7000.5), '₦7,000.50');
    },
  );
  test(
    'malformed/non-finite/negative prices and invalid pagination fail closed',
    () {
      for (final price in [-1, 'NaN', 'Infinity', null, 10001]) {
        expect(
          () => Deal.fromJson({...row(), 'finalPrice': price}),
          throwsFormatException,
        );
      }
      expect(
        () => DealPage.fromJson({...page([]), 'deals': {}}),
        throwsFormatException,
      );
      expect(
        () => DealPage.fromJson({...page([]), 'hasMore': 'true'}),
        throwsFormatException,
      );
    },
  );
  test(
    'service requests correct endpoint/page and keeps successful empty results',
    () async {
      final api = service((request) async {
        expect(request.url.path, '/api/deals');
        expect(request.url.queryParameters, {'page': '2', 'limit': '6'});
        return response(page([], number: 2, limit: 6));
      });
      final result = await api.list(page: 2, limit: 6);
      expect(result.deals, isEmpty);
      expect(result.hasMore, false);
    },
  );
  test(
    'network/server/malformed responses are errors, never empty success',
    () async {
      for (final callback in <Future<http.Response> Function(http.Request)>[
        (_) async => throw http.ClientException('private transport details'),
        (_) async => http.Response('private exception', 503),
        (_) async => http.Response('invalid JSON', 200),
        (_) async => response(page([], number: 2)),
      ]) {
        await expectLater(
          service(callback).list(),
          throwsA(isA<DealsException>()),
        );
      }
    },
  );
  test(
    'Deal opening fetches full product and exact offer using backend price',
    () async {
      final requests = <String>[];
      final api = service((request) async {
        requests.add(request.url.path);
        if (request.url.path.startsWith('/api/deals/')) {
          return response({'deal': row(), 'serverTime': now.toIso8601String()});
        }
        return response({
          '_id': productId,
          'name': 'NaijaGo Blender',
          'description': 'Full product',
          'price': 20000,
          'effectivePrice': 15000,
          'category': 'Home Appliances',
          'stockQuantity': 5,
          'isActive': true,
          'imageUrls': [],
          'sellerType': 'vendor',
          'sellerId': vendorId,
          'vendor': {'_id': vendorId, 'businessName': 'Lucas World'},
          'selectedOffer': {'_id': secondId},
          'offers': [
            {
              '_id': offerId,
              'price': 10000,
              'discountPrice': null,
              'effectivePrice': 7000,
              'status': 'active',
              'stockQuantity': 5,
              'sellerType': 'vendor',
              'sellerId': {'_id': vendorId, 'businessName': 'Lucas World'},
              'deal': {'dealId': id},
            },
          ],
        });
      });
      final product = await api.productForDeal(Deal.fromJson(row()));
      expect(requests, ['/api/deals/$id', '/api/products/$productId']);
      expect(product.offerId, offerId);
      expect(product.price, 7000);
      expect(product.description, 'Full product');
      expect(product.sellerId, vendorId);
      expect(product.stockQuantity, 5);
    },
  );
  test(
    'opening expired Deal does not request product or invent a checkout product',
    () async {
      var calls = 0;
      final api = service((request) async {
        calls++;
        return response({
          'deal': row(end: now),
          'serverTime': now.toIso8601String(),
        });
      });
      await expectLater(
        api.productForDeal(Deal.fromJson(row())),
        throwsA(isA<DealsException>()),
      );
      expect(calls, 1);
    },
  );
  test('opening missing or changed offer fails closed', () async {
    final api = service(
      (request) async => request.url.path.startsWith('/api/deals/')
          ? response({'deal': row(), 'serverTime': now.toIso8601String()})
          : response({'_id': productId, 'isActive': true, 'offers': []}),
    );
    await expectLater(
      api.productForDeal(Deal.fromJson(row())),
      throwsA(isA<DealsException>()),
    );
  });
  test(
    'pagination deduplicates, prevents simultaneous calls and respects hasMore',
    () async {
      var calls = 0;
      final api = service((request) async {
        calls++;
        final number = int.parse(request.url.queryParameters['page']!);
        return response(
          page(
            number == 1 ? [row()] : [row(), row(dealId: secondId)],
            number: number,
            more: number == 1,
            total: 2,
          ),
        );
      });
      final provider = DealsProvider(service: api, clock: () => now);
      addTearDown(provider.dispose);
      await provider.refresh();
      await Future.wait([provider.loadMore(), provider.loadMore()]);
      expect(calls, 2);
      expect(provider.deals.map((deal) => deal.id), [id, secondId]);
      expect(provider.hasMore, false);
      await provider.loadMore();
      expect(calls, 2);
    },
  );
  test('late pagination cannot overwrite a newer refresh', () async {
    final delayed = Completer<http.Response>();
    var calls = 0;
    final api = service((request) async {
      calls++;
      if (calls == 2) return delayed.future;
      return response(
        page(calls == 1 ? [row()] : [row(dealId: secondId)], more: calls == 1),
      );
    });
    final provider = DealsProvider(service: api, clock: () => now);
    addTearDown(provider.dispose);
    await provider.refresh();
    final more = provider.loadMore();
    await provider.refresh();
    delayed.complete(response(page([row()], number: 2)));
    await more;
    expect(provider.deals.map((deal) => deal.id), [secondId]);
    expect(provider.loadingMore, false);
  });
  test(
    'server clock offset removes expired Deals without API polling',
    () async {
      var clock = now.subtract(const Duration(days: 1));
      var calls = 0;
      final provider = DealsProvider(
        clock: () => clock,
        service: service((_) async {
          calls++;
          return response(
            page([row(end: now.add(const Duration(seconds: 1)))]),
          );
        }),
      );
      addTearDown(provider.dispose);
      await provider.refresh();
      expect(provider.deals.length, 1);
      clock = clock.add(const Duration(seconds: 1));
      expect(provider.deals, isEmpty);
      expect(calls, 1);
    },
  );
  testWidgets('Deal card displays server prices, vendor, badge and countdown', (
    tester,
  ) async {
    final api = service((_) async => response(page([])));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 210,
            height: 329,
            child: DealCard(deal: Deal.fromJson(row()), now: now, service: api),
          ),
        ),
      ),
    );
    expect(find.text('NaijaGo Blender'), findsOneWidget);
    expect(find.text('Lucas World'), findsOneWidget);
    expect(find.text('₦10,000'), findsOneWidget);
    expect(find.text('₦7,000'), findsOneWidget);
    expect(find.text('30% OFF'), findsOneWidget);
    expect(find.text('Ends in 4h 32m'), findsOneWidget);
    final original = tester.widget<Text>(find.text('₦10,000'));
    expect(original.style!.decoration, TextDecoration.lineThrough);
    expect(tester.takeException(), isNull);
  });
  testWidgets('fixed Deal badge displays backend discount amount', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 210,
            height: 329,
            child: DealCard(
              deal: Deal.fromJson({
                ...row(),
                'discountType': 'fixed',
                'discountValue': 3000,
              }),
              now: now,
              service: service((_) async => response(page([]))),
            ),
          ),
        ),
      ),
    );
    expect(find.text('₦3,000 OFF'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Deals screen empty state and error retry', (tester) async {
    var calls = 0;
    final api = service((_) async {
      calls++;
      return calls == 1
          ? http.Response('private server details', 503)
          : response(page([]));
    });
    addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));
    await tester.pumpWidget(
      MaterialApp(
        home: DealsScreen(service: api, clock: () => now),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    expect(find.textContaining('private server'), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(
      find.text('No active Deals right now. Check back for new offers.'),
      findsOneWidget,
    );
  });
  testWidgets('Deals screen loads next page and ends pagination', (
    tester,
  ) async {
    final api = service((request) async {
      final number = int.parse(request.url.queryParameters['page']!);
      return response(
        page(
          [row(dealId: number == 1 ? id : secondId)],
          number: number,
          more: number == 1,
        ),
      );
    });
    addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));
    await tester.pumpWidget(
      MaterialApp(
        home: DealsScreen(service: api, clock: () => now),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Load more Deals'));
    await tester.tap(find.text('Load more Deals'));
    await tester.pumpAndSettle();
    expect(find.text('Load more Deals'), findsNothing);
    expect(find.text('You’re all caught up'), findsOneWidget);
  });
  testWidgets(
    'expired Deal disappears on local countdown tick without request',
    (tester) async {
      var clock = now;
      var calls = 0;
      final api = service((_) async {
        calls++;
        return response(page([row(end: now.add(const Duration(seconds: 1)))]));
      });
      addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));
      await tester.pumpWidget(
        MaterialApp(
          home: DealsScreen(service: api, clock: () => clock),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('NaijaGo Blender'), findsOneWidget);
      clock = now.add(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('NaijaGo Blender'), findsNothing);
      expect(calls, 1);
    },
  );
  testWidgets('Home Deals section has See All and requests only six Deals', (
    tester,
  ) async {
    final api = service((request) async {
      final limit = int.parse(request.url.queryParameters['limit']!);
      expect(limit, 6);
      return response(page([], limit: limit));
    });
    addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DealsHomeSection(service: api)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('NaijaGo Deals'), findsOneWidget);
    expect(find.text('See All'), findsOneWidget);
    expect(find.text('New Deals are coming. Check back soon.'), findsOneWidget);
  });
}
