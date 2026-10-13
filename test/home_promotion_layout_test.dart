import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naija_go/models/product.dart';
import 'package:naija_go/screens/Main/home_screen.dart';
import 'package:naija_go/theme/app_theme.dart';
import 'package:naija_go/widgets/deals_home_section.dart';
import 'package:naija_go/widgets/restaurant_photo_banner.dart';
import 'package:naija_go/widgets/shopping_assistant_identity.dart';
import 'helpers/premium_preview.dart';
import 'shopping_assistant_test.dart' as fixtures;

Product meal(
  String id, {
  bool active = true,
  bool closed = false,
  int stock = 5,
  String category = 'Restaurant',
  String subcategory = '',
  List<String>? photos,
}) => Product(
  id: id,
  name: 'Food $id',
  description: 'Fixture only',
  price: 200,
  category: category,
  subcategory: subcategory,
  stockQuantity: stock,
  isActive: active,
  vendorId: 'aaaaaaaaaaaaaaaaaaaaaaaa',
  vendorBusinessName: 'Restaurant fixture',
  vendorTemporarilyClosed: closed,
  imageUrls: photos ?? ['https://fixture.example.invalid/$id.jpg'],
);
Future<void> mountFood(
  WidgetTester tester,
  List<Product> products,
  ValueChanged<Product> onOpen, {
  bool reduceMotion = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: RestaurantPhotoBanner(products: products, onOpen: onOpen),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  for (final width in [320.0, 390.0, 600.0]) {
    for (final dark in [false, true]) {
      for (final scale in [1.0, 1.5]) {
        testWidgets(
          'food framing shows full photo at $width, dark=$dark, text=$scale',
          (tester) async {
            tester.view.physicalSize = Size(width, 800);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final product = meal('full-dish');
            Product? opened;
            await tester.pumpWidget(
              MaterialApp(
                theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
                home: Scaffold(
                  body: MediaQuery(
                    data: MediaQueryData(
                      size: Size(width, 800),
                      disableAnimations: true,
                      textScaler: TextScaler.linear(scale),
                    ),
                    child: SizedBox(
                      // Exercise a banner narrower than the viewport too.
                      width: width > 390 ? 390 : width,
                      child: RestaurantPhotoBanner(
                        products: [product],
                        onOpen: (value) => opened = value,
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pump(const Duration(milliseconds: 100));
            final photo = find.byType(CachedNetworkImage);
            final image = tester.widget<CachedNetworkImage>(photo);
            expect(image.fit, BoxFit.contain);
            expect(image.alignment, Alignment.center);
            expect(image.imageUrl, product.imageUrls.first);
            final banner = tester.getRect(
              find.byKey(const ValueKey('restaurant-photo-full-dish')),
            );
            final photoBounds = tester.getRect(photo);
            expect(photoBounds.right, closeTo(banner.right - 10, .01));
            expect(photoBounds.top, closeTo(banner.top + 10, .01));
            expect(photoBounds.bottom, closeTo(banner.bottom - 10, .01));
            expect(
              tester.getRect(find.text(product.name)).right,
              lessThan(photoBounds.left),
            );
            final title = tester.widget<Text>(find.text(product.name));
            expect(
              title.style!.color,
              (dark ? AppTheme.darkTheme : AppTheme.lightTheme)
                  .colorScheme
                  .onSurface,
            );
            expect(tester.takeException(), isNull);
            await tester.tap(photo);
            expect(opened, same(product));
            await tester.pumpWidget(const SizedBox.shrink());
          },
        );
      }
    }
  }
  test(
    'food banner uses original URLs, excludes unavailable items and deduplicates',
    () {
      final original = meal('one');
      final rows = RestaurantPhotoBanner.visibleProducts([
        original,
        original,
        meal('inactive', active: false),
        meal('closed', closed: true),
        meal('sold', stock: 0),
        meal('fashion', category: 'Fashion'),
        meal('medicine', subcategory: 'Medicine'),
        meal('empty', photos: []),
      ]);
      expect(rows, [original]);
      expect(
        RestaurantPhotoBanner.photoUrl(rows.single),
        original.imageUrls.first,
      );
      expect(
        RestaurantPhotoBanner.photoUrl(
          meal('bad', photos: ['data:image/png,abc', 'file:///secret']),
        ),
        isNull,
      );
    },
  );
  testWidgets(
    'food photos can be swiped, tapped and replaced by refreshed menu items',
    (tester) async {
      Product? opened;
      final first = meal('one'), second = meal('two');
      await mountFood(tester, [first, second], (value) => opened = value);
      expect(
        tester
            .widget<CachedNetworkImage>(find.byType(CachedNetworkImage).first)
            .imageUrl,
        first.imageUrls.first,
      );
      await tester.tap(find.byKey(const ValueKey('restaurant-photo-one')));
      expect(opened, same(first));
      await tester.drag(find.byType(PageView), const Offset(-800, 0));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const ValueKey('restaurant-photo-two')));
      expect(opened, same(second));
      await mountFood(tester, [meal('fresh')], (value) => opened = value);
      await tester.pump();
      expect(find.text('Food fresh'), findsOneWidget);
      expect(find.text('Food one'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 11));
    },
  );
  testWidgets('food rotation respects reduced motion and cancels on disposal', (
    tester,
  ) async {
    await mountFood(tester, [meal('one'), meal('two')], (_) {});
    await tester.pump(const Duration(seconds: 7));
    expect(tester.widget<PageView>(find.byType(PageView)).controller!.page, 0);
    await mountFood(
      tester,
      [meal('one'), meal('two')],
      (_) {},
      reduceMotion: false,
    );
    await tester.pump(const Duration(seconds: 3));
    await mountFood(
      tester,
      [meal('one'), meal('two')],
      (_) {},
      reduceMotion: false,
    );
    // Complete the MaterialApp theme transition before measuring the timer.
    // Its inherited theme updates can restart the banner's dependencies.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.widget<PageView>(find.byType(PageView)).controller!.page, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 11));
    expect(tester.takeException(), isNull);
  });
  testWidgets('no restaurant photos means no invented breakfast promotion', (
    tester,
  ) async {
    await mountFood(tester, [], (_) {});
    expect(find.byType(PageView), findsNothing);
    expect(find.textContaining('Breakfast'), findsNothing);
  });
  testWidgets(
    'actual Home uses wide banners, compact AI and no side cart or Deals prefetch',
    (tester) async {
      await fixtures.localReads(() async {
        await fixtures.show(tester, const HomeScreen());
        await tester.binding.setSurfaceSize(const Size(390, 844));
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(ShoppingAssistantEntry), findsNothing);
        expect(find.text('AI assistant'), findsOneWidget);
        expect(find.byTooltip('Open cart'), findsNothing);
        final height = tester
            .getSize(find.byKey(const ValueKey('home-main-banners')))
            .height;
        expect(height, closeTo((390 - 32) / 2.6, .01));
        expect(
          find.byKey(const ValueKey('main-banner-home-low-cost')),
          findsOneWidget,
        );
        expect(
          tester.getSize(find.byKey(const ValueKey('home-main-banners'))).width,
          closeTo(390 - 32, .01),
        );
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('low-cost-entry-banner')),
          200,
          scrollable: find
              .descendant(
                of: find.byType(CustomScrollView).first,
                matching: find.byType(Scrollable),
              )
              .first,
        );
        final lowCostSize = tester.getSize(
          find.byKey(const ValueKey('low-cost-entry-banner')),
        );
        expect(lowCostSize.width, closeTo(390 - 32, .01));
        expect(lowCostSize.height, closeTo((390 - 32) / 2.6, .01));
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('open-naijago-deals')),
          250,
          scrollable: find
              .descendant(
                of: find.byType(CustomScrollView).first,
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(find.byType(DealsHomeSection), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 11));
      });
    },
  );
  testWidgets(
    'new Deals artwork renders with original branding at phone width',
    (tester) async {
      tester.view.physicalSize = const Size(390, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: await previewTheme(tester, AppTheme.lightTheme),
          home: RepaintBoundary(
            key: const ValueKey('deals-banner-preview'),
            child: const Scaffold(body: Center(child: DealsHomeSection())),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await savePremiumPreview(
        tester,
        const ValueKey('deals-banner-preview'),
        'deals-banner',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
