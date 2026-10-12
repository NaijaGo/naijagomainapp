import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ThemeData> previewTheme(WidgetTester tester, ThemeData base) async {
  if (Platform.environment['NAIJAGO_PREMIUM_PREVIEW_DIR'] == null) return base;
  await tester.runAsync(() async {
    for (final font in {
      'Roboto': 'C:/Windows/Fonts/segoeui.ttf',
      'MaterialIcons':
          'C:/flutter-sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    }.entries) {
      final loader = FontLoader(font.key);
      loader.addFont(
        Future.value(
          ByteData.sublistView(await File(font.value).readAsBytes()),
        ),
      );
      await loader.load();
    }
  });
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: 'Roboto'),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'Roboto'),
    appBarTheme: base.appBarTheme.copyWith(
      titleTextStyle: base.appBarTheme.titleTextStyle!.copyWith(
        fontFamily: 'Roboto',
      ),
    ),
  );
}

Future<void> savePremiumPreview(
  WidgetTester tester,
  Key key,
  String name,
) async {
  final directory = Platform.environment['NAIJAGO_PREMIUM_PREVIEW_DIR'];
  if (directory == null) return;
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 200)),
  );
  await tester.pump(const Duration(milliseconds: 100));
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(directory).create(recursive: true);
    await File(
      '$directory/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
