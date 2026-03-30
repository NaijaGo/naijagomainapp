import 'package:flutter/material.dart';

class PharmacyUi {
  static const Color deepNavy = Color(0xFF031B4E);
  static const Color teal = Color(0xFF138C7A);
  static const Color mint = Color(0xFFD9F6EE);
  static const Color surface = Color(0xFFF4FAF8);
  static const Color card = Colors.white;
  static const Color border = Color(0xFFD6E7E3);
  static const Color mutedText = Color(0xFF5F726E);
  static const Color success = Color(0xFF1E9B6D);
  static const Color warning = Color(0xFFE2A53A);
  static const Color danger = Color(0xFFC85E5E);

  static final ThemeData theme = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: surface,
    colorScheme: ColorScheme.fromSeed(
      seedColor: deepNavy,
      brightness: Brightness.light,
      primary: deepNavy,
      secondary: teal,
      surface: card,
      error: danger,
      onPrimary: card,
      onSecondary: card,
      onSurface: deepNavy,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: deepNavy,
      foregroundColor: card,
      titleTextStyle: TextStyle(
        color: card,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: deepNavy,
      contentTextStyle: TextStyle(color: card),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: card,
      hintStyle: const TextStyle(color: mutedText),
      labelStyle: const TextStyle(
        color: mutedText,
        fontWeight: FontWeight.w600,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: deepNavy, width: 1.3),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: danger, width: 1.3),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: deepNavy,
        foregroundColor: card,
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: deepNavy,
        minimumSize: const Size(0, 52),
        side: const BorderSide(color: border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: deepNavy.withValues(alpha: 0.06),
      selectedColor: mint,
      side: const BorderSide(color: border),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
      ),
      labelStyle: const TextStyle(
        color: mutedText,
        fontWeight: FontWeight.w600,
      ),
      secondaryLabelStyle: const TextStyle(
        color: deepNavy,
        fontWeight: FontWeight.w700,
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: border,
      thickness: 1,
    ),
  );

  static BoxDecoration heroDecoration() {
    return BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [deepNavy, teal],
      ),
      borderRadius: BorderRadius.circular(28),
      boxShadow: [
        BoxShadow(
          color: deepNavy.withValues(alpha: 0.16),
          blurRadius: 28,
          offset: const Offset(0, 16),
        ),
      ],
    );
  }

  static BoxDecoration panelDecoration({
    Color color = card,
    double radius = 24,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: border),
      boxShadow: [
        BoxShadow(
          color: deepNavy.withValues(alpha: 0.05),
          blurRadius: 18,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }
}

class PharmacyHero extends StatelessWidget {
  final String badge;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> stats;

  const PharmacyHero({
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
      decoration: PharmacyUi.heroDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _HeroBadge(label: badge),
              ),
              Container(
                height: 56,
                width: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: PharmacyUi.card.withValues(alpha: 0.12),
                ),
                child: Icon(
                  icon,
                  color: PharmacyUi.card,
                  size: 28,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              color: PharmacyUi.card,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFFE5FAF4),
              fontSize: 15,
              height: 1.55,
            ),
          ),
          if (stats.isNotEmpty) ...[
            const SizedBox(height: 24),
            Wrap(
              spacing: 24,
              runSpacing: 14,
              children: stats,
            ),
          ],
        ],
      ),
    );
  }
}

class PharmacyStat extends StatelessWidget {
  final String label;
  final String value;

  const PharmacyStat({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFE5FAF4),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: PharmacyUi.card,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class PharmacyPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const PharmacyPanel({
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
      decoration: PharmacyUi.panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: PharmacyUi.deepNavy,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: PharmacyUi.mutedText,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  final String label;

  const _HeroBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: PharmacyUi.card.withValues(alpha: 0.12),
          border: Border.all(color: PharmacyUi.card.withValues(alpha: 0.16)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: PharmacyUi.card,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
