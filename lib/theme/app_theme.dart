import 'package:flutter/material.dart';

import 'app_tokens.dart';

class AppTheme {
  // Brand colors
  static const Color primaryNavy = Color(0xFF102B5C);
  static const Color deepNavy = Color(0xFF081A3A);
  static const Color accentBlue = Color(0xFF3B82F6);
  static const Color accentGreen = Color(0xFF16A34A);
  static const Color dangerRed = Color(0xFFEF4444);

  // Neutral colors
  static const Color secondaryBlack = Color(0xFF111827);
  static const Color softGrey = Color(0xFFF5F7FB);
  static const Color cardWhite = Colors.white;
  static const Color borderGrey = Color(0xFFE5E7EB);
  static const Color mutedText = Color(0xFF6B7280);

  static ThemeData get lightTheme {
    final base = ThemeData.light(useMaterial3: true);

    return base.copyWith(
      brightness: Brightness.light,
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
        onSurface: secondaryBlack,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: secondaryBlack,
        elevation: 0,
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
        shape: RoundedRectangleBorder(
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
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryNavy,
          side: const BorderSide(color: borderGrey),
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryNavy,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
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
        backgroundColor: const Color(0xFFF3F6FA),
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
