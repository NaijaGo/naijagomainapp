import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naija_go/theme/app_colors.dart';
import 'package:naija_go/theme/app_theme.dart';

double contrast(Color a, Color b) {
  final values = [a.computeLuminance(), b.computeLuminance()]..sort();
  return (values.last + .05) / (values.first + .05);
}

void main() {
  test(
    'Royal Blue tokens and primary controls match the requested palette',
    () {
      expect(AppColors.royalBlue, const Color(0xFF4169E1));
      expect(AppColors.darkRoyalBlue, const Color(0xFF1E3A8A));
      expect(AppColors.lightBlue, const Color(0xFFEFF6FF));
      expect(AppColors.green, const Color(0xFF16A34A));
      final theme = AppTheme.lightTheme;
      expect(theme.colorScheme.primary, AppColors.royalBlue);
      expect(theme.scaffoldBackgroundColor, AppColors.background);
      expect(
        theme.elevatedButtonTheme.style!.backgroundColor!.resolve({}),
        AppColors.royalBlue,
      );
      expect(theme.tabBarTheme.labelColor, AppColors.royalBlue);
      expect(
        contrast(AppColors.white, AppColors.royalBlue),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(AppColors.text, AppColors.background),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(AppColors.mutedText, AppColors.white),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(AppColors.successText, AppColors.successSurface),
        greaterThanOrEqualTo(4.5),
      );
    },
  );
  testWidgets('primary actions and tabs fit a small screen with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              bottom: const TabBar(
                tabs: [
                  Tab(text: 'Orders'),
                  Tab(text: 'Account'),
                ],
              ),
            ),
            body: Center(
              child: ElevatedButton(
                onPressed: () => taps++,
                child: const Text('Continue'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Continue'));
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });
  test('existing dark theme has readable primary buttons, text and links', () {
    final theme = AppTheme.darkTheme;
    expect(theme.colorScheme.primary, AppColors.royalBlue);
    expect(
      contrast(theme.colorScheme.primary, theme.colorScheme.onPrimary),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(theme.colorScheme.surface, theme.colorScheme.onSurface),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(AppColors.darkLink, AppColors.darkSurface),
      greaterThanOrEqualTo(4.5),
    );
  });
}
