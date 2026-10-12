import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naija_go/models/product.dart';
import 'package:naija_go/screens/Main/home_screen.dart' show ProductService;
import 'package:naija_go/splash_screen.dart';
import 'package:naija_go/theme/app_theme.dart';
import 'package:naija_go/widgets/vendor_logo_strip.dart';
import 'helpers/premium_preview.dart';

const vendorId = '69301d2e1e0bda27c09bcbc2';
Map<String, dynamic> productJson() => {
  '_id': 'local-product',
  'name': 'Local fixture',
  'price': 200,
  'category': 'Groceries',
  'stockQuantity': 3,
  'sellerType': 'vendor',
  'sellerId': vendorId,
  'sellerName': 'Original vendor',
  'vendor': {
    '_id': vendorId,
    'businessName': 'Original vendor',
    'businessLogoUrl': 'https://fixture.example.invalid/vendor-logo.png',
  },
};

Future<void> entrance(
  WidgetTester tester,
  VoidCallback done, {
  Size size = const Size(390, 844),
  double scale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: await previewTheme(tester, AppTheme.lightTheme),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: RepaintBoundary(
        key: const ValueKey('entrance-preview'),
        child: SplashScreen(onSplashFinished: done),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets(
    'entrance retains original brand, wording and single completion',
    (tester) async {
      var completions = 0;
      await entrance(tester, () => completions++);
      final backdrop = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('entrance-blue-gradient')),
      );
      final gradient = (backdrop.decoration as BoxDecoration).gradient!;
      expect(gradient.colors, [
        Colors.white,
        AppTheme.blueSurface,
        AppTheme.blueAccent,
      ]);
      await savePremiumPreview(
        tester,
        const ValueKey('entrance-preview'),
        'entrance',
      );
      expect(find.text('Your neighbourhood. Delivered.'), findsOneWidget);
      expect(
        find.text('Discover local businesses. Shop with confidence.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Image>(
              find.byWidgetPredicate(
                (w) =>
                    w is Image &&
                    w.image is AssetImage &&
                    (w.image as AssetImage).assetName ==
                        'assets/naijago-logo-transparent.png',
              ),
            )
            .image,
        isA<AssetImage>(),
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('entrance-continue')),
      );
      await tester.tap(find.byKey(const ValueKey('entrance-continue')));
      await tester.tap(find.text('Skip'));
      await tester.pump(const Duration(seconds: 11));
      expect(completions, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'entrance automatic timeout and disposal preserve startup behavior',
    (tester) async {
      var completions = 0;
      await entrance(tester, () => completions++);
      await tester.pump(const Duration(seconds: 10));
      expect(completions, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      await entrance(tester, () => completions++);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 11));
      expect(completions, 1);
    },
  );
  testWidgets('entrance scrolls on small screens with enlarged text', (
    tester,
  ) async {
    var completions = 0;
    await entrance(
      tester,
      () => completions++,
      size: const Size(320, 568),
      scale: 1.6,
    );
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byKey(const ValueKey('entrance-continue')));
    await tester.tap(find.byKey(const ValueKey('entrance-continue')));
    expect(completions, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  test('original logo survives parsing and local catalogue cache', () {
    final product = Product.fromJson(productJson());
    final cached = Product.fromJson(product.toJson());
    expect(cached.vendorBusinessLogoUrl, product.vendorBusinessLogoUrl);
    expect(VendorLogoEntry.fromProducts([product, cached]).single.id, vendorId);
    expect(
      VendorLogoEntry.fromProducts([cached]).single.name,
      'Original vendor',
    );
  });
  test('vendor row omits inactive, unknown and mismatched sellers', () {
    final inactive = productJson()..['isActive'] = false;
    final otherSeller = productJson()
      ..['sellerId'] = 'aaaaaaaaaaaaaaaaaaaaaaaa';
    final own = productJson()..['sellerType'] = 'naijago';
    final missing = productJson()..['vendor'] = '';
    expect(
      VendorLogoEntry.fromProducts(
        [inactive, otherSeller, own, missing].map(Product.fromJson),
      ),
      isEmpty,
    );
    final legacy = productJson()..['vendor'] = vendorId;
    expect(
      VendorLogoEntry.fromProducts([Product.fromJson(legacy)]).single.logoUrl,
      isNull,
    );
  });
  testWidgets('vendor name and fallback remain clickable on a small screen', (
    tester,
  ) async {
    VendorLogoEntry? opened;
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const entry = VendorLogoEntry(
      id: vendorId,
      name: 'Original vendor',
      logoUrl: 'not-a-url',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: VendorLogoStrip(
              vendors: const [entry],
              onOpen: (value) => opened = value,
            ),
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.storefront_outlined), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('vendor-logo-$vendorId')));
    expect(opened?.id, vendorId);
    expect(tester.takeException(), isNull);
  });
  testWidgets('empty vendor collection hides the row', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VendorLogoStrip(vendors: const [], onOpen: (_) {}),
        ),
      ),
    );
    expect(find.text('Shop by vendor'), findsNothing);
  });
  test(
    'vendor catalogue requests every page with the chosen vendor filter',
    () async {
      final pages = <String>[];
      final client = MockClient((request) async {
        expect(request.url.path, '/api/products/search');
        expect(request.url.queryParameters['vendor'], vendorId);
        expect(request.url.queryParameters['q'], '');
        pages.add(request.url.queryParameters['page']!);
        return http.Response(
          jsonEncode({
            'products': [],
            'total': 31,
            'page': int.parse(pages.last),
            'hasMore': pages.last == '1',
          }),
          200,
        );
      });
      addTearDown(client.close);
      final service = ProductService(searchClient: client);
      expect(
        (await service.searchProducts('', vendor: vendorId)).hasMore,
        isTrue,
      );
      expect(
        (await service.searchProducts('', vendor: vendorId, page: 2)).hasMore,
        isFalse,
      );
      expect(pages, ['1', '2']);
    },
  );
}
