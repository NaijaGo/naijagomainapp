import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ShoppingAssistantEntry extends StatelessWidget {
  const ShoppingAssistantEntry({super.key, required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(22),
    child: InkWell(
      key: const ValueKey('open-shopping-assistant'),
      onTap: onOpen,
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppTheme.logoBlue.withValues(alpha: 0.16)),
          gradient: LinearGradient(
            colors: [
              AppTheme.logoBlue.withValues(alpha: 0.045),
              Colors.white,
              AppTheme.logoGreen.withValues(alpha: 0.07),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AssistantMark(),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Shopping Assistant',
                        style: TextStyle(
                          color: AppTheme.primaryNavy,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Tell us what you need. Find products that fit your budget.',
                        style: TextStyle(
                          color: AppTheme.mutedText,
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.logoBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      'Open assistant',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class ShoppingAssistantIntro extends StatelessWidget {
  const ShoppingAssistantIntro({super.key});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppTheme.logoBlue.withValues(alpha: 0.12)),
      gradient: LinearGradient(
        colors: [
          AppTheme.logoBlue.withValues(alpha: 0.055),
          AppTheme.logoGreen.withValues(alpha: 0.07),
        ],
      ),
    ),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AssistantMark(),
        SizedBox(height: 16),
        Text(
          'Tell us what you need',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppTheme.primaryNavy,
            height: 1.2,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Describe a product or budget and explore matching NaijaGo listings.',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.secondaryBlack,
            height: 1.5,
          ),
        ),
      ],
    ),
  );
}

class _AssistantMark extends StatelessWidget {
  const _AssistantMark();

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: 54,
      height: 54,
      child: Stack(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.logoBlue,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.shopping_bag_outlined,
              color: Colors.white,
              size: 28,
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 25,
              height: 25,
              decoration: BoxDecoration(
                color: AppTheme.logoGreen,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 14,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
