import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:naija_go/main.dart' show ThemeChanger, ThemeChangerState;
import 'package:naija_go/models/product.dart';
import 'package:naija_go/providers/cart_provider.dart';
import 'package:naija_go/screens/Main/home_screen.dart' show ProductCard;
import 'package:naija_go/theme/app_theme.dart';
import 'package:naija_go/widgets/customer_bottom_navigation.dart';
import 'package:naija_go/widgets/naijago_wordmark.dart';
import 'package:naija_go/widgets/shopping_assistant_identity.dart';
import 'package:naija_go/widgets/tech_glow_background.dart';

Product fixtureProduct({
  int stock = 5,
  bool medicine = false,
  double price = 200,
}) => Product(
  id: 'local-ui-fixture',
  name: medicine ? 'Prescription fixture' : 'Original vendor photo',
  description: 'Local layout fixture',
  price: price,
  category: medicine ? 'Cosmetics & Beauty' : 'Groceries',
  subcategory: medicine ? 'Medicine' : 'Fresh Produce',
  stockQuantity: stock,
  vendorId: 'fixture-vendor',
  sellerType: 'vendor',
  sellerId: 'fixture-vendor',
  sellerName: 'NaijaGo vendor',
  requiresPrescription: medicine,
  medicineAccess: medicine ? 'prescription' : null,
  imageUrls: const ['https://fixture.example.invalid/original.jpg'],
);

class _ImageHeaders implements HttpHeaders {
  @override
  void forEach(void Function(String, List<String>) callback) {
    callback('content-type', ['image/jpeg']);
    callback('cache-control', ['max-age=3600']);
  }

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ImageResponse extends Stream<List<int>> implements HttpClientResponse {
  _ImageResponse(this.bytes);
  final Uint8List bytes;
  @override
  int get statusCode => 200;
  @override
  int get contentLength => bytes.length;
  @override
  String get reasonPhrase => 'OK';
  @override
  HttpHeaders get headers => _ImageHeaders();
  @override
  bool get isRedirect => false;
  @override
  bool get persistentConnection => false;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  List<RedirectInfo> get redirects => [];
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.value(bytes).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ImageRequest implements HttpClientRequest {
  _ImageRequest(this.bytes);
  final Uint8List bytes;
  @override
  HttpHeaders get headers => _ImageHeaders();
  @override
  bool followRedirects = true;
  @override
  int maxRedirects = 5;
  @override
  int contentLength = 0;
  @override
  bool persistentConnection = false;
  @override
  Future<void> addStream(Stream<List<int>> stream) => stream.drain<void>();
  @override
  Future<HttpClientResponse> close() async => _ImageResponse(bytes);
  @override
  void abort([Object? exception, StackTrace? stackTrace]) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ImageClient implements HttpClient {
  _ImageClient(this.bytes);
  final Uint8List bytes;
  @override
  bool autoUncompress = true;
  @override
  Future<HttpClientRequest> openUrl(String method, Uri uri) async {
    if (uri.host != 'fixture.example.invalid') {
      throw StateError('Unexpected external request in local UI test.');
    }
    return _ImageRequest(bytes);
  }

  @override
  Future<HttpClientRequest> getUrl(Uri uri) => openUrl('GET', uri);
  @override
  void close({bool force = false}) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> mountProduct(
  WidgetTester tester,
  Future<void> Function(CartProvider) action, {
  double width = 390,
  double scale = 1,
  Product? product,
  bool preview = false,
}) async {
  final cart = CartProvider();
  final data = product ?? fixtureProduct();
  final baseTheme = AppTheme.lightTheme;
  final theme = preview
      ? baseTheme.copyWith(
          textTheme: baseTheme.textTheme.apply(fontFamily: 'Roboto'),
          primaryTextTheme: baseTheme.primaryTextTheme.apply(
            fontFamily: 'Roboto',
          ),
          appBarTheme: baseTheme.appBarTheme.copyWith(
            titleTextStyle: baseTheme.appBarTheme.titleTextStyle!.copyWith(
              fontFamily: 'Roboto',
            ),
          ),
        )
      : baseTheme;
  final bytes = File('assets/categories/groceries.jpg').readAsBytesSync();
  final cache = await tester.runAsync(
    () => Directory.systemTemp.createTemp('naijago-ui-fixture-'),
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (_) async => cache!.path,
      );
  await tester.runAsync(() async {
    await CachedNetworkImageProvider.defaultCacheManager.putFile(
      data.imageUrls.first,
      bytes,
      fileExtension: 'jpg',
    );
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    PaintingBinding.instance.imageCache.putIfAbsent(
      CachedNetworkImageProvider(data.imageUrls.first),
      () => OneFrameImageStreamCompleter(
        Future.value(ImageInfo(image: frame.image)),
      ),
    );
    codec.dispose();
  });
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await HttpOverrides.runZoned(() async {
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: cart,
        child: MaterialApp(
          theme: theme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: RepaintBoundary(
            key: const ValueKey('customer-premium-preview'),
            child: Scaffold(
              appBar: AppBar(title: const NaijaGoWordmark()),
              bottomNavigationBar: CustomerBottomNavigation(
                currentIndex: 0,
                onTap: (_) {},
              ),
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (preview) ...[
                        const Text(
                          'Recommended for you',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.asset(
                            'assets/categories/groceries.jpg',
                            height: 145,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: SizedBox(
                              height:
                                  ProductCard.standardImageHeight +
                                  (ProductCard.standardCardHeight -
                                          ProductCard.standardImageHeight) *
                                      scale,
                              child: ProductCard(
                                product: data,
                                heroTag: 'fixture-photo',
                              ),
                            ),
                          ),
                          if (preview) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
                                height:
                                    ProductCard.standardImageHeight +
                                    (ProductCard.standardCardHeight -
                                            ProductCard.standardImageHeight) *
                                        scale,
                                child: ProductCard(
                                  product: fixtureProduct(stock: 0),
                                  heroTag: 'fixture-empty',
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 18),
                      ShoppingAssistantEntry(onOpen: () {}),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () async => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await action(cart);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 11));
  }, createHttpClient: (_) => _ImageClient(bytes));
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        null,
      );
}

void main() {
  test(
    'shared palette uses Royal Blue and accessible text/button contrast',
    () {
      double contrast(Color a, Color b) {
        final aa = a.computeLuminance(), bb = b.computeLuminance();
        return ((aa > bb ? aa : bb) + 0.05) / ((aa < bb ? aa : bb) + 0.05);
      }

      expect(AppTheme.logoBlue, const Color(0xFF0000FE));
      expect(AppTheme.brandBlue, const Color(0xFF4169E1));
      expect(AppTheme.primaryNavy, AppTheme.brandBlue);
      expect(AppTheme.forestGreen, AppTheme.brandBlue);
      expect(AppTheme.deepForest, AppTheme.deepBlue);
      expect(AppTheme.sageSurface, AppTheme.blueSurface);
      expect(
        contrast(AppTheme.forestGreen, Colors.white),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(AppTheme.brightBlue, Colors.white),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(AppTheme.mutedText, AppTheme.softGrey),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(AppTheme.secondaryBlack, Colors.white),
        greaterThanOrEqualTo(7),
      );
      expect(
        AppTheme.lightTheme.cardTheme.surfaceTintColor,
        Colors.transparent,
      );
      expect(
        AppTheme.lightTheme.elevatedButtonTheme.style!.minimumSize!
            .resolve({})!
            .width
            .isFinite,
        isTrue,
      );
      expect(
        AppTheme.lightTheme.outlinedButtonTheme.style!.minimumSize!
            .resolve({})!
            .width
            .isFinite,
        isTrue,
      );
    },
  );
  test('shared actions, forms and navigation use the blue brand theme', () {
    final theme = AppTheme.lightTheme;
    expect(theme.colorScheme.primary, AppTheme.brandBlue);
    expect(theme.colorScheme.surfaceContainerHighest, AppTheme.blueSurface);
    expect(theme.scaffoldBackgroundColor, AppTheme.softGrey);
    expect(theme.cardColor, Colors.white);
    expect(
      theme.elevatedButtonTheme.style!.backgroundColor!.resolve({}),
      AppTheme.brandBlue,
    );
    expect(
      theme.outlinedButtonTheme.style!.foregroundColor!.resolve({}),
      AppTheme.brandBlue,
    );
    expect(theme.floatingActionButtonTheme.backgroundColor, AppTheme.brandBlue);
    expect(
      theme.bottomNavigationBarTheme.selectedItemColor,
      AppTheme.brandBlue,
    );
    expect(theme.chipTheme.selectedColor, AppTheme.blueSurface);
    expect(
      (theme.inputDecorationTheme.focusedBorder! as OutlineInputBorder)
          .borderSide
          .color,
      AppTheme.brandBlue,
    );
    expect(
      theme.checkboxTheme.fillColor!.resolve({WidgetState.selected}),
      AppTheme.brandBlue,
    );
  });
  testWidgets(
    'stored dark mode and switching back retain readable blue themes',
    (tester) async {
      SharedPreferences.setMockInitialValues({'isDarkMode': true});
      ThemeData? activeTheme;
      await tester.pumpWidget(
        ThemeChanger(
          child: Builder(
            builder: (context) {
              activeTheme = Theme.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(activeTheme!.brightness, Brightness.dark);
      expect(activeTheme!.cardColor, AppTheme.darkSurface);
      expect(activeTheme!.colorScheme.primary, AppTheme.brandBlue);
      expect(activeTheme!.scaffoldBackgroundColor, AppTheme.secondaryBlack);
      final primary = activeTheme!.colorScheme.primary.computeLuminance();
      final onPrimary = activeTheme!.colorScheme.onPrimary.computeLuminance();
      expect(
        ((primary > onPrimary ? primary : onPrimary) + .05) /
            ((primary < onPrimary ? primary : onPrimary) + .05),
        greaterThanOrEqualTo(4.5),
      );
      tester
          .state<ThemeChangerState>(find.byType(ThemeChanger))
          .changeTheme(ThemeMode.light);
      await tester.pumpAndSettle();
      expect(activeTheme!.brightness, Brightness.light);
      expect(activeTheme!.colorScheme.primary, AppTheme.brandBlue);
      expect(activeTheme!.cardColor, Colors.white);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('all five tabs retain their original ordering and callbacks', (
    tester,
  ) async {
    final selected = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: CustomerBottomNavigation(
            currentIndex: 0,
            onTap: selected.add,
          ),
        ),
      ),
    );
    for (final label in ['Home', 'Cart', 'Categories', 'Explore', 'Account']) {
      await tester.tap(find.text(label));
    }
    expect(selected, [0, 1, 2, 3, 4]);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'product card keeps the original photo URL, naira price, seller and add-to-cart action',
    (tester) async {
      await mountProduct(tester, (cart) async {
        final image = tester.widget<CachedNetworkImage>(
          find.byType(CachedNetworkImage).first,
        );
        expect(image.imageUrl, fixtureProduct().imageUrls.first);
        expect(image.fit, BoxFit.contain);
        expect(find.text('Original vendor photo'), findsOneWidget);
        expect(find.text('NaijaGo vendor'), findsOneWidget);
        expect(find.textContaining('200.00'), findsOneWidget);
        await tester.tap(find.text('Add to Cart'));
        await tester.pump();
        expect(cart.itemCount, 1);
        expect(tester.takeException(), isNull);
      });
    },
  );
  for (final amount in [1500.0, 150000.5, 1000000.0]) {
    testWidgets('product card groups $amount without changing cart values', (
      tester,
    ) async {
      final labels = {
        1500.0: '₦1,500.00',
        150000.5: '₦150,000.50',
        1000000.0: '₦1,000,000.00',
      };
      await mountProduct(tester, (cart) async {
        expect(find.text(labels[amount]!), findsOneWidget);
        await tester.tap(find.text('Add to Cart'));
        await tester.pump();
        expect(cart.totalAmount, amount);
        expect(cart.itemCount, 1);
        expect(tester.takeException(), isNull);
      }, product: fixtureProduct(price: amount));
    });
  }
  testWidgets('sold-out and medicine consultation protections remain visible', (
    tester,
  ) async {
    await mountProduct(tester, (_) async {
      expect(find.text('Out of Stock'), findsOneWidget);
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Out of Stock'),
            )
            .onPressed,
        isNull,
      );
    }, product: fixtureProduct(stock: 0));
    await mountProduct(tester, (_) async {
      expect(find.text('Consult'), findsOneWidget);
      expect(find.text('Add to Cart'), findsNothing);
    }, product: fixtureProduct(medicine: true));
  });
  testWidgets(
    'narrow screen and enlarged text preserve controls without overflow',
    (tester) async {
      await mountProduct(
        tester,
        (_) async {
          expect(tester.takeException(), isNull);
          expect(find.text('Add to Cart'), findsOneWidget);
        },
        width: 320,
        scale: 1.3,
        preview: true,
      );
    },
  );
  testWidgets('quiet background does not intercept existing child actions', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: TechGlowBackground(
          showCommerceIcons: true,
          child: Center(
            child: TextButton(
              onPressed: () => taps++,
              child: const Text('Existing action'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Existing action'));
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('render actual shared customer widgets for local visual review', (
    tester,
  ) async {
    final directory = Platform.environment['NAIJAGO_PREMIUM_PREVIEW_DIR'];
    if (directory != null) {
      await tester.runAsync(() async {
        final font = FontLoader('Roboto');
        font.addFont(
          Future.value(
            ByteData.sublistView(
              await File('C:/Windows/Fonts/segoeui.ttf').readAsBytes(),
            ),
          ),
        );
        await font.load();
        final icons = FontLoader('MaterialIcons');
        icons.addFont(
          Future.value(
            ByteData.sublistView(
              await File(
                'C:/flutter-sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
              ).readAsBytes(),
            ),
          ),
        );
        await icons.load();
      });
    }
    await mountProduct(tester, (_) async {
      expect(tester.takeException(), isNull);
      if (directory != null) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('customer-premium-preview')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory(directory).create(recursive: true);
          await File(
            '$directory/customer-premium-preview.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    }, preview: true);
  });
}
