import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naija_go/theme/app_theme.dart';
import 'package:naija_go/widgets/naijago_wordmark.dart';
import 'package:naija_go/widgets/shopping_assistant_identity.dart';

Future<void> mount(
  WidgetTester tester, {
  double width = 390,
  double scale = 1,
  VoidCallback? onOpen,
}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final baseTheme = AppTheme.lightTheme;
  final theme = Platform.environment['NAIJAGO_BRAND_FONT_DIR'] == null
      ? baseTheme
      : baseTheme.copyWith(
          textTheme: baseTheme.textTheme.apply(fontFamily: 'Roboto'),
          primaryTextTheme: baseTheme.primaryTextTheme.apply(
            fontFamily: 'Roboto',
          ),
          appBarTheme: baseTheme.appBarTheme.copyWith(
            titleTextStyle: baseTheme.appBarTheme.titleTextStyle!.copyWith(
              fontFamily: 'Roboto',
            ),
          ),
        );
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: RepaintBoundary(
        key: const ValueKey('brand-preview'),
        child: Scaffold(
          appBar: AppBar(
            title: const NaijaGoWordmark(),
            backgroundColor: Colors.white,
          ),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ShoppingAssistantEntry(onOpen: onOpen ?? () {}),
                  const SizedBox(height: 20),
                  const ShoppingAssistantIntro(),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets(
    'home wordmark uses original logo blue for Naija and green for Go',
    (tester) async {
      await mount(tester);
      final text = tester.widget<Text>(
        find.descendant(
          of: find.byType(NaijaGoWordmark),
          matching: find.byType(Text),
        ),
      );
      final span = text.textSpan! as TextSpan;
      expect(span.toPlainText(), 'NaijaGo');
      final children = span.children!.cast<TextSpan>();
      expect(children[0].style!.color, const Color(0xFF0000FE));
      expect(children[1].style!.color, const Color(0xFF008953));
      expect(text.semanticsLabel, 'NaijaGo');
    },
  );

  testWidgets(
    'assistant has an explicit name, shopping identity and open action',
    (tester) async {
      var opens = 0;
      await mount(tester, onOpen: () => opens++);
      expect(find.text('Shopping Assistant'), findsOneWidget);
      expect(find.text('Open assistant'), findsOneWidget);
      expect(find.byIcon(Icons.shopping_bag_outlined), findsNWidgets(2));
      await tester.tap(find.text('Open assistant'));
      await tester.pump();
      expect(opens, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('whole assistant card opens the same action', (tester) async {
    var opens = 0;
    await mount(tester, onOpen: () => opens++);
    await tester.tap(find.text('Shopping Assistant'));
    await tester.pump();
    expect(opens, 1);
  });

  testWidgets(
    'assistant identity wraps safely on a narrow phone with larger text',
    (tester) async {
      await mount(tester, width: 320, scale: 1.7);
      expect(find.text('Shopping Assistant'), findsOneWidget);
      expect(find.text('Open assistant'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'renders the actual brand and assistant widgets for visual review',
    (tester) async {
      final fontDirectory = Platform.environment['NAIJAGO_BRAND_FONT_DIR'];
      if (fontDirectory != null) {
        await tester.runAsync(() async {
          final textFonts = FontLoader('Roboto');
          for (final name in [
            'roboto-regular.ttf',
            'roboto-bold.ttf',
            'roboto-black.ttf',
          ]) {
            textFonts.addFont(
              Future.value(
                ByteData.sublistView(
                  await File('$fontDirectory/$name').readAsBytes(),
                ),
              ),
            );
          }
          await textFonts.load();
          final icons = FontLoader('MaterialIcons');
          icons.addFont(
            Future.value(
              ByteData.sublistView(
                await File(
                  '$fontDirectory/materialicons-regular.otf',
                ).readAsBytes(),
              ),
            ),
          );
          await icons.load();
        });
      }
      await mount(tester);
      expect(tester.takeException(), isNull);
      final directory = Platform.environment['NAIJAGO_BRAND_PREVIEW_DIR'];
      if (directory != null) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('brand-preview')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory(directory).create(recursive: true);
          await File(
            '$directory/naijago-assistant-brand-preview.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    },
  );
}
