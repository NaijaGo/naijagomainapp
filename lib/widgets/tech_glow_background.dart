import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Calm brand backdrop for the existing account and authentication screens.
class TechGlowBackground extends StatelessWidget {
  const TechGlowBackground({
    super.key,
    required this.child,
    this.showCommerceIcons = false,
  });
  final Widget child;
  final bool showCommerceIcons;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppTheme.forestGreen, AppTheme.deepForest],
      ),
    ),
    child: Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          top: -110,
          right: -95,
          child: IgnorePointer(
            child: Container(
              width: 310,
              height: 310,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.sageAccent.withValues(alpha: 0.065),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -140,
          left: -110,
          child: IgnorePointer(
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.sageAccent.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
            ),
          ),
        ),
        if (showCommerceIcons)
          Positioned(
            top: 70,
            left: 24,
            child: IgnorePointer(
              child: Icon(
                Icons.shopping_bag_outlined,
                size: 64,
                color: AppTheme.sageAccent.withValues(alpha: 0.065),
              ),
            ),
          ),
        child,
      ],
    ),
  );
}
