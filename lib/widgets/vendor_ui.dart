import 'package:flutter/material.dart';

class VendorUi {
  static const Color deepNavyBlue = Color(0xFF03024C);
  static const Color greenYellow = Color(0xFFB7FFD4);
  static const Color whiteBackground = Colors.white;
  static const Color blue = Color(0xFF0D2E91);
  static const Color surface = Color(0xFFF4F7FB);
  static const Color border = Color(0xFFD8E1F0);
  static const Color softText = Color(0xFFD9E4F6);
  static const Color textMuted = Color(0xFF5B6886);
  static const Color success = Color(0xFF1E9E67);
  static const Color warning = Color(0xFFE0A325);
  static const Color danger = Color(0xFFC64848);

  static final ThemeData theme = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: surface,
    colorScheme: ColorScheme.fromSeed(
      seedColor: deepNavyBlue,
      brightness: Brightness.light,
      primary: deepNavyBlue,
      secondary: greenYellow,
      surface: whiteBackground,
      error: danger,
      onPrimary: whiteBackground,
      onSecondary: deepNavyBlue,
      onSurface: deepNavyBlue,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: deepNavyBlue,
      foregroundColor: whiteBackground,
      titleTextStyle: TextStyle(
        color: whiteBackground,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: deepNavyBlue,
      contentTextStyle: TextStyle(color: whiteBackground),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: whiteBackground,
      hintStyle: const TextStyle(color: textMuted),
      labelStyle: const TextStyle(
        color: textMuted,
        fontWeight: FontWeight.w600,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: deepNavyBlue, width: 1.3),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: danger, width: 1.3),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: deepNavyBlue,
        foregroundColor: whiteBackground,
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: deepNavyBlue,
        side: const BorderSide(color: border),
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: deepNavyBlue,
      foregroundColor: whiteBackground,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: deepNavyBlue.withValues(alpha: 0.06),
      selectedColor: greenYellow,
      disabledColor: border,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      side: const BorderSide(color: border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      labelStyle: const TextStyle(
        color: textMuted,
        fontWeight: FontWeight.w600,
      ),
      secondaryLabelStyle: const TextStyle(
        color: deepNavyBlue,
        fontWeight: FontWeight.w700,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return deepNavyBlue;
        }
        return whiteBackground;
      }),
      checkColor: WidgetStateProperty.all(whiteBackground),
      side: const BorderSide(color: border),
    ),
    dividerTheme: const DividerThemeData(color: border, thickness: 1),
  );

  static BoxDecoration panelDecoration({
    Color color = whiteBackground,
    double radius = 24,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: border),
      boxShadow: [
        BoxShadow(
          color: deepNavyBlue.withValues(alpha: 0.06),
          blurRadius: 20,
          offset: const Offset(0, 12),
        ),
      ],
    );
  }

  static BoxDecoration heroDecoration() {
    return BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [deepNavyBlue, blue],
      ),
      borderRadius: BorderRadius.circular(28),
      boxShadow: [
        BoxShadow(
          color: deepNavyBlue.withValues(alpha: 0.18),
          blurRadius: 30,
          offset: const Offset(0, 16),
        ),
      ],
    );
  }
}

class VendorPageHero extends StatelessWidget {
  final String badge;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> stats;

  const VendorPageHero({
    super.key,
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.stats = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: VendorUi.heroDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _VendorHeroBadge(label: badge)),
              Container(
                height: 56,
                width: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: VendorUi.whiteBackground.withValues(alpha: 0.12),
                ),
                child: Icon(icon, color: VendorUi.whiteBackground, size: 28),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              color: VendorUi.whiteBackground,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              color: VendorUi.softText,
              fontSize: 15,
              height: 1.55,
            ),
          ),
          if (stats.isNotEmpty) ...[
            const SizedBox(height: 24),
            Wrap(spacing: 24, runSpacing: 14, children: stats),
          ],
        ],
      ),
    );
  }
}

class VendorPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const VendorPanel({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: VendorUi.panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: VendorUi.deepNavyBlue,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: VendorUi.textMuted, height: 1.5),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

class VendorHeroStat extends StatelessWidget {
  final String label;
  final String value;

  const VendorHeroStat({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: VendorUi.softText,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: VendorUi.whiteBackground,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _VendorHeroBadge extends StatelessWidget {
  final String label;

  const _VendorHeroBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: VendorUi.whiteBackground.withValues(alpha: 0.12),
          border: Border.all(
            color: VendorUi.whiteBackground.withValues(alpha: 0.14),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: VendorUi.whiteBackground,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
