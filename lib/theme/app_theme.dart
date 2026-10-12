import 'package:flutter/material.dart';

import 'app_tokens.dart';

class AppTheme {
  // Original blue/green wordmark, sampled from assets/naijago-brand.jpg.
  static const Color logoBlue = Color(0xFF0000FE);
  static const Color logoGreen = Color(0xFF008953);

  // Muted blue UI palette; the original logo colours remain above.
  static const Color brandBlue = Color(0xFF365D9B);
  static const Color deepBlue = Color(0xFF1D2D47);
  static const Color brightBlue = Color(0xFF5274A8);
  static const Color blueSurface = Color(0xFFF2F5FA);
  static const Color blueAccent = Color(0xFFDFE7F3);
  static const Color darkSurface = Color(0xFF24334B);

  // Existing screens retain these aliases; all resolve to the blue palette.
  static const Color forestGreen = brandBlue;
  static const Color deepForest = deepBlue;
  static const Color leafGreen = brightBlue;
  static const Color sageSurface = blueSurface;
  static const Color sageAccent = blueAccent;
  static const Color warmGold = Color(0xFFD7AC50);
  static const Color primaryNavy = forestGreen;
  static const Color deepNavy = deepForest;
  static const Color accentBlue = brightBlue;
  static const Color accentGreen = leafGreen;
  static const Color dangerRed = Color(0xFFEF4444);

  // Neutral colors
  static const Color secondaryBlack = Color(0xFF182238);
  static const Color softGrey = Color(0xFFF7F9FD);
  static const Color cardWhite = Colors.white;
  static const Color borderGrey = Color(0xFFE2E8F2);
  static const Color mutedText = Color(0xFF5E6A7F);

  static ThemeData get lightTheme {
    final base = ThemeData.light(useMaterial3: true);

    return base.copyWith(
      brightness: Brightness.light,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      scaffoldBackgroundColor: softGrey,
      primaryColor: primaryNavy,
      splashColor: accentBlue.withValues(alpha: 0.08),
      highlightColor: Colors.transparent,

      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: primaryNavy,
        onPrimary: Colors.white,
        secondary: accentBlue,
        onSecondary: Colors.white,
        error: dangerRed,
        onError: Colors.white,
        surface: cardWhite,
        surfaceContainerHighest: sageSurface,
        onSurface: secondaryBlack,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: secondaryBlack,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        iconTheme: IconThemeData(color: secondaryBlack),
        titleTextStyle: TextStyle(
          color: secondaryBlack,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),

      iconTheme: const IconThemeData(color: secondaryBlack, size: 22),

      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w800,
          color: secondaryBlack,
          letterSpacing: -0.4,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: secondaryBlack,
          letterSpacing: -0.3,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: secondaryBlack,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: secondaryBlack,
        ),
        bodyLarge: TextStyle(fontSize: 16, color: secondaryBlack, height: 1.5),
        bodyMedium: TextStyle(fontSize: 14, color: secondaryBlack, height: 1.5),
        bodySmall: TextStyle(fontSize: 12.5, color: mutedText, height: 1.4),
      ),

      cardColor: cardWhite,

      cardTheme: CardThemeData(
        color: cardWhite,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: borderGrey),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        margin: EdgeInsets.zero,
      ),

      dividerColor: borderGrey,

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: primaryNavy,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFE5E7EB),
          disabledForegroundColor: const Color(0xFF9CA3AF),
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryNavy,
          side: const BorderSide(color: borderGrey),
          minimumSize: const Size(64, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryNavy,
          textStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardWhite,
        hintStyle: const TextStyle(color: mutedText, fontSize: 14),
        labelStyle: const TextStyle(color: mutedText, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: borderGrey, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: borderGrey, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: primaryNavy, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: dangerRed, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: dangerRed, width: 1.4),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: sageSurface,
        disabledColor: const Color(0xFFE5E7EB),
        selectedColor: primaryNavy,
        secondarySelectedColor: primaryNavy,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        labelStyle: const TextStyle(
          color: secondaryBlack,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: const TextStyle(
          color: Colors.white,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: secondaryBlack,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryNavy,
      ),

      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: const BorderSide(color: borderGrey),
        fillColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? forestGreen : null,
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: forestGreen,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: cardWhite,
        selectedItemColor: forestGreen,
        unselectedItemColor: mutedText,
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardWhite,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: cardWhite,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
      ),
    );
  }
}
