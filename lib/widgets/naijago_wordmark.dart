import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class NaijaGoWordmark extends StatelessWidget {
  const NaijaGoWordmark({super.key});

  @override
  Widget build(BuildContext context) => const Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: 'Naija',
          style: TextStyle(color: AppTheme.logoBlue),
        ),
        TextSpan(
          text: 'Go',
          style: TextStyle(color: AppTheme.logoGreen),
        ),
      ],
    ),
    semanticsLabel: 'NaijaGo',
    style: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.2,
    ),
  );
}
